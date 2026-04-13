/**
 * Voice Activities Route
 *
 * Screen for launching and managing activities in a voice channel.
 * Integrates the ActivityPicker and ActivitySession components.
 */
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { Stack, useLocalSearchParams, router } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';
import { ActivityPicker } from '../../components/voice/ActivityPicker';
import { ActivitySession } from '../../components/voice/ActivitySession';
import { useActivityStore } from '@stores/activityStore';

export default function VoiceActivitiesScreen() {
  const { themeColors } = useTheme();
  const { channelId, serverId } = useLocalSearchParams<{
    channelId: string;
    serverId: string;
  }>();

  const currentSession = useActivityStore((s) => s.currentSession);

  const pickerVisible = useActivityStore((s) => s.pickerVisible);

  // Open picker automatically if no active session
  useEffect(() => {
    if (!currentSession) {
      useActivityStore.getState().openPicker();
    }
  }, [currentSession]);

  // If both the picker and session are closed, go back
  useEffect(() => {
    if (!currentSession && !pickerVisible && router.canGoBack()) {
      router.back();
    }
  }, [currentSession, pickerVisible]);

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: currentSession
            ? currentSession.activity.name
            : 'Activities',
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <ActivityPicker
          channelId={channelId || ''}
          serverId={serverId || ''}
        />
        {currentSession ? (
          <ActivitySession
            channelId={channelId || ''}
            serverId={serverId || ''}
          />
        ) : null}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
