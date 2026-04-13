/**
 * Mobile Supabase Client
 *
 * Creates a Supabase client configured for React Native:
 * - Auth tokens stored in SecureStore (Keychain / KeyStore)
 * - Auto-refresh enabled
 * - Detect network URL for local development on physical devices
 *
 * CRIT-006: Added runtime validation of Supabase configuration.
 * Requirements: 2.1, 2.2, 2.5, 37.1
 */
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../constants/Config';
import { supabaseSecureStorage } from './secureStorage';

let supabaseInstance: SupabaseClient | null = null;

/**
 * Get or create the singleton Supabase client for mobile.
 * CRIT-006: Validates URL and key format before creating client.
 */
export function getSupabase(): SupabaseClient {
  if (supabaseInstance) {
    return supabaseInstance;
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error(
      'Missing Supabase configuration. Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
    );
  }

  // CRIT-006: Validate URL format
  try {
    new URL(SUPABASE_URL);
  } catch {
    throw new Error('Invalid SUPABASE_URL format');
  }

  // CRIT-006: Validate key format (JWT structure)
  if (!SUPABASE_ANON_KEY.match(/^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/)) {
    throw new Error('Invalid SUPABASE_ANON_KEY format');
  }

  supabaseInstance = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      storage: supabaseSecureStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false, // Not applicable on mobile
    },
  });

  return supabaseInstance;
}

/** Convenience export */
export const supabase = getSupabase();
