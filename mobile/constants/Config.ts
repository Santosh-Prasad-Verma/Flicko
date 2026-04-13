/**
 * Application Configuration Constants
 *
 * Environment-specific settings, API URLs, feature flags, and limits.
 * Never hardcode these values in components or services.
 * MED-001: Added runtime validation for required environment variables.
 */

/** MED-001: Helper to require environment variables with validation */
function requireEnv(key: string, defaultValue?: string): string {
  const value = process.env[key] ?? defaultValue;
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${key}. ` +
      `Set it in .env file or environment.`
    );
  }
  return value;
}

/** MED-001: Helper to validate URL format */
function validateUrl(url: string, name: string): string {
  try {
    new URL(url);
    return url;
  } catch {
    throw new Error(`Invalid URL for ${name}: ${url}`);
  }
}

/** Supabase configuration — values come from environment or defaults */
export const SUPABASE_URL = validateUrl(
  requireEnv('EXPO_PUBLIC_SUPABASE_URL'),
  'SUPABASE_URL'
);
export const SUPABASE_ANON_KEY = requireEnv('EXPO_PUBLIC_SUPABASE_ANON_KEY');

/** Mail Gateway URL — the local or deployed mail-gateway service */
export const MAIL_GATEWAY_URL = validateUrl(
  process.env.EXPO_PUBLIC_MAIL_GATEWAY_URL ?? 'http://localhost:8080',
  'MAIL_GATEWAY_URL'
);

/** Go Backend REST API URL (voice tokens, uploads, bot commands, etc.) */
export const GO_BACKEND_URL = validateUrl(
  process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:8080',
  'GO_BACKEND_URL'
);
/** API key for the mail-gateway /send endpoint (matches SEND_API_KEY in mail-gateway .env) */
export const MAIL_GATEWAY_API_KEY =
  process.env.EXPO_PUBLIC_MAIL_GATEWAY_API_KEY ?? '';

// MED-001: Log config status in development
if (__DEV__) {
  console.log('Config loaded:', {
    SUPABASE_URL,
    MAIL_GATEWAY_URL,
    hasAnonKey: !!SUPABASE_ANON_KEY,
    hasMailKey: !!MAIL_GATEWAY_API_KEY,
  });
}

/** App metadata */
export const APP_NAME = 'Flicko';
export const APP_VERSION = '1.0.0';
export const APP_SCHEME = 'flicko';

/** Auth configuration */
export const AUTH_CONFIG = {
  /** Minimum password length */
  MIN_PASSWORD_LENGTH: 8,
  /** Minimum username length */
  MIN_USERNAME_LENGTH: 2,
  /** Maximum username length */
  MAX_USERNAME_LENGTH: 32,
  /** Maximum biometric retry attempts before fallback */
  MAX_BIOMETRIC_ATTEMPTS: 3,
  /** OAuth callback URL */
  OAUTH_REDIRECT_URL: `${APP_SCHEME}://auth/callback`,
  /** Session refresh interval in ms (5 minutes) */
  SESSION_REFRESH_INTERVAL: 5 * 60 * 1000,
} as const;

/** Message limits */
export const MESSAGE_CONFIG = {
  /** Maximum message content length */
  MAX_LENGTH: 4000,
  /** Maximum file attachment size in bytes (25 MB) */
  MAX_ATTACHMENT_SIZE: 25 * 1024 * 1024,
  /** Maximum number of attachments per message */
  MAX_ATTACHMENTS: 10,
  /** Number of messages to fetch per page */
  PAGE_SIZE: 50,
  /** Typing indicator timeout in ms */
  TYPING_TIMEOUT: 5000,
} as const;

/** Rate limiting */
export const RATE_LIMIT = {
  /** Minimum ms between message sends */
  MESSAGE_SEND_INTERVAL: 1000,
  /** Minimum ms between reaction toggles */
  REACTION_INTERVAL: 500,
  /** Minimum ms between friend requests */
  FRIEND_REQUEST_INTERVAL: 2000,
} as const;

/** Realtime configuration */
export const REALTIME_CONFIG = {
  /** Initial reconnect delay in ms */
  INITIAL_RECONNECT_DELAY: 1000,
  /** Maximum reconnect delay in ms */
  MAX_RECONNECT_DELAY: 30000,
  /** Reconnect backoff multiplier */
  BACKOFF_MULTIPLIER: 2,
} as const;

/** Music API configuration (cross-platform music search) */
export const MUSIC_API_URL = 'https://api.musicapi.com/public/search';
export const MUSIC_API_KEY = process.env.EXPO_PUBLIC_MUSIC_API_KEY ?? '';

/** Secure storage keys */
export const STORAGE_KEYS = {
  ACCESS_TOKEN: 'flicko_access_token',
  REFRESH_TOKEN: 'flicko_refresh_token',
  BIOMETRIC_ENABLED: 'flicko_biometric_enabled',
  USER_SESSION: 'flicko_user_session',
  THEME_PREFERENCE: 'flicko_theme',
  LAST_ACTIVE_SERVER: 'flicko_last_server',
  LAST_ACTIVE_CHANNEL: 'flicko_last_channel',
  PUSH_TOKEN: 'flicko_push_token',
} as const;
