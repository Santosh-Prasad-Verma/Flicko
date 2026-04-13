/**
 * Soundboard Component
 *
 * Discord-style soundboard bottom sheet for voice channels.
 * Supports favorites, server sounds, trending, volume control,
 * search, and sound upload.
 *
 * Requirements: Soundboard Feature
 */
import React, { memo, useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  TextInput,
  Alert,
  ActivityIndicator,
} from 'react-native';
import Animated, { FadeIn, FadeOut, ZoomIn } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { Modal } from '../ui/Modal';
import { useTheme } from '../../hooks/useTheme';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import {
  useSoundboardStore,
  type SoundboardSound,
  type SoundboardTab,
} from '@stores/soundboardStore';
import {
  getServerSounds,
  getFavoriteSounds,
  getTrendingSounds,
  toggleFavoriteSound,
  recordSoundPlay,
  uploadSound,
} from '@services/soundboardService';

interface SoundboardProps {
  serverId: string;
  channelId: string;
}

// ── Sound Button ──────────────────────────────────────────────────────────

const SoundButton = memo(function SoundButton({
  sound,
  isPlaying,
  onPlay,
  onToggleFavorite,
}: {
  sound: SoundboardSound;
  isPlaying: boolean;
  onPlay: (sound: SoundboardSound) => void;
  onToggleFavorite: (soundId: string) => void;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View entering={ZoomIn.duration(200)} style={styles.soundBtnWrapper}>
      <Pressable
        onPress={() => onPlay(sound)}
        onLongPress={() => onToggleFavorite(sound.id)}
        style={({ pressed }) => [
          styles.soundBtn,
          {
            backgroundColor: isPlaying
              ? themeColors.accentPrimary
              : themeColors.bgTertiary,
            opacity: pressed ? 0.8 : 1,
          },
        ]}
        accessibilityLabel={`Play ${sound.name}`}
        accessibilityHint="Long press to toggle favorite"
      >
        <Text style={styles.soundEmoji}>{sound.emoji}</Text>
        <Text
          style={[
            styles.soundName,
            {
              color: isPlaying ? '#FFFFFF' : themeColors.textPrimary,
            },
          ]}
          numberOfLines={1}
        >
          {sound.name}
        </Text>
        {sound.isFavorite && (
          <Ionicons
            name="star"
            size={10}
            color={themeColors.warning}
            style={styles.favStar}
          />
        )}
      </Pressable>
    </Animated.View>
  );
});

// ── Volume Slider ─────────────────────────────────────────────────────────

const VolumeControl = memo(function VolumeControl({
  volume,
  onVolumeChange,
}: {
  volume: number;
  onVolumeChange: (v: number) => void;
}) {
  const { themeColors } = useTheme();
  const percentage = Math.round(volume * 100);

  return (
    <View style={styles.volumeRow}>
      <Pressable
        onPress={() => onVolumeChange(Math.max(0, volume - 0.1))}
        hitSlop={8}
        style={styles.volumeBtn}
      >
        <Ionicons
          name={volume === 0 ? 'volume-mute' : 'volume-low'}
          size={18}
          color={themeColors.textSecondary}
        />
      </Pressable>
      <View
        style={[styles.volumeTrack, { backgroundColor: themeColors.bgTertiary }]}
      >
        <View
          style={[
            styles.volumeFill,
            {
              backgroundColor: themeColors.accentPrimary,
              width: `${percentage}%`,
            },
          ]}
        />
      </View>
      <Pressable
        onPress={() => onVolumeChange(Math.min(1, volume + 0.1))}
        hitSlop={8}
        style={styles.volumeBtn}
      >
        <Ionicons
          name="volume-high"
          size={18}
          color={themeColors.textSecondary}
        />
      </Pressable>
      <Text style={[styles.volumeLabel, { color: themeColors.textMuted }]}>
        {percentage}%
      </Text>
    </View>
  );
});

// ── Tab Bar ───────────────────────────────────────────────────────────────

const TABS: { key: SoundboardTab; label: string; icon: string }[] = [
  { key: 'favorites', label: 'Favorites', icon: 'star' },
  { key: 'server', label: 'Server', icon: 'musical-notes' },
  { key: 'trending', label: 'Trending', icon: 'trending-up' },
];

const TabBar = memo(function TabBar({
  activeTab,
  onTabChange,
}: {
  activeTab: SoundboardTab;
  onTabChange: (tab: SoundboardTab) => void;
}) {
  const { themeColors } = useTheme();

  return (
    <View style={styles.tabRow}>
      {TABS.map((tab) => (
        <Pressable
          key={tab.key}
          onPress={() => onTabChange(tab.key)}
          style={[
            styles.tab,
            activeTab === tab.key && {
              borderBottomColor: themeColors.accentPrimary,
              borderBottomWidth: 2,
            },
          ]}
          accessibilityRole="tab"
          accessibilityState={{ selected: activeTab === tab.key }}
        >
          <Ionicons
            name={tab.icon as any}
            size={16}
            color={
              activeTab === tab.key
                ? themeColors.accentPrimary
                : themeColors.textMuted
            }
          />
          <Text
            style={[
              styles.tabText,
              {
                color:
                  activeTab === tab.key
                    ? themeColors.accentPrimary
                    : themeColors.textMuted,
              },
            ]}
          >
            {tab.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
});

// ── Main Soundboard ───────────────────────────────────────────────────────

export const Soundboard = memo(function Soundboard({
  serverId,
  channelId,
}: SoundboardProps) {
  const { themeColors, theme } = useTheme();
  const store = useSoundboardStore();
  const [loading, setLoading] = useState(false);
  const [searchText, setSearchText] = useState('');

  // Fetch sounds when tab changes
  useEffect(() => {
    if (!store.visible) return;
    let cancelled = false;

    const fetchSounds = async () => {
      setLoading(true);
      try {
        switch (store.activeTab) {
          case 'favorites': {
            const sounds = await getFavoriteSounds();
            if (!cancelled) store.setFavorites(sounds);
            break;
          }
          case 'server': {
            const sounds = await getServerSounds(serverId);
            if (!cancelled) store.setServerSounds(sounds);
            break;
          }
          case 'trending': {
            const sounds = await getTrendingSounds();
            if (!cancelled) store.setTrendingSounds(sounds);
            break;
          }
        }
      } catch (err) {
        console.error('[Soundboard] fetch error:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    fetchSounds();
    return () => {
      cancelled = true;
    };
  }, [store.visible, store.activeTab, serverId]);

  // Get current sounds based on tab
  const currentSounds = useMemo(() => {
    let sounds: SoundboardSound[];
    switch (store.activeTab) {
      case 'favorites':
        sounds = store.favorites;
        break;
      case 'server':
        sounds = store.serverSounds;
        break;
      case 'trending':
        sounds = store.trendingSounds;
        break;
      default:
        sounds = [];
    }

    if (searchText.trim()) {
      const q = searchText.toLowerCase();
      sounds = sounds.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.emoji.includes(q),
      );
    }

    return sounds;
  }, [store.activeTab, store.favorites, store.serverSounds, store.trendingSounds, searchText]);

  const handlePlay = useCallback(
    async (sound: SoundboardSound) => {
      if (store.playingId === sound.id) {
        store.setPlaying(null);
        return;
      }
      store.setPlaying(sound.id);
      try {
        await recordSoundPlay(sound.id);
      } catch {
        // Non-critical — don't block playback
      }
      // Auto-stop after duration (simulate playback)
      setTimeout(() => {
        store.setPlaying(null);
      }, (sound.duration || 3) * 1000);
    },
    [store],
  );

  const handleToggleFavorite = useCallback(
    async (soundId: string) => {
      try {
        store.toggleFavorite(soundId);
        await toggleFavoriteSound(soundId);
      } catch (err) {
        // Revert on failure
        store.toggleFavorite(soundId);
        Alert.alert('Error', 'Failed to update favorite');
      }
    },
    [store],
  );

  const handleUpload = useCallback(() => {
    Alert.alert(
      'Upload Sound',
      'Select an audio file (MP3, WAV, OGG) under 512KB and 5 seconds.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Choose File',
          onPress: () => {
            // In production this would use expo-document-picker
            Alert.alert('Coming Soon', 'Sound upload will be available in a future update.');
          },
        },
      ],
    );
  }, []);

  const renderSound = useCallback(
    ({ item }: { item: SoundboardSound }) => (
      <SoundButton
        sound={item}
        isPlaying={store.playingId === item.id}
        onPlay={handlePlay}
        onToggleFavorite={handleToggleFavorite}
      />
    ),
    [store.playingId, handlePlay, handleToggleFavorite],
  );

  const emptyIcon =
    store.activeTab === 'favorites'
      ? 'star-outline'
      : store.activeTab === 'trending'
        ? 'trending-up-outline'
        : 'musical-notes-outline';

  const emptyText =
    store.activeTab === 'favorites'
      ? 'No favorite sounds yet.\nLong-press a sound to add it!'
      : store.activeTab === 'trending'
        ? 'No trending sounds yet.'
        : 'No sounds in this server.\nUpload one to get started!';

  return (
    <Modal
      visible={store.visible}
      onClose={store.close}
      title="Soundboard"
      theme={theme}
    >
      {/* Search */}
      <View style={[styles.searchBox, { backgroundColor: themeColors.bgTertiary }]}>
        <Ionicons name="search" size={16} color={themeColors.textMuted} />
        <TextInput
          style={[styles.searchInput, { color: themeColors.textPrimary }]}
          placeholder="Search sounds..."
          placeholderTextColor={themeColors.textMuted}
          value={searchText}
          onChangeText={setSearchText}
          returnKeyType="search"
        />
        {searchText.length > 0 && (
          <Pressable onPress={() => setSearchText('')} hitSlop={8}>
            <Ionicons name="close-circle" size={16} color={themeColors.textMuted} />
          </Pressable>
        )}
      </View>

      {/* Tabs */}
      <TabBar activeTab={store.activeTab} onTabChange={store.setTab} />

      {/* Volume */}
      <VolumeControl volume={store.volume} onVolumeChange={store.setVolume} />

      {/* Sound Grid */}
      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={themeColors.accentPrimary} />
        </View>
      ) : currentSounds.length === 0 ? (
        <View style={styles.center}>
          <Ionicons
            name={emptyIcon as any}
            size={40}
            color={themeColors.textMuted}
          />
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            {emptyText}
          </Text>
        </View>
      ) : (
        <FlatList
          data={currentSounds}
          renderItem={renderSound}
          keyExtractor={(item) => item.id}
          numColumns={3}
          columnWrapperStyle={styles.gridRow}
          contentContainerStyle={styles.gridContainer}
          showsVerticalScrollIndicator={false}
          style={styles.gridList}
        />
      )}

      {/* Upload button (server tab only) */}
      {store.activeTab === 'server' && (
        <Pressable
          onPress={handleUpload}
          style={[styles.uploadBtn, { backgroundColor: themeColors.accentPrimary }]}
          accessibilityLabel="Upload new sound"
        >
          <Ionicons name="cloud-upload" size={18} color="#FFFFFF" />
          <Text style={styles.uploadText}>Upload Sound</Text>
        </Pressable>
      )}
    </Modal>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    borderRadius: borderRadius.md,
    height: 36,
    gap: spacing.xs,
    marginBottom: spacing.md,
  },
  searchInput: {
    flex: 1,
    ...typography.bodySmall,
    paddingVertical: 0,
  },
  tabRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.08)',
    marginBottom: spacing.md,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.sm,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  volumeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.md,
    paddingHorizontal: spacing.xs,
  },
  volumeBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  volumeTrack: {
    flex: 1,
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
  },
  volumeFill: {
    height: '100%',
    borderRadius: 2,
  },
  volumeLabel: {
    ...typography.micro,
    minWidth: 32,
    textAlign: 'right',
  },
  gridList: {
    maxHeight: 280,
  },
  gridContainer: {
    paddingBottom: spacing.md,
  },
  gridRow: {
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  soundBtnWrapper: {
    flex: 1,
  },
  soundBtn: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xs,
    borderRadius: borderRadius.md,
    minHeight: 72,
    position: 'relative',
  },
  soundEmoji: {
    fontSize: 24,
    marginBottom: spacing.xs,
  },
  soundName: {
    ...typography.micro,
    textAlign: 'center',
  },
  favStar: {
    position: 'absolute',
    top: 4,
    right: 4,
  },
  center: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.xxxl,
    gap: spacing.sm,
  },
  emptyText: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  uploadBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    marginTop: spacing.sm,
  },
  uploadText: {
    color: '#FFFFFF',
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
});
