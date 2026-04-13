/**
 * ScreenShareViewer — Full-screen share viewer with zoom/pan
 *
 * Renders a real LiveKit VideoTrack for the remote participant's
 * screen share track, with pinch-to-zoom and pan gestures.
 */
import React, { useState, useMemo } from 'react';
import { View, Text, StyleSheet, Dimensions, Pressable } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  runOnJS,
} from 'react-native-reanimated';
import { router } from 'expo-router';
import { useTheme } from '@/hooks/useTheme';
import { useVoiceStore } from '@/shared/stores/voiceStore';
import { Ionicons } from '@expo/vector-icons';
import { VideoTrack as LKVideoTrack } from '@livekit/react-native';
import { Track } from 'livekit-client';
import type { Room } from 'livekit-client';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const MIN_ZOOM = 1;
const MAX_ZOOM = 5;

interface ScreenShareViewerProps {
  participantId: string;
  participantName: string;
  showViewerCount?: boolean;
  viewerCount?: number;
  onClose?: () => void;
}

export function ScreenShareViewer({
  participantId,
  participantName,
  showViewerCount,
  viewerCount,
  onClose,
}: ScreenShareViewerProps) {
  const { themeColors } = useTheme();
  const room = useVoiceStore((s) => s.room) as Room | null;
  const [controlsVisible, setControlsVisible] = useState(true);

  // Resolve screen share track reference from LiveKit room
  const screenTrackRef = useMemo(() => {
    if (!room) return undefined;

    const remoteParticipant = room.remoteParticipants?.get(participantId);
    if (!remoteParticipant) return undefined;

    const screenPub = remoteParticipant.getTrackPublication(Track.Source.ScreenShare);
    if (!screenPub?.track) return undefined;

    return {
      participant: remoteParticipant,
      publication: screenPub,
      source: Track.Source.ScreenShare,
    };
  }, [room, participantId]);

  // Zoom + Pan State
  const scale = useSharedValue(1);
  const savedScale = useSharedValue(1);
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const savedTranslateX = useSharedValue(0);
  const savedTranslateY = useSharedValue(0);

  // Pinch-to-Zoom Gesture
  const pinchGesture = Gesture.Pinch()
    .onUpdate((e) => {
      const newScale = savedScale.value * e.scale;
      scale.value = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, newScale));
    })
    .onEnd(() => {
      savedScale.value = scale.value;
      if (scale.value < 1) {
        scale.value = withSpring(1);
        savedScale.value = 1;
        translateX.value = withSpring(0);
        translateY.value = withSpring(0);
        savedTranslateX.value = 0;
        savedTranslateY.value = 0;
      }
    });

  // Pan Gesture (only when zoomed)
  const panGesture = Gesture.Pan()
    .minPointers(1)
    .onUpdate((e) => {
      if (scale.value <= 1) return;
      const maxPanX = (SCREEN_WIDTH * (scale.value - 1)) / 2;
      const maxPanY = (SCREEN_HEIGHT * (scale.value - 1)) / 2;
      translateX.value = Math.max(-maxPanX, Math.min(maxPanX, savedTranslateX.value + e.translationX));
      translateY.value = Math.max(-maxPanY, Math.min(maxPanY, savedTranslateY.value + e.translationY));
    })
    .onEnd(() => {
      savedTranslateX.value = translateX.value;
      savedTranslateY.value = translateY.value;
    });

  // Double-tap to zoom
  const doubleTapGesture = Gesture.Tap()
    .numberOfTaps(2)
    .onEnd(() => {
      if (scale.value > 1) {
        scale.value = withSpring(1);
        savedScale.value = 1;
        translateX.value = withSpring(0);
        translateY.value = withSpring(0);
        savedTranslateX.value = 0;
        savedTranslateY.value = 0;
      } else {
        scale.value = withSpring(2);
        savedScale.value = 2;
      }
    });

  // Single tap to toggle controls
  const singleTapGesture = Gesture.Tap()
    .onEnd(() => {
      runOnJS(setControlsVisible)(!controlsVisible);
    });

  const composedGesture = Gesture.Simultaneous(
    pinchGesture,
    panGesture,
    Gesture.Exclusive(doubleTapGesture, singleTapGesture),
  );

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
  }));

  if (!screenTrackRef) {
    return (
      <View style={[styles.noScreen, { backgroundColor: themeColors.bgSecondary }]}>
        <Ionicons name="desktop-outline" size={48} color={themeColors.textSecondary} />
        <Text style={[styles.noScreenText, { color: themeColors.textSecondary }]}>
          {participantName} stopped sharing their screen
        </Text>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: '#000' }]}>
      <GestureDetector gesture={composedGesture}>
        <Animated.View style={[styles.videoWrapper, animatedStyle]}>
          {/* Real LiveKit Screen Share VideoTrack */}
          <LKVideoTrack
            trackRef={screenTrackRef}
            style={styles.screenVideo}
            objectFit="contain"
            zOrder={0}
          />
        </Animated.View>
      </GestureDetector>

      {/* Overlay Controls */}
      {controlsVisible && (
        <View style={styles.overlay} pointerEvents="box-none">
          <View style={styles.topBar}>
            <View style={styles.streamerInfo}>
              <View style={[styles.liveBadge, { backgroundColor: '#ed4245' }]}>
                <Text style={styles.liveText}>LIVE</Text>
              </View>
              <Text style={styles.streamerName}>{participantName}'s screen</Text>
            </View>

            <View style={styles.topBarRight}>
              {showViewerCount && (
                <View style={styles.viewerBadge}>
                  <Ionicons name="eye-outline" size={14} color="#fff" />
                  <Text style={styles.viewerText}>{viewerCount}</Text>
                </View>
              )}

              {onClose && (
                <Pressable onPress={onClose} style={styles.closeButton} hitSlop={10}>
                  <Ionicons name="close" size={22} color="#fff" />
                </Pressable>
              )}
            </View>
          </View>

          {/* Bottom controls */}
          <View style={styles.bottomBar}>
            <Pressable
              style={styles.drawButton}
              onPress={() => router.push(`/voice/drawing?shareId=${participantId}&channelId=`)}
              hitSlop={8}
            >
              <Ionicons name="pencil" size={18} color="#fff" />
              <Text style={styles.drawButtonText}>Draw</Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, position: 'relative' },
  videoWrapper: { flex: 1 },
  screenVideo: { flex: 1 },
  noScreen: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: 12 },
  noScreenText: { fontSize: 14 },
  overlay: { ...StyleSheet.absoluteFillObject, justifyContent: 'space-between' },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 48,
    paddingBottom: 12,
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  streamerInfo: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  liveBadge: { paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 },
  liveText: { color: '#fff', fontSize: 11, fontFamily: 'gg-sans-bold' },
  streamerName: { color: '#fff', fontSize: 14, fontFamily: 'gg-sans-semibold' },
  topBarRight: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  viewerBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  viewerText: { color: '#fff', fontSize: 12, fontFamily: 'gg-sans-semibold' },
  closeButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  bottomBar: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingBottom: 32,
    paddingHorizontal: 16,
  },
  drawButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(255,255,255,0.2)',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  drawButtonText: {
    color: '#fff',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
});
