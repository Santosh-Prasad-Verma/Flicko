/**
 * Video Settings Service — User video preferences
 *
 * Zero-cost: Stored in Supabase Postgres video_settings table
 */
import { supabase } from '../lib/supabase';

export interface VideoSettings {
  user_id: string;
  default_camera_enabled: boolean;
  default_camera_facing: 'front' | 'back';
  mirror_self_view: boolean;
  preferred_quality: 'auto' | '360p' | '480p' | '720p' | '1080p';
  preferred_fps: 15 | 30 | 60;
  hardware_acceleration: boolean;
  screen_share_audio: boolean;
  screen_share_quality: '720p15' | '720p30' | '1080p30' | '1080p60';
  reduced_motion: boolean;
  data_saver_mode: boolean;
  max_incoming_quality: '360p' | '480p' | '720p' | '1080p';
  default_layout: 'grid' | 'focus' | 'sidebar';
  show_non_video: boolean;
  pip_enabled: boolean;
  pip_position: 'top_left' | 'top_right' | 'bottom_left' | 'bottom_right';
}

export async function getVideoSettings(): Promise<VideoSettings | null> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;

  const { data, error } = await supabase
    .from('video_settings')
    .select('*')
    .eq('user_id', session.user.id)
    .single();

  if (error) return null;
  return data;
}

export async function updateVideoSettings(
  updates: Partial<Omit<VideoSettings, 'user_id'>>
): Promise<VideoSettings> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('video_settings')
    .update(updates)
    .eq('user_id', session.user.id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function ensureVideoSettings(): Promise<VideoSettings> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  // Try to get existing settings
  const existing = await getVideoSettings();
  if (existing) return existing;

  // Create default settings
  const { data, error } = await supabase
    .from('video_settings')
    .insert({ user_id: session.user.id })
    .select()
    .single();

  if (error) throw error;
  return data;
}
