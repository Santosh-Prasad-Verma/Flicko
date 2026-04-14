/**
 * Artist Card Component
 *
 * Displays a music artist with image, name, genres, and source.
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
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { MusicArtist } from '../../services/musicApi.service';
import { MusicSourceBadge } from './MusicSourceBadge';

interface ArtistCardProps {
  artist: MusicArtist;
  onPress?: () => void;
}

function formatFollowers(count?: number): string {
  if (!count) return '';
  if (count >= 1_000_000) return `${(count / 1_000_000).toFixed(1)}M followers`;
  if (count >= 1_000) return `${(count / 1_000).toFixed(1)}K followers`;
  return `${count} followers`;
}

export function ArtistCard({ artist, onPress }: ArtistCardProps) {
  const { themeColors } = useTheme();

  const handlePress = () => {
    if (onPress) {
      onPress();
    } else if (artist.externalUrl) {
      Linking.openURL(artist.externalUrl);
    }
  };

  return (
    <Pressable
      style={({ pressed }) => [
        styles.container,
        pressed && { backgroundColor: themeColors.bgTertiary },
      ]}
      onPress={handlePress}
      accessibilityLabel={`Artist: ${artist.name}`}
      accessibilityRole="button"
    >
      {/* Artist Image */}
      <View style={[styles.avatar, { backgroundColor: themeColors.bgTertiary }]}>
        {artist.imageUrl ? (
          <Image source={{ uri: artist.imageUrl }} style={styles.avatarImage} />
        ) : (
          <Ionicons name="person" size={28} color={themeColors.textMuted} />
        )}
      </View>

      {/* Artist Info */}
      <View style={styles.info}>
        <Text
          style={[styles.name, { color: themeColors.textPrimary }]}
          numberOfLines={1}
        >
          {artist.name}
        </Text>
        <Text
          style={[styles.meta, { color: themeColors.textMuted }]}
          numberOfLines={1}
        >
          {artist.genres?.slice(0, 2).join(', ') ||
            formatFollowers(artist.followerCount) ||
            'Artist'}
        </Text>
      </View>

      {/* Source */}
      <MusicSourceBadge source={artist.source} />
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
  avatar: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  avatarImage: {
    width: '100%',
    height: '100%',
  },
  info: {
    flex: 1,
    gap: 2,
  },
  name: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  meta: {
    ...typography.caption,
  },
});
