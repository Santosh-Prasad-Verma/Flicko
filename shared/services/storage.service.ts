import { supabase } from '../lib/supabase';

/**
 * Storage Service
 * 
 * Handles all file upload, deletion, and retrieval operations
 * using Supabase Storage buckets.
 * 
 * Requirements: 9.1, 9.2, 9.4, 9.5, 9.6, 9.9
 */

export interface FileUploadResult {
    url: string;
    path: string;
}

const MAX_FILE_SIZE_MAP: Record<string, number> = {
    avatars: 5 * 1024 * 1024, // 5MB
    'server-icons': 5 * 1024 * 1024, // 5MB
    banners: 10 * 1024 * 1024, // 10MB
    emojis: 256 * 1024, // 256KB
    attachments: 25 * 1024 * 1024, // 25MB
};

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

/**
 * Remove stale files when a user re-uploads with a different extension.
 * e.g. avatar.png → avatar.gif — the old avatar.png would remain without this cleanup.
 *
 * @param bucket - Storage bucket name
 * @param folder - The folder (userId / serverId) to scan
 * @param prefix - The filename prefix to match (e.g. "avatar", "banner", "icon")
 */
async function cleanupStaleFiles(bucket: string, folder: string, prefix: string): Promise<void> {
    try {
        const { data: existing } = await supabase.storage.from(bucket).list(folder, { limit: 50 });
        if (existing && existing.length > 0) {
            const stale = existing
                .filter((f) => f.name.startsWith(`${prefix}.`))
                .map((f) => `${folder}/${f.name}`);
            if (stale.length > 0) {
                await supabase.storage.from(bucket).remove(stale);
            }
        }
    } catch {
        // Non-fatal — worst case one stale file remains
    }
}

/**
 * Get the public URL for a file in a storage bucket
 * 
 * @param bucket - The storage bucket name
 * @param path - The file path within the bucket
 * @returns The public URL as a string
 */
export function getPublicUrl(bucket: string, path: string): string {
    if (!path) return '';
    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    return data.publicUrl;
}

/**
 * Generic file upload method
 * 
 * @param bucket - The storage bucket name
 * @param path - The destination path for the file
 * @param file - The file to upload
 * @param maxSize - Optional max size in bytes (defaults to bucket default)
 * @returns Object with the public URL and storage path
 * @throws Error if upload fails or validation fails
 */
export async function uploadFile(
    bucket: string,
    path: string,
    file: File,
    maxSize?: number
): Promise<FileUploadResult> {
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
        throw new Error('User not authenticated');
    }

    // Validate file size
    const limit = maxSize || MAX_FILE_SIZE_MAP[bucket] || 10 * 1024 * 1024; // fallback to 10MB
    if (file.size > limit) {
        const mbLimit = Math.round(limit / (1024 * 1024));
        const kbLimit = Math.round(limit / 1024);
        const displayLimit = limit < 1024 * 1024 ? `${kbLimit}KB` : `${mbLimit}MB`;
        throw new Error(`File size exceeds the ${displayLimit} limit`);
    }

    // Ensure path doesn't contain traversal characters (Requirement 9.9: Path Traversal Prevention)
    if (path.includes('../') || path.includes('..\\')) {
        throw new Error('Invalid file path: Traversal characters matched');
    }

    // Upload to Supabase Storage (upsert: true to overwrite existing)
    const { data, error } = await supabase.storage
        .from(bucket)
        .upload(path, file, {
            cacheControl: '3600',
            upsert: true,
        });

    if (error) {
        throw new Error(`Failed to upload file to ${bucket}: ${error.message}`);
    }

    if (!data) {
        throw new Error(`File upload failed: No data returned from ${bucket}`);
    }

    return {
        url: getPublicUrl(bucket, path),
        path: data.path, // returns actual uploaded path
    };
}

/**
 * Generic file deletion method
 * 
 * @param bucket - The storage bucket name
 * @param path - The file path to delete
 * @throws Error if deletion fails
 */
export async function deleteFile(bucket: string, path: string): Promise<void> {
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
        throw new Error('User not authenticated');
    }

    const { error } = await supabase.storage.from(bucket).remove([path]);

    if (error) {
        throw new Error(`Failed to delete file from ${bucket}: ${error.message}`);
    }
}

/**
 * Upload an avatar image
 * 
 * @param userId - The user ID to namespace the file
 * @param file - The image file
 * @returns Object with the public URL and path
 */
export async function uploadAvatar(userId: string, file: File): Promise<FileUploadResult> {
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
        throw new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed');
    }

    const fileExt = file.name.split('.').pop();

    // Deterministic path per user — prevents duplicate files on re-upload
    const fileName = `${userId}/avatar.${fileExt}`;

    // Remove stale files if extension changed (e.g. avatar.png → avatar.gif)
    await cleanupStaleFiles('avatars', userId, 'avatar');

    return uploadFile('avatars', fileName, file);
}

/**
 * Upload a server icon image
 * 
 * @param serverId - The server ID to namespace the file
 * @param file - The image file
 * @returns Object with the public URL and path
 */
export async function uploadServerIcon(serverId: string, file: File): Promise<FileUploadResult> {
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
        throw new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed');
    }

    const fileExt = file.name.split('.').pop();
    // Deterministic path per server — prevents duplicate files on re-upload
    const filePath = `${serverId}/icon.${fileExt}`;

    // Remove stale files if extension changed
    await cleanupStaleFiles('server-icons', serverId, 'icon');

    return uploadFile('server-icons', filePath, file);
}

/**
 * Upload a message attachment
 * 
 * @param channelId - The channel ID to namespace the file
 * @param file - The attachment file (can be of any safe type)
 * @returns Object with the public URL and path
 */
export async function uploadAttachment(channelId: string, file: File): Promise<FileUploadResult> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const fileExt = file.name.split('.').pop();
    // Name includes channelId, userId, and timestamp to ensure uniqueness and organization
    const filePath = `${channelId}/${user.id}-${Date.now()}.${fileExt}`;

    return uploadFile('attachments', filePath, file);
}

/**
 * Upload a server custom emoji
 * 
 * @param serverId - The server ID
 * @param file - The emoji image file
 * @returns Object with the public URL and path
 */
export async function uploadEmoji(serverId: string, file: File): Promise<FileUploadResult> {
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
        throw new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed');
    }

    const fileExt = file.name.split('.').pop();
    const filePath = `${serverId}/${Date.now()}.${fileExt}`;

    return uploadFile('emojis', filePath, file);
}
