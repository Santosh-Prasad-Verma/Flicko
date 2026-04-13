/**
 * Server Onboarding Screen
 *
 * Welcome screen shown to new members — rules, default channels, prompts.
 * Requirements: Feature 24 (Server Onboarding)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useTheme } from '../../../hooks/useTheme';
import {
  OnboardingConfig,
  OnboardingPrompt,
  getOnboardingConfig,
  completeOnboarding,
  hasCompletedOnboarding,
} from '@services/onboardingService';
import { useAuthStore } from '@stores/authStore';

export default function OnboardingScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const userId = useAuthStore((s: any) => s.user?.id);
  const { themeColors: c } = useTheme();

  const [config, setConfig] = useState<OnboardingConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [step, setStep] = useState(0); // 0 = welcome, 1..n = prompts, last = done
  const [selectedOptions, setSelectedOptions] = useState<Record<string, string[]>>({});
  const [rulesAccepted, setRulesAccepted] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!serverId || !userId) return;
    (async () => {
      try {
        const done = await hasCompletedOnboarding(serverId, userId);
        if (done) { router.back(); return; }
        const cfg = await getOnboardingConfig(serverId);
        setConfig(cfg);
      } catch {}
      setLoading(false);
    })();
  }, [serverId, userId]);

  const totalSteps = config ? 1 + (config.prompts?.length ?? 0) + 1 : 1;
  const isLastStep = step === totalSteps - 1;

  const handleNext = useCallback(async () => {
    if (isLastStep) {
      if (!serverId || !userId) return;
      setSubmitting(true);
      try {
        await completeOnboarding(serverId, userId, selectedOptions);
        router.back();
      } catch {}
      setSubmitting(false);
    } else {
      setStep((s) => s + 1);
    }
  }, [isLastStep, serverId, userId, selectedOptions, step]);

  const toggleOption = (promptId: string, optionLabel: string) => {
    setSelectedOptions((prev) => {
      const current = prev[promptId] ?? [];
      const has = current.includes(optionLabel);
      return {
        ...prev,
        [promptId]: has ? current.filter((o) => o !== optionLabel) : [...current, optionLabel],
      };
    });
  };

  if (loading) {
    return (
      <View style={[styles.center, { backgroundColor: c.bgPrimary }]}>
        <Stack.Screen options={{ headerShown: false }} />
        <ActivityIndicator color={c.accentPrimary} />
      </View>
    );
  }

  if (!config || !config.enabled) {
    return (
      <View style={[styles.center, { backgroundColor: c.bgPrimary }]}>
        <Stack.Screen options={{ headerShown: false }} />
        <Text style={[styles.emptyText, { color: c.textSecondary }]}>No onboarding configured</Text>
        <Pressable onPress={() => router.back()} style={[styles.primaryBtn, { backgroundColor: c.accentPrimary }]}>
          <Text style={[styles.primaryBtnText, { color: c.textPrimary }]}>Continue</Text>
        </Pressable>
      </View>
    );
  }

  const currentPrompt: OnboardingPrompt | undefined = config.prompts?.[step - 1];

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen options={{ headerShown: false }} />

      <View
        style={[
          styles.header,
          {
            paddingTop: insets.top + spacing.sm,
            backgroundColor: c.bgSecondary,
            borderBottomColor: c.border,
          },
        ]}
      >
        <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.headerBtn, { backgroundColor: c.bgTertiary }]}> 
          <Ionicons name="arrow-back" size={22} color={c.textPrimary} />
        </Pressable>
        <Text style={[styles.headerTitle, { color: c.textPrimary }]}>Onboarding</Text>
        <View style={[styles.headerBtn, { backgroundColor: c.bgTertiary, opacity: 0 }]}> 
          <Ionicons name="arrow-back" size={22} color={c.textPrimary} />
        </View>
      </View>

      {/* Progress bar */}
      <View style={[styles.progressBar, { backgroundColor: c.border }]}>
        <View style={[styles.progressFill, { backgroundColor: c.accentPrimary, width: `${((step + 1) / totalSteps) * 100}%` }]} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {step === 0 ? (
          /* Welcome Step */
          <View style={styles.welcomeContainer}>
            <Ionicons name="sparkles" size={56} color={c.accentPrimary} />
            <Text style={[styles.welcomeTitle, { color: c.textPrimary }]}>{config.welcome_title || 'Welcome!'}</Text>
            {config.welcome_description && (
              <Text style={[styles.welcomeDesc, { color: c.textSecondary }]}>{config.welcome_description}</Text>
            )}

            {config.rules && config.rules.length > 0 && (
              <View style={[styles.rulesCard, { backgroundColor: c.bgSecondary }]}>
                <Text style={[styles.rulesTitle, { color: c.textPrimary }]}>Server Rules</Text>
                {config.rules.map((rule, i) => (
                  <View key={i} style={styles.ruleRow}>
                    <Text style={[styles.ruleNumber, { color: c.accentPrimary }]}>{i + 1}</Text>
                    <Text style={[styles.ruleText, { color: c.textSecondary }]}>{rule}</Text>
                  </View>
                ))}
                {config.require_rules_acceptance && (
                  <Pressable style={styles.acceptRow} onPress={() => setRulesAccepted(!rulesAccepted)}>
                    <Ionicons
                      name={rulesAccepted ? 'checkbox' : 'square-outline'}
                      size={22}
                      color={rulesAccepted ? c.accentPrimary : c.textMuted}
                    />
                    <Text style={[styles.acceptText, { color: c.textPrimary }]}>I agree to the server rules</Text>
                  </Pressable>
                )}
              </View>
            )}
          </View>
        ) : currentPrompt ? (
          /* Prompt Step */
          <View style={styles.promptContainer}>
            <Text style={[styles.promptTitle, { color: c.textPrimary }]}>{currentPrompt.title}</Text>
            <Text style={[styles.promptDesc, { color: c.textSecondary }]}>{currentPrompt.description}</Text>
            <View style={styles.optionsList}>
              {currentPrompt.options.map((opt, i) => {
                const selected = (selectedOptions[currentPrompt.id] ?? []).includes(opt.label);
                return (
                  <Pressable
                    key={i}
                    style={[styles.optionCard, { backgroundColor: selected ? c.bgTertiary : c.bgSecondary, borderColor: selected ? c.accentPrimary : c.border }]}
                    onPress={() => toggleOption(currentPrompt.id, opt.label)}
                  >
                    <Ionicons
                      name={selected ? 'checkmark-circle' : 'ellipse-outline'}
                      size={20}
                      color={selected ? c.accentPrimary : c.textMuted}
                    />
                    <Text style={[styles.optionLabel, { color: c.textPrimary }]}>{opt.label}</Text>
                  </Pressable>
                );
              })}
            </View>
          </View>
        ) : (
          /* Completion Step */
          <View style={styles.welcomeContainer}>
            <Ionicons name="checkmark-circle" size={56} color={c.success} />
            <Text style={[styles.welcomeTitle, { color: c.textPrimary }]}>You're all set!</Text>
            <Text style={[styles.welcomeDesc, { color: c.textSecondary }]}>Enjoy the server</Text>
          </View>
        )}
      </ScrollView>

      {/* Bottom Button */}
      <View style={styles.bottomBar}>
        {step > 0 && (
          <Pressable style={[styles.backBtn, { borderColor: c.border }]} onPress={() => setStep((s) => s - 1)}>
            <Text style={[styles.backBtnText, { color: c.textSecondary }]}>Back</Text>
          </Pressable>
        )}
        <Pressable
          style={[
            styles.primaryBtn,
            { backgroundColor: c.accentPrimary, flex: 1 },
            (step === 0 && config.require_rules_acceptance && !rulesAccepted) && { opacity: 0.5 },
          ]}
          onPress={handleNext}
          disabled={(step === 0 && config.require_rules_acceptance && !rulesAccepted) || submitting}
        >
          {submitting ? (
            <ActivityIndicator color={c.textPrimary} size="small" />
          ) : (
            <Text style={[styles.primaryBtnText, { color: c.textPrimary }]}>
              {isLastStep ? 'Finish' : 'Next'}
            </Text>
          )}
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  headerBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md },
  progressBar: { height: 3 },
  progressFill: { height: 3 },
  content: { flexGrow: 1, justifyContent: 'center', padding: spacing.xl },
  welcomeContainer: { alignItems: 'center', gap: spacing.md },
  welcomeTitle: { ...typography.headingXL, textAlign: 'center' },
  welcomeDesc: { ...typography.body, textAlign: 'center', maxWidth: 300 },
  rulesCard: { width: '100%', borderRadius: borderRadius.md, padding: spacing.lg, marginTop: spacing.md },
  rulesTitle: { ...typography.headingS, marginBottom: spacing.md },
  ruleRow: { flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.sm },
  ruleNumber: { ...typography.bodyBold, width: 24 },
  ruleText: { ...typography.bodySmall, flex: 1 },
  acceptRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.md, paddingTop: spacing.md, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.1)' },
  acceptText: { ...typography.bodySmall },
  promptContainer: { gap: spacing.md },
  promptTitle: { ...typography.headingL },
  promptDesc: { ...typography.body },
  optionsList: { gap: spacing.sm, marginTop: spacing.sm },
  optionCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: borderRadius.md, borderWidth: 1 },
  optionLabel: { ...typography.bodySmall, fontFamily: 'gg-sans-medium' },
  bottomBar: { flexDirection: 'row', padding: spacing.lg, gap: spacing.sm },
  backBtn: { borderWidth: 1, borderRadius: borderRadius.md, height: MINIMUM_TOUCH_TARGET, paddingHorizontal: spacing.xl, justifyContent: 'center', alignItems: 'center' },
  backBtnText: { ...typography.bodyBold },
  primaryBtn: { height: MINIMUM_TOUCH_TARGET, borderRadius: borderRadius.md, justifyContent: 'center', alignItems: 'center', paddingHorizontal: spacing.xl },
  primaryBtnText: { ...typography.bodyBold },
  emptyText: { ...typography.body },
});
