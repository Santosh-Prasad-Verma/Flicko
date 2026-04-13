/**
 * Onboarding Service
 *
 * Server onboarding flow: welcome screen, default channels, rules acceptance.
 * Requirements: Feature 24 (Server Onboarding)
 */
import { supabase } from '../lib/supabase';

export interface OnboardingConfig {
  server_id: string;
  enabled: boolean;
  welcome_title: string;
  welcome_description: string | null;
  welcome_image_url: string | null;
  default_channel_ids: string[];
  rules: string[];
  require_rules_acceptance: boolean;
  prompts: OnboardingPrompt[];
}

export interface OnboardingPrompt {
  id: string;
  title: string;
  description: string;
  type: 'multiple_choice' | 'dropdown';
  required: boolean;
  options: { label: string; role_ids?: string[]; channel_ids?: string[] }[];
}

export interface OnboardingCompletion {
  user_id: string;
  server_id: string;
  completed_at: string;
  selected_options: Record<string, string[]>;
}

// ─── Config CRUD ───────────────────────────────────────────────────────────────

export async function getOnboardingConfig(serverId: string): Promise<OnboardingConfig | null> {
  const { data, error } = await supabase
    .from('server_onboarding')
    .select('*')
    .eq('server_id', serverId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function updateOnboardingConfig(
  serverId: string,
  updates: Partial<Omit<OnboardingConfig, 'server_id'>>,
) {
  const { error } = await supabase
    .from('server_onboarding')
    .upsert(
      { server_id: serverId, ...updates },
      { onConflict: 'server_id' },
    );
  if (error) throw error;
}

// ─── Completion tracking ───────────────────────────────────────────────────────

export async function hasCompletedOnboarding(
  serverId: string,
  userId: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from('onboarding_completions')
    .select('user_id')
    .eq('server_id', serverId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return !!data;
}

export async function completeOnboarding(
  serverId: string,
  userId: string,
  selectedOptions: Record<string, string[]>,
) {
  const { error } = await supabase
    .from('onboarding_completions')
    .insert({
      server_id: serverId,
      user_id: userId,
      selected_options: selectedOptions,
      completed_at: new Date().toISOString(),
    });
  if (error) throw error;
}
