/**
 * Cloudinary Media Service
 *
 * Handles image/video uploads to Cloudinary via signed uploads.
 * Used for: avatars, banners, server icons, chat images, GIFs, stickers.
 *
 * Architecture:
 *   1. Client requests a signature from the backend (/cloudinary/sign)
 *   2. Client uploads directly to Cloudinary with that signature
 *   3. Cloudinary returns public_id + secure_url
 *   4. We store public_id in the database (URLs are derived from it)
 *
 * Cloudinary free tier: 25 credits (1 credit = 1GB storage OR bandwidth OR 1000 transforms).
 */
import Constants from 'expo-constants';

// ── Config ────────────────────────────────────────────────────────────────

const API_URL =
  Constants.expoConfig?.extra?.apiUrl ??
  process.env.EXPO_PUBLIC_API_URL ??
  'http://localhost:8080';

const CLOUDINARY_CLOUD_NAME =
  process.env.EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME ?? '';

// ── Types ─────────────────────────────────────────────────────────────────

export interface CloudinarySignResponse {
  timestamp: number;
  signature: string;
  apiKey: string;
  cloudName: string;
  uploadPreset: string;
  folder: string;
  /** Whether color analysis was signed into this request */
  colors?: boolean;
}

export interface CloudinaryUploadResult {
  public_id: string;
  secure_url: string;
  url: string;
  format: string;
  width: number;
  height: number;
  bytes: number;
  resource_type: string;
  /** Dominant colors returned when `colors: true` is requested */
  colors?: [string, number][];
  /** Predominant color categories (Cloudinary and Google) */
  predominant?: {
    google?: [string, number][];
    cloudinary?: [string, number][];
  };
}

// ── Retry Helper ──────────────────────────────────────────────────────────

/**
 * Retry a fetch call with exponential back-off.
 * Retries only on network errors and 5xx responses (not 4xx).
 */
async function fetchWithRetry(
  input: RequestInfo,
  init?: RequestInit,
  retries = 2,
  baseDelay = 800,
): Promise<Response> {
  let lastErr: any;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(input, init);
      // Don't retry client errors (4xx) — only server errors (5xx)
      if (res.ok || (res.status >= 400 && res.status < 500)) return res;
      lastErr = new Error(`Server error: ${res.status}`);
    } catch (err: any) {
      lastErr = err;
    }
    if (attempt < retries) {
      const delay = baseDelay * Math.pow(2, attempt);
      if (__DEV__) console.log(`[Cloudinary] Retry ${attempt + 1}/${retries} in ${delay}ms`);
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastErr;
}

// ── Signature Fetching ────────────────────────────────────────────────────

/**
 * Get a signed upload payload from the backend.
 * The backend signs with CLOUDINARY_API_SECRET (never exposed to the client).
 *
 * @param folder - Optional subfolder override (default: "flickochat")
 * @param authToken - Supabase access token for authenticated requests
 * @param publicId - Optional deterministic public_id (must be signed)
 */
async function getUploadSignature(
  authToken: string,
  folder?: string,
  publicId?: string,
  colors?: boolean,
): Promise<CloudinarySignResponse> {
  const qp = new URLSearchParams();
  if (folder) qp.set('folder', folder);
  if (publicId) qp.set('public_id', publicId);
  if (colors) qp.set('colors', 'true');
  const qs = qp.toString();
  const url = `${API_URL}/api/v1/cloudinary/sign${qs ? '?' + qs : ''}`;

  if (__DEV__) {
    console.log('[Cloudinary] Requesting signature from:', url);
  }

  let res: Response;
  try {
    res = await fetchWithRetry(url, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
  } catch (networkErr: any) {
    throw new Error(
      `Cannot reach backend at ${API_URL}. ` +
      `Check that the server is running and your device is on the same network. ` +
      `(${networkErr.message})`
    );
  }

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    if (res.status === 401) {
      throw new Error(
        'Authentication failed. Please sign out and sign in again.'
      );
    }
    throw new Error(`Failed to get upload signature: ${res.status} ${body}`);
  }

  return res.json();
}

// ── Upload to Cloudinary ──────────────────────────────────────────────────

/**
 * Upload a media file (image/video/GIF) to Cloudinary using signed upload.
 *
 * @param fileUri    - Local file URI (from image picker, camera, etc.)
 * @param mimeType   - MIME type (e.g. "image/jpeg", "image/gif", "video/mp4")
 * @param authToken  - Supabase access token
 * @param options    - Optional overrides (folder, publicId for deterministic naming)
 * @returns Cloudinary upload result with public_id and secure_url
 */
export async function uploadToCloudinary(
  fileUri: string,
  mimeType: string,
  authToken: string,
  options?: {
    folder?: string;
    publicId?: string;
    fileName?: string;
    /** Request Cloudinary color analysis (adds colors + predominant to response) */
    colors?: boolean;
  },
): Promise<CloudinaryUploadResult> {
  // 1. Get signed credentials from backend (pass public_id + colors so they're included in signature)
  const sign = await getUploadSignature(authToken, options?.folder, options?.publicId, options?.colors);

  // 2. Build multipart form
  const form = new FormData();
  const ext = fileUri.split('.').pop()?.toLowerCase() || 'jpg';
  const fileName = options?.fileName ?? `upload.${ext}`;

  form.append('file', {
    uri: fileUri,
    type: mimeType,
    name: fileName,
  } as any);
  form.append('api_key', sign.apiKey);
  form.append('timestamp', String(sign.timestamp));
  form.append('signature', sign.signature);
  form.append('upload_preset', sign.uploadPreset);
  form.append('folder', options?.folder ?? sign.folder);

  // Deterministic public_id = overwrite on re-upload (no duplicates)
  if (options?.publicId) {
    form.append('public_id', options.publicId);
    form.append('overwrite', 'true');
    form.append('invalidate', 'true');
  }

  // Request color analysis (signed param — must be included in backend signature)
  if (sign.colors) {
    form.append('colors', 'true');
  }

  // 3. Upload directly to Cloudinary (with retry for transient failures)
  const cloudName = sign.cloudName || CLOUDINARY_CLOUD_NAME;
  const uploadUrl = `https://api.cloudinary.com/v1_1/${cloudName}/auto/upload`;

  let res: Response;
  try {
    res = await fetchWithRetry(uploadUrl, { method: 'POST', body: form });
  } catch (uploadErr: any) {
    throw new Error(
      `Could not reach Cloudinary. Check your internet connection. (${uploadErr.message})`
    );
  }

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Cloudinary upload failed: ${res.status} ${body}`);
  }

  return res.json();
}

// ── Convenience Wrappers ──────────────────────────────────────────────────

/**
 * Upload a user avatar. Uses deterministic public_id to prevent duplicates.
 */
export async function uploadAvatar(
  fileUri: string,
  mimeType: string,
  userId: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: 'flickochat/avatars',
    publicId: `user_${userId}_avatar`,
    colors: true,
  });
}

/**
 * Upload a user banner. Uses deterministic public_id to prevent duplicates.
 */
export async function uploadBanner(
  fileUri: string,
  mimeType: string,
  userId: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: 'flickochat/banners',
    publicId: `user_${userId}_banner`,
    colors: true,
  });
}

/**
 * Upload a server icon. Uses deterministic public_id to prevent duplicates.
 */
export async function uploadServerIcon(
  fileUri: string,
  mimeType: string,
  serverId: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: 'flickochat/server-icons',
    publicId: `server_${serverId}_icon`,
  });
}

/**
 * Upload a server banner. Uses deterministic public_id to prevent duplicates.
 */
export async function uploadServerBanner(
  fileUri: string,
  mimeType: string,
  serverId: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: 'flickochat/server-banners',
    publicId: `server_${serverId}_banner`,
  });
}

/**
 * Upload a sticker image. Uses deterministic public_id per sticker name.
 */
export async function uploadSticker(
  fileUri: string,
  mimeType: string,
  serverId: string,
  stickerName: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  const safeName = stickerName.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: `flickochat/stickers/${serverId}`,
    publicId: `sticker_${safeName}`,
  });
}

/**
 * Upload a chat image/video/GIF. Uses unique name (not deterministic).
 */
export async function uploadChatMedia(
  fileUri: string,
  mimeType: string,
  channelId: string,
  userId: string,
  authToken: string,
): Promise<CloudinaryUploadResult> {
  return uploadToCloudinary(fileUri, mimeType, authToken, {
    folder: `flickochat/chat/${channelId}`,
    fileName: `${userId}_${Date.now()}.${fileUri.split('.').pop() || 'jpg'}`,
  });
}

// ── URL Helpers ───────────────────────────────────────────────────────────

/**
 * Build an optimized Cloudinary URL from a public_id.
 * Supports on-the-fly transformations (resize, format, quality).
 *
 * @param publicId     - Cloudinary public_id
 * @param options      - Transformation options
 * @returns Optimized URL string
 */
export function getCloudinaryUrl(
  publicId: string,
  options?: {
    width?: number;
    height?: number;
    crop?: 'fill' | 'fit' | 'limit' | 'thumb';
    quality?: 'auto' | number;
    format?: 'auto' | 'webp' | 'jpg' | 'png';
  },
): string {
  const cloudName = CLOUDINARY_CLOUD_NAME;
  if (!cloudName) return publicId; // fallback if not configured

  const transforms: string[] = [];
  if (options?.width) transforms.push(`w_${options.width}`);
  if (options?.height) transforms.push(`h_${options.height}`);
  if (options?.crop) transforms.push(`c_${options.crop}`);
  if (options?.quality) transforms.push(`q_${options.quality}`);
  if (options?.format) transforms.push(`f_${options.format}`);

  const transformStr = transforms.length > 0 ? `/${transforms.join(',')}` : '';
  return `https://res.cloudinary.com/${cloudName}/image/upload${transformStr}/${publicId}`;
}

/**
 * Check if a URL is a Cloudinary URL
 */
export function isCloudinaryUrl(url: string): boolean {
  return url.includes('res.cloudinary.com') || url.includes('api.cloudinary.com');
}

/**
 * Extract public_id from a Cloudinary secure_url.
 * Example: https://res.cloudinary.com/demo/image/upload/v1234/flickochat/avatars/user_abc_avatar.jpg
 * Returns: flickochat/avatars/user_abc_avatar
 */
export function extractPublicId(url: string): string | null {
  const match = url.match(/\/upload\/(?:v\d+\/)?(flickochat\/.+?)(?:\.\w+)?$/);
  return match ? match[1] : null;
}
