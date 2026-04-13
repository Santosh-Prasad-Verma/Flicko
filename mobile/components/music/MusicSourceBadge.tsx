/**
 * Music Source Badge
 *
 * Displays a small badge indicating which streaming service a music result is from.
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  MusicSource,
  getSourceDisplayName,
  getSourceIcon,
} from '../../services/musicApi.service';

interface MusicSourceBadgeProps {
  source: MusicSource;
  showLabel?: boolean;
  size?: 'small' | 'medium';
}

const SOURCE_COLORS: Partial<Record<MusicSource, string>> = {
  spotify: '#1DB954',
  appleMusic: '#FA243C',
  youtube: '#FF0000',
  youtubeMusic: '#FF0000',
  soundCloud: '#FF5500',
  deezer: '#FEAA2D',
  tidal: '#000000',
  amazonMusic: '#00A8E1',
  pandora: '#00A0EE',
};

export function MusicSourceBadge({
  source,
  showLabel = false,
  size = 'small',
}: MusicSourceBadgeProps) {
  const { themeColors } = useTheme();
  const iconName = getSourceIcon(source) as keyof typeof Ionicons.glyphMap;
  const color = SOURCE_COLORS[source] || themeColors.accentPrimary;
  const iconSize = size === 'small' ? 14 : 18;

  return (
    <View
      style={[
        styles.badge,
        size === 'medium' && styles.badgeMedium,
        { backgroundColor: `${color}20` },
      ]}
    >
      <Ionicons name={iconName} size={iconSize} color={color} />
      {showLabel && (
        <Text style={[styles.label, { color }]} numberOfLines={1}>
          {getSourceDisplayName(source)}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: 4,
    gap: 4,
  },
  badgeMedium: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    borderRadius: 6,
  },
  label: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
    fontSize: 10,
  },
});
