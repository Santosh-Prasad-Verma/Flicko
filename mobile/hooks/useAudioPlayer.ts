/**
 * Audio Player Hook
 *
 * Provides audio playback functionality using expo-av for playing
 * music previews and other audio content.
 */
import { useState, useEffect, useCallback, useRef } from 'react';
import { Audio, AVPlaybackStatus } from 'expo-av';

export interface AudioPlayerState {
  isPlaying: boolean;
  isLoading: boolean;
  isLoaded: boolean;
  duration: number;
  position: number;
  error: string | null;
}

export interface AudioPlayerControls {
  play: () => Promise<void>;
  pause: () => Promise<void>;
  toggle: () => Promise<void>;
  stop: () => Promise<void>;
  seek: (position: number) => Promise<void>;
  loadAndPlay: (uri: string) => Promise<void>;
}

export interface UseAudioPlayerReturn extends AudioPlayerState, AudioPlayerControls {}

const initialState: AudioPlayerState = {
  isPlaying: false,
  isLoading: false,
  isLoaded: false,
  duration: 0,
  position: 0,
  error: null,
};

/**
 * Hook for managing audio playback with expo-av.
 *
 * @param initialUri - Optional initial audio URI to load
 * @param autoPlay - Whether to auto-play when loaded (default: false)
 */
export function useAudioPlayer(
  initialUri?: string,
  autoPlay = false
): UseAudioPlayerReturn {
  const [state, setState] = useState<AudioPlayerState>(initialState);
  const soundRef = useRef<Audio.Sound | null>(null);
  const currentUriRef = useRef<string | null>(null);

  // Configure audio mode on mount
  useEffect(() => {
    Audio.setAudioModeAsync({
      playsInSilentModeIOS: true,
      staysActiveInBackground: false,
      shouldDuckAndroid: true,
    });

    return () => {
      // Cleanup on unmount
      if (soundRef.current) {
        soundRef.current.stopAsync().then(() => {
          if (soundRef.current) {
             soundRef.current.unloadAsync();
          }
        });
      }
    };
  }, []);

  // Handle playback status updates
  const onPlaybackStatusUpdate = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) {
      setState((prev) => ({
        ...prev,
        isLoaded: false,
        isPlaying: false,
        error: status.error || null,
      }));
      return;
    }

    setState((prev) => ({
      ...prev,
      isLoaded: true,
      isPlaying: status.isPlaying,
      duration: status.durationMillis || 0,
      position: status.positionMillis || 0,
      isLoading: false,
      error: null,
    }));

    // Handle playback finished
    if (status.didJustFinish) {
      setState((prev) => ({ ...prev, isPlaying: false, position: 0 }));
    }
  }, []);

  // Load audio from URI
  const loadAudio = useCallback(
    async (uri: string): Promise<boolean> => {
      try {
        // Unload existing sound
        if (soundRef.current) {
          await soundRef.current.unloadAsync();
          soundRef.current = null;
        }

        setState((prev) => ({ ...prev, isLoading: true, error: null }));
        currentUriRef.current = uri;

        const { sound } = await Audio.Sound.createAsync(
          { uri },
          { shouldPlay: false },
          onPlaybackStatusUpdate
        );

        soundRef.current = sound;
        return true;
      } catch (error: any) {
        setState((prev) => ({
          ...prev,
          isLoading: false,
          error: error.message || 'Failed to load audio',
        }));
        return false;
      }
    },
    [onPlaybackStatusUpdate]
  );

  // Load initial URI
  useEffect(() => {
    if (initialUri) {
      loadAudio(initialUri).then((loaded) => {
        if (loaded && autoPlay) {
          soundRef.current?.playAsync();
        }
      });
    }
  }, [initialUri, autoPlay, loadAudio]);

  // Play
  const play = useCallback(async () => {
    if (!soundRef.current) return;
    try {
      await soundRef.current.playAsync();
    } catch (error: any) {
      setState((prev) => ({ ...prev, error: error.message }));
    }
  }, []);

  // Pause
  const pause = useCallback(async () => {
    if (!soundRef.current) return;
    try {
      await soundRef.current.pauseAsync();
    } catch (error: any) {
      setState((prev) => ({ ...prev, error: error.message }));
    }
  }, []);

  // Toggle play/pause
  const toggle = useCallback(async () => {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }, [state.isPlaying, play, pause]);

  // Stop and reset
  const stop = useCallback(async () => {
    if (!soundRef.current) return;
    try {
      await soundRef.current.stopAsync();
      await soundRef.current.setPositionAsync(0);
    } catch (error: any) {
      setState((prev) => ({ ...prev, error: error.message }));
    }
  }, []);

  // Seek to position
  const seek = useCallback(async (position: number) => {
    if (!soundRef.current) return;
    try {
      await soundRef.current.setPositionAsync(position);
    } catch (error: any) {
      setState((prev) => ({ ...prev, error: error.message }));
    }
  }, []);

  // Load and immediately play
  const loadAndPlay = useCallback(
    async (uri: string) => {
      const loaded = await loadAudio(uri);
      if (loaded && soundRef.current) {
        await soundRef.current.playAsync();
      }
    },
    [loadAudio]
  );

  return {
    ...state,
    play,
    pause,
    toggle,
    stop,
    seek,
    loadAndPlay,
  };
}

/**
 * Format milliseconds to mm:ss display.
 */
export function formatTime(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}
