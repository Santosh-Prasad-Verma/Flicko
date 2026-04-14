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
  server_id?: string;
  is_muted: boolean;
  is_deafened: boolean;
  is_self_muted: boolean;
  is_self_deafened: boolean;
  is_streaming?: boolean;
  is_video?: boolean;
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
  serverId: string,
): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { error } = await supabase.from('voice_states').upsert(
    {
      user_id: user.id,
      channel_id: channelId,
      server_id: serverId,
      session_id: sessionId,
      is_muted: false,
      is_deafened: false,
      is_self_muted: false,
      is_self_deafened: false,
      is_streaming: false,
      is_video: false,
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
  updates: Partial<Pick<VoiceStateRow, 'is_self_muted' | 'is_self_deafened'>>,
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
      is_muted,
      is_deafened,
      is_self_muted,
      is_self_deafened,
      is_streaming,
      is_video,
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
      muted: row.is_self_muted || row.is_muted,
      deafened: row.is_self_deafened || row.is_deafened,
      speaking: false,
      video: row.is_video || false,
      streaming: row.is_streaming || false,
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
