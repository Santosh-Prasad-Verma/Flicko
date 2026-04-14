/**
 * BotSettingsScreen — Reusable bot settings shell component.
 *
 * Renders a header, enable/disable toggle, and children slots for
 * bot-specific settings fields. Used by each bot-<name>.tsx screen.
 */
import React, { ReactNode } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface BotSettingsScreenProps {
  title: string;
  emoji: string;
  description: string;
  enabled: boolean;
  onToggle: (value: boolean) => void;
  isLoading: boolean;
  children: ReactNode;
}

export function BotSettingsScreen({
  title,
  emoji,
  description,
  enabled,
  onToggle,
  isLoading,
  children,
}: BotSettingsScreenProps) {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      <Stack.Screen options={{ headerShown: false }} />

      {/* Header */}
      <View
        style={[
          styles.header,
          { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgPrimary },
        ]}
      >
        <Pressable style={styles.backButton} onPress={() => router.back()} hitSlop={8}>
          <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
        </Pressable>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
          {emoji} {title}
        </Text>
        <View style={{ width: 40 }} />
      </View>

      {isLoading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={[
            styles.scroll,
            { paddingBottom: insets.bottom + spacing.xxxl },
          ]}
          showsVerticalScrollIndicator={false}
        >
          {/* Enable Toggle */}
          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
            <View style={styles.row}>
              <View style={{ flex: 1 }}>
                <Text style={[styles.label, { color: themeColors.textPrimary }]}>
                  Enable {title}
                </Text>
                <Text style={[styles.hint, { color: themeColors.textMuted }]}>
                  {description}
                </Text>
              </View>
              <Switch
                value={enabled}
                onValueChange={onToggle}
                trackColor={{
                  false: themeColors.bgTertiary,
                  true: themeColors.accentPrimary + '80',
                }}
                thumbColor={enabled ? themeColors.accentPrimary : themeColors.textMuted}
              />
            </View>
          </View>

          {/* Bot-specific settings */}
          {enabled && children}
        </ScrollView>
      )}
    </View>
  );
}

// ── Section & Field Components ──────────────────────────────────────────────

export function SettingsSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  const { themeColors } = useTheme();
  return (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
        {title}
      </Text>
      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        {children}
      </View>
    </View>
  );
}

export function ToggleField({
  label,
  hint,
  value,
  onValueChange,
}: {
  label: string;
  hint?: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
}) {
  const { themeColors } = useTheme();
  return (
    <View style={styles.fieldRow}>
      <View style={{ flex: 1 }}>
        <Text style={[styles.label, { color: themeColors.textPrimary }]}>{label}</Text>
        {hint && (
          <Text style={[styles.hint, { color: themeColors.textMuted }]}>{hint}</Text>
        )}
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{
          false: themeColors.bgTertiary,
          true: themeColors.accentPrimary + '80',
        }}
        thumbColor={value ? themeColors.accentPrimary : themeColors.textMuted}
      />
    </View>
  );
}

export function InfoField({
  label,
  value,
}: {
  label: string;
  value: string | number;
}) {
  const { themeColors } = useTheme();
  return (
    <View style={styles.fieldRow}>
      <Text style={[styles.label, { color: themeColors.textPrimary }]}>{label}</Text>
      <Text style={[styles.fieldValue, { color: themeColors.textMuted }]}>
        {String(value)}
      </Text>
    </View>
  );
}

// ── Styles ──────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
  },
  backButton: {
    width: 40,
    height: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
  },
  headerTitle: { ...typography.headingM },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  scroll: {
    paddingHorizontal: spacing.lg,
    gap: spacing.md,
  },
  card: {
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  section: { gap: spacing.sm },
  sectionTitle: {
    ...typography.overline,
    paddingLeft: spacing.sm,
  },
  fieldRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
    gap: spacing.md,
  },
  label: { ...typography.body },
  hint: { ...typography.bodySmall, marginTop: 2 },
  fieldValue: { ...typography.body },
});
