/**
 * Mobile Auth Service
 *
 * Wraps Supabase auth specifically for mobile, using SecureStore
 * for token storage. Provides login, register, logout, session
 * restoration, and token refresh.
 *
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
 */
import { supabase } from './supabase';
import { clearSecureStorage } from './secureStorage';
import { queryClient } from './queryClient';
import { useAuthStore } from '@stores/authStore';
import { router } from 'expo-router';
import AsyncStorage from '@react-native-async-storage/async-storage';

// ── MED-002: Retry with exponential backoff ─────────────────────────────────

/** HTTP status codes that should NOT be retried (client auth errors). */
const NON_RETRYABLE_CODES = new Set([400, 401, 403, 404, 422]);

/**
 * Retry an async operation with exponential backoff and jitter.
 * Non-retryable auth errors (4xx) are thrown immediately.
 */
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries = 3,
  baseDelayMs = 500,
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      lastError = err;

      // Don't retry on auth / client errors
      const status = err?.status ?? err?.statusCode;
      if (typeof status === 'number' && NON_RETRYABLE_CODES.has(status)) {
        throw err;
      }

      if (attempt === maxRetries) break;

      // Exponential backoff with jitter: delay * 2^attempt * (0.5–1.5)
      const jitter = 0.5 + Math.random();
      const delay = baseDelayMs * Math.pow(2, attempt) * jitter;
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

/**
 * Sign in with email and password.
 * MED-002: Wrapped with retryWithBackoff for transient network failures.
 */
export async function signIn(email: string, password: string) {
  return retryWithBackoff(async () => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.trim().toLowerCase(),
      password,
    });
    if (error) throw error;
    return data;
  });
}

/**
 * Register a new account.
 */
export async function signUp(
  email: string,
  password: string,
  username: string,
) {
  const { data, error } = await supabase.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
    options: {
      data: {
        username: username.trim(),
        display_name: username.trim(),
      },
    },
  });
  if (error) throw error;
  return data;
}

/**
 * Restore the session from SecureStore on app launch.
 * Supabase client handles this automatically via the storage adapter,
 * but this explicitly checks and updates the auth store.
 */
export async function restoreSession() {
  const store = useAuthStore.getState();
  store.setIsLoading(true);

  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;

    if (session) {
      store.setSession(session);
      store.setUser(session.user as any);
      store.setIsAuthenticated(true);
    }
  } catch (err: any) {
    // Invalid/expired refresh token — clear stale session gracefully
    console.warn('[Auth] Session restore failed, clearing stale tokens:', err.message);
    try { await supabase.auth.signOut(); } catch { /* ignore */ }
    await clearSecureStorage();
    store.setSession(null);
    store.setUser(null);
    store.setIsAuthenticated(false);
  } finally {
    store.setIsLoading(false);
    store.setInitialized(true);
  }
}

/**
 * Full logout: sign out from Supabase, disconnect WebSocket,
 * clear caches, clear SecureStore, reset auth store, navigate to login.
 *
 * MED-003: Ensures WebSocket is disconnected and React Query cache
 * is cleared to prevent stale data leaking between sessions.
 */
export async function logout() {
  try {
    await supabase.auth.signOut();
  } catch {
    // Continue even if sign-out fails
  }

  // MED-003: Disconnect WebSocket to stop receiving events for old session
  try {
    const { wsManager } = await import('@shared/services/ws/WebSocketManager');
    wsManager.destroy();
  } catch {
    // Non-critical: WS may not be connected
  }

  // MED-003: Clear React Query cache to prevent stale data in next session
  try {
    queryClient.clear();
  } catch {
    // Non-critical
  }

  // Clear secure token storage
  await clearSecureStorage();

  // Clear cached data from AsyncStorage (but keep non-auth preferences)
  const keysToKeep = ['flicko-settings', 'flicko-theme'];
  try {
    const allKeys = await AsyncStorage.getAllKeys();
    const keysToRemove = allKeys.filter(
      (key) => !keysToKeep.includes(key),
    );
    if (keysToRemove.length > 0) {
      await AsyncStorage.multiRemove(keysToRemove);
    }
  } catch {
    // Non-critical: continue with logout
  }

  // Reset auth store
  useAuthStore.getState().logout();

  // Navigate to login
  router.replace('/login');
}
