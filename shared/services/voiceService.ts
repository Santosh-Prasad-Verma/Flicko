/**
 * Voice Service (React Native)
 *
 * Manages LiveKit room connections, participant state,
 * and voice channel join/leave/mute operations.
 *
 * Requirements: Feature 15-19 (Voice & Video Channels)
 */
import { supabase } from '../lib/supabase';
import { useVoiceStore, type VoiceParticipant } from '../stores/voiceStore';

// ── Types ─────────────────────────────────────────────────────────────────

export interface VoiceTokenResponse {
  token: string;
  ws_url: string;
  room_name: string;
}

export interface VoiceStateRow {
  id: string;
  user_id: string;
  channel_id: string;
  session_id: string;
  self_mute: boolean;
  self_deaf: boolean;
  server_mute: boolean;
  server_deaf: boolean;
  joined_at: string;
}

// ── Constants ─────────────────────────────────────────────────────────────

const LIVEKIT_TOKEN_ENDPOINT = '/v1/voice/token';

// ── API Functions ─────────────────────────────────────────────────────────

/**
 * Request a LiveKit token for joining a voice channel
 */
export async function requestVoiceToken(
  channelId: string,
): Promise<VoiceTokenResponse> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  // Call the backend token service
  // This could be a Supabase Edge Function or external endpoint
  const { data, error } = await supabase.functions.invoke('voice-token', {
    body: { channel_id: channelId },
  });

  if (error) throw error;
  return data as VoiceTokenResponse;
}

/**
 * Join a voice channel (update DB state)
 */
export async function joinVoiceChannel(
  channelId: string,
  sessionId: string,
): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { error } = await supabase.from('voice_states').upsert(
    {
      user_id: user.id,
      channel_id: channelId,
      session_id: sessionId,
      self_mute: false,
      self_deaf: false,
      server_mute: false,
      server_deaf: false,
      joined_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  if (error) throw error;
}

/**
 * Leave a voice channel (remove DB state)
 */
export async function leaveVoiceChannel(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const { error } = await supabase
    .from('voice_states')
    .delete()
    .eq('user_id', user.id);

  if (error) console.error('[voiceService] leave error:', error);
}

/**
 * Update voice state (mute/deafen)
 */
export async function updateVoiceState(
  updates: Partial<Pick<VoiceStateRow, 'self_mute' | 'self_deaf'>>,
): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const { error } = await supabase
    .from('voice_states')
    .update(updates)
    .eq('user_id', user.id);

  if (error) console.error('[voiceService] updateState error:', error);
}

/**
 * Get current participants in a voice channel
 */
export async function getVoiceParticipants(
  channelId: string,
): Promise<VoiceParticipant[]> {
  const { data, error } = await supabase
    .from('voice_states')
    .select(`
      user_id,
      self_mute,
      self_deaf,
      server_mute,
      server_deaf,
      user:profiles!voice_states_user_id_fkey(username, display_name, avatar)
    `)
    .eq('channel_id', channelId);

  if (error) throw error;

  return (data ?? []).map((row: any) => {
    const profile = Array.isArray(row.user) ? row.user[0] : row.user;
    return {
      userId: row.user_id,
      username: profile?.username ?? 'Unknown',
      displayName: profile?.display_name ?? profile?.username ?? 'Unknown',
      avatarUrl: profile?.avatar ?? null,
      muted: row.self_mute || row.server_mute,
      deafened: row.self_deaf || row.server_deaf,
      speaking: false,
      video: false,
      streaming: false,
    };
  });
}

/**
 * Subscribe to voice state changes in a channel
 */
export function subscribeToVoiceStates(
  channelId: string,
  onUpdate: (participants: VoiceParticipant[]) => void,
): () => void {
  const channel = supabase
    .channel(`voice:${channelId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'voice_states',
        filter: `channel_id=eq.${channelId}`,
      },
      async () => {
        // Refetch all participants on any change
        try {
          const participants = await getVoiceParticipants(channelId);
          onUpdate(participants);
        } catch (err) {
          console.error('[voiceService] subscribe update error:', err);
        }
      },
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
