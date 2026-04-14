import React, { useEffect, useState } from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { PanGestureHandler, PanGestureHandlerGestureEvent } from 'react-native-gesture-handler';
import Animated, {
  useAnimatedGestureHandler,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  runOnJS,
} from 'react-native-reanimated';
import { VideoTrack as LKVideoTrack, useRoomContext, useLocalParticipant, useRemoteParticipants } from '@livekit/react-native';
import { Track } from 'livekit-client';
import { useVoiceStore } from '@stores/voiceStore';
import { VoiceOverlay } from './VoiceOverlay';
import { router } from 'expo-router';

// Screen boundaries for snapping calculating
const PIP_WIDTH = 120;
const PIP_HEIGHT = 160;

export const FloatingVideoPiP = () => {
  const { channelId, connectionState, room } = useVoiceStore();
  
  // To handle the pure audio VoiceOverlay if no video is active
  const [activeVideoTrack, setActiveVideoTrack] = useState<Track | null>(null);

  // Reanimated values for dragging
  const translateX = useSharedValue(20);
  const translateY = useSharedValue(20);

  const gestureHandler = useAnimatedGestureHandler<PanGestureHandlerGestureEvent, { startX: number; startY: number }>({
    onStart: (_, ctx) => {
      ctx.startX = translateX.value;
      ctx.startY = translateY.value;
    },
    onActive: (event, ctx) => {
      translateX.value = ctx.startX + event.translationX;
      translateY.value = ctx.startY + event.translationY;
    },
    onEnd: (_) => {
      // Very basic snap back to edge
      if (translateX.value < 100) translateX.value = withSpring(20);
      else translateX.value = withSpring(200); // Or screen width minus PIP_WIDTH
      
      if (translateY.value < 100) translateY.value = withSpring(20);
    },
  });

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [
        { translateX: translateX.value },
        { translateY: translateY.value },
      ],
    };
  });

  // Tap to return to full screen
  const goFullscreen = () => {
    router.push(`/server/${useVoiceStore.getState().serverId}/channel/${channelId}/voice`);
  };

  // Skip rendering entirely if not connected
  if (connectionState !== 'connected' || !channelId) return null;

  // We should actively scan the room for people streaming camera.
  // For the basic implementation, if there is no video, just render the Audio VoiceOverlay.
  // If there IS video, render the floating gesture handler.

  // NOTE: A real implementation would parse the `room` object for participants with `source === Track.Source.Camera`.

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
      {/* If Audio Only -> Render the existing bar at the very bottom */}
      <View style={styles.bottomBarContainer} pointerEvents="box-none">
         <VoiceOverlay onPress={goFullscreen} />
      </View>

      {/* If Video Active -> Render the draggable PiP block */}
      {/* 
      {activeVideoTrack && (
        <PanGestureHandler onGestureEvent={gestureHandler}>
          <Animated.View style={[styles.pipContainer, animatedStyle]}>
             <LKVideoTrack track={activeVideoTrack} style={StyleSheet.absoluteFill} />
          </Animated.View>
        </PanGestureHandler>
      )}
      */}
    </View>
  );
};

const styles = StyleSheet.create({
  bottomBarContainer: {
    position: 'absolute',
    bottom: 60, // Above tabs
    left: 0,
    right: 0,
  },
  pipContainer: {
    position: 'absolute',
    width: PIP_WIDTH,
    height: PIP_HEIGHT,
    backgroundColor: '#000',
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.5,
    shadowRadius: 10,
    elevation: 8,
  }
});
