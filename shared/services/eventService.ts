/**
 * Events Service
 *
 * CRUD for scheduled events + RSVP management.
 * Requirements: Feature 10 (Scheduled Events)
 */
import { supabase } from '../lib/supabase';

export interface ScheduledEvent {
  id: string;
  server_id: string;
  channel_id: string | null;
  name: string;
  description: string | null;
  start_time: string;
  end_time: string | null;
  location: string | null;
  image_url: string | null;
  status: 'scheduled' | 'active' | 'completed' | 'cancelled';
  creator_id: string;
  interested_count: number;
  created_at: string;
  creator?: { username: string; display_name?: string };
  channel?: { name: string; type: string };
}

export interface EventRSVP {
  id: string;
  event_id: string;
  user_id: string;
  status: 'interested' | 'going';
  user?: { username: string; display_name?: string; avatar_url?: string };
}

// ─── CRUD ──────────────────────────────────────────────────────────────────────

export async function getServerEvents(serverId: string): Promise<ScheduledEvent[]> {
  const { data, error } = await supabase
    .from('scheduled_events')
    .select(`
      *,
      creator:profiles!creator_id(username, display_name),
      channel:channels!channel_id(name, type)
    `)
    .eq('server_id', serverId)
    .in('status', ['scheduled', 'active'])
    .order('start_time', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function getEvent(eventId: string): Promise<ScheduledEvent> {
  const { data, error } = await supabase
    .from('scheduled_events')
    .select(`
      *,
      creator:profiles!creator_id(username, display_name),
      channel:channels!channel_id(name, type)
    `)
    .eq('id', eventId)
    .single();
  if (error) throw error;
  return data;
}

export async function createEvent(input: {
  serverId: string;
  name: string;
  description?: string;
  startTime: string;
  endTime?: string;
  channelId?: string;
  location?: string;
  creatorId: string;
}): Promise<ScheduledEvent> {
  const { data, error } = await supabase
    .from('scheduled_events')
    .insert({
      server_id: input.serverId,
      name: input.name,
      description: input.description || null,
      start_time: input.startTime,
      end_time: input.endTime || null,
      channel_id: input.channelId || null,
      location: input.location || null,
      creator_id: input.creatorId,
      status: 'scheduled',
    })
    .select('*')
    .single();
  if (error) throw error;
  return data;
}

export async function updateEvent(eventId: string, updates: Partial<{
  name: string;
  description: string | null;
  start_time: string;
  end_time: string | null;
  location: string | null;
  channel_id: string | null;
  status: 'scheduled' | 'active' | 'completed' | 'cancelled';
}>) {
  const { error } = await supabase
    .from('scheduled_events')
    .update(updates)
    .eq('id', eventId);
  if (error) throw error;
}

export async function deleteEvent(eventId: string) {
  const { error } = await supabase.from('scheduled_events').delete().eq('id', eventId);
  if (error) throw error;
}

// ─── RSVP ──────────────────────────────────────────────────────────────────────

export async function getEventRSVPs(eventId: string): Promise<EventRSVP[]> {
  const { data, error } = await supabase
    .from('event_rsvps')
    .select('*, user:profiles!user_id(username, display_name, avatar_url)')
    .eq('event_id', eventId);
  if (error) throw error;
  return data ?? [];
}

export async function rsvpToEvent(eventId: string, userId: string, status: 'interested' | 'going') {
  const { error } = await supabase
    .from('event_rsvps')
    .upsert({ event_id: eventId, user_id: userId, status }, { onConflict: 'event_id,user_id' });
  if (error) throw error;
}

export async function cancelRSVP(eventId: string, userId: string) {
  const { error } = await supabase
    .from('event_rsvps')
    .delete()
    .eq('event_id', eventId)
    .eq('user_id', userId);
  if (error) throw error;
}
