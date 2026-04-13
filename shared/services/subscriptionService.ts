// ============================================
// Subscription Service — Dev/testing mock
// Real implementation would use RevenueCat/StoreKit
// ============================================
import { supabase } from '../../mobile/services/supabase';
import type { Subscription, Entitlement, NitroPlan } from '../stores/subscriptionStore';

// ---- Fetch Subscription ----

export async function fetchSubscription(): Promise<Subscription | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', user.id)
    .in('status', ['active', 'grace_period'])
    .single();

  if (error || !data) return null;
  return data as Subscription;
}

// ---- Fetch Entitlements ----

export async function fetchEntitlements(): Promise<Entitlement[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return [];

  const { data, error } = await supabase
    .from('entitlements')
    .select('*')
    .eq('user_id', user.id)
    .eq('revoked', false);

  if (error) return [];
  return (data ?? []) as Entitlement[];
}

// ---- Purchase Subscription (Dev Mock) ----

export async function purchaseSubscription(plan: NitroPlan): Promise<Subscription> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // For dev/testing: directly create a subscription in the DB
  const periodEnd = new Date();
  periodEnd.setDate(periodEnd.getDate() + 30);

  const { data, error } = await supabase
    .from('subscriptions')
    .upsert(
      {
        user_id: user.id,
        plan,
        status: 'active',
        store: 'dev_mock',
        current_period_start: new Date().toISOString(),
        current_period_end: periodEnd.toISOString(),
        cancel_at_period_end: false,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' }
    )
    .select()
    .single();

  if (error) throw error;

  // Also grant entitlement
  await supabase
    .from('entitlements')
    .upsert(
      {
        user_id: user.id,
        type: plan,
        source: 'dev_grant',
        granted_at: new Date().toISOString(),
        revoked: false,
      },
      { onConflict: 'user_id,type' }
    );

  return data as Subscription;
}

// ---- Cancel Subscription ----

export async function cancelSubscription(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { error } = await supabase
    .from('subscriptions')
    .update({ cancel_at_period_end: true, updated_at: new Date().toISOString() })
    .eq('user_id', user.id)
    .in('status', ['active', 'grace_period']);

  if (error) throw error;
}

// ---- Restore Purchases (Dev Mock) ----

export async function restorePurchases(): Promise<Subscription | null> {
  // In dev mode, just re-fetch the current subscription
  return fetchSubscription();
}

// ---- Feature Gate Helper ----

export function canUseCrossServerEmoji(plan: NitroPlan | null): boolean {
  return plan === 'nitro_basic' || plan === 'nitro_full';
}

export function canUseAnimatedEmoji(plan: NitroPlan | null): boolean {
  return plan === 'nitro_basic' || plan === 'nitro_full';
}

export function getMaxUploadSize(plan: NitroPlan | null): number {
  if (plan === 'nitro_full') return 500 * 1024 * 1024;
  if (plan === 'nitro_basic') return 50 * 1024 * 1024;
  return 25 * 1024 * 1024;
}

export function getMaxSoundboardSlots(plan: NitroPlan | null): number {
  if (plan === 'nitro_full') return 48;
  if (plan === 'nitro_basic') return 24;
  return 5;
}

export function getStreamQuality(plan: NitroPlan | null): string {
  if (plan === 'nitro_full') return '4K/60fps';
  if (plan === 'nitro_basic') return '1080p';
  return '720p';
}
