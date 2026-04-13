// ============================================
// Subscription Store (Zustand)
// Manages Nitro subscription state + feature gating
// ============================================
import { create } from 'zustand';

// ---- Types ----

export type NitroPlan = 'nitro_basic' | 'nitro_full';
export type SubscriptionStatus = 'active' | 'grace_period' | 'expired' | 'revoked' | 'paused' | 'cancelled' | 'canceled' | 'past_due' | 'unpaid' | 'incomplete' | 'none';

export interface Subscription {
  id: string;
  user_id: string;
  plan: NitroPlan;
  status: SubscriptionStatus;
  store: 'app_store' | 'play_store' | 'stripe' | 'dev_mock';
  current_period_start: string;
  current_period_end: string;
  cancel_at_period_end: boolean;
  created_at: string;
  updated_at: string;
}

export interface Entitlement {
  id: string;
  user_id: string;
  type: string;
  source: 'subscription' | 'purchase' | 'gift' | 'dev_grant';
  granted_at: string;
  expires_at?: string;
  revoked: boolean;
}

export interface NitroPlanInfo {
  id: NitroPlan;
  name: string;
  monthlyPrice: number;
  yearlyPrice: number;
  includedBoosts: number;
  features: string[];
  tierColor: string;
}

export const NITRO_PLANS: NitroPlanInfo[] = [
  {
    id: 'nitro_full',
    name: 'Nitro',
    monthlyPrice: 9.99,
    yearlyPrice: 99.99,
    includedBoosts: 2,
    tierColor: '#5865F2',
    features: [
      '2 Server Boosts + 30% off extra Boosts',
      '500MB uploads',
      'Custom animated emoji anywhere',
      'HD video streaming up to 4K/60fps',
      'Custom profiles & banners',
      'Animated avatar',
      'Custom app icons',
      '48 Soundboard slots',
    ],
  },
  {
    id: 'nitro_basic',
    name: 'Nitro Basic',
    monthlyPrice: 2.99,
    yearlyPrice: 29.99,
    includedBoosts: 0,
    tierColor: '#EB459E',
    features: [
      '50MB uploads',
      'Custom emoji anywhere',
      'Animated emoji & stickers',
      '24 Soundboard slots',
    ],
  },
];

// ---- Feature Gating Matrix ----

export interface FeatureLimits {
  maxEmojiSize: number;       // KB
  maxUploadSize: number;      // bytes
  emojiUploadLimit: number;
  animatedEmoji: boolean;
  customSoundboardSlots: number;
  streamQuality: string;
  maxFileUpload: number;      // bytes
  serverBoosts: number;
  profileBanner: boolean;
  animatedAvatar: boolean;
  customAppIcons: boolean;
}

export const FEATURE_LIMITS: Record<'free' | 'nitro_basic' | 'nitro_full', FeatureLimits> = {
  free: {
    maxEmojiSize: 256,
    maxUploadSize: 25 * 1024 * 1024,
    emojiUploadLimit: 50,
    animatedEmoji: false,
    customSoundboardSlots: 5,
    streamQuality: '720p',
    maxFileUpload: 25 * 1024 * 1024,
    serverBoosts: 0,
    profileBanner: false,
    animatedAvatar: false,
    customAppIcons: false,
  },
  nitro_basic: {
    maxEmojiSize: 512,
    maxUploadSize: 50 * 1024 * 1024,
    emojiUploadLimit: 100,
    animatedEmoji: true,
    customSoundboardSlots: 24,
    streamQuality: '1080p',
    maxFileUpload: 50 * 1024 * 1024,
    serverBoosts: 0,
    profileBanner: false,
    animatedAvatar: false,
    customAppIcons: false,
  },
  nitro_full: {
    maxEmojiSize: 512,
    maxUploadSize: 500 * 1024 * 1024,
    emojiUploadLimit: 500,
    animatedEmoji: true,
    customSoundboardSlots: 48,
    streamQuality: '4K/60',
    maxFileUpload: 500 * 1024 * 1024,
    serverBoosts: 2,
    profileBanner: true,
    animatedAvatar: true,
    customAppIcons: true,
  },
};

// ---- Store ----

interface SubscriptionStore {
  subscription: Subscription | null;
  entitlements: Entitlement[];
  isLoading: boolean;
  isPurchasing: boolean;

  // Computed
  isNitro: boolean;
  plan: NitroPlan | null;
  limits: FeatureLimits;

  // Actions
  setSubscription: (sub: Subscription | null) => void;
  setEntitlements: (entitlements: Entitlement[]) => void;
  setLoading: (loading: boolean) => void;
  setPurchasing: (purchasing: boolean) => void;
  hasEntitlement: (type: string) => boolean;
  canUseFeature: (feature: keyof FeatureLimits) => boolean;
  reset: () => void;
}

function getLimits(plan: NitroPlan | null): FeatureLimits {
  if (plan === 'nitro_full') return FEATURE_LIMITS.nitro_full;
  if (plan === 'nitro_basic') return FEATURE_LIMITS.nitro_basic;
  return FEATURE_LIMITS.free;
}

export const useSubscriptionStore = create<SubscriptionStore>((set, get) => ({
  subscription: null,
  entitlements: [],
  isLoading: false,
  isPurchasing: false,
  isNitro: false,
  plan: null,
  limits: FEATURE_LIMITS.free,

  setSubscription: (sub) => {
    const plan = sub && (sub.status === 'active' || sub.status === 'grace_period') ? sub.plan : null;
    set({
      subscription: sub,
      isNitro: plan !== null,
      plan,
      limits: getLimits(plan),
    });
  },

  setEntitlements: (entitlements) => set({ entitlements }),

  setLoading: (isLoading) => set({ isLoading }),
  setPurchasing: (isPurchasing) => set({ isPurchasing }),

  hasEntitlement: (type) => {
    const { entitlements } = get();
    return entitlements.some((e) => e.type === type && !e.revoked);
  },

  canUseFeature: (feature) => {
    const { limits } = get();
    const val = limits[feature];
    return typeof val === 'boolean' ? val : (val as number) > 0;
  },

  reset: () =>
    set({
      subscription: null,
      entitlements: [],
      isLoading: false,
      isPurchasing: false,
      isNitro: false,
      plan: null,
      limits: FEATURE_LIMITS.free,
    }),
}));
