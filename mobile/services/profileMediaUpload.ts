/**
 * Upload profile avatar/banner to Supabase Storage (fallback when Cloudinary is unavailable).
 */
import { supabase } from './supabase';

function extFromMime(mimeType: string): string {
  if (mimeType.includes('png')) return 'png';
  if (mimeType.includes('gif')) return 'gif';
  if (mimeType.includes('webp')) return 'webp';
  if (mimeType.includes('jpeg') || mimeType.includes('jpg')) return 'jpg';
  return 'jpg';
}

export async function uploadProfileImageToSupabase(
  uri: string,
  mimeType: string,
  userId: string,
  kind: 'avatar' | 'banner',
): Promise<string> {
  const ext = extFromMime(mimeType);
  const bucket = kind === 'avatar' ? 'avatars' : 'banners';
  const path =
    kind === 'avatar'
      ? `profiles/${userId}/avatar.${ext}`
      : `profiles/${userId}/banner.${ext}`;

  const res = await fetch(uri);
  const blob = await res.blob();

  const { error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(path, blob, {
      contentType: mimeType || 'image/jpeg',
      upsert: true,
    });

  if (uploadError) {
    throw new Error(uploadError.message);
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(path);
  const url = data?.publicUrl;
  if (!url) throw new Error('No public URL returned for upload');
  return `${url}?t=${Date.now()}`;
}
