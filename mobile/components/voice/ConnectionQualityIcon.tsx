/**
 * ConnectionQualityIcon — Per-participant signal strength indicator
 */
import React, { memo } from 'react';
import { View, StyleSheet } from 'react-native';

interface Props {
  quality: string;
  size?: number;
}

const QUALITY_COLORS: Record<string, string> = {
  excellent: '#43b581',
  good: '#43b581',
  fair: '#faa61a',
  poor: '#ed4245',
  unknown: '#747f8d',
};

const QUALITY_BARS: Record<string, number> = {
  excellent: 4,
  good: 3,
  fair: 2,
  poor: 1,
  unknown: 0,
};

export const ConnectionQualityIcon = memo(function ConnectionQualityIcon({
  quality,
  size = 16,
}: Props) {
  const color = QUALITY_COLORS[quality] || QUALITY_COLORS.unknown;
  const bars = QUALITY_BARS[quality] || 0;
  const barWidth = size / 6;
  const gap = size / 12;

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      {[1, 2, 3, 4].map((i) => (
        <View
          key={i}
          style={{
            width: barWidth,
            height: (i / 4) * size * 0.8,
            backgroundColor: i <= bars ? color : 'rgba(255,255,255,0.2)',
            borderRadius: barWidth / 2,
            marginHorizontal: gap / 2,
          }}
        />
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
});
