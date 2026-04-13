import { create } from 'zustand';
import { supabase } from '../lib/supabase';

/**
 * Wraps LiveKit SDK for room lifecycle, camera/screen controls,
 * quality management, and stats collection.
 *
 * Zero-cost: Uses self-hosted LiveKit on Oracle Cloud Always Free tier
 */

// ──────────────────────────────────────────
// Types
// ──────────────────────────────────────────

export type VoiceConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'failed';

export type VideoLayout = 'grid' | 'focus' | 'sidebar';

export interface ParticipantTrack {
  source: string; // 'camera' | 'microphone' | 'screen_share' | 'screen_share_audio'
  kind: string;   // 'audio' | 'video'
  enabled: boolean;
  muted: boolean;
}

export interface VoiceParticipant {
  id: string;
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  metadata: Record<string, unknown>;
  muted: boolean;
  deafened: boolean;
  speaking: boolean;
  audioEnabled: boolean;
  videoEnabled: boolean;
  screenSharing: boolean;
  isSpeaking: boolean;
  connectionQuality: string;
  tracks: ParticipantTrack[];
  // Legacy compat
  video: boolean;
  streaming: boolean;
}

export interface MediaQualityPreset {
  name: string;
  width: number;
  height: number;
  fps: number;
  maxBitrate: number;
}

export interface StreamConfig {
  channelId: string;
  serverId: string;
  title?: string;
  streamType?: 'screen' | 'application' | 'game' | 'camera';
  quality?: '720p15' | '720p30' | '1080p30' | '1080p60';
}

export interface MediaStats {
  outgoing: {
    video?: { width: number; height: number; fps: number; bitrate: number; codec: string };
    screen?: { width: number; height: number; fps: number; bitrate: number; codec: string };
    audio?: { bitrate: number; codec: string };
  };
  incoming: Map<string, {
    video?: { width: number; height: number; fps: number; bitrate: number };
    audio?: { bitrate: number };
  }>;
  networkQuality: 'excellent' | 'good' | 'fair' | 'poor';
}

interface VoiceState {
  // ── Connection ──
  room: any; // LiveKit Room instance
  channelId: string | null;
  channelName: string | null;
  serverId: string | null;
  connectionState: VoiceConnectionState;

  // ── Local User Media State ──
  muted: boolean;
  deafened: boolean;
  videoEnabled: boolean;
  screenSharing: boolean;
  cameraFacing: 'front' | 'back';
  videoQuality: string;
  // Legacy compat
  video: boolean;
  streaming: boolean;

  // ── Participants ──
  participants: VoiceParticipant[];
  activeSpeakers: Set<string>;

  // ── Streams (Go Live) ──
  activeStreamId: string | null;
  streamTitle: string;
  watchingStreamId: string | null;

  // ── UI State ──
  videoLayout: VideoLayout;
  focusedParticipantId: string | null;
  controlsVisible: boolean;
  pipActive: boolean;

  // ── Stats ──
  mediaStats: MediaStats | null;
  elapsedTime: number;

  // ── Actions ──
  setRoom: (room: any) => void;
  connect: (channelId: string, channelName: string, serverId: string) => void;
  disconnect: () => void;
  setConnected: (connected: boolean) => void;
  setConnectionState: (state: VoiceConnectionState) => void;
  setChannelId: (id: string | null) => void;
  setServerId: (id: string | null) => void;

  toggleMute: () => void;
  toggleDeafen: () => void;
  setMuted: (muted: boolean) => void;
  setDeafened: (deafened: boolean) => void;
  setVideoEnabled: (enabled: boolean) => void;
  setScreenSharing: (sharing: boolean) => void;
  setCameraFacing: (facing: 'front' | 'back') => void;
  setVideoQuality: (quality: string) => void;
  setVideo: (on: boolean) => void;
  setStreaming: (on: boolean) => void;

  setSpeaking: (userId: string, speaking: boolean) => void;
  setParticipants: (participants: VoiceParticipant[]) => void;
  addParticipant: (participant: VoiceParticipant) => void;
  removeParticipant: (userId: string) => void;
  updateParticipant: (id: string, updates: Partial<VoiceParticipant>) => void;
  updateParticipantTrack: (id: string, track: ParticipantTrack) => void;
  setActiveSpeakers: (speakers: Set<string>) => void;

  setActiveStreamId: (id: string | null) => void;
  setStreamTitle: (title: string) => void;
  setWatchingStreamId: (id: string | null) => void;

  setVideoLayout: (layout: VideoLayout) => void;
  setFocusedParticipant: (id: string | null) => void;
  setControlsVisible: (visible: boolean) => void;
  setPipActive: (active: boolean) => void;

  setMediaStats: (stats: MediaStats) => void;
  incrementElapsedTime: () => void;

  handleDataMessage: (data: unknown, senderId?: string) => void;
  reset: () => void;
}

export const QUALITY_PRESETS: Record<string, MediaQualityPreset> = {
  '360p':    { name: '360p',    width: 640,  height: 360,  fps: 30, maxBitrate: 800_000 },
  '480p':    { name: '480p',    width: 854,  height: 480,  fps: 30, maxBitrate: 1_200_000 },
  '720p':    { name: '720p',    width: 1280, height: 720,  fps: 30, maxBitrate: 2_500_000 },
  '1080p':   { name: '1080p',   width: 1920, height: 1080, fps: 30, maxBitrate: 4_000_000 },
};

export const SCREEN_SHARE_PRESETS: Record<string, MediaQualityPreset> = {
  '720p15':  { name: '720p 15fps',  width: 1280, height: 720,  fps: 15, maxBitrate: 1_500_000 },
  '720p30':  { name: '720p 30fps',  width: 1280, height: 720,  fps: 30, maxBitrate: 2_500_000 },
  '1080p30': { name: '1080p 30fps', width: 1920, height: 1080, fps: 30, maxBitrate: 4_000_000 },
  '1080p60': { name: '1080p 60fps', width: 1920, height: 1080, fps: 60, maxBitrate: 6_000_000 },
};

// ──────────────────────────────────────────
// Initial State
// ──────────────────────────────────────────

const initialState = {
  room: null as any,
  channelId: null as string | null,
  channelName: null as string | null,
  serverId: null as string | null,
  connectionState: 'disconnected' as VoiceConnectionState,
  muted: false,
  deafened: false,
  videoEnabled: false,
  screenSharing: false,
  cameraFacing: 'front' as 'front' | 'back',
  videoQuality: 'auto',
  video: false,
  streaming: false,
  participants: [] as VoiceParticipant[],
  activeSpeakers: new Set<string>(),
  activeStreamId: null as string | null,
  streamTitle: '',
  watchingStreamId: null as string | null,
  videoLayout: 'grid' as VideoLayout,
  focusedParticipantId: null as string | null,
  controlsVisible: true,
  pipActive: false,
  mediaStats: null as MediaStats | null,
  elapsedTime: 0,
};

// ──────────────────────────────────────────
// Store
// ──────────────────────────────────────────

export const useVoiceStore = create<VoiceState>((set, get) => ({
  ...initialState,

  // ── Room ──
  setRoom: (room) => set({ room }),

  // ── Connection ──
  setConnected: (connected) => set({
    connectionState: connected ? 'connected' : 'disconnected',
  }),
  setConnectionState: (connectionState) => set({ connectionState }),
  setChannelId: (channelId) => set({ channelId }),
  setServerId: (serverId) => set({ serverId }),

  connect: (channelId, channelName, serverId) =>
    set({
      channelId,
      channelName,
      serverId,
      connectionState: 'connected',
      muted: false,
      deafened: false,
      videoEnabled: false,
      screenSharing: false,
      video: false,
      streaming: false,
    }),

  disconnect: () =>
    set({
      ...initialState,
      participants: [],
      activeSpeakers: new Set(),
    }),

  // ── Local Media ──
  toggleMute: () => set((s) => ({ muted: !s.muted })),

  toggleDeafen: () =>
    set((s) => ({
      deafened: !s.deafened,
      muted: !s.deafened ? true : s.muted,
    })),

  setMuted: (muted) => set({ muted }),
  setDeafened: (deafened) => set({ deafened }),
  setVideoEnabled: (videoEnabled) => set({ videoEnabled, video: videoEnabled }),
  setScreenSharing: (screenSharing) => set({ screenSharing, streaming: screenSharing }),
  setCameraFacing: (cameraFacing) => set({ cameraFacing }),
  setVideoQuality: (videoQuality) => set({ videoQuality }),
  setVideo: (video) => set({ video, videoEnabled: video }),
  setStreaming: (streaming) => set({ streaming, screenSharing: streaming }),

  // ── Participants ──
  setSpeaking: (userId, speaking) =>
    set((s) => ({
      participants: s.participants.map((p) =>
        p.userId === userId ? { ...p, speaking, isSpeaking: speaking } : p
      ),
    })),

  setParticipants: (participants) => set({ participants }),

  addParticipant: (participant) =>
    set((s) => ({
      participants: [
        ...s.participants.filter(p => p.userId !== participant.userId),
        participant
      ],
    })),

  removeParticipant: (userId) =>
    set((s) => ({
      participants: s.participants.filter((p) => p.userId !== userId && p.id !== userId),
      focusedParticipantId: s.focusedParticipantId === userId ? null : s.focusedParticipantId,
    })),

  updateParticipant: (id, updates) =>
    set((s) => ({
      participants: s.participants.map((p) =>
        (p.id === id || p.userId === id) ? { ...p, ...updates } : p
      ),
    })),

  updateParticipantTrack: (id, track) =>
    set((s) => ({
      participants: s.participants.map((p) => {
        if (p.id !== id && p.userId !== id) return p;
        const tracks = (p.tracks || []).filter((t) => t.source !== track.source);
        tracks.push(track);
        const videoEnabled = tracks.some((t) => t.source === 'camera' && t.enabled && !t.muted);
        const screenSharing = tracks.some((t) => t.source === 'screen_share' && t.enabled && !t.muted);
        const audioEnabled = tracks.some((t) => t.source === 'microphone' && t.enabled && !t.muted);
        return {
          ...p,
          tracks,
          videoEnabled,
          screenSharing,
          audioEnabled,
          video: videoEnabled,
          streaming: screenSharing,
        };
      }),
    })),

  setActiveSpeakers: (speakerIds) =>
    set((s) => ({
      participants: s.participants.map((p) => ({
        ...p,
        isSpeaking: speakerIds.has(p.id) || speakerIds.has(p.userId),
        speaking: speakerIds.has(p.id) || speakerIds.has(p.userId),
      })),
      activeSpeakers: speakerIds,
    })),

  // ── Streams ──
  setActiveStreamId: (activeStreamId) => set({ activeStreamId }),
  setStreamTitle: (streamTitle) => set({ streamTitle }),
  setWatchingStreamId: (watchingStreamId) => set({ watchingStreamId }),

  // ── UI ──
  setVideoLayout: (videoLayout) => set({ videoLayout }),
  setFocusedParticipant: (focusedParticipantId) => set({ focusedParticipantId }),
  setControlsVisible: (controlsVisible) => set({ controlsVisible }),
  setPipActive: (pipActive) => set({ pipActive }),

  // ── Stats ──
  setMediaStats: (mediaStats) => set({ mediaStats }),
  incrementElapsedTime: () => set((s) => ({ elapsedTime: s.elapsedTime + 1 })),

  // ── Data Messages ──
  handleDataMessage: (_data, _senderId) => {
    // Handle custom signaling: focus requests, reactions, etc.
  },

  // ── Reset ──
  reset: () => set({
    ...initialState,
    participants: [],
    activeSpeakers: new Set(),
  }),
}));

// ──────────────────────────────────────────
// Token fetcher (exported for use by mediaService)
// ──────────────────────────────────────────

export async function fetchVoiceToken(config: {
  channelId: string;
  serverId: string;
  video?: boolean;
  screenShare?: boolean;
  streamTitle?: string;
  streamType?: string;
  quality?: string;
}): Promise<{ token: string; room: string; streamId: string | null; serverUrl: string; qualityConfig?: any }> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const response = await supabase.functions.invoke('voice-token', {
    body: config,
    headers: { Authorization: `Bearer ${session.access_token}` },
  });

  if (response.error) throw new Error(response.error.message);
  return response.data;
}
