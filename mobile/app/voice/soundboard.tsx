/**
 * Voice Soundboard Route
 *
 * Screen for the soundboard in a voice channel.
 * Wraps the Soundboard component with route params.
 */
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';
import { Soundboard } from '../../components/voice/Soundboard';
import { useSoundboardStore } from '@stores/soundboardStore';

export default function VoiceSoundboardScreen() {
  const { themeColors } = useTheme();
  const { channelId, serverId } = useLocalSearchParams<{
    channelId: string;
    serverId: string;
  }>();

  // Auto-open the soundboard when navigating to this route
  useEffect(() => {
    useSoundboardStore.getState().open();
  }, []);

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Soundboard',
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <Soundboard
          serverId={serverId || ''}
          channelId={channelId || ''}
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
