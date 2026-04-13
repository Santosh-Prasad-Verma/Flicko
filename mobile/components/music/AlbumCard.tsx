/**
 * Album Card Component
 *
 * Displays a music album with artwork, title, artist, year, and source.
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
import { MusicAlbum } from '../../services/musicApi.service';
import { MusicSourceBadge } from './MusicSourceBadge';

interface AlbumCardProps {
  album: MusicAlbum;
  onPress?: () => void;
}

export function AlbumCard({ album, onPress }: AlbumCardProps) {
  const { themeColors } = useTheme();

  const handlePress = () => {
    if (onPress) {
      onPress();
    } else if (album.externalUrl) {
      Linking.openURL(album.externalUrl);
    }
  };

  return (
    <Pressable
      style={({ pressed }) => [
        styles.container,
        pressed && { backgroundColor: themeColors.bgTertiary },
      ]}
      onPress={handlePress}
      accessibilityLabel={`${album.name} by ${album.artistName}`}
      accessibilityRole="button"
    >
      {/* Album Art */}
      <View style={[styles.artwork, { backgroundColor: themeColors.bgTertiary }]}>
        {album.imageUrl ? (
          <Image source={{ uri: album.imageUrl }} style={styles.artworkImage} />
        ) : (
          <Ionicons name="disc" size={28} color={themeColors.textMuted} />
        )}
      </View>

      {/* Album Info */}
      <View style={styles.info}>
        <Text
          style={[styles.title, { color: themeColors.textPrimary }]}
          numberOfLines={1}
        >
          {album.name}
        </Text>
        <Text
          style={[styles.artist, { color: themeColors.textMuted }]}
          numberOfLines={1}
        >
          {album.artistName}
          {album.releaseYear && ` • ${album.releaseYear}`}
          {album.trackCount && ` • ${album.trackCount} tracks`}
        </Text>
      </View>

      {/* Source */}
      <MusicSourceBadge source={album.source} />
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
    width: 56,
    height: 56,
    borderRadius: 6,
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
});
