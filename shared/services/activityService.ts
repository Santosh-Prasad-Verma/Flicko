/**
 * Activity Service
 *
 * Handles fetching available activities, creating/joining/ending
 * activity sessions in voice channels.
 *
 * Requirements: Activity Picker & Session Lifecycle
 */
import { supabase } from '../lib/supabase';
import type {
  Activity,
  ActivityCategory,
  ActivitySession,
  ActivitySessionState,
  ActivityParticipant,
} from '../stores/activityStore';

// ── Fetch activities ──────────────────────────────────────────────────────

/**
 * Get all available activities, optionally filtered by category
 */
export async function getActivities(
  category?: ActivityCategory,
): Promise<Activity[]> {
  let query = supabase
    .from('activities')
    .select('*')
    .eq('enabled', true)
    .order('name');

  if (category) {
    query = query.eq('category', category);
  }

  const { data, error } = await query;

  if (error) throw new Error(`Failed to fetch activities: ${error.message}`);

  let results = data ?? [];

  // Fallback mock activities if none found in the database
  return results.map((row: any) => ({
    id: row.id,
    name: row.name,
    description: row.description || '',
    iconUrl: row.icon_url || '',
    category: row.category as ActivityCategory,
    maxParticipants: row.max_participants || 25,
    isPremium: row.is_premium || false,
    embedUrl: row.embed_url || '',
    developer: row.developer || 'Flicko',
    avgDuration: row.avg_duration || '~15 min',
  }));
}

// ── Session management ────────────────────────────────────────────────────

/**
 * Create a new activity session in a voice channel
 */
export async function createActivitySession(params: {
  activityId: string;
  channelId: string;
  serverId: string;
}): Promise<ActivitySession> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { data: activity, error: activityError } = await supabase
    .from('activities')
    .select('*')
    .eq('id', params.activityId)
    .maybeSingle();

  if (activityError || !activity) {
    throw new Error('Activity not found. Run Supabase migrations (includes 098_seed_builtin_activities).');
  }

  // Create session
  const { data: session, error } = await supabase
    .from('activity_sessions')
    .insert({
      activity_id: params.activityId,
      channel_id: params.channelId,
      server_id: params.serverId,
      host_user_id: user.id,
      state: 'launching',
      embed_url: activity.embed_url,
    })
    .select()
    .single();

  if (error) throw new Error(`Failed to create session: ${error.message}`);

  // Add host as participant
  await supabase.from('activity_participants').insert({
    session_id: session.id,
    user_id: user.id,
  });

  return {
    id: session.id,
    activityId: session.activity_id,
    activity: {
      id: activity.id,
      name: activity.name,
      description: activity.description || '',
      iconUrl: activity.icon_url || '',
      category: activity.category,
      maxParticipants: activity.max_participants || 25,
      isPremium: activity.is_premium || false,
      embedUrl: activity.embed_url || '',
      developer: activity.developer || 'Flicko',
      avgDuration: activity.avg_duration || '~15 min',
    },
    channelId: session.channel_id,
    serverId: session.server_id,
    hostUserId: session.host_user_id,
    state: 'launching',
    participants: [],
    embedUrl: session.embed_url,
    createdAt: session.created_at,
    startedAt: null,
    endedAt: null,
    errorMessage: null,
  };
}

/**
 * Join an existing activity session
 */
export async function joinActivitySession(sessionId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { error } = await supabase
    .from('activity_participants')
    .upsert({ session_id: sessionId, user_id: user.id });

  if (error) throw new Error(`Failed to join session: ${error.message}`);
}

/**
 * Leave an activity session
 */
export async function leaveActivitySession(sessionId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  await supabase
    .from('activity_participants')
    .delete()
    .eq('session_id', sessionId)
    .eq('user_id', user.id);
}

/**
 * Update the session state
 */
export async function updateSessionState(
  sessionId: string,
  state: ActivitySessionState,
): Promise<void> {
  const updates: Record<string, any> = { state };

  if (state === 'active') updates.started_at = new Date().toISOString();
  if (state === 'ended') updates.ended_at = new Date().toISOString();

  const { error } = await supabase
    .from('activity_sessions')
    .update(updates)
    .eq('id', sessionId);

  if (error) throw new Error(`Failed to update session: ${error.message}`);
}

/**
 * End an activity session (host only)
 */
export async function endActivitySession(sessionId: string): Promise<void> {
  await updateSessionState(sessionId, 'ended');
  // Remove all participants
  await supabase
    .from('activity_participants')
    .delete()
    .eq('session_id', sessionId);
}

/**
 * Get the active session for a voice channel (if any)
 */
export async function getActiveSession(
  channelId: string,
): Promise<ActivitySession | null> {
  const { data, error } = await supabase
    .from('activity_sessions')
    .select('*, activity:activities(*), participants:activity_participants(*, profile:profiles(username, display_name, avatar))')
    .eq('channel_id', channelId)
    .in('state', ['launching', 'active'])
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error || !data) return null;

  return {
    id: data.id,
    activityId: data.activity_id,
    activity: {
      id: data.activity.id,
      name: data.activity.name,
      description: data.activity.description || '',
      iconUrl: data.activity.icon_url || '',
      category: data.activity.category,
      maxParticipants: data.activity.max_participants || 25,
      isPremium: data.activity.is_premium || false,
      embedUrl: data.activity.embed_url || '',
      developer: data.activity.developer || 'Flicko',
      avgDuration: data.activity.avg_duration || '~15 min',
    },
    channelId: data.channel_id,
    serverId: data.server_id,
    hostUserId: data.host_user_id,
    state: data.state,
    participants: (data.participants ?? []).map((p: any) => ({
      userId: p.user_id,
      displayName: p.profile?.display_name || p.profile?.username || 'Unknown',
      avatarUrl: p.profile?.avatar || null,
      joinedAt: p.created_at,
    })),
    embedUrl: data.embed_url,
    createdAt: data.created_at,
    startedAt: data.started_at,
    endedAt: data.ended_at,
    errorMessage: null,
  };
}

/**
 * Subscribe to real-time session updates for a channel
 */
export function subscribeToActivitySession(
  channelId: string,
  onUpdate: (session: ActivitySession | null) => void,
): () => void {
  const channel = supabase
    .channel(`activity-session:${channelId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'activity_sessions',
        filter: `channel_id=eq.${channelId}`,
      },
      async () => {
        // Re-fetch the active session on any change
        const session = await getActiveSession(channelId);
        onUpdate(session);
      },
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
