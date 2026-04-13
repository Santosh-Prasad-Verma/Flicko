/**
 * Supabase client re-export for shared/ code.
 *
 * The actual client lives in mobile/services/supabase.ts because
 * initialisation depends on mobile-specific secure storage.
 * Shared services import from here so the path alias `@lib/supabase` resolves.
 */
export { supabase, getSupabase } from '../../mobile/services/supabase';
