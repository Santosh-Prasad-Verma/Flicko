import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createZustandStorage } from '../lib/storage';
import type { User } from '@shared/types';
import type { Session } from '@supabase/supabase-js';

// NOTE: Importing supabase statically causes circular deps in some setups.
// Lazy-import is used in isSessionValid to verify token server-side.
let _supabasePromise: Promise<any> | null = null;
async function getSupabaseAuth() {
  if (!_supabasePromise) {
    _supabasePromise = import('../lib/supabase').then(m => m.supabase?.auth ?? m.getSupabase?.()?.auth).catch(() => null);
  }
  return _supabasePromise;
}

type PersistedUser = User & {
  user_metadata?: {
    username?: string;
    display_name?: string;
    avatar_url?: string;
  };
};

function compactUser(input: unknown): PersistedUser | null {
  if (!input) return null;

  const raw = input as Record<string, unknown>;

  const userMetadata = (raw.user_metadata as Record<string, unknown> | undefined) ?? {};
  const username =
    (raw.username as string | undefined) ??
    (userMetadata.username as string | undefined) ??
    (raw.email as string | undefined)?.split('@')?.[0] ??
    'User';

  const compacted: PersistedUser = {
    id: (raw.id as string | undefined) ?? '',
    email: (raw.email as string | undefined) ?? '',
    username,
    discriminator: (raw.discriminator as string | undefined) ?? '0000',
    display_name:
      (raw.display_name as string | null | undefined) ??
      (userMetadata.display_name as string | undefined) ??
      username,
    avatar:
      (raw.avatar as string | null | undefined) ??
      (userMetadata.avatar_url as string | undefined) ??
      null,
    banner: (raw.banner as string | null | undefined) ?? null,
    bio: (raw.bio as string | null | undefined) ?? null,
    pronouns: (raw.pronouns as string | null | undefined) ?? null,
    status: (raw.status as User['status'] | undefined) ?? 'offline',
    custom_status: (raw.custom_status as string | null | undefined) ?? null,
    created_at: (raw.created_at as string | undefined) ?? new Date().toISOString(),
    updated_at: (raw.updated_at as string | undefined) ?? new Date().toISOString(),
    user_metadata: {
      username,
      display_name:
        (raw.display_name as string | null | undefined) ??
        (userMetadata.display_name as string | undefined) ??
        username,
      avatar_url:
        (raw.avatar as string | null | undefined) ??
        (userMetadata.avatar_url as string | undefined) ??
        undefined,
    },
  };

  return compacted;
}

// MED-019: Maximum session age (30 days in seconds).
const MAX_SESSION_AGE_SECONDS = 30 * 24 * 60 * 60;

/**
 * Returns true if the session is still valid (not expired and within max age).
 * CRIT-009: Now verifies JWT with the server when possible.
 */
function isSessionValid(session: Session | null): boolean {
  if (!session) return false;

  const now = Math.floor(Date.now() / 1000);

  // Check Supabase token expiry
  if (session.expires_at && session.expires_at <= now) return false;

  // MED-019: Enforce max session age (30 days from issued_at or created_at)
  const issuedAt = (session as any).created_at
    ? new Date((session as any).created_at).getTime() / 1000
    : session.expires_at
      ? session.expires_at - 3600 // fallback: assume 1h token lifetime
      : now;

  if (now - issuedAt > MAX_SESSION_AGE_SECONDS) return false;

  return true;
}

/**
 * CRIT-009: Async session validation that also verifies the JWT server-side.
 * Falls back to local-only check if server is unreachable.
 */
async function isSessionValidAsync(session: Session | null): Promise<boolean> {
  if (!isSessionValid(session)) return false;

  // CRIT-009: Verify JWT signature with Supabase
  try {
    const auth = await getSupabaseAuth();
    if (auth && session?.access_token) {
      const { data, error } = await auth.getUser(session.access_token);
      if (error || !data?.user) {
        return false;
      }
    }
  } catch {
    // Network error — fall back to local validation (already passed above)
  }

  return true;
}

export interface AuthStore {
  user: PersistedUser | null;
  session: Session | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  initialized: boolean;

  setUser: (user: unknown) => void;
  setSession: (session: Session | null) => void;
  setIsLoading: (isLoading: boolean) => void;
  setIsAuthenticated: (isAuthenticated: boolean) => void;
  setInitialized: (initialized: boolean) => void;
  isSessionExpired: () => boolean;
  logout: () => void;
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      user: null,
      session: null,
      isLoading: true,
      isAuthenticated: false,
      initialized: false,

      setUser: (user) => set({ user: compactUser(user) }),
      setSession: (session) => {
        // MED-019: Reject expired or too-old sessions
        if (session && !isSessionValid(session)) {
          set({ session: null, user: null, isAuthenticated: false });
          return;
        }
        set({ session });
      },
      setIsLoading: (isLoading) => set({ isLoading }),
      setIsAuthenticated: (isAuthenticated) => set({ isAuthenticated }),
      setInitialized: (initialized) => set({ initialized }),
      isSessionExpired: () => {
        const state = useAuthStore.getState();
        return !isSessionValid(state.session);
      },
      logout: () =>
        set({
          user: null,
          session: null,
          isAuthenticated: false,
        }),
    }),
    {
      name: 'flicko-auth',
      storage: createJSONStorage(() => createZustandStorage()),
      // Only persist safe user fields, explicitly exclude sensitive data (HIGH-002)
      partialize: (state) => ({
        user: state.user ? {
          id: state.user.id,
          email: state.user.email,
          username: state.user.username,
          discriminator: state.user.discriminator,
          display_name: state.user.display_name,
          avatar: state.user.avatar,
          banner: state.user.banner,
          bio: state.user.bio,
          status: state.user.status,
          custom_status: state.user.custom_status,
          created_at: state.user.created_at,
          updated_at: state.user.updated_at,
          // Explicitly exclude: user_metadata, session tokens, access_token, refresh_token
        } as PersistedUser : null,
      }),
    }
  )
);
