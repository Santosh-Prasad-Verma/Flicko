/**
 * Flicko Plus — Premium Subscription Screen
 *
 * Flicko Plus pricing page with two tiers,
 * feature comparison, and animated gradient branding.
 */
import React, { useState, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Dimensions,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Stack, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useTheme } from '../hooks/useTheme';
import { spacing, borderRadius } from '../constants/Colors';
import {
  useSubscriptionStore,
  type NitroPlan,
} from '@stores/subscriptionStore';
import {
  purchaseSubscriptionWithStripe,
  cancelStripeSubscription,
  restoreStripePurchases,
  fetchStripeSubscription,
  initializeStripe,
  formatPrice,
  type SubscriptionPlan,
} from '@services/stripePaymentService';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

/* ─── Plan definitions ─── */
interface PlanFeature {
  text: string;
  included: boolean;
}

interface Plan {
  id: 'basic' | 'plus';
  name: string;
  tagline: string;
  monthlyPrice: string;
  yearlyPrice: string;
  yearlySaving: string;
  icon: keyof typeof Ionicons.glyphMap;
  gradient: [string, string];
  features: PlanFeature[];
}

const PLANS: Plan[] = [
  {
    id: 'basic',
    name: 'Flicko Basic',
    tagline: 'Great for casual users',
    monthlyPrice: '₹249',
    yearlyPrice: '₹2,499',
    yearlySaving: 'Save 16%',
    icon: 'flash',
    gradient: ['#5865F2', '#7289DA'],
    features: [
      { text: '50MB file uploads', included: true },
      { text: 'Custom emoji anywhere', included: true },
      { text: 'HD video streaming (720p)', included: true },
      { text: 'Animated avatar', included: true },
      { text: 'Custom status badge', included: true },
      { text: '2 Server Boosts', included: true },
      { text: 'Custom profiles & banners', included: false },
      { text: '4K video streaming', included: false },
      { text: 'Longer messages (4000 chars)', included: false },
      { text: 'Custom server icons (GIF)', included: false },
    ],
  },
  {
    id: 'plus',
    name: 'Flicko Plus',
    tagline: 'The ultimate Flicko experience',
    monthlyPrice: '₹849',
    yearlyPrice: '₹8,499',
    yearlySaving: 'Save 17%',
    icon: 'diamond',
    gradient: ['#5865F2', '#EB459E'],
    features: [
      { text: '500MB file uploads', included: true },
      { text: 'Custom emoji anywhere', included: true },
      { text: '4K video streaming (2160p)', included: true },
      { text: 'Animated avatar & banner', included: true },
      { text: 'Custom status badge', included: true },
      { text: '2 Server Boosts included', included: true },
      { text: 'Custom profiles & themes', included: true },
      { text: 'Longer messages (4000 chars)', included: true },
      { text: 'Custom server icons (GIF)', included: true },
      { text: 'Early access to new features', included: true },
    ],
  },
];

/* ─── Perk spotlight items ─── */
interface Perk {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  description: string;
  gradient: [string, string];
}

const PERKS: Perk[] = [
  {
    icon: 'cloud-upload',
    title: 'Bigger Uploads',
    description: 'Share files up to 500MB with your friends.',
    gradient: ['#5865F2', '#7289DA'],
  },
  {
    icon: 'happy',
    title: 'Custom Emoji',
    description: 'Use your custom emoji in any server.',
    gradient: ['#FEE75C', '#F0B232'],
  },
  {
    icon: 'videocam',
    title: 'HD Streaming',
    description: 'Stream in stunning 4K quality for everyone to enjoy.',
    gradient: ['#57F287', '#248046'],
  },
  {
    icon: 'person-circle',
    title: 'Custom Profiles',
    description: 'Stand out with animated avatars, banners, and themes.',
    gradient: ['#EB459E', '#FE73B1'],
  },
  {
    icon: 'rocket',
    title: 'Server Boosts',
    description: '2 free boosts to level up your favorite servers.',
    gradient: ['#F47FFF', '#C472ED'],
  },
  {
    icon: 'sparkles',
    title: 'Early Access',
    description: 'Be the first to try upcoming Flicko features.',
    gradient: ['#5865F2', '#EB459E'],
  },
];

type BillingCycle = 'monthly' | 'yearly';

// Map local plan IDs to Stripe plan IDs
const PLAN_TO_STRIPE: Record<string, SubscriptionPlan> = {
  basic: 'basic',
  plus: 'plus',
};

export default function FlickoPlusScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors: c } = useTheme();
  const [selectedPlan, setSelectedPlan] = useState<'basic' | 'plus'>('plus');
  const [billing, setBilling] = useState<BillingCycle>('monthly');

  const {
    subscription,
    isNitro,
    plan: currentStorePlan,
    isPurchasing,
    setSubscription,
    setEntitlements,
    setPurchasing,
    setLoading: setStoreLoading,
  } = useSubscriptionStore();

  // Load current subscription on mount and initialize Stripe
  useEffect(() => {
    (async () => {
      // Initialize Stripe SDK
      await initializeStripe();
      
      setStoreLoading(true);
      try {
        const sub = await fetchStripeSubscription();
        if (sub) {
          // Convert Stripe plan to store format
          setSubscription({
            id: sub.id,
            user_id: '', // Will be filled from auth
            plan: sub.plan === 'plus' ? 'nitro_full' : 'nitro_basic',
            status: sub.status === 'active' ? 'active' : 'canceled',
            store: 'stripe',
            current_period_start: new Date().toISOString(),
            current_period_end: sub.currentPeriodEnd,
            cancel_at_period_end: sub.cancelAtPeriodEnd,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          });
        }
      } finally {
        setStoreLoading(false);
      }
    })();
  }, []);

  const handleSubscribe = useCallback(async () => {
    const stripePlan = PLAN_TO_STRIPE[selectedPlan];
    if (!stripePlan) return;
    
    setPurchasing(true);
    try {
      const result = await purchaseSubscriptionWithStripe(
        billing === 'yearly' ? `${stripePlan}_yearly` as SubscriptionPlan : stripePlan
      );
      
      if (result.success) {
        // Refresh subscription
        const sub = await fetchStripeSubscription();
        if (sub) {
          setSubscription({
            id: sub.id,
            user_id: '',
            plan: sub.plan === 'plus' ? 'nitro_full' : 'nitro_basic',
            status: 'active',
            store: 'stripe',
            current_period_start: new Date().toISOString(),
            current_period_end: sub.currentPeriodEnd,
            cancel_at_period_end: sub.cancelAtPeriodEnd,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          });
        }
        
        Alert.alert(
          'Success!', 
          `You're now subscribed to ${selectedPlan === 'plus' ? 'Flicko Plus' : 'Flicko Basic'}!`,
          [{ text: 'Awesome!', onPress: () => router.back() }]
        );
      } else {
        Alert.alert('Payment Failed', result.error || 'Please try again.');
      }
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to subscribe');
    } finally {
      setPurchasing(false);
    }
  }, [selectedPlan, billing]);

  const handleCancel = useCallback(async () => {
    Alert.alert(
      'Cancel Subscription',
      'Your subscription will remain active until the end of the current billing period.',
      [
        { text: 'Keep Subscription', style: 'cancel' },
        {
          text: 'Cancel',
          style: 'destructive',
          onPress: async () => {
            try {
              const success = await cancelStripeSubscription();
              if (success) {
                const sub = await fetchStripeSubscription();
                if (sub) {
                  setSubscription({
                    id: sub.id,
                    user_id: '',
                    plan: sub.plan === 'plus' ? 'nitro_full' : 'nitro_basic',
                    status: sub.status,
                    store: 'stripe',
                    current_period_start: new Date().toISOString(),
                    current_period_end: sub.currentPeriodEnd,
                    cancel_at_period_end: true,
                    created_at: new Date().toISOString(),
                    updated_at: new Date().toISOString(),
                  });
                }
                Alert.alert('Cancelled', 'Your subscription will expire at the end of the billing period.');
              } else {
                Alert.alert('Error', 'Failed to cancel subscription. Please try again.');
              }
            } catch (err: any) {
              Alert.alert('Error', err.message ?? 'Failed to cancel');
            }
          },
        },
      ]
    );
  }, []);

  const handleRestore = useCallback(async () => {
    setStoreLoading(true);
    try {
      const sub = await restoreStripePurchases();
      if (sub) {
        setSubscription({
          id: sub.id,
          user_id: '',
          plan: sub.plan === 'plus' ? 'nitro_full' : 'nitro_basic',
          status: sub.status,
          store: 'stripe',
          current_period_start: new Date().toISOString(),
          current_period_end: sub.currentPeriodEnd,
          cancel_at_period_end: sub.cancelAtPeriodEnd,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
        Alert.alert('Restored', 'Your subscription has been restored!');
      } else {
        Alert.alert('No Subscription', 'No active subscription found.');
      }
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to restore');
    } finally {
      setStoreLoading(false);
    }
  }, []);

  // Is the currently selected plan the active one?
  const isCurrentPlanActive = isNitro && currentStorePlan === (selectedPlan === 'plus' ? 'nitro_full' : 'nitro_basic');

  const plan = PLANS.find((p) => p.id === selectedPlan)!;
  const price = billing === 'monthly' ? plan.monthlyPrice : plan.yearlyPrice;

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: false,
          animation: 'slide_from_bottom',
        }}
      />
      <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
        {/* Hero Header */}
        <LinearGradient
          colors={['#5865F2', '#EB459E', '#FEE75C']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.hero, { paddingTop: insets.top + 8 }]}
        >
          {/* Close button */}
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={styles.closeBtn}
          >
            <Ionicons name="close" size={26} color="#fff" />
          </Pressable>

          <View style={styles.heroContent}>
            <Ionicons name="diamond" size={48} color="#fff" />
            <Text style={styles.heroTitle}>Flicko Plus</Text>
            <Text style={styles.heroSubtitle}>
              Unlock the best of Flicko with premium features
            </Text>
          </View>
        </LinearGradient>

        <ScrollView
          contentContainerStyle={{ paddingBottom: insets.bottom + 100 }}
          showsVerticalScrollIndicator={false}
        >
          {/* Active Subscription Banner */}
          {isNitro && subscription && (
            <View style={[styles.activeBanner, { backgroundColor: '#5865F220', borderColor: '#5865F2' }]}>
              <Ionicons name="checkmark-circle" size={20} color="#5865F2" />
              <View style={{ flex: 1 }}>
                <Text style={[styles.activeBannerTitle, { color: c.textPrimary }]}>
                  {currentStorePlan === 'nitro_full' ? 'Flicko Plus' : 'Flicko Basic'} Active
                </Text>
                <Text style={[styles.activeBannerSub, { color: c.textMuted }]}>
                  Renews {new Date(subscription.current_period_end).toLocaleDateString()}
                  {subscription.cancel_at_period_end ? ' (cancelling)' : ''}
                </Text>
              </View>
              <Pressable onPress={handleCancel}>
                <Text style={{ color: '#ED4245', fontSize: 13, fontFamily: 'gg-sans-semibold' }}>Cancel</Text>
              </Pressable>
            </View>
          )}
          {/* Plan Selector Tabs */}
          <View style={[styles.planTabs, { backgroundColor: c.bgSecondary }]}>
            {PLANS.map((p) => {
              const active = selectedPlan === p.id;
              return (
                <Pressable
                  key={p.id}
                  style={[
                    styles.planTab,
                    active && styles.planTabActive,
                    active && { borderColor: '#5865F2' },
                    { backgroundColor: active ? c.bgTertiary : 'transparent' },
                  ]}
                  onPress={() => setSelectedPlan(p.id)}
                >
                  <LinearGradient
                    colors={p.gradient}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.planTabIcon}
                  >
                    <Ionicons name={p.icon} size={16} color="#fff" />
                  </LinearGradient>
                  <Text
                    style={[
                      styles.planTabName,
                      { color: active ? c.textPrimary : c.textSecondary },
                    ]}
                  >
                    {p.name}
                  </Text>
                  {active && (
                    <Ionicons name="checkmark-circle" size={18} color="#5865F2" />
                  )}
                </Pressable>
              );
            })}
          </View>

          {/* Billing Toggle */}
          <View style={[styles.billingToggle, { backgroundColor: c.bgSecondary }]}>
            {(['monthly', 'yearly'] as BillingCycle[]).map((cycle) => {
              const active = billing === cycle;
              return (
                <Pressable
                  key={cycle}
                  style={[
                    styles.billingOption,
                    active && { backgroundColor: c.accentPrimary },
                  ]}
                  onPress={() => setBilling(cycle)}
                >
                  <Text
                    style={[
                      styles.billingText,
                      { color: active ? '#fff' : c.textSecondary },
                    ]}
                  >
                    {cycle === 'monthly' ? 'Monthly' : 'Yearly'}
                  </Text>
                  {cycle === 'yearly' && (
                    <View style={styles.saveBadge}>
                      <Text style={styles.saveBadgeText}>{plan.yearlySaving}</Text>
                    </View>
                  )}
                </Pressable>
              );
            })}
          </View>

          {/* Price Card */}
          <View style={[styles.priceCard, { backgroundColor: c.bgSecondary }]}>
            <LinearGradient
              colors={plan.gradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.priceGradientBar}
            />
            <View style={styles.priceInner}>
              <View style={styles.priceRow}>
                <View>
                  <Text style={[styles.planName, { color: c.textPrimary }]}>{plan.name}</Text>
                  <Text style={[styles.planTagline, { color: c.textSecondary }]}>
                    {plan.tagline}
                  </Text>
                </View>
                <View style={styles.priceBlock}>
                  <Text style={[styles.priceAmount, { color: c.textPrimary }]}>{price}</Text>
                  <Text style={[styles.pricePeriod, { color: c.textMuted }]}>
                    /{billing === 'monthly' ? 'mo' : 'yr'}
                  </Text>
                </View>
              </View>
            </View>
          </View>

          {/* Features List */}
          <Text style={[styles.sectionTitle, { color: c.textMuted }]}>WHAT YOU GET</Text>
          <View style={[styles.featuresCard, { backgroundColor: c.bgSecondary }]}>
            {plan.features.map((feat, i) => (
              <View
                key={i}
                style={[
                  styles.featureRow,
                  i < plan.features.length - 1 && {
                    borderBottomWidth: StyleSheet.hairlineWidth,
                    borderBottomColor: c.border,
                  },
                ]}
              >
                <Ionicons
                  name={feat.included ? 'checkmark-circle' : 'close-circle'}
                  size={20}
                  color={feat.included ? '#57F287' : c.textMuted}
                />
                <Text
                  style={[
                    styles.featureText,
                    {
                      color: feat.included ? c.textPrimary : c.textMuted,
                      textDecorationLine: feat.included ? 'none' : 'line-through',
                    },
                  ]}
                >
                  {feat.text}
                </Text>
              </View>
            ))}
          </View>

          {/* Perks Showcase */}
          <Text style={[styles.sectionTitle, { color: c.textMuted }]}>WHY GO PREMIUM</Text>
          <View style={styles.perksGrid}>
            {PERKS.map((perk, i) => (
              <View
                key={i}
                style={[styles.perkCard, { backgroundColor: c.bgSecondary }]}
              >
                <LinearGradient
                  colors={perk.gradient}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.perkIconWrap}
                >
                  <Ionicons name={perk.icon} size={22} color="#fff" />
                </LinearGradient>
                <Text style={[styles.perkTitle, { color: c.textPrimary }]}>
                  {perk.title}
                </Text>
                <Text style={[styles.perkDesc, { color: c.textSecondary }]}>
                  {perk.description}
                </Text>
              </View>
            ))}
          </View>

          {/* FAQ / note */}
          <View style={[styles.faqCard, { backgroundColor: c.bgSecondary }]}>
            <Ionicons name="information-circle-outline" size={20} color={c.textMuted} />
            <Text style={[styles.faqText, { color: c.textSecondary }]}>
              Subscriptions are managed through your app store. You can cancel
              anytime from your device settings.
            </Text>
          </View>

          {/* Restore Purchases */}
          <Pressable style={styles.restoreBtn} onPress={handleRestore}>
            <Text style={{ color: c.accentPrimary, fontSize: 14, fontFamily: 'gg-sans-semibold' }}>
              Restore Purchases
            </Text>
          </Pressable>

          {/* Dev badge */}
          <View style={[styles.devBadge, { backgroundColor: '#FAA61A20', borderColor: '#FAA61A' }]}>
            <Ionicons name="construct" size={14} color="#FAA61A" />
            <Text style={{ color: '#FAA61A', fontSize: 12 }}>
              Dev Mode — No real charges. Subscriptions are mocked.
            </Text>
          </View>
        </ScrollView>

        {/* Floating Subscribe Button */}
        <View
          style={[
            styles.bottomBar,
            {
              paddingBottom: insets.bottom + 12,
              backgroundColor: c.bgPrimary,
              borderTopColor: c.border,
            },
          ]}
        >
          <Pressable
            style={({ pressed }) => [
              styles.subscribeBtn,
              pressed && { opacity: 0.85 },
              (isPurchasing || isCurrentPlanActive) && { opacity: 0.6 },
            ]}
            onPress={handleSubscribe}
            disabled={isPurchasing || isCurrentPlanActive}
          >
            <LinearGradient
              colors={plan.gradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.subscribeBtnGradient}
            >
              {isPurchasing ? (
                <ActivityIndicator color="#fff" size="small" />
              ) : (
                <>
                  <Ionicons name="diamond" size={18} color="#fff" style={{ marginRight: 8 }} />
                  <Text style={styles.subscribeBtnText}>
                    {isCurrentPlanActive ? 'Current Plan' : `Subscribe — ${price}/${billing === 'monthly' ? 'month' : 'year'}`}
                  </Text>
                </>
              )}
            </LinearGradient>
          </Pressable>
        </View>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },

  /* ─── Hero ─── */
  hero: {
    paddingBottom: 28,
    alignItems: 'center',
  },
  closeBtn: {
    position: 'absolute',
    top: 52,
    left: 16,
    zIndex: 10,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.25)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroContent: {
    alignItems: 'center',
    paddingTop: 40,
    gap: 8,
  },
  heroTitle: {
    color: '#fff',
    fontSize: 28,
    fontFamily: 'gg-sans-bold',
    letterSpacing: -0.5,
  },
  heroSubtitle: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 15,
    textAlign: 'center',
    paddingHorizontal: 32,
    lineHeight: 21,
  },

  /* ─── Plan Tabs ─── */
  planTabs: {
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  planTab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 14,
    gap: 12,
  },
  planTabActive: {
    borderLeftWidth: 3,
  },
  planTabIcon: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  planTabName: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
    flex: 1,
  },

  /* ─── Billing Toggle ─── */
  billingToggle: {
    marginHorizontal: spacing.md,
    marginTop: spacing.sm,
    borderRadius: borderRadius.md,
    flexDirection: 'row',
    padding: 4,
    gap: 4,
  },
  billingOption: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    borderRadius: borderRadius.sm,
    gap: 6,
  },
  billingText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  saveBadge: {
    backgroundColor: '#57F287',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 8,
  },
  saveBadgeText: {
    color: '#000',
    fontSize: 10,
    fontFamily: 'gg-sans-bold',
  },

  /* ─── Price Card ─── */
  priceCard: {
    marginHorizontal: spacing.md,
    marginTop: spacing.sm,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  priceGradientBar: {
    height: 4,
  },
  priceInner: {
    padding: spacing.lg,
  },
  priceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  planName: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  planTagline: {
    fontSize: 13,
    marginTop: 2,
  },
  priceBlock: {
    alignItems: 'flex-end',
  },
  priceAmount: {
    fontSize: 26,
    fontFamily: 'gg-sans-bold',
  },
  pricePeriod: {
    fontSize: 12,
    marginTop: -2,
  },

  /* ─── Features ─── */
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    paddingBottom: spacing.sm,
  },
  featuresCard: {
    marginHorizontal: spacing.md,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
    gap: 12,
  },
  featureText: {
    fontSize: 14,
    flex: 1,
  },

  /* ─── Perks Grid ─── */
  perksGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  perkCard: {
    width: (SCREEN_WIDTH - spacing.md * 2 - spacing.sm) / 2,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    gap: 8,
  },
  perkIconWrap: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  perkTitle: {
    fontSize: 14,
    fontFamily: 'gg-sans-bold',
  },
  perkDesc: {
    fontSize: 12,
    lineHeight: 17,
  },

  /* ─── FAQ ─── */
  faqCard: {
    marginHorizontal: spacing.md,
    marginTop: spacing.lg,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    flexDirection: 'row',
    gap: 10,
    alignItems: 'flex-start',
  },
  faqText: {
    fontSize: 12,
    lineHeight: 18,
    flex: 1,
  },

  /* ─── Active Banner ─── */
  activeBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    gap: 10,
  },
  activeBannerTitle: {
    fontSize: 14,
    fontFamily: 'gg-sans-bold',
  },
  activeBannerSub: {
    fontSize: 12,
    marginTop: 2,
  },

  /* ─── Restore + Dev ─── */
  restoreBtn: {
    alignItems: 'center',
    paddingVertical: spacing.lg,
  },
  devBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginHorizontal: spacing.md,
    padding: spacing.sm,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    marginBottom: spacing.md,
  },

  /* ─── Bottom Subscribe Bar ─── */
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingTop: 12,
    paddingHorizontal: spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  subscribeBtn: {
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  subscribeBtnGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
  },
  subscribeBtnText: {
    color: '#fff',
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
  },
});
