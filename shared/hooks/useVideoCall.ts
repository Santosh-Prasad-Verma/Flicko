/**
 * useVideoCall — Hook for managing video call state and controls
 *
 * Wraps mediaService + voiceStore for easy component integration
 */
import { useCallback, useEffect, useRef } from 'react';
import { AppState, AppStateStatus } from 'react-native';
import { useVoiceStore } from '../stores/voiceStore';
import { mediaService } from '../services/mediaService';

interface UseVideoCallOptions {
  channelId: string;
  serverId: string;
  autoJoin?: boolean;
  enableVideo?: boolean;
  enableAudio?: boolean;
}

export function useVideoCall(options: UseVideoCallOptions) {
  const {
    channelId,
    serverId,
    autoJoin = false,
    enableVideo = false,
    enableAudio = true,
  } = options;

  const store = useVoiceStore();
  const elapsedTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // ── Join/Leave ──

  const join = useCallback(async () => {
    try {
      store.setConnectionState('connecting');
      await mediaService.joinChannel({
        channelId,
        serverId,
        enableVideo,
        enableAudio,
      });
    } catch (error) {
      store.setConnectionState('disconnected');
      throw error;
    }
  }, [channelId, serverId, enableVideo, enableAudio]);

  const leave = useCallback(async () => {
    await mediaService.leaveChannel();
  }, []);

  // ── Media Toggles ──

  const toggleCamera = useCallback(async () => {
    await mediaService.enableCamera(!store.videoEnabled);
  }, [store.videoEnabled]);

  const toggleMic = useCallback(async () => {
    await mediaService.setMicEnabled(store.muted);
  }, [store.muted]);

  const toggleDeafen = useCallback(async () => {
    await mediaService.setDeafened(!store.deafened);
  }, [store.deafened]);

  const flipCamera = useCallback(async () => {
    await mediaService.switchCamera();
  }, []);

  // ── Screen Share ──

  const startScreenShare = useCallback(async (quality?: string) => {
    await mediaService.startScreenShare({
      quality: quality as any,
      audio: true,
    });
  }, []);

  const stopScreenShare = useCallback(async () => {
    await mediaService.stopScreenShare();
  }, []);

  // ── Layout ──

  const setLayout = useCallback((layout: 'grid' | 'focus' | 'sidebar') => {
    store.setVideoLayout(layout);
  }, []);

  const focusParticipant = useCallback((participantId: string | null) => {
    store.setFocusedParticipant(participantId);
    if (participantId) {
      store.setVideoLayout('focus');
    }
  }, []);

  // ── Elapsed Timer ──

  useEffect(() => {
    if (store.connectionState === 'connected') {
      elapsedTimerRef.current = setInterval(() => {
        store.incrementElapsedTime();
      }, 1000);
    }
    return () => {
      if (elapsedTimerRef.current) {
        clearInterval(elapsedTimerRef.current);
      }
    };
  }, [store.connectionState]);

  // ── App State Handling (background/foreground) ──

  useEffect(() => {
    let wasVideoEnabled = false;

    const handleAppState = (nextState: AppStateStatus) => {
      if (!mediaService.isConnected()) return;

      if (nextState === 'background' || nextState === 'inactive') {
        if (store.videoEnabled) {
          mediaService.enableCamera(false);
          wasVideoEnabled = true;
        }
      } else if (nextState === 'active') {
        if (wasVideoEnabled) {
          mediaService.enableCamera(true);
          wasVideoEnabled = false;
        }
      }
    };

    const subscription = AppState.addEventListener('change', handleAppState);
    return () => subscription.remove();
  }, [store.videoEnabled]);

  // ── Auto Join ──

  useEffect(() => {
    if (autoJoin) {
      join();
    }
  }, [autoJoin]);

  // ── Derived State ──

  const participantList = store.participants;
  const videoParticipants = participantList.filter((p) => p.videoEnabled || p.video);
  const screenSharers = participantList.filter((p) => p.screenSharing || p.streaming);

  return {
    // State
    connectionState: store.connectionState,
    muted: store.muted,
    deafened: store.deafened,
    videoEnabled: store.videoEnabled,
    screenSharing: store.screenSharing,
    cameraFacing: store.cameraFacing,
    videoLayout: store.videoLayout,
    focusedParticipantId: store.focusedParticipantId,
    elapsedTime: store.elapsedTime,
    mediaStats: store.mediaStats,

    // Participants
    participants: participantList,
    videoParticipants,
    screenSharers,
    activeSpeakers: store.activeSpeakers,
    participantCount: participantList.length,

    // Streams
    activeStreamId: store.activeStreamId,
    watchingStreamId: store.watchingStreamId,

    // Actions
    join,
    leave,
    toggleCamera,
    toggleMic,
    toggleDeafen,
    flipCamera,
    startScreenShare,
    stopScreenShare,
    setLayout,
    focusParticipant,
  };
}
