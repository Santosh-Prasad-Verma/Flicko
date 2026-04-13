/**
 * Track Card Component
 *
 * Displays a music track with artwork, title, artist, duration, and source.
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Image,
  Linking,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { MusicTrack, formatDuration } from '../../services/musicApi.service';
import { MusicSourceBadge } from './MusicSourceBadge';

interface TrackCardProps {
  track: MusicTrack;
  onPress?: () => void;
}

export function TrackCard({ track, onPress }: TrackCardProps) {
  const { themeColors } = useTheme();

  const handlePress = () => {
    if (onPress) {
      onPress();
    } else if (track.externalUrl) {
      Linking.openURL(track.externalUrl);
    }
  };

  return (
    <Pressable
      style={({ pressed }) => [
        styles.container,
        pressed && { backgroundColor: themeColors.bgTertiary },
      ]}
      onPress={handlePress}
      accessibilityLabel={`${track.name} by ${track.artistName}`}
      accessibilityRole="button"
    >
      {/* Album Art */}
      <View style={[styles.artwork, { backgroundColor: themeColors.bgTertiary }]}>
        {track.imageUrl ? (
          <Image source={{ uri: track.imageUrl }} style={styles.artworkImage} />
        ) : (
          <Ionicons name="musical-note" size={24} color={themeColors.textMuted} />
        )}
      </View>

      {/* Track Info */}
      <View style={styles.info}>
        <Text
          style={[styles.title, { color: themeColors.textPrimary }]}
          numberOfLines={1}
        >
          {track.name}
        </Text>
        <Text
          style={[styles.artist, { color: themeColors.textMuted }]}
          numberOfLines={1}
        >
          {track.artistName}
          {track.albumName && ` • ${track.albumName}`}
        </Text>
      </View>

      {/* Duration & Source */}
      <View style={styles.meta}>
        {track.durationMs && (
          <Text style={[styles.duration, { color: themeColors.textMuted }]}>
            {formatDuration(track.durationMs)}
          </Text>
        )}
        <MusicSourceBadge source={track.source} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  artwork: {
    width: 48,
    height: 48,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  artworkImage: {
    width: '100%',
    height: '100%',
  },
  info: {
    flex: 1,
    gap: 2,
  },
  title: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  artist: {
    ...typography.caption,
  },
  meta: {
    alignItems: 'flex-end',
    gap: 4,
  },
  duration: {
    ...typography.caption,
    fontSize: 11,
  },
});
