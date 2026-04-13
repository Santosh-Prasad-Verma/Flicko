/**
 * File Upload Service (React Native)
 *
 * Handles file picking (images, documents), and upload routing:
 *   - Images/videos/GIFs → Cloudinary (CDN + optimization)
 *   - Documents/archives → Supabase Storage (private + signed URLs)
 *
 * Requirements: Feature 9 (File Upload Infrastructure)
 */
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';
import { supabase } from '../lib/supabase';
import { useUploadStore, type UploadItem } from '../stores/uploadStore';
import { uploadToCloudinary } from './cloudinaryService';
import { uploadAttachment, getSignedUrl, isMediaFile } from './attachmentStorage';

// ── Constants ─────────────────────────────────────────────────────────────

const MAX_FILE_SIZE = 8 * 1024 * 1024; // 8MB free tier
const MAX_UPLOADS_PER_MESSAGE = 10;
const PRESIGN_EXPIRY_MINUTES = 5;

const ALLOWED_EXTENSIONS = new Set([
  'jpg', 'jpeg', 'png', 'gif', 'webp',
  'mp4', 'mov', 'webm',
  'mp3', 'ogg', 'wav',
  'pdf', 'txt', 'doc', 'docx',
]);

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/quicktime', 'video/webm'];

// ── Types ─────────────────────────────────────────────────────────────────

export interface PickedFile {
  uri: string;
  filename: string;
  mimeType: string;
  size: number;
  width?: number;
  height?: number;
}

export interface PresignedUrlResponse {
  upload_url: string;
  file_key: string;
  public_url: string;
  expires_at: string;
}

// ── File Picking ──────────────────────────────────────────────────────────

/**
 * Pick an image from the device gallery
 */
export async function pickImage(options?: {
  allowsMultipleSelection?: boolean;
  quality?: number;
}): Promise<PickedFile[]> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) {
    throw new Error('Media library permission is required to upload images');
  }

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images', 'videos'],
    allowsMultipleSelection: options?.allowsMultipleSelection ?? true,
    quality: options?.quality ?? 0.8,
    exif: false,
  });

  if (result.canceled || !result.assets?.length) return [];

  return result.assets.map((asset) => ({
    uri: asset.uri,
    filename: asset.fileName ?? `image_${Date.now()}.jpg`,
    mimeType: asset.mimeType ?? 'image/jpeg',
    size: asset.fileSize ?? 0,
    width: asset.width,
    height: asset.height,
  }));
}

/**
 * Take a photo with the camera
 */
export async function takePhoto(): Promise<PickedFile | null> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) {
    throw new Error('Camera permission is required to take photos');
  }

  const result = await ImagePicker.launchCameraAsync({
    quality: 0.8,
    exif: false,
  });

  if (result.canceled || !result.assets?.length) return null;

  const asset = result.assets[0];
  return {
    uri: asset.uri,
    filename: asset.fileName ?? `photo_${Date.now()}.jpg`,
    mimeType: asset.mimeType ?? 'image/jpeg',
    size: asset.fileSize ?? 0,
    width: asset.width,
    height: asset.height,
  };
}

/**
 * Pick a video from the device
 */
export async function pickVideo(): Promise<PickedFile | null> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) {
    throw new Error('Media library permission is required to upload videos');
  }

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['videos'],
    quality: 0.8,
    videoMaxDuration: 300, // 5 minutes
  });

  if (result.canceled || !result.assets?.length) return null;

  const asset = result.assets[0];
  return {
    uri: asset.uri,
    filename: asset.fileName ?? `video_${Date.now()}.mp4`,
    mimeType: asset.mimeType ?? 'video/mp4',
    size: asset.fileSize ?? 0,
    width: asset.width,
    height: asset.height,
  };
}

// ── Validation ────────────────────────────────────────────────────────────

export function validateFile(file: PickedFile): { valid: boolean; error?: string } {
  // Check file size
  if (file.size > MAX_FILE_SIZE) {
    const mbLimit = Math.round(MAX_FILE_SIZE / (1024 * 1024));
    return { valid: false, error: `File exceeds ${mbLimit}MB limit` };
  }

  // Check extension
  const ext = file.filename.split('.').pop()?.toLowerCase();
  if (ext && !ALLOWED_EXTENSIONS.has(ext)) {
    return { valid: false, error: `File type .${ext} is not allowed` };
  }

  return { valid: true };
}

// ── Upload Flow ───────────────────────────────────────────────────────────

/**
 * Upload a file with progress tracking.
 * Routes media → Cloudinary, documents → Supabase Storage.
 */
export async function uploadFileToStorage(
  channelId: string,
  file: PickedFile,
  uploadId: string,
): Promise<{ url: string; fileKey: string }> {
  const store = useUploadStore.getState();

  // Validate
  const validation = validateFile(file);
  if (!validation.valid) {
    store.failUpload(uploadId, validation.error!);
    throw new Error(validation.error);
  }

  store.setProgress(uploadId, 0.1);

  try {
    // Get current user + auth token
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.user || !session.access_token) throw new Error('Not authenticated');
    const user = session.user;
    const token = session.access_token;

    store.setProgress(uploadId, 0.3);

    let url: string;
    let fileKey: string;

    if (isMediaFile(file.mimeType)) {
      // Images/videos/GIFs → Cloudinary
      const result = await uploadToCloudinary(file.uri, file.mimeType, token, {
        folder: `flickochat/channels/${channelId}`,
      });
      url = result.secure_url;
      fileKey = result.public_id;
    } else {
      // Documents → Supabase private storage
      const ext = file.filename.split('.').pop()?.toLowerCase() ?? 'bin';
      fileKey = `channels/${channelId}/${user.id}-${Date.now()}.${ext}`;

      const base64 = await FileSystem.readAsStringAsync(file.uri, {
        encoding: FileSystem.EncodingType.Base64,
      });
      const binaryString = atob(base64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      store.setProgress(uploadId, 0.5);

      await uploadAttachment(fileKey, bytes, file.mimeType);
      url = await getSignedUrl(fileKey);
    }

    store.setProgress(uploadId, 0.9);
    store.completeUpload(uploadId, url, fileKey);
    store.setProgress(uploadId, 1.0);

    return { url, fileKey };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Upload failed';
    store.failUpload(uploadId, message);
    throw err;
  }
}

/**
 * Upload multiple files for a channel message
 */
export async function uploadFilesForMessage(
  files: PickedFile[],
  channelId: string,
): Promise<UploadItem[]> {
  const store = useUploadStore.getState();

  // Check total count including already pending uploads
  const existingCount = store.getPendingAttachments(channelId).length;
  if (existingCount + files.length > MAX_UPLOADS_PER_MESSAGE) {
    throw new Error(`Maximum ${MAX_UPLOADS_PER_MESSAGE} files per message (${existingCount} already attached)`);
  }

  // Add all uploads to the store first
  const uploadIds: string[] = [];
  for (const file of files) {
    const id = `upload-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    store.addUpload({
      id,
      filename: file.filename,
      contentType: file.mimeType,
      size: file.size,
      localUri: file.uri,
      channelId,
      width: file.width,
      height: file.height,
    });
    uploadIds.push(id);
  }

  // Upload all files in parallel
  const promises = files.map((file, idx) =>
    uploadFileToStorage(channelId, file, uploadIds[idx]).catch(() => null),
  );

  await Promise.allSettled(promises);

  // Return completed uploads
  return store.getPendingAttachments(channelId);
}

/**
 * Helper to check if a file is an image
 */
export function isImageFile(mimeType: string): boolean {
  return ALLOWED_IMAGE_TYPES.includes(mimeType);
}

/**
 * Helper to check if a file is a video
 */
export function isVideoFile(mimeType: string): boolean {
  return ALLOWED_VIDEO_TYPES.includes(mimeType);
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
