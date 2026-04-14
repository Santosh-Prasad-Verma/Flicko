/**
 * VideoLayoutToggle
 * 
 * Component to toggle between different video grid layouts.
 */
import React from 'react';
import { View, StyleSheet, Pressable, Text } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';

export type VideoLayout = 'grid' | 'focus' | 'sidebar';

interface VideoLayoutToggleProps {
  currentLayout: VideoLayout;
  onLayoutChange: (layout: VideoLayout) => void;
  hasScreenShare?: boolean;
}

export function VideoLayoutToggle({
  currentLayout,
  onLayoutChange,
  hasScreenShare = false,
}: VideoLayoutToggleProps) {
  const { themeColors } = useTheme();

  const options: { id: VideoLayout; icon: string; label: string }[] = [
    { id: 'grid', icon: 'grid-outline', label: 'Grid' },
    { id: 'focus', icon: 'scan-outline', label: 'Focus' },
    { id: 'sidebar', icon: 'reorder-four-outline', label: 'Sidebar' },
  ];

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}>
      {options.map((opt) => {
        const isActive = currentLayout === opt.id;
        return (
          <Pressable
            key={opt.id}
            style={[
              styles.option,
              isActive && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => onLayoutChange(opt.id)}
          >
            <Ionicons
              name={opt.icon as any}
              size={18}
              color={isActive ? themeColors.accentPrimary : themeColors.textMuted}
            />
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    borderRadius: 8,
    padding: 4,
    gap: 4,
  },
  option: {
    padding: 6,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
