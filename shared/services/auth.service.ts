import { supabase } from '../lib/supabase';
import type { User, Session, Provider } from '@supabase/supabase-js';

/**
 * Authentication Service
 * 
 * Handles user authentication, registration, session management,
 * and OAuth integrations using Supabase Auth.
 * 
 * Requirements: 4.1, 4.5, 4.6, 4.7, 4.8
 */

export interface AuthSignUpInput {
    email: string;
    password: string;
    username: string;
}

export interface AuthSignInInput {
    email: string;
    password: string;
}

export interface AuthResponse {
    user: User | null;
    session: Session | null;
}

/**
 * Register a new user with email and password
 * 
 * Includes username metadata which is used by the database trigger
 * to auto-create the user profile.
 * 
 * @param input - Sign up credentials including username
 * @returns Auth response with user and session
 * @throws Error if registration fails
 */
export async function signUp(input: AuthSignUpInput): Promise<AuthResponse> {
    const { email, password, username } = input;

    // Basic validation
    if (!email || !email.includes('@')) {
        throw new Error('Please enter a valid email address');
    }

    if (!password || password.length < 8) {
        throw new Error('Password must be at least 8 characters long');
    }

    if (!username || username.trim().length < 2) {
        throw new Error('Username must be at least 2 characters');
    }

    const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
            data: {
                username: username.trim(),
            },
            // Since Flicko is a chat app, we might want to auto-confirm depending on settings,
            // but assuming email confirmations are required by default Supabase config:
            emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
    });

    if (error) {
        throw new Error(`Registration failed: ${error.message}`);
    }

    return {
        user: data.user,
        session: data.session,
    };
}

/**
 * Sign in an existing user with email and password
 * 
 * @param input - Sign in credentials
 * @returns Auth response with user and session
 * @throws Error if sign in fails (e.g. invalid credentials)
 */
export async function signIn(input: AuthSignInInput): Promise<AuthResponse> {
    const { email, password } = input;

    if (!email || !password) {
        throw new Error('Email and password are required');
    }

    const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
    });

    if (error) {
        throw new Error(`Sign in failed: ${error.message}`);
    }

    return {
        user: data.user,
        session: data.session,
    };
}

/**
 * Sign in using an OAuth provider (e.g. Google, GitHub, Discord)
 * 
 * Redirects the user to the provider's login page.
 * 
 * @param provider - The OAuth provider to use
 * @throws Error if initialization fails
 */
export async function signInWithOAuth(provider: Provider): Promise<void> {
    const { error } = await supabase.auth.signInWithOAuth({
        provider,
        options: {
            redirectTo: `${window.location.origin}/auth/callback`,
        },
    });

    if (error) {
        throw new Error(`OAuth sign in failed: ${error.message}`);
    }
}

/**
 * Sign out the current user and clear their session
 * 
 * @throws Error if sign out fails
 */
export async function signOut(): Promise<void> {
    const { error } = await supabase.auth.signOut();

    if (error) {
        throw new Error(`Sign out failed: ${error.message}`);
    }
}

/**
 * Get the current active session
 * 
 * Useful for restoring state on application load.
 * 
 * @returns The current session or null if none exists
 * @throws Error if fetching session fails
 */
export async function getSession(): Promise<Session | null> {
    const { data, error } = await supabase.auth.getSession();

    if (error) {
        throw new Error(`Failed to get session: ${error.message}`);
    }

    return data.session;
}

/**
 * Get the current authenticated user
 * 
 * @returns The current user or null if none exists
 * @throws Error if fetching user fails
 */
export async function getCurrentUser(): Promise<User | null> {
    const { data, error } = await supabase.auth.getUser();

    if (error) {
        // We don't throw if it's just an auth session missing error
        if (error.status === 400 || error.message.includes('session context')) {
            return null;
        }
        throw new Error(`Failed to get user: ${error.message}`);
    }

    return data.user;
}

/**
 * Subscribe to authentication state changes
 * 
 * @param callback - Function to call when auth state changes
 * @returns An object with an unsubscribe method
 */
export function onAuthStateChange(
    callback: (event: string, session: Session | null) => void
): { unsubscribe: () => void } {
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
        callback(event, session);
    });

    return {
        unsubscribe: () => {
            data.subscription.unsubscribe();
        }
    };
}
