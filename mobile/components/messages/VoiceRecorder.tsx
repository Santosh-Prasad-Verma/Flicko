/**
 * Voice Recording / Voice Notes (Feature 43)
 *
 * Record and send voice messages in chat.
 * Uses expo-av for recording and playback.
 */
import React, { memo, useCallback, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';

interface VoiceRecorderProps {
  onSend: (uri: string, durationMs: number) => void;
  onCancel?: () => void;
}

/**
 * Voice recording button + waveform UI.
 * Hold to record, release to send. Slide left to cancel.
 */
export const VoiceRecorder = memo(function VoiceRecorder({
  onSend,
  onCancel,
}: VoiceRecorderProps) {
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [duration, setDuration] = useState(0);
  const durationInterval = useRef<ReturnType<typeof setInterval>>(undefined);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const startRecording = useCallback(async () => {
    try {
      const { granted } = await Audio.requestPermissionsAsync();
      if (!granted) {
        Alert.alert('Permission needed', 'Microphone access is required to record voice messages.');
        return;
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording: rec } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      setRecording(rec);
      setIsRecording(true);
      setDuration(0);

      // Pulse animation
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.15, duration: 600, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1, duration: 600, useNativeDriver: true }),
        ])
      ).start();

      // Duration counter
      const startTime = Date.now();
      durationInterval.current = setInterval(() => {
        setDuration(Date.now() - startTime);
      }, 100);
    } catch (err) {
      Alert.alert('Error', 'Could not start recording.');
    }
  }, [pulseAnim]);

  const stopAndSend = useCallback(async () => {
    if (!recording) return;

    clearInterval(durationInterval.current);
    pulseAnim.stopAnimation();
    pulseAnim.setValue(1);
    setIsRecording(false);

    try {
      await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      const status = await recording.getStatusAsync();
      setRecording(null);

      if (uri && duration > 500) {
        onSend(uri, status.durationMillis || duration);
      }
    } catch {
      // Recording may already be stopped
    }

    await Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
    });
  }, [recording, duration, onSend, pulseAnim]);

  const cancelRecording = useCallback(async () => {
    if (!recording) return;

    clearInterval(durationInterval.current);
    pulseAnim.stopAnimation();
    pulseAnim.setValue(1);
    setIsRecording(false);

    try {
      await recording.stopAndUnloadAsync();
    } catch {}
    setRecording(null);

    await Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
    });

    onCancel?.();
  }, [recording, pulseAnim, onCancel]);

  const formatDuration = (ms: number) => {
    const secs = Math.floor(ms / 1000);
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  if (isRecording) {
    return (
      <View style={styles.recordingBar}>
        <TouchableOpacity onPress={cancelRecording} style={styles.cancelBtn}>
          <Ionicons name="trash-outline" size={22} color="#ED4245" />
        </TouchableOpacity>
        <Animated.View style={[styles.recordingDot, { transform: [{ scale: pulseAnim }] }]} />
        <Text style={styles.recordingTime}>{formatDuration(duration)}</Text>
        <View style={styles.waveformPlaceholder}>
          {Array.from({ length: 12 }).map((_, i) => (
            <View
              key={i}
              style={[
                styles.waveBar,
                { height: 8 + Math.random() * 16 },
              ]}
            />
          ))}
        </View>
        <TouchableOpacity onPress={stopAndSend} style={styles.sendVoiceBtn}>
          <Ionicons name="send" size={20} color="#FFF" />
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <TouchableOpacity onPress={startRecording} style={styles.micBtn}>
      <Ionicons name="mic" size={22} color="#B9BBBE" />
    </TouchableOpacity>
  );
});

// ─── Voice Message Player ────────────────────────────────────────────────────

interface VoiceMessagePlayerProps {
  uri: string;
  durationMs: number;
}

/**
 * Inline player for received voice messages.
 */
export const VoiceMessagePlayer = memo(function VoiceMessagePlayer({
  uri,
  durationMs,
}: VoiceMessagePlayerProps) {
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const soundRef = useRef<Audio.Sound>(undefined);

  const formatDuration = (ms: number) => {
    const secs = Math.floor(ms / 1000);
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  const togglePlayback = useCallback(async () => {
    if (playing && soundRef.current) {
      await soundRef.current.pauseAsync();
      setPlaying(false);
      return;
    }

    try {
      if (soundRef.current) {
        await soundRef.current.playAsync();
      } else {
        const { sound } = await Audio.Sound.createAsync(
          { uri },
          { shouldPlay: true },
          (status: Audio.Sound extends { getStatusAsync(): Promise<infer S> } ? S : any) => {
            if (status.isLoaded) {
              setProgress(status.positionMillis / (status.durationMillis || durationMs));
              if (status.didJustFinish) {
                setPlaying(false);
                setProgress(0);
              }
            }
          }
        );
        soundRef.current = sound;
      }
      setPlaying(true);
    } catch {
      Alert.alert('Error', 'Could not play voice message.');
    }
  }, [playing, uri, durationMs]);

  return (
    <View style={styles.playerContainer}>
      <TouchableOpacity onPress={togglePlayback} style={styles.playBtn}>
        <Ionicons name={playing ? 'pause' : 'play'} size={20} color="#FFF" />
      </TouchableOpacity>
      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${Math.min(progress * 100, 100)}%` }]} />
      </View>
      <Text style={styles.playerDuration}>{formatDuration(durationMs)}</Text>
    </View>
  );
});

const styles = StyleSheet.create({
  micBtn: {
    padding: 8,
  },
  recordingBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2F3136',
    borderRadius: 22,
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 10,
    flex: 1,
  },
  cancelBtn: {
    padding: 4,
  },
  recordingDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#ED4245',
  },
  recordingTime: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'GGSans-Medium',
    minWidth: 40,
  },
  waveformPlaceholder: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  waveBar: {
    width: 3,
    backgroundColor: '#5865F2',
    borderRadius: 1.5,
  },
  sendVoiceBtn: {
    backgroundColor: '#5865F2',
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  // Player
  playerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2F3136',
    borderRadius: 20,
    padding: 8,
    gap: 10,
    minWidth: 200,
  },
  playBtn: {
    backgroundColor: '#5865F2',
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: '#40444B',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#5865F2',
    borderRadius: 2,
  },
  playerDuration: {
    color: '#96989D',
    fontSize: 12,
    fontFamily: 'GGSans-Medium',
    minWidth: 35,
    textAlign: 'right',
  },
});
