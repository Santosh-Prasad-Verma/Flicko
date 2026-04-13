/**
 * Onboarding Settings Screen
 *
 * Configure welcome screen, default channels, rules and onboarding prompts.
 * Route: /server/[serverId]/settings/onboarding
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Alert,
  Switch,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import {
  getOnboardingConfig,
  updateOnboardingConfig,
  type OnboardingConfig,
} from '@services/onboardingService';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function OnboardingScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: config, isLoading } = useQuery({
    queryKey: ['onboarding', serverId],
    queryFn: () => getOnboardingConfig(serverId!),
    enabled: !!serverId,
  });

  const [enabled, setEnabled] = useState(false);
  const [welcomeTitle, setWelcomeTitle] = useState('');
  const [welcomeDescription, setWelcomeDescription] = useState('');
  const [rules, setRules] = useState<string[]>([]);
  const [requireRules, setRequireRules] = useState(false);
  const [newRule, setNewRule] = useState('');
  const [hasChanges, setHasChanges] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false);

  useEffect(() => {
    if (config) {
      setEnabled(config.enabled);
      setWelcomeTitle(config.welcome_title || '');
      setWelcomeDescription(config.welcome_description || '');
      setRules(config.rules || []);
      setRequireRules(config.require_rules_acceptance);
    }
  }, [config]);

  const saveMutation = useMutation({
    mutationFn: () =>
      updateOnboardingConfig(serverId!, {
        enabled,
        welcome_title: welcomeTitle.trim(),
        welcome_description: welcomeDescription.trim() || null,
        rules,
        require_rules_acceptance: requireRules,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['onboarding', serverId] });
      setHasChanges(false);
      Alert.alert('Saved', 'Onboarding settings updated.');
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  const addRule = useCallback(() => {
    if (!newRule.trim()) return;
    setRules((prev) => [...prev, newRule.trim()]);
    setNewRule('');
    setHasChanges(true);
  }, [newRule]);

  const removeRule = useCallback((index: number) => {
    setRules((prev) => prev.filter((_, i) => i !== index));
    setHasChanges(true);
  }, []);

  const markChanged = () => setHasChanges(true);

  if (isLoading) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary, justifyContent: 'center', alignItems: 'center' }]}>
        <ActivityIndicator size="large" color={themeColors.accentPrimary} />
      </View>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Onboarding</Text>
          <Pressable
            onPress={() => saveMutation.mutate()}
            disabled={!hasChanges || saveMutation.isPending}
            style={[styles.saveBtn, { opacity: hasChanges ? 1 : 0.4 }]}
          >
            {saveMutation.isPending ? (
              <ActivityIndicator size="small" color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.saveText, { color: themeColors.accentPrimary }]}>Save</Text>
            )}
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={{ padding: spacing.lg, paddingBottom: insets.bottom + 40 }}>
          {/* Enable toggle */}
          <View style={[styles.toggleRow, { backgroundColor: themeColors.bgSecondary }]}>
            <View style={styles.toggleInfo}>
              <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>Enable Onboarding</Text>
              <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
                Show a welcome screen to new members
              </Text>
            </View>
            <Switch
              value={enabled}
              onValueChange={(v) => { setEnabled(v); markChanged(); }}
            />
          </View>

          {enabled && (
            <>
              {/* Welcome Title */}
              <Text style={[styles.label, { color: themeColors.textMuted }]}>WELCOME TITLE</Text>
              <TextInput
                value={welcomeTitle}
                onChangeText={(v) => { setWelcomeTitle(v); markChanged(); }}
                maxLength={100}
                placeholder="Welcome to our server!"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgSecondary }]}
              />

              {/* Welcome Description */}
              <Text style={[styles.label, { color: themeColors.textMuted }]}>DESCRIPTION</Text>
              <TextInput
                value={welcomeDescription}
                onChangeText={(v) => { setWelcomeDescription(v); markChanged(); }}
                maxLength={300}
                multiline
                numberOfLines={3}
                placeholder="Tell new members about your server"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, styles.multiline, { color: themeColors.textPrimary, backgroundColor: themeColors.bgSecondary }]}
              />

              {/* Rules */}
              <Text style={[styles.label, { color: themeColors.textMuted }]}>SERVER RULES</Text>
              {rules.map((rule, index) => (
                <View key={index} style={[styles.ruleRow, { backgroundColor: themeColors.bgSecondary }]}>
                  <Text style={[styles.ruleNumber, { color: themeColors.accentPrimary }]}>
                    {index + 1}.
                  </Text>
                  <Text style={[styles.ruleText, { color: themeColors.textPrimary }]}>
                    {rule}
                  </Text>
                  <Pressable onPress={() => removeRule(index)} hitSlop={8}>
                    <Ionicons name="close-circle" size={18} color={themeColors.danger} />
                  </Pressable>
                </View>
              ))}

              <View style={styles.addRuleRow}>
                <TextInput
                  value={newRule}
                  onChangeText={setNewRule}
                  placeholder="Add a rule..."
                  placeholderTextColor={themeColors.textMuted}
                  style={[styles.ruleInput, { color: themeColors.textPrimary, backgroundColor: themeColors.bgSecondary }]}
                  onSubmitEditing={addRule}
                  returnKeyType="done"
                />
                <Pressable
                  onPress={addRule}
                  disabled={!newRule.trim()}
                  style={[styles.addRuleBtn, { backgroundColor: themeColors.accentPrimary, opacity: newRule.trim() ? 1 : 0.4 }]}
                >
                  <Ionicons name="add" size={20} color="#fff" />
                </Pressable>
              </View>

              {/* Require rules acceptance */}
              <View style={[styles.toggleRow, { backgroundColor: themeColors.bgSecondary, marginTop: spacing.lg }]}>
                <View style={styles.toggleInfo}>
                  <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>
                    Require Rules Acceptance
                  </Text>
                  <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
                    Members must accept rules before participating
                  </Text>
                </View>
                <Switch
                  value={requireRules}
                  onValueChange={(v) => { setRequireRules(v); markChanged(); }}
                />
              </View>
            </>
          )}

          {/* Preview */}
          {enabled && (
            <Pressable
              onPress={() => setPreviewOpen(true)}
              style={[styles.previewCard, { backgroundColor: themeColors.bgSecondary }]}
            >
              <Ionicons name="eye-outline" size={20} color={themeColors.accentPrimary} />
              <View style={styles.previewInfo}>
                <Text style={[styles.previewTitle, { color: themeColors.textPrimary }]}>Preview welcome screen</Text>
                <Text style={[styles.previewDesc, { color: themeColors.textMuted }]}>
                  Tap to see how new members will see onboarding before they join channels.
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </ScrollView>

        <Modal visible={previewOpen} animationType="slide" transparent onRequestClose={() => setPreviewOpen(false)}>
          <View style={styles.previewModalOverlay}>
            <View style={[styles.previewModalCard, { backgroundColor: themeColors.bgSecondary }]}>
              <Text style={[styles.previewModalTitle, { color: themeColors.textPrimary }]}>
                {welcomeTitle.trim() || 'Welcome'}
              </Text>
              <ScrollView style={styles.previewModalScroll} showsVerticalScrollIndicator>
                {!!welcomeDescription.trim() && (
                  <Text style={[styles.previewModalBody, { color: themeColors.textSecondary }]}>
                    {welcomeDescription.trim()}
                  </Text>
                )}
                {rules.length > 0 && (
                  <>
                    <Text style={[styles.previewRulesHeading, { color: themeColors.textMuted }]}>RULES</Text>
                    {rules.map((rule, i) => (
                      <Text key={i} style={[styles.previewRuleLine, { color: themeColors.textPrimary }]}>
                        {i + 1}. {rule}
                      </Text>
                    ))}
                  </>
                )}
                {requireRules && (
                  <Text style={[styles.previewFootnote, { color: themeColors.accentPrimary }]}>
                    Members must accept these rules before participating.
                  </Text>
                )}
              </ScrollView>
              <Pressable
                style={[styles.previewCloseBtn, { backgroundColor: themeColors.accentPrimary }]}
                onPress={() => setPreviewOpen(false)}
              >
                <Text style={styles.previewCloseBtnText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      </View>
    </>
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
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  saveBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveText: { fontSize: 16, fontFamily: 'gg-sans-semibold' },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.lg,
  },
  toggleInfo: { flex: 1 },
  toggleLabel: { fontSize: 15, fontFamily: 'gg-sans-semibold' },
  toggleDesc: { fontSize: 12, marginTop: 2 },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
    marginTop: spacing.md,
  },
  input: {
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
  multiline: {
    minHeight: 80,
    textAlignVertical: 'top',
  },
  ruleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.xs,
    gap: spacing.sm,
  },
  ruleNumber: { fontSize: 14, fontFamily: 'gg-sans-bold', width: 24 },
  ruleText: { flex: 1, fontSize: 14 },
  addRuleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  ruleInput: {
    flex: 1,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 14,
  },
  addRuleBtn: {
    width: MINIMUM_TOUCH_TARGET,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  previewCard: {
    flexDirection: 'row',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginTop: spacing.xl,
    gap: spacing.md,
  },
  previewInfo: { flex: 1 },
  previewTitle: { fontSize: 14, fontFamily: 'gg-sans-semibold' },
  previewDesc: { fontSize: 12, marginTop: 2, lineHeight: 18 },
  previewModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.65)',
    justifyContent: 'center',
    padding: spacing.lg,
  },
  previewModalCard: {
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
    maxHeight: '85%',
  },
  previewModalTitle: {
    fontSize: 22,
    fontFamily: 'gg-sans-bold',
    marginBottom: spacing.md,
  },
  previewModalScroll: { maxHeight: 360 },
  previewModalBody: { fontSize: 15, lineHeight: 22, marginBottom: spacing.md },
  previewRulesHeading: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginTop: spacing.sm,
    marginBottom: spacing.xs,
  },
  previewRuleLine: { fontSize: 14, marginBottom: spacing.xs, lineHeight: 20 },
  previewFootnote: { fontSize: 13, marginTop: spacing.md, fontFamily: 'gg-sans-semibold' },
  previewCloseBtn: {
    marginTop: spacing.lg,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    alignItems: 'center',
  },
  previewCloseBtnText: { color: '#fff', fontSize: 16, fontFamily: 'gg-sans-semibold' },
});
