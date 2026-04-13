/**
 * Language Settings
 * Route: /settings/language
 */
import React from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable } from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

const LANGUAGES = [
  { code: 'en', name: 'English', native: 'English' },
  { code: 'es', name: 'Spanish', native: 'Español' },
  { code: 'fr', name: 'French', native: 'Français' },
  { code: 'de', name: 'German', native: 'Deutsch' },
  { code: 'ja', name: 'Japanese', native: '日本語' },
  { code: 'ko', name: 'Korean', native: '한국어' },
  { code: 'zh', name: 'Chinese', native: '中文' },
  { code: 'pt', name: 'Portuguese', native: 'Português' },
  { code: 'ru', name: 'Russian', native: 'Русский' },
  { code: 'ar', name: 'Arabic', native: 'العربية' },
  { code: 'hi', name: 'Hindi', native: 'हिन्दी' },
];

export default function LanguageSettingsScreen() {
  const { themeColors } = useTheme();
  const selected = useSettingsStore((s) => s.language);
  const setLanguage = useSettingsStore((s) => s.setLanguage);

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Language',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>SELECT LANGUAGE</Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {LANGUAGES.map((lang, i) => (
            <Pressable
              key={lang.code}
              style={[
                styles.row,
                { borderBottomColor: themeColors.border },
                i === LANGUAGES.length - 1 && { borderBottomWidth: 0 },
              ]}
              onPress={() => setLanguage(lang.code)}
            >
              <View style={styles.rowInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>{lang.name}</Text>
                <Text style={[styles.rowNative, { color: themeColors.textMuted }]}>{lang.native}</Text>
              </View>
              {selected === lang.code && (
                <Ionicons name="checkmark-circle" size={22} color={themeColors.accentPrimary} />
              )}
            </Pressable>
          ))}
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: 12,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  rowInfo: { flex: 1 },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowNative: { ...typography.caption, marginTop: 2 },
});
