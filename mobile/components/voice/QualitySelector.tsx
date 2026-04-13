/**
 * QualitySelector — Video quality picker (resolution + fps)
 */
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { useTheme } from '@/hooks/useTheme';
import { Ionicons } from '@expo/vector-icons';
import { QUALITY_PRESETS } from '@/shared/services/mediaService';

interface QualitySelectorProps {
  currentQuality: string;
  onSelectQuality: (quality: string) => void;
  isScreenShare?: boolean;
}

const QUALITY_OPTIONS = Object.entries(QUALITY_PRESETS).map(([key, preset]) => ({
  key,
  ...preset,
}));

export function QualitySelector({
  currentQuality,
  onSelectQuality,
  isScreenShare: _isScreenShare = false,
}: QualitySelectorProps) {
  const { themeColors } = useTheme();

  return (
    <View style={styles.container}>
      <Text style={[styles.title, { color: themeColors.textSecondary }]}>VIDEO QUALITY</Text>

      {QUALITY_OPTIONS.map((option) => {
        const isSelected = currentQuality === option.key;

        return (
          <Pressable
            key={option.key}
            onPress={() => onSelectQuality(option.key)}
            style={[
              styles.option,
              {
                backgroundColor: isSelected ? 'rgba(88,101,242,0.1)' : themeColors.bgTertiary,
                borderColor: isSelected ? '#5865f2' : 'transparent',
              },
            ]}
          >
            <View style={styles.optionInfo}>
              <Text style={[styles.optionName, { color: themeColors.textPrimary }]}>
                {option.name}
              </Text>
              <Text style={[styles.optionDetail, { color: themeColors.textSecondary }]}>
                {option.width}x{option.height} @ {option.fps}fps
              </Text>
            </View>

            {isSelected && <Ionicons name="checkmark-circle" size={22} color="#5865f2" />}
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 6,
  },
  title: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: 4,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1.5,
  },
  optionInfo: {
    gap: 2,
  },
  optionName: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  optionDetail: {
    fontSize: 12,
  },
});
