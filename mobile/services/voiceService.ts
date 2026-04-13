import { supabase } from '../../shared/lib/supabase';
import { useVoiceStore } from '@stores/voiceStore';
import { mediaService } from '@services/mediaService';
import { startAudioSession, stopAudioSession } from '../lib/livekit';
import * as Crypto from 'expo-crypto';

/**
 * Voice Service for Flicko Mobile
 *
 * Manages WebRTC voice/video connections via LiveKit SFU.
 * Handles:
 * - Voice channel join/leave with Supabase voice_states
 * - LiveKit room connection via mediaService
 * - Connection state management
 * - Audio/video track toggling
 * - Screen sharing lifecycle
 * - Connection quality monitoring
 *
 * Architecture: Client → Supabase Edge Fn (token) → LiveKit SFU → Peers
 */

export type VoiceConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'failed';

export type AudioInputMode = 'voice_activity' | 'push_to_talk';

export interface VoiceSettings {
  noiseSuppression: boolean;
  echoCancellation: boolean;
  autoGainControl: boolean;
  inputMode: AudioInputMode;
  inputSensitivity: number;
  outputVolume: number;
}

export interface ConnectionQuality {
  score: number;
  latencyMs: number;
  packetLossPercent: number;
  jitterMs: number;
}

export interface VoiceParticipantInfo {
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  isMuted: boolean;
  isDeafened: boolean;
  isSpeaking: boolean;
  isVideo: boolean;
  isStreaming: boolean;
  connectionQuality: ConnectionQuality | null;
}

const DEFAULT_SETTINGS: VoiceSettings = {
  noiseSuppression: true,
  echoCancellation: true,
  autoGainControl: true,
  inputMode: 'voice_activity',
  inputSensitivity: 50,
  outputVolume: 100,
};

// Module-level state
let currentSessionId: string | null = null;
let connectionState: VoiceConnectionState = 'disconnected';
let voiceSettings: VoiceSettings = { ...DEFAULT_SETTINGS };
let connectionQuality: ConnectionQuality | null = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 5;

// Callbacks
type StateChangeCallback = (state: VoiceConnectionState) => void;
type ParticipantChangeCallback = (participants: VoiceParticipantInfo[]) => void;
type QualityChangeCallback = (quality: ConnectionQuality) => void;
type SpeakingChangeCallback = (userId: string, speaking: boolean) => void;

const stateChangeListeners = new Set<StateChangeCallback>();
const participantChangeListeners = new Set<ParticipantChangeCallback>();
const qualityChangeListeners = new Set<QualityChangeCallback>();
const speakingChangeListeners = new Set<SpeakingChangeCallback>();

function emitStateChange(state: VoiceConnectionState) {
  connectionState = state;
  stateChangeListeners.forEach((cb) => cb(state));
}

function emitParticipantChange(participants: VoiceParticipantInfo[]) {
  participantChangeListeners.forEach((cb) => cb(participants));
}

function emitQualityChange(quality: ConnectionQuality) {
  connectionQuality = quality;
  qualityChangeListeners.forEach((cb) => cb(quality));
}

async function generateSessionId(): Promise<string> {
  const uuid = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    `${Date.now()}-${Math.random()}`
  );
  return uuid.substring(0, 32);
}

/**
 * Join a voice channel:
 * 1. Generate session ID
 * 2. Upsert voice_state in Supabase
 * 3. Start native audio session
 * 4. Connect to LiveKit room via mediaService
 * 5. Subscribe to realtime voice state changes
 */
export async function joinVoiceChannel(
  channelId: string,
  channelName: string,
  serverId: string
): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  if (connectionState === 'connected' || connectionState === 'connecting') {
    await leaveVoiceChannel();
  }

  emitStateChange('connecting');
  reconnectAttempts = 0;

  try {
    currentSessionId = await generateSessionId();

    const { error: voiceStateError } = await supabase
      .from('voice_states')
      .upsert({
        user_id: user.id,
        channel_id: channelId,
        server_id: serverId,
        session_id: currentSessionId,
        is_muted: false,
        is_deafened: false,
        is_self_muted: false,
        is_self_deafened: false,
        is_streaming: false,
        is_video: false,
        joined_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

    if (voiceStateError) {
      throw new Error(`Failed to set voice state: ${voiceStateError.message}`);
    }

    await logConnectionEvent(user.id, channelId, currentSessionId, 'connecting');

    // Start native audio session (configures speakers / bluetooth)
    await startAudioSession();

    // Connect to LiveKit room via mediaService
    try {
      await mediaService.joinChannel({
        channelId,
        serverId,
        enableVideo: false,
        enableAudio: true,
      });
    } catch (err) {
      console.warn('[VoiceService] LiveKit connection failed, state-only mode:', err);
    }

    emitStateChange('connected');
    useVoiceStore.getState().connect(channelId, channelName, serverId);

    subscribeToVoiceStates(channelId);
    await logConnectionEvent(user.id, channelId, currentSessionId, 'connected');
  } catch (error) {
    emitStateChange('failed');
    await logConnectionEvent(user.id, channelId, currentSessionId ?? 'unknown', 'failed');
    throw error;
  }
}

/**
 * Leave the current voice channel
 */
export async function leaveVoiceChannel(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const store = useVoiceStore.getState();
  const channelId = store.channelId;

  if (channelId && currentSessionId) {
    await logConnectionEvent(user.id, channelId, currentSessionId, 'disconnected');
  }

  // Disconnect LiveKit room
  try {
    await mediaService.leaveChannel();
  } catch (err) {
    console.warn('[VoiceService] mediaService.leaveChannel error:', err);
  }

  await stopAudioSession();

  const { error } = await supabase
    .from('voice_states')
    .delete()
    .eq('user_id', user.id);

  if (error) {
    console.warn('[VoiceService] Failed to remove voice state:', error.message);
  }

  if (channelId) {
    unsubscribeFromVoiceStates(channelId);
  }

  currentSessionId = null;
  connectionQuality = null;
  reconnectAttempts = 0;
  store.disconnect();
  emitStateChange('disconnected');
}

/**
 * Toggle self-mute — uses LiveKit localParticipant.setMicrophoneEnabled
 */
export async function toggleMute(): Promise<boolean> {
  const store = useVoiceStore.getState();
  const newMuted = !store.muted;

  try {
    await mediaService.setMicEnabled(!newMuted);
  } catch {
    store.setMuted(newMuted);
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    await supabase
      .from('voice_states')
      .update({ is_self_muted: newMuted, updated_at: new Date().toISOString() })
      .eq('user_id', user.id);
  }

  return newMuted;
}

/**
 * Toggle self-deafen (also mutes)
 */
export async function toggleDeafen(): Promise<boolean> {
  const store = useVoiceStore.getState();
  const newDeafened = !store.deafened;

  try {
    await mediaService.setDeafened(newDeafened);
  } catch {
    store.setDeafened(newDeafened);
    if (newDeafened) store.setMuted(true);
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    await supabase
      .from('voice_states')
      .update({
        is_self_deafened: newDeafened,
        is_self_muted: newDeafened || store.muted,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', user.id);
  }

  return newDeafened;
}

/**
 * Toggle video (camera on/off)
 */
export async function toggleVideo(): Promise<boolean> {
  const store = useVoiceStore.getState();
  const newVideo = !store.video;

  try {
    await mediaService.enableCamera(newVideo);
  } catch {
    store.setVideo(newVideo);
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    await supabase
      .from('voice_states')
      .update({ is_video: newVideo, updated_at: new Date().toISOString() })
      .eq('user_id', user.id);
  }

  return newVideo;
}

/**
 * Toggle screen sharing
 */
export async function toggleScreenShare(): Promise<boolean> {
  const store = useVoiceStore.getState();
  const newStreaming = !store.streaming;

  try {
    if (newStreaming) {
      await mediaService.startScreenShare({ audio: true });
    } else {
      await mediaService.stopScreenShare();
    }
  } catch {
    store.setStreaming(newStreaming);
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    await supabase
      .from('voice_states')
      .update({ is_streaming: newStreaming, updated_at: new Date().toISOString() })
      .eq('user_id', user.id);

    if (newStreaming && currentSessionId) {
      await supabase.from('screen_shares').insert({
        user_id: user.id,
        channel_id: store.channelId!,
        session_id: currentSessionId,
        share_type: 'screen',
        resolution: '1920x1080',
        frame_rate: 30,
      });
    } else if (!newStreaming) {
      await supabase
        .from('screen_shares')
        .update({ ended_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .is('ended_at', null);
    }
  }

  return newStreaming;
}

/**
 * Get current voice states for a channel
 */
export async function getChannelVoiceStates(channelId: string): Promise<VoiceParticipantInfo[]> {
  const { data, error } = await supabase
    .from('voice_states')
    .select('*, user:profiles!user_id(id, username, display_name, avatar_url:avatar)')
    .eq('channel_id', channelId);

  if (error) {
    console.warn('[VoiceService] Failed to fetch voice states:', error.message);
    return [];
  }

  return (data ?? []).map((vs: any) => ({
    userId: vs.user_id,
    username: vs.user?.username ?? 'Unknown',
    displayName: vs.user?.display_name ?? vs.user?.username ?? 'Unknown',
    avatarUrl: vs.user?.avatar_url ?? null,
    isMuted: vs.is_self_muted || vs.is_muted,
    isDeafened: vs.is_self_deafened || vs.is_deafened,
    isSpeaking: false,
    isVideo: vs.is_video,
    isStreaming: vs.is_streaming,
    connectionQuality: null,
  }));
}

// ── Realtime subscriptions ───────────────────────────────────────────────

const voiceStateChannels = new Map<string, any>();

function subscribeToVoiceStates(channelId: string) {
  if (voiceStateChannels.has(channelId)) return;

  const channel = supabase
    .channel(`voice-states:${channelId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'voice_states',
        filter: `channel_id=eq.${channelId}`,
      },
      async () => {
        const participants = await getChannelVoiceStates(channelId);
        emitParticipantChange(participants);

        const store = useVoiceStore.getState();
        store.setParticipants(
          participants.map((p) => ({
            id: p.userId,
            userId: p.userId,
            username: p.username,
            displayName: p.displayName,
            avatarUrl: p.avatarUrl,
            metadata: {},
            muted: p.isMuted,
            deafened: p.isDeafened,
            speaking: p.isSpeaking,
            audioEnabled: !p.isMuted,
            videoEnabled: p.isVideo,
            screenSharing: p.isStreaming,
            isSpeaking: p.isSpeaking,
            connectionQuality: 'good',
            tracks: [],
            video: p.isVideo,
            streaming: p.isStreaming,
          }))
        );
      }
    )
    .subscribe();

  voiceStateChannels.set(channelId, channel);
}

function unsubscribeFromVoiceStates(channelId: string) {
  const channel = voiceStateChannels.get(channelId);
  if (channel) {
    supabase.removeChannel(channel);
    voiceStateChannels.delete(channelId);
  }
}

// ── Connection event logging ─────────────────────────────────────────────

async function logConnectionEvent(
  userId: string,
  channelId: string,
  sessionId: string,
  eventType: 'connecting' | 'connected' | 'disconnected' | 'reconnecting' | 'failed'
) {
  try {
    await supabase.from('voice_connection_logs').insert({
      user_id: userId,
      channel_id: channelId,
      session_id: sessionId,
      event_type: eventType,
      quality_score: connectionQuality?.score ?? null,
      latency_ms: connectionQuality?.latencyMs ?? null,
      packet_loss_percent: connectionQuality?.packetLossPercent ?? null,
    });
  } catch (err) {
    console.warn('[VoiceService] Failed to log connection event:', err);
  }
}

// ── Settings ─────────────────────────────────────────────────────────────

export function getVoiceSettings(): VoiceSettings {
  return { ...voiceSettings };
}

export function updateVoiceSettings(updates: Partial<VoiceSettings>): VoiceSettings {
  voiceSettings = { ...voiceSettings, ...updates };
  return { ...voiceSettings };
}

// ── Event listeners ──────────────────────────────────────────────────────

export function onConnectionStateChange(callback: StateChangeCallback): () => void {
  stateChangeListeners.add(callback);
  return () => stateChangeListeners.delete(callback);
}

export function onParticipantChange(callback: ParticipantChangeCallback): () => void {
  participantChangeListeners.add(callback);
  return () => participantChangeListeners.delete(callback);
}

export function onConnectionQualityChange(callback: QualityChangeCallback): () => void {
  qualityChangeListeners.add(callback);
  return () => qualityChangeListeners.delete(callback);
}

export function onSpeakingChange(callback: SpeakingChangeCallback): () => void {
  speakingChangeListeners.add(callback);
  return () => speakingChangeListeners.delete(callback);
}

// ── Getters ──────────────────────────────────────────────────────────────

export function getConnectionState(): VoiceConnectionState {
  return connectionState;
}

export function getConnectionQuality(): ConnectionQuality | null {
  return connectionQuality;
}

export function getSessionId(): string | null {
  return currentSessionId;
}

const voiceService = {
  joinVoiceChannel,
  leaveVoiceChannel,
  toggleMute,
  toggleDeafen,
  toggleVideo,
  toggleScreenShare,
  getChannelVoiceStates,
  getVoiceSettings,
  updateVoiceSettings,
  getConnectionState,
  getConnectionQuality,
  getSessionId,
  onConnectionStateChange,
  onParticipantChange,
  onConnectionQualityChange,
  onSpeakingChange,
};

export default voiceService;
