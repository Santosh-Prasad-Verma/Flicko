/**
 * Soundboard Service
 *
 * Handles CRUD operations for soundboard sounds, favorites management,
 * and audio playback via the server API.
 *
 * Requirements: Soundboard Feature
 */
import { supabase } from '../lib/supabase';
import type { SoundboardSound } from '../stores/soundboardStore';

// ── Fetch sounds ──────────────────────────────────────────────────────────

/**
 * Get all soundboard sounds for a server
 */
export async function getServerSounds(serverId: string): Promise<SoundboardSound[]> {
  const { data, error } = await supabase
    .from('soundboard_sounds')
    .select('*, uploader:profiles!uploaded_by(username)')
    .eq('server_id', serverId)
    .order('name');

  if (error) throw new Error(`Failed to fetch server sounds: ${error.message}`);

  return (data ?? []).map((row: any) => ({
    id: row.id,
    name: row.name,
    emoji: row.emoji || '🔊',
    soundUrl: row.sound_url,
    duration: row.duration || 0,
    uploadedBy: row.uploader?.username ?? 'Unknown',
    serverId: row.server_id,
    isFavorite: false, // populated separately
    playCount: row.play_count || 0,
    createdAt: row.created_at,
  }));
}

/**
 * Get the current user's favorite sounds
 */
export async function getFavoriteSounds(): Promise<SoundboardSound[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { data, error } = await supabase
    .from('soundboard_favorites')
    .select('sound:soundboard_sounds(*, uploader:profiles!uploaded_by(username))')
    .eq('user_id', user.id);

  if (error) throw new Error(`Failed to fetch favorites: ${error.message}`);

  return (data ?? []).map((row: any) => {
    const s = row.sound;
    return {
      id: s.id,
      name: s.name,
      emoji: s.emoji || '🔊',
      soundUrl: s.sound_url,
      duration: s.duration || 0,
      uploadedBy: s.uploader?.username ?? 'Unknown',
      serverId: s.server_id,
      isFavorite: true,
      playCount: s.play_count || 0,
      createdAt: s.created_at,
    };
  });
}

/**
 * Get trending / popular sounds across all servers the user is in
 */
export async function getTrendingSounds(): Promise<SoundboardSound[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  // Get servers the user is in
  const { data: memberships } = await supabase
    .from('server_members')
    .select('server_id')
    .eq('user_id', user.id);

  if (!memberships || memberships.length === 0) return [];

  const serverIds = memberships.map((m) => m.server_id);

  const { data, error } = await supabase
    .from('soundboard_sounds')
    .select('*, uploader:profiles!uploaded_by(username)')
    .in('server_id', serverIds)
    .order('play_count', { ascending: false })
    .limit(20);

  if (error) throw new Error(`Failed to fetch trending sounds: ${error.message}`);

  return (data ?? []).map((row: any) => ({
    id: row.id,
    name: row.name,
    emoji: row.emoji || '🔊',
    soundUrl: row.sound_url,
    duration: row.duration || 0,
    uploadedBy: row.uploader?.username ?? 'Unknown',
    serverId: row.server_id,
    isFavorite: false,
    playCount: row.play_count || 0,
    createdAt: row.created_at,
  }));
}

// ── Favorites ─────────────────────────────────────────────────────────────

/**
 * Toggle a sound as favorite for the current user
 */
export async function toggleFavoriteSound(soundId: string): Promise<boolean> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  // Check if already favorited
  const { data: existing } = await supabase
    .from('soundboard_favorites')
    .select('id')
    .eq('user_id', user.id)
    .eq('sound_id', soundId)
    .maybeSingle();

  if (existing) {
    // Remove favorite
    await supabase
      .from('soundboard_favorites')
      .delete()
      .eq('user_id', user.id)
      .eq('sound_id', soundId);
    return false;
  } else {
    // Add favorite
    await supabase
      .from('soundboard_favorites')
      .insert({ user_id: user.id, sound_id: soundId });
    return true;
  }
}

// ── Playback tracking ─────────────────────────────────────────────────────

/**
 * Record a sound play and increment play count
 */
export async function recordSoundPlay(soundId: string): Promise<void> {
  await supabase.rpc('increment_sound_play_count', { sound_id: soundId });
}

// ── Upload ────────────────────────────────────────────────────────────────

/**
 * Upload a new soundboard sound
 */
export async function uploadSound(params: {
  serverId: string;
  name: string;
  emoji: string;
  fileUri: string;
  duration: number;
}): Promise<SoundboardSound> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  // Upload to storage
  const filename = `${Date.now()}_${params.name.replace(/\s+/g, '_')}.mp3`;
  const filePath = `soundboard/${params.serverId}/${filename}`;

  const response = await fetch(params.fileUri);
  const blob = await response.blob();

  const { error: uploadError } = await supabase.storage
    .from('attachments')
    .upload(filePath, blob, { contentType: 'audio/mpeg' });

  if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

  const { data: urlData } = supabase.storage
    .from('attachments')
    .getPublicUrl(filePath);

  // Create DB record
  const { data, error } = await supabase
    .from('soundboard_sounds')
    .insert({
      server_id: params.serverId,
      name: params.name,
      emoji: params.emoji,
      sound_url: urlData.publicUrl,
      duration: params.duration,
      uploaded_by: user.id,
    })
    .select()
    .single();

  if (error) throw new Error(`Failed to save sound: ${error.message}`);

  return {
    id: data.id,
    name: data.name,
    emoji: data.emoji || '🔊',
    soundUrl: data.sound_url,
    duration: data.duration || 0,
    uploadedBy: user.email ?? 'You',
    serverId: data.server_id,
    isFavorite: false,
    playCount: 0,
    createdAt: data.created_at,
  };
}

/**
 * Delete a soundboard sound (server admin or uploader only)
 */
export async function deleteSound(soundId: string): Promise<void> {
  const { error } = await supabase
    .from('soundboard_sounds')
    .delete()
    .eq('id', soundId);

  if (error) throw new Error(`Failed to delete sound: ${error.message}`);
}
