import { supabase } from '../lib/supabase';
import type { User } from '@shared/types/models';

/**
 * Profile Service
 * 
 * Handles all user profile-related API operations including fetching profiles,
 * updating profile information, and avatar uploads to Supabase Storage.
 * 
 * Requirements: 13.1, 13.2, 13.3, 13.4
 */

export interface UpdateProfileInput {
  username?: string;
  bio?: string | null;
  banner?: string | null;
  custom_status?: string | null;
}

export interface UploadAvatarResult {
  url: string;
  path: string;
}

/**
 * Get a user profile by ID
 * 
 * @param userId - The ID of the user to fetch
 * @returns The user profile object
 * @throws Error if profile not found or query fails
 */
export async function getProfile(userId: string): Promise<User> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    throw new Error(`Failed to fetch profile: ${error.message}`);
  }

  if (!data) {
    throw new Error('Profile not found');
  }

  return data;
}

/**
 * Get the current authenticated user's profile
 * 
 * @returns The current user's profile object
 * @throws Error if user is not authenticated or query fails
 */
export async function getCurrentProfile(): Promise<User> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  return getProfile(user.id);
}

/**
 * Update the current user's profile
 * 
 * Validates username uniqueness and updates profile information.
 * 
 * @param input - Profile update data
 * @returns The updated user profile
 * @throws Error if update fails, user is not authenticated, or validation fails
 */
export async function updateProfile(input: UpdateProfileInput): Promise<User> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate username if provided
  if (input.username !== undefined) {
    if (!input.username || input.username.trim().length === 0) {
      throw new Error('Username cannot be empty');
    }
    
    if (input.username.length < 2) {
      throw new Error('Username must be at least 2 characters');
    }
    
    if (input.username.length > 32) {
      throw new Error('Username must be 32 characters or less');
    }

    // Check for valid username format (alphanumeric, underscores, hyphens)
    const usernameRegex = /^[a-zA-Z0-9_-]+$/;
    if (!usernameRegex.test(input.username)) {
      throw new Error('Username can only contain letters, numbers, underscores, and hyphens');
    }

    // Check username uniqueness (with same discriminator)
    const { data: currentProfile } = await supabase
      .from('profiles')
      .select('discriminator')
      .eq('id', user.id)
      .single();

    if (currentProfile) {
      const { data: existingUser } = await supabase
        .from('profiles')
        .select('id')
        .eq('username', input.username.trim())
        .eq('discriminator', currentProfile.discriminator)
        .neq('id', user.id)
        .single();

      if (existingUser) {
        throw new Error('Username is already taken');
      }
    }
  }

  // Validate bio length if provided
  if (input.bio !== undefined && input.bio !== null) {
    if (input.bio.length > 190) {
      throw new Error('Bio must be 190 characters or less');
    }
  }

  // Validate custom status length if provided
  if (input.custom_status !== undefined && input.custom_status !== null) {
    if (input.custom_status.length > 128) {
      throw new Error('Custom status must be 128 characters or less');
    }
  }

  // Build update object
  const updateData: Partial<User> = {
    updated_at: new Date().toISOString(),
  };
  
  if (input.username !== undefined) {
    updateData.username = input.username.trim();
  }
  if (input.bio !== undefined) {
    updateData.bio = input.bio;
  }
  if (input.banner !== undefined) {
    updateData.banner = input.banner;
  }
  if (input.custom_status !== undefined) {
    updateData.custom_status = input.custom_status;
  }

  // Update the profile
  const { data, error } = await supabase
    .from('profiles')
    .update(updateData)
    .eq('id', user.id)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to update profile: ${error.message}`);
  }

  if (!data) {
    throw new Error('Profile update failed: No data returned');
  }

  return data;
}

/**
 * Upload an avatar image to Supabase Storage
 * 
 * Validates file type and size, uploads to storage, and updates the user's profile.
 * 
 * @param file - The image file to upload
 * @returns Object containing the public URL and storage path
 * @throws Error if upload fails, file is invalid, or user is not authenticated
 */
export async function uploadAvatar(file: File): Promise<UploadAvatarResult> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate file type
  const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  if (!allowedTypes.includes(file.type)) {
    throw new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed');
  }

  // Validate file size (max 5MB)
  const maxSize = 5 * 1024 * 1024; // 5MB in bytes
  if (file.size > maxSize) {
    throw new Error('File size exceeds 5MB limit');
  }

  // Generate deterministic filename — prevents duplicate files on re-upload
  const fileExt = file.name.split('.').pop();
  const fileName = `${user.id}/avatar.${fileExt}`;
  const filePath = `avatars/${fileName}`;

  // Clean up stale files if extension changed (e.g. avatar.png → avatar.gif)
  try {
    const { data: existing } = await supabase.storage
      .from('avatars')
      .list(`avatars/${user.id}`, { limit: 20 });
    if (existing && existing.length > 0) {
      const stale = existing
        .filter((f) => f.name.startsWith('avatar.'))
        .map((f) => `avatars/${user.id}/${f.name}`);
      if (stale.length > 0) {
        await supabase.storage.from('avatars').remove(stale);
      }
    }
  } catch {
    // Non-fatal
  }

  // Upload to Supabase Storage (upsert replaces same-name file)
  const { data: uploadData, error: uploadError } = await supabase.storage
    .from('avatars')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: true,
    });

  if (uploadError) {
    throw new Error(`Failed to upload avatar: ${uploadError.message}`);
  }

  if (!uploadData) {
    throw new Error('Avatar upload failed: No data returned');
  }

  // Get public URL with cache-buster so CDN/browser loads the fresh version
  const { data: { publicUrl } } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath);

  const freshUrl = `${publicUrl}?v=${Date.now()}`;

  // Update profile with new avatar URL
  const { error: updateError } = await supabase
    .from('profiles')
    .update({ 
      avatar: freshUrl,
      updated_at: new Date().toISOString(),
    })
    .eq('id', user.id);

  if (updateError) {
    // Try to clean up uploaded file if profile update fails
    await supabase.storage.from('avatars').remove([filePath]);
    throw new Error(`Failed to update profile with avatar: ${updateError.message}`);
  }

  return {
    url: freshUrl,
    path: filePath,
  };
}
