import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio, InterruptionModeAndroid, InterruptionModeIOS } from 'expo-av';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { supabase } from '../../services/supabase';
import { invokeCommand } from '../../../shared/services/botService';
import { GO_BACKEND_URL } from '../../constants/Config';

interface BotMusicControlsProps {
  serverId: string;
  channelId: string;
}

interface MusicEventData {
  action: 'play' | 'skip' | 'pause' | 'resume' | 'stop' | 'shuffle' | 'volume' | 'queue_add';
  title?: string;
  url?: string;
  level?: number;
}

export function BotMusicControls({ serverId, channelId }: BotMusicControlsProps) {
  const { themeColors } = useTheme();
  const [nowPlaying, setNowPlaying] = useState<string | null>(null);
  const [currentUrl, setCurrentUrl] = useState<string | null>(null);
  const [isPaused, setIsPaused] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [sound, setSound] = useState<Audio.Sound | null>(null);

  useEffect(() => {
    // Setup audio session
    Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
      staysActiveInBackground: true,
      interruptionModeIOS: InterruptionModeIOS.DoNotMix,
      playsInSilentModeIOS: true,
      shouldDuckAndroid: true,
      interruptionModeAndroid: InterruptionModeAndroid.DoNotMix,
      playThroughEarpieceAndroid: false,
    });

    return () => {
      if (sound) {
        sound.unloadAsync();
      }
    };
  }, [sound]);

  useEffect(() => {
    // 1. Initial fetch of current state
    fetchInitialState();

    // 2. Subscribe to bot_events for this server
    const channel = supabase
      .channel(`bot-events-${serverId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'bot_events',
          filter: `server_id=eq.${serverId}`,
        },
        (payload) => {
          const event = payload.new as any;
          if (event.event_type === 'MUSIC_UPDATE') {
            handleMusicEvent(event.data as MusicEventData);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [serverId]);

  const fetchInitialState = async () => {
    try {
      const response = await fetch(`${GO_BACKEND_URL}/api/v1/servers/${serverId}/music/state`, {
        headers: {
          'Authorization': `Bearer ${(await supabase.auth.getSession()).data.session?.access_token}`,
        },
      });
      if (response.ok) {
        const data = await response.json();
        // Set now playing if queue not empty
        if (data.queue && data.queue.length > 0) {
          // The backend currently doesn't track "current index" in the response yet,
          // but we can assume the first item is now playing if the bot is active.
          setNowPlaying(data.queue[0].title);
          // TODO: Add more granular state tracking if backend supports it
        }
        if (data.settings) {
          // Update paused state based on settings if available
        }
      }
    } catch (error) {
      console.error('Failed to fetch initial music state:', error);
    }
  };

  const playSound = async (url: string) => {
    try {
      if (sound) {
        await sound.unloadAsync();
      }
      
      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: url },
        { shouldPlay: true }
      );
      
      newSound.setOnPlaybackStatusUpdate((status: any) => {
        if (status.didJustFinish) {
          handleAction('skip');
        }
      });

      setSound(newSound);
      setIsPaused(false);
    } catch (error) {
      console.error('Error playing sound:', error);
    }
  };

  const handleMusicEvent = async (data: MusicEventData) => {
    switch (data.action) {
      case 'play':
      case 'queue_add':
        if (!nowPlaying || data.action === 'play') {
          setNowPlaying(data.title || 'Unknown Track');
          if (data.url && data.url !== currentUrl) {
            setCurrentUrl(data.url);
            playSound(data.url);
          }
        }
        break;
      case 'pause':
        setIsPaused(true);
        if (sound) await sound.pauseAsync();
        break;
      case 'resume':
        setIsPaused(false);
        if (sound) await sound.playAsync();
        break;
      case 'stop':
        setNowPlaying(null);
        setCurrentUrl(null);
        setIsPaused(false);
        if (sound) {
          await sound.unloadAsync();
          setSound(null);
        }
        break;
      case 'skip':
        setNowPlaying(data.title || 'Skipping...');
        setIsPaused(false);
        fetchInitialState(); // Refresh to get the new first track
        break;
    }
  };

  const handleAction = async (command: string, options: Record<string, any> = {}) => {
    if (isLoading) return;
    setIsLoading(true);
    try {
      await invokeCommand(command, serverId, channelId, options);
    } catch (error) {
      console.error(`Failed to invoke music command ${command}:`, error);
    } finally {
      setIsLoading(false);
    }
  };

  if (!nowPlaying && !isLoading) {
    return null; // Don't show if nothing playing
  }

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgSecondary, borderTopColor: themeColors.border }]}>
      <View style={styles.nowPlayingInfo}>
        <Ionicons name="musical-notes" size={20} color={themeColors.accentPrimary} />
        <View style={styles.textContainer}>
          <Text style={[styles.nowPlayingLabel, { color: themeColors.textMuted }]}>
            NOW PLAYING
          </Text>
          <Text style={[styles.trackTitle, { color: themeColors.textPrimary }]} numberOfLines={1}>
            {nowPlaying || 'Loading...'}
          </Text>
        </View>
      </View>

      <View style={styles.controls}>
        <Pressable 
          onPress={() => handleAction('shuffle')}
          style={styles.iconButton}
        >
          <Ionicons name="shuffle" size={22} color={themeColors.textMuted} />
        </Pressable>

        <Pressable 
          onPress={() => handleAction(isPaused ? 'resume' : 'pause')}
          style={styles.playbackButton}
          disabled={isLoading}
        >
          {isLoading ? (
            <ActivityIndicator size="small" color={themeColors.primary} />
          ) : (
            <Ionicons 
              name={isPaused ? "play-circle" : "pause-circle"} 
              size={36} 
              color={themeColors.accentPrimary} 
            />
          )}
        </Pressable>

        <Pressable 
          onPress={() => handleAction('skip')}
          style={styles.iconButton}
          disabled={isLoading}
        >
          <Ionicons name="play-forward" size={24} color={themeColors.textPrimary} />
        </Pressable>

        <Pressable 
          onPress={() => handleAction('stop')}
          style={styles.iconButton}
          disabled={isLoading}
        >
          <Ionicons name="stop" size={22} color={themeColors.textDanger} />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.md,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  nowPlayingInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  textContainer: {
    flex: 1,
  },
  nowPlayingLabel: {
    ...typography.caption,
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  trackTitle: {
    ...typography.body,
    fontWeight: '600',
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  iconButton: {
    width: MINIMUM_TOUCH_TARGET,
    height: MINIMUM_TOUCH_TARGET,
    alignItems: 'center',
    justifyContent: 'center',
  },
  playbackButton: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
