/**
 * Supabase Attachment Storage Service
 *
 * Handles non-media file uploads (PDFs, ZIPs, APKs, documents, etc.)
 * to a private Supabase Storage bucket with signed URL access.
 *
 * Architecture:
 *   - Private "attachments" bucket with RLS-based access
 *   - Upload with authenticated user session
 *   - Download via time-limited signed URLs (10 minutes default)
 *
 * Use Cloudinary for images/video/GIFs (better CDN + optimization).
 * Use this service for everything else.
 */
import { supabase } from '../lib/supabase';

// ── Config ────────────────────────────────────────────────────────────────

const BUCKET_NAME = 'attachments';
const SIGNED_URL_EXPIRY = 60 * 10; // 10 minutes

// Media MIME types that should go through Cloudinary instead
const CLOUDINARY_MIME_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'video/mp4',
  'video/quicktime',
  'video/webm',
]);

// ── Types ─────────────────────────────────────────────────────────────────

export interface AttachmentUploadResult {
  /** Storage path in bucket (e.g. "channels/abc/user123-1709654321.pdf") */
  path: string;
  /** Full storage path including bucket */
  fullPath: string;
}

export interface SignedUrlResult {
  signedUrl: string;
  path: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────

/**
 * Check if a file should be uploaded to Cloudinary (media) or Supabase Storage (attachment).
 */
export function isMediaFile(mimeType: string): boolean {
  return CLOUDINARY_MIME_TYPES.has(mimeType.toLowerCase());
}

// ── Upload ────────────────────────────────────────────────────────────────

/**
 * Upload a file attachment to private Supabase Storage bucket.
 *
 * @param storagePath - Path within the bucket (e.g. "channels/{channelId}/{filename}")
 * @param fileBlob    - File data as Blob, ArrayBuffer, or FormData file
 * @param mimeType    - MIME type of the file
 * @param options     - Additional options
 * @returns Upload result with storage path
 */
export async function uploadAttachment(
  storagePath: string,
  fileBlob: Blob | ArrayBuffer | Uint8Array,
  mimeType: string,
  options?: { upsert?: boolean },
): Promise<AttachmentUploadResult> {
  const body = fileBlob instanceof Uint8Array
    ? new Blob([fileBlob], { type: mimeType })
    : fileBlob instanceof ArrayBuffer
      ? new Blob([new Uint8Array(fileBlob)], { type: mimeType })
      : fileBlob;

  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .upload(storagePath, body, {
      contentType: mimeType,
      upsert: options?.upsert ?? false,
    });

  if (error) {
    throw new Error(`Attachment upload failed: ${error.message}`);
  }

  return {
    path: storagePath,
    fullPath: data.path,
  };
}

// ── Download / Signed URLs ────────────────────────────────────────────────

/**
 * Get a time-limited signed URL for a private attachment.
 *
 * @param storagePath - Path within the bucket
 * @param expiresIn   - URL validity in seconds (default: 10 minutes)
 * @returns Signed URL string
 */
export async function getSignedUrl(
  storagePath: string,
  expiresIn: number = SIGNED_URL_EXPIRY,
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .createSignedUrl(storagePath, expiresIn);

  if (error || !data?.signedUrl) {
    throw new Error(`Failed to create signed URL: ${error?.message ?? 'Unknown error'}`);
  }

  return data.signedUrl;
}

/**
 * Get signed URLs for multiple attachments in batch.
 *
 * @param paths     - Array of storage paths
 * @param expiresIn - URL validity in seconds (default: 10 minutes)
 * @returns Array of { signedUrl, path } objects
 */
export async function getSignedUrls(
  paths: string[],
  expiresIn: number = SIGNED_URL_EXPIRY,
): Promise<SignedUrlResult[]> {
  if (paths.length === 0) return [];

  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .createSignedUrls(paths, expiresIn);

  if (error || !data) {
    throw new Error(`Failed to create signed URLs: ${error?.message ?? 'Unknown error'}`);
  }

  return data.map((item) => ({
    signedUrl: item.signedUrl,
    path: item.path ?? '',
  }));
}

// ── Delete ────────────────────────────────────────────────────────────────

/**
 * Delete an attachment from storage.
 *
 * @param storagePath - Path within the bucket
 */
export async function deleteAttachment(storagePath: string): Promise<void> {
  const { error } = await supabase.storage
    .from(BUCKET_NAME)
    .remove([storagePath]);

  if (error) {
    throw new Error(`Attachment delete failed: ${error.message}`);
  }
}

/**
 * Delete multiple attachments from storage.
 *
 * @param paths - Array of storage paths
 */
export async function deleteAttachments(paths: string[]): Promise<void> {
  if (paths.length === 0) return;

  const { error } = await supabase.storage
    .from(BUCKET_NAME)
    .remove(paths);

  if (error) {
    throw new Error(`Attachment delete failed: ${error.message}`);
  }
}
