/**
 * Stripe Payment Service — Production Implementation
 *
 * Handles all Stripe payment flows for Flicko+ subscriptions.
 * Supports payment sheet, subscription management, and webhook handling.
 *
 * Features:
 * - Initialize Stripe with publishable key
 * - Present payment sheet for secure card entry
 * - Create and manage subscriptions
 * - Handle payment confirmation
 * - Restore purchases
 * - Cancel subscriptions
 *
 * Requirements: 2.8
 */
import {
  initStripe,
  presentPaymentSheet,
  confirmPayment,
  createPaymentMethod,
  retrievePaymentIntent,
  isPlatformPaySupported,
  PlatformPay,
} from '@stripe/stripe-react-native';
import { supabase } from '../../mobile/services/supabase';
import { Alert, Platform } from 'react-native';
import Constants from 'expo-constants';

const STRIPE_PUBLISHABLE_KEY = process.env.EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY || 
  Constants.expoConfig?.extra?.stripePublishableKey || '';

const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8080';

export type SubscriptionPlan = 'basic' | 'plus' | 'basic_yearly' | 'plus_yearly';

interface PaymentResult {
  success: boolean;
  error?: string;
  subscriptionId?: string;
  clientSecret?: string;
}

interface SubscriptionDetails {
  id: string;
  plan: SubscriptionPlan;
  status: 'active' | 'canceled' | 'past_due' | 'unpaid' | 'incomplete';
  currentPeriodEnd: string;
  cancelAtPeriodEnd: boolean;
  price: number;
  currency: string;
}

let isStripeInitialized = false;

/**
 * Initialize Stripe SDK
 */
export async function initializeStripe(): Promise<boolean> {
  if (isStripeInitialized) return true;
  
  if (!STRIPE_PUBLISHABLE_KEY) {
    console.error('[Stripe] Publishable key not configured');
    return false;
  }

  try {
    await initStripe({
      publishableKey: STRIPE_PUBLISHABLE_KEY,
      merchantIdentifier: 'merchant.com.flicko.app',
      urlScheme: 'flicko',
    });
    
    isStripeInitialized = true;
    console.log('[Stripe] Initialized successfully');
    return true;
  } catch (err: any) {
    console.error('[Stripe] Initialization failed:', err);
    return false;
  }
}

/**
 * Ensure Stripe is initialized before operations
 */
async function ensureInitialized(): Promise<boolean> {
  if (!isStripeInitialized) {
    return await initializeStripe();
  }
  return true;
}

/**
 * Create a payment intent on the backend
 */
async function createPaymentIntent(
  plan: SubscriptionPlan,
  customerId?: string
): Promise<{ clientSecret: string; customerId: string; subscriptionId: string } | null> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      throw new Error('Not authenticated');
    }

    const response = await fetch(`${API_BASE_URL}/api/v1/payments/create-intent`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({
        plan,
        customerId,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Failed to create payment intent');
    }

    const data = await response.json();
    return {
      clientSecret: data.clientSecret,
      customerId: data.customerId,
      subscriptionId: data.subscriptionId,
    };
  } catch (err: any) {
    console.error('[Stripe] Create payment intent failed:', err);
    return null;
  }
}

/**
 * Present payment sheet and handle payment
 */
export async function purchaseSubscriptionWithStripe(
  plan: SubscriptionPlan
): Promise<PaymentResult> {
  if (!(await ensureInitialized())) {
    return { success: false, error: 'Payment system not initialized' };
  }

  try {
    // Get user session
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    // Check if user already has a Stripe customer ID
    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', user.id)
      .single();

    const existingCustomerId = profile?.stripe_customer_id;

    // Create payment intent
    const intentData = await createPaymentIntent(plan, existingCustomerId);
    if (!intentData) {
      return { success: false, error: 'Failed to initialize payment' };
    }

    const { clientSecret, customerId, subscriptionId } = intentData;

    // Save customer ID if new
    if (!existingCustomerId && customerId) {
      await supabase
        .from('profiles')
        .update({ stripe_customer_id: customerId })
        .eq('id', user.id);
    }

    // Present payment sheet
    const { error } = await presentPaymentSheet({
      clientSecret,
      merchantDisplayName: 'Flicko',
      allowsDelayedPaymentMethods: true,
      billingDetails: {
        email: user.email || undefined,
      },
    });

    if (error) {
      console.error('[Stripe] Payment sheet error:', error);
      
      if (error.code === 'Canceled') {
        return { success: false, error: 'Payment cancelled' };
      }
      
      return { success: false, error: error.message };
    }

    // Payment successful - confirm subscription
    const confirmResult = await confirmSubscriptionInDatabase(subscriptionId, plan);
    
    if (!confirmResult) {
      return { success: false, error: 'Payment succeeded but subscription activation failed' };
    }

    return {
      success: true,
      subscriptionId,
    };
  } catch (err: any) {
    console.error('[Stripe] Purchase error:', err);
    return { success: false, error: err.message || 'Payment failed' };
  }
}

/**
 * Confirm subscription in database after successful payment
 */
async function confirmSubscriptionInDatabase(
  subscriptionId: string,
  plan: SubscriptionPlan
): Promise<boolean> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return false;

    const { error } = await supabase
      .from('subscriptions')
      .upsert({
        user_id: user.id,
        stripe_subscription_id: subscriptionId,
        plan: plan.startsWith('plus') ? 'nitro_full' : 'nitro_basic',
        status: 'active',
        store: 'stripe',
        current_period_start: new Date().toISOString(),
        current_period_end: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        cancel_at_period_end: false,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });

    if (error) {
      console.error('[Stripe] Database update failed:', error);
      return false;
    }

    // Grant entitlements
    await supabase
      .from('entitlements')
      .upsert({
        user_id: user.id,
        type: plan.startsWith('plus') ? 'nitro_full' : 'nitro_basic',
        source: 'stripe_purchase',
        granted_at: new Date().toISOString(),
        revoked: false,
      }, {
        onConflict: 'user_id,type',
      });

    return true;
  } catch (err) {
    console.error('[Stripe] Confirm subscription error:', err);
    return false;
  }
}

/**
 * Fetch current subscription details
 */
export async function fetchStripeSubscription(): Promise<SubscriptionDetails | null> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    // First check local database
    const { data: localSub } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('user_id', user.id)
      .in('status', ['active', 'grace_period'])
      .single();

    if (localSub?.stripe_subscription_id) {
      // Sync with Stripe
      const { data: { session } } = await supabase.auth.getSession();
      
      const response = await fetch(
        `${API_BASE_URL}/api/v1/payments/subscription/${localSub.stripe_subscription_id}`,
        {
          headers: {
            'Authorization': `Bearer ${session?.access_token || ''}`,
          },
        }
      );

      if (response.ok) {
        const stripeData = await response.json();
        
        // Update local status if different
        if (stripeData.status !== localSub.status) {
          await supabase
            .from('subscriptions')
            .update({ status: stripeData.status, updated_at: new Date().toISOString() })
            .eq('user_id', user.id);
        }

        return {
          id: localSub.stripe_subscription_id,
          plan: localSub.plan === 'nitro_full' ? 'plus' : 'basic',
          status: stripeData.status,
          currentPeriodEnd: stripeData.currentPeriodEnd,
          cancelAtPeriodEnd: stripeData.cancelAtPeriodEnd,
          price: stripeData.price,
          currency: stripeData.currency,
        };
      }
    }

    return localSub ? {
      id: localSub.id,
      plan: localSub.plan === 'nitro_full' ? 'plus' : 'basic',
      status: localSub.status,
      currentPeriodEnd: localSub.current_period_end,
      cancelAtPeriodEnd: localSub.cancel_at_period_end,
      price: localSub.plan === 'nitro_full' ? 849 : 249,
      currency: 'inr',
    } : null;
  } catch (err) {
    console.error('[Stripe] Fetch subscription error:', err);
    return null;
  }
}

/**
 * Cancel subscription
 */
export async function cancelStripeSubscription(): Promise<boolean> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return false;

    const { data: { session } } = await supabase.auth.getSession();

    // Get current subscription
    const { data: subscription } = await supabase
      .from('subscriptions')
      .select('stripe_subscription_id')
      .eq('user_id', user.id)
      .in('status', ['active'])
      .single();

    if (!subscription?.stripe_subscription_id) {
      // No Stripe subscription, just update local
      await supabase
        .from('subscriptions')
        .update({ cancel_at_period_end: true, updated_at: new Date().toISOString() })
        .eq('user_id', user.id);
      return true;
    }

    // Cancel via backend
    const response = await fetch(
      `${API_BASE_URL}/api/v1/payments/cancel-subscription`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.access_token || ''}`,
        },
        body: JSON.stringify({
          subscriptionId: subscription.stripe_subscription_id,
        }),
      }
    );

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Failed to cancel subscription');
    }

    // Update local database
    await supabase
      .from('subscriptions')
      .update({ cancel_at_period_end: true, updated_at: new Date().toISOString() })
      .eq('user_id', user.id);

    return true;
  } catch (err: any) {
    console.error('[Stripe] Cancel subscription error:', err);
    Alert.alert('Error', err.message || 'Failed to cancel subscription');
    return false;
  }
}

/**
 * Restore purchases (sync with Stripe)
 */
export async function restoreStripePurchases(): Promise<SubscriptionDetails | null> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    // Re-fetch subscription from Stripe
    return await fetchStripeSubscription();
  } catch (err) {
    console.error('[Stripe] Restore purchases error:', err);
    return null;
  }
}

/**
 * Check if Apple Pay / Google Pay is supported
 */
export async function checkPlatformPaySupport(): Promise<boolean> {
  if (Platform.OS === 'web') return false;
  
  try {
    return await isPlatformPaySupported();
  } catch {
    return false;
  }
}

/**
 * Get pricing for a plan
 */
export function getPlanPricing(plan: SubscriptionPlan): {
  price: number;
  currency: string;
  period: 'month' | 'year';
} {
  const pricing = {
    basic: { price: 249, currency: 'INR', period: 'month' as const },
    plus: { price: 849, currency: 'INR', period: 'month' as const },
    basic_yearly: { price: 2499, currency: 'INR', period: 'year' as const },
    plus_yearly: { price: 8499, currency: 'INR', period: 'year' as const },
  };
  
  return pricing[plan];
}

/**
 * Format price for display
 */
export function formatPrice(price: number, currency: string): string {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(price);
}
