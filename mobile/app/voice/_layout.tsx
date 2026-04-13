/**
 * Voice Route Group Layout
 *
 * Provides a stack navigator for voice-related screens
 * (soundboard, activities).
 */
import { Stack } from 'expo-router';
import React from 'react';
import { useTheme } from '../../hooks/useTheme';

export default function VoiceLayout() {
  const { themeColors } = useTheme();
  
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: themeColors.bgTertiary },
        animation: 'slide_from_right',
      }}
    />
  );
}
