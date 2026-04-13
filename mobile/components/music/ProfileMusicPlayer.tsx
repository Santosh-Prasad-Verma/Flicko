/**
 * Profile Music Player Component
 *
 * Allows users to search for and play music previews on their profile.
 * Shows currently playing track with artwork, progress, and controls.
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  FlatList,
  Modal,
  ActivityIndicator,
  Linking,
  Alert,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { useAudioPlayer, formatTime } from '../../hooks/useAudioPlayer';
import {
  useMusicSearch,
  MusicTrack,
  MusicSource,
  getSourceDisplayName,
} from '../../services/musicApi.service';
import { MusicSourceBadge } from '../music/MusicSourceBadge';
import { spacing, typography } from '../../constants/Colors';

export interface ProfileMusicTrack {
  id: string;
  name: string;
  artist: string;
  album?: string;
  imageUrl?: string;
  previewUrl?: string;
  externalUrl?: string;
  source: MusicSource;
}

interface ProfileMusicPlayerProps {
  /** Currently selected track (persisted in profile) */
  currentTrack?: ProfileMusicTrack | null;
  /** Called when user selects a new track */
  onTrackChange?: (track: ProfileMusicTrack | null) => void;
  /** Whether this is the user's own profile (can edit) */
  isOwnProfile?: boolean;
}

export function ProfileMusicPlayer({
  currentTrack,
  onTrackChange,
  isOwnProfile = false,
}: ProfileMusicPlayerProps) {
  const { themeColors } = useTheme();
  const [showPicker, setShowPicker] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const audio = useAudioPlayer(currentTrack?.previewUrl);

  // Search for tracks
  const { data: searchResults = [], isLoading: searchLoading } = useMusicSearch({
    query: searchQuery,
    type: 'track',
    limit: 15,
  });

  const handleSelectTrack = useCallback(
    (track: MusicTrack) => {
      const profileTrack: ProfileMusicTrack = {
        id: track.id,
        name: track.name,
        artist: track.artistName,
        album: track.albumName,
        imageUrl: track.imageUrl,
        previewUrl: track.previewUrl,
        externalUrl: track.externalUrl,
        source: track.source,
      };
      onTrackChange?.(profileTrack);
      setShowPicker(false);
      setSearchQuery('');

      // Play the preview if available
      if (track.previewUrl) {
        audio.loadAndPlay(track.previewUrl);
      }
    },
    [onTrackChange, audio]
  );

  const handleClearTrack = useCallback(() => {
    audio.stop();
    onTrackChange?.(null);
  }, [audio, onTrackChange]);

  // Open song in external streaming app
  const handleOpenInApp = useCallback(async () => {
    if (!currentTrack?.externalUrl) {
      Alert.alert('Not Available', 'No external link available for this track.');
      return;
    }

    try {
      const canOpen = await Linking.canOpenURL(currentTrack.externalUrl);
      if (canOpen) {
        await Linking.openURL(currentTrack.externalUrl);
      } else {
        Alert.alert(
          'App Not Installed',
          `Install ${getSourceDisplayName(currentTrack.source)} to play the full song.`
        );
      }
    } catch (error) {
      Alert.alert('Error', 'Could not open the link.');
    }
  }, [currentTrack]);

  // No track selected - show placeholder or add button
  if (!currentTrack) {
    if (!isOwnProfile) return null;

    return (
      <View style={styles.container}>
        <Pressable
          style={[styles.addMusicButton, { backgroundColor: themeColors.bgTertiary }]}
          onPress={() => setShowPicker(true)}
        >
          <Ionicons name="musical-notes" size={20} color={themeColors.textMuted} />
          <Text style={[styles.addMusicText, { color: themeColors.textMuted }]}>
            Add music to your profile
          </Text>
        </Pressable>

        {/* Search Modal */}
        <MusicPickerModal
          visible={showPicker}
          onClose={() => setShowPicker(false)}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          results={searchResults as MusicTrack[]}
          isLoading={searchLoading}
          onSelectTrack={handleSelectTrack}
          themeColors={themeColors}
        />
      </View>
    );
  }

  // Track is selected - show player
  const progress = audio.duration > 0 ? (audio.position / audio.duration) * 100 : 0;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
          LISTENING TO
        </Text>
        <MusicSourceBadge source={currentTrack.source} showLabel size="small" />
      </View>

      <View style={[styles.playerCard, { backgroundColor: themeColors.bgTertiary }]}>
        {/* Album Art */}
        <Pressable
          style={styles.albumArt}
          onPress={audio.toggle}
          accessibilityLabel={audio.isPlaying ? 'Pause' : 'Play'}
        >
          {currentTrack.imageUrl ? (
            <Image
              source={{ uri: currentTrack.imageUrl }}
              style={styles.albumImage}
              contentFit="cover"
            />
          ) : (
            <View style={[styles.albumPlaceholder, { backgroundColor: themeColors.bgSecondary }]}>
              <Ionicons name="musical-notes" size={24} color={themeColors.textMuted} />
            </View>
          )}
          {/* Play/Pause overlay */}
          <View style={styles.playOverlay}>
            {audio.isLoading ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Ionicons
                name={audio.isPlaying ? 'pause' : 'play'}
                size={24}
                color="#fff"
              />
            )}
          </View>
        </Pressable>

        {/* Track Info */}
        <View style={styles.trackInfo}>
          <Text
            style={[styles.trackName, { color: themeColors.textPrimary }]}
            numberOfLines={1}
          >
            {currentTrack.name}
          </Text>
          <Text
            style={[styles.artistName, { color: themeColors.textMuted }]}
            numberOfLines={1}
          >
            {currentTrack.artist}
          </Text>
          {currentTrack.album && (
            <Text
              style={[styles.albumName, { color: themeColors.textMuted }]}
              numberOfLines={1}
            >
              {currentTrack.album}
            </Text>
          )}
        </View>

        {/* Actions */}
        {isOwnProfile && (
          <View style={styles.actions}>
            <Pressable
              style={styles.actionButton}
              onPress={() => setShowPicker(true)}
              accessibilityLabel="Change track"
            >
              <Ionicons name="swap-horizontal" size={18} color={themeColors.textMuted} />
            </Pressable>
            <Pressable
              style={styles.actionButton}
              onPress={handleClearTrack}
              accessibilityLabel="Remove track"
            >
              <Ionicons name="close" size={18} color={themeColors.textMuted} />
            </Pressable>
          </View>
        )}
      </View>

      {/* Progress Bar */}
      {audio.isLoaded && (
        <View style={styles.progressContainer}>
          <View style={[styles.progressBar, { backgroundColor: themeColors.bgSecondary }]}>
            <View
              style={[
                styles.progressFill,
                { backgroundColor: themeColors.accentPrimary, width: `${progress}%` },
              ]}
            />
          </View>
          <View style={styles.progressTimes}>
            <Text style={[styles.timeText, { color: themeColors.textMuted }]}>
              {formatTime(audio.position)}
            </Text>
            <Text style={[styles.timeText, { color: themeColors.textMuted }]}>
              {formatTime(audio.duration)}
            </Text>
          </View>
        </View>
      )}

      {/* Open in App Button */}
      {currentTrack.externalUrl && (
        <View style={{ gap: spacing.xs }}>
          <Pressable
            style={[styles.openInAppButton, { backgroundColor: themeColors.bgTertiary }]}
            onPress={handleOpenInApp}
            accessibilityLabel={`Play full song in ${getSourceDisplayName(currentTrack.source)}`}
          >
            <Ionicons name="open-outline" size={16} color={themeColors.textPrimary} />
            <Text style={[styles.openInAppText, { color: themeColors.textPrimary }]}>
              Play full song in {getSourceDisplayName(currentTrack.source)}
            </Text>
          </Pressable>

          <Pressable
            style={[styles.openInAppButton, { backgroundColor: themeColors.bgTertiary }]}
            onPress={async () => {
              const cmd = `/play ${currentTrack.externalUrl}`;
              try {
                const Clipboard = (await import('expo-clipboard')).default;
                await Clipboard.setStringAsync(cmd);
                Alert.alert('Command Copied!', 'Paste this into any Server chat to invoke the Music Bot.');
              } catch {
                Alert.alert('Manual Command', `Type: ${cmd}`);
              }
            }}
            accessibilityLabel={`Copy music bot command`}
          >
            <Ionicons name="terminal" size={16} color={themeColors.accentPrimary} />
            <Text style={[styles.openInAppText, { color: themeColors.accentPrimary }]}>
              Copy Bot Command (/play)
            </Text>
          </Pressable>
        </View>
      )}

      {/* Preview notice */}
      {currentTrack.previewUrl && !currentTrack.externalUrl && (
        <Text style={[styles.previewNotice, { color: themeColors.textMuted }]}>
          30-second preview
        </Text>
      )}

      {/* Search Modal */}
      <MusicPickerModal
        visible={showPicker}
        onClose={() => setShowPicker(false)}
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        results={searchResults as MusicTrack[]}
        isLoading={searchLoading}
        onSelectTrack={handleSelectTrack}
        themeColors={themeColors}
      />
    </View>
  );
}

// Music picker modal component
interface MusicPickerModalProps {
  visible: boolean;
  onClose: () => void;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  results: MusicTrack[];
  isLoading: boolean;
  onSelectTrack: (track: MusicTrack) => void;
  themeColors: any;
}

function MusicPickerModal({
  visible,
  onClose,
  searchQuery,
  onSearchChange,
  results,
  isLoading,
  onSelectTrack,
  themeColors,
}: MusicPickerModalProps) {
  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: 'rgba(0,0,0,0.7)' }]}>
        <View style={[styles.modalContent, { backgroundColor: themeColors.bgPrimary }]}>
          {/* Header */}
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>
              Choose a Song
            </Text>
            <Pressable onPress={onClose} accessibilityLabel="Close">
              <Ionicons name="close" size={24} color={themeColors.textMuted} />
            </Pressable>
          </View>

          {/* Search Input */}
          <View style={[styles.searchBox, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="search" size={18} color={themeColors.textMuted} />
            <TextInput
              style={[styles.searchInput, { color: themeColors.textPrimary }]}
              placeholder="Search for a song..."
              placeholderTextColor={themeColors.textMuted}
              value={searchQuery}
              onChangeText={onSearchChange}
              autoFocus
            />
            {searchQuery.length > 0 && (
              <Pressable onPress={() => onSearchChange('')}>
                <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
              </Pressable>
            )}
          </View>

          {/* Results */}
          {isLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : results.length === 0 ? (
            <View style={styles.emptyContainer}>
              <Ionicons name="musical-notes-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                {searchQuery.length < 2
                  ? 'Type to search for songs'
                  : 'No songs found'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={results}
              keyExtractor={(item) => `${item.source}-${item.id}`}
              renderItem={({ item }: { item: MusicTrack }) => (
                <Pressable
                  style={[styles.resultRow, { borderBottomColor: themeColors.bgTertiary }]}
                  onPress={() => onSelectTrack(item)}
                >
                  {item.imageUrl ? (
                    <Image source={{ uri: item.imageUrl }} style={styles.resultImage} />
                  ) : (
                    <View style={[styles.resultImagePlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
                      <Ionicons name="musical-note" size={20} color={themeColors.textMuted} />
                    </View>
                  )}
                  <View style={styles.resultInfo}>
                    <Text
                      style={[styles.resultTitle, { color: themeColors.textPrimary }]}
                      numberOfLines={1}
                    >
                      {item.name}
                    </Text>
                    <Text
                      style={[styles.resultArtist, { color: themeColors.textMuted }]}
                      numberOfLines={1}
                    >
                      {item.artistName}
                    </Text>
                  </View>
                  {item.previewUrl ? (
                    <Ionicons name="play-circle" size={24} color={themeColors.accentPrimary} />
                  ) : (
                    <Text style={[styles.noPreview, { color: themeColors.textMuted }]}>
                      No preview
                    </Text>
                  )}
                </Pressable>
              )}
            />
          )}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
    letterSpacing: 0.5,
  },
  addMusicButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.md,
    borderRadius: 8,
    gap: spacing.sm,
  },
  addMusicText: {
    ...typography.body,
  },
  playerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 8,
    gap: spacing.sm,
  },
  albumArt: {
    width: 56,
    height: 56,
    borderRadius: 4,
    overflow: 'hidden',
    position: 'relative',
  },
  albumImage: {
    width: '100%',
    height: '100%',
  },
  albumPlaceholder: {
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  playOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  trackInfo: {
    flex: 1,
    gap: 2,
  },
  trackName: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  artistName: {
    ...typography.caption,
  },
  albumName: {
    ...typography.caption,
    fontSize: 11,
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  actionButton: {
    padding: spacing.xs,
  },
  progressContainer: {
    marginTop: spacing.sm,
  },
  progressBar: {
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  progressTimes: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  timeText: {
    ...typography.caption,
    fontSize: 10,
  },
  previewNotice: {
    ...typography.caption,
    fontSize: 10,
    textAlign: 'center',
    marginTop: spacing.xs,
  },
  openInAppButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    borderRadius: 8,
    marginTop: spacing.sm,
  },
  openInAppText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  // Modal styles
  modalOverlay: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  modalContent: {
    height: '80%',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingTop: spacing.md,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    marginBottom: spacing.md,
  },
  modalTitle: {
    ...typography.headingL,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.md,
    paddingHorizontal: spacing.sm,
    borderRadius: 8,
    height: 40,
    gap: spacing.xs,
  },
  searchInput: {
    flex: 1,
    ...typography.body,
    paddingVertical: 0,
  },
  sourceList: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.xs,
  },
  sourceChip: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 6,
    borderRadius: 16,
    marginRight: spacing.xs,
  },
  sourceChipText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
  emptyText: {
    ...typography.body,
    textAlign: 'center',
  },
  resultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    gap: spacing.sm,
  },
  resultImage: {
    width: 44,
    height: 44,
    borderRadius: 4,
  },
  resultImagePlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  resultInfo: {
    flex: 1,
    gap: 2,
  },
  resultTitle: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  resultArtist: {
    ...typography.caption,
  },
  noPreview: {
    ...typography.caption,
    fontSize: 10,
  },
});
