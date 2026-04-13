/**
 * LOW-008: Shared numeric constants extracted from magic numbers.
 *
 * Import these in services and mobile code instead of using raw literals.
 */

// ─── Validation Limits ─────────────────────────────────────────────────────────

/** Max length for server names. */
export const MAX_SERVER_NAME_LENGTH = 100;

/** Max length for channel names. */
export const MAX_CHANNEL_NAME_LENGTH = 100;

/** Max length for message content. */
export const MAX_MESSAGE_LENGTH = 2000;

/** Max length for user bios / "About Me". */
export const MAX_BIO_LENGTH = 190;

/** Max length for display names. */
export const MAX_DISPLAY_NAME_LENGTH = 32;

/** Max length for pronouns. */
export const MAX_PRONOUNS_LENGTH = 40;

/** Max length for custom status text. */
export const MAX_CUSTOM_STATUS_LENGTH = 128;

// ─── Pagination ─────────────────────────────────────────────────────────────────

/** Default number of messages per page. */
export const DEFAULT_PAGE_SIZE = 50;

/** Maximum page size allowed by API. */
export const MAX_PAGE_SIZE = 100;

/** Default number of thread messages per page. */
export const DEFAULT_THREAD_PAGE_SIZE = 50;

/** Max number of public templates returned. */
export const MAX_PUBLIC_TEMPLATES = 50;

// ─── Timeouts & Intervals (milliseconds) ───────────────────────────────────────

/** Default Supabase query timeout. */
export const DEFAULT_TIMEOUT_MS = 10_000;

/** Circuit breaker reset delay. */
export const CIRCUIT_BREAKER_RESET_MS = 30_000;

/** Circuit breaker failure threshold before opening. */
export const CIRCUIT_BREAKER_THRESHOLD = 5;

/** Base delay for exponential retry backoff. */
export const RETRY_BASE_DELAY_MS = 1_000;

/** Default maximum retry attempts. */
export const DEFAULT_MAX_RETRIES = 3;

/** Typing indicator throttle interval. */
export const TYPING_THROTTLE_MS = 1_000;

/** Typing indicator auto-expire timeout. */
export const TYPING_EXPIRE_MS = 5_000;

/** Navigation guard debounce timeout. */
export const NAVIGATION_GUARD_TIMEOUT_MS = 1_000;

/** Voice state refetch interval. */
export const VOICE_STATE_REFETCH_INTERVAL_MS = 5_000;

/** Stage participant refetch interval. */
export const STAGE_REFETCH_INTERVAL_MS = 3_000;

/** React Query stale time (1 minute). */
export const QUERY_STALE_TIME_MS = 60_000;

/** React Query garbage collection time (5 minutes). */
export const QUERY_GC_TIME_MS = 300_000;

/** React Query default retry count. */
export const QUERY_DEFAULT_RETRIES = 2;

// ─── Time Conversions ───────────────────────────────────────────────────────────

export const SECONDS_PER_MINUTE = 60;
export const SECONDS_PER_HOUR = 3_600;
export const SECONDS_PER_DAY = 86_400;
export const MS_PER_SECOND = 1_000;
export const MS_PER_MINUTE = 60_000;
export const MS_PER_HOUR = 3_600_000;
export const MS_PER_DAY = 86_400_000;
export const SEVEN_DAYS_MS = 7 * MS_PER_DAY;

// ─── Storage ────────────────────────────────────────────────────────────────────

/** Cache-Control header for uploaded files (1 hour). */
export const STORAGE_CACHE_CONTROL = '3600';

/** Default cache TTL for offline cache entries (seconds). */
export const DEFAULT_CACHE_TTL_SECONDS = 300;

// ─── Thread Defaults ────────────────────────────────────────────────────────────

/** Default auto-archive duration for threads (24 hours in minutes). */
export const DEFAULT_AUTO_ARCHIVE_MINUTES = 1440;
