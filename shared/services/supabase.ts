/**
 * Re-export supabase client from shared/lib/supabase.
 * This barrel lets `@services/supabase` resolve correctly via tsconfig paths.
 */
export { supabase, getSupabase } from '../lib/supabase';
