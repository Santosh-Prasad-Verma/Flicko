/**
 * Appearance Settings Screen
 *
 * Mirrors web UserSettingsModal "Appearance" tab.
 * Theme selection (dark/light/amoled/auto), font size, message display.
 * All changes persist via useSettingsStore.
 * Route: /settings/appearance
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

type Theme = 'dark' | 'light' | 'amoled' | 'auto';
type MessageDisplay = 'cozy' | 'compact';

export default function AppearanceSettingsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  // Read from persistent store
  const currentTheme = useSettingsStore((s) => s.theme);
  const currentFontSize = useSettingsStore((s) => s.fontSize);
  const currentMessageDisplay = useSettingsStore((s) => s.messageDisplay);

  // Store actions
  const setTheme = useSettingsStore((s) => s.setTheme);
  const setFontSize = useSettingsStore((s) => s.setFontSize);
  const setMessageDisplay = useSettingsStore((s) => s.setMessageDisplay);

  const themes: { value: Theme; label: string; description: string; icon: keyof typeof Ionicons.glyphMap }[] = [
    { value: 'auto', label: 'Auto', description: 'Follows system setting', icon: 'phone-portrait-outline' },
    { value: 'dark', label: 'Dark', description: 'Default dark theme', icon: 'moon-outline' },
    { value: 'light', label: 'Light', description: 'Classic light mode', icon: 'sunny-outline' },
    { value: 'amoled', label: 'AMOLED Dark', description: 'True black for OLED screens', icon: 'contrast-outline' },
  ];

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Appearance',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
      >
        {/* Theme */}
        <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>THEME</Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {themes.map((t, i) => (
            <Pressable
              key={t.value}
              style={[
                styles.themeRow,
                i < themes.length - 1 && {
                  borderBottomWidth: StyleSheet.hairlineWidth,
                  borderBottomColor: themeColors.border,
                },
              ]}
              onPress={() => setTheme(t.value)}
            >
              <Ionicons name={t.icon} size={20} color={currentTheme === t.value ? themeColors.accentPrimary : themeColors.textMuted} style={{ marginRight: spacing.sm }} />
              <View style={styles.themeInfo}>
                <Text style={[styles.themeLabel, { color: themeColors.textPrimary }]}>
                  {t.label}
                </Text>
                <Text style={[styles.themeDesc, { color: themeColors.textMuted }]}>
                  {t.description}
                </Text>
              </View>
              <View
                style={[
                  styles.radio,
                  {
                    borderColor: currentTheme === t.value ? themeColors.accentPrimary : themeColors.textMuted,
                  },
                ]}
              >
                {currentTheme === t.value && (
                  <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>
          ))}
        </View>

        {/* Message Display */}
        <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>
          MESSAGE DISPLAY
        </Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {(['cozy', 'compact'] as const).map((mode, i) => (
            <Pressable
              key={mode}
              style={[
                styles.themeRow,
                i === 0 && {
                  borderBottomWidth: StyleSheet.hairlineWidth,
                  borderBottomColor: themeColors.border,
                },
              ]}
              onPress={() => setMessageDisplay(mode)}
            >
              <Ionicons
                name={mode === 'cozy' ? 'chatbubbles-outline' : 'list-outline'}
                size={20}
                color={currentMessageDisplay === mode ? themeColors.accentPrimary : themeColors.textMuted}
                style={{ marginRight: spacing.sm }}
              />
              <View style={styles.themeInfo}>
                <Text style={[styles.themeLabel, { color: themeColors.textPrimary }]}>
                  {mode === 'cozy' ? 'Cozy' : 'Compact'}
                </Text>
                <Text style={[styles.themeDesc, { color: themeColors.textMuted }]}>
                  {mode === 'cozy'
                    ? 'Modern with avatar display'
                    : 'Condensed for more messages'}
                </Text>
              </View>
              <View
                style={[
                  styles.radio,
                  {
                    borderColor:
                      currentMessageDisplay === mode ? themeColors.accentPrimary : themeColors.textMuted,
                  },
                ]}
              >
                {currentMessageDisplay === mode && (
                  <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>
          ))}
        </View>

        {/* Font Size */}
        <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>
          CHAT FONT SIZE
        </Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={styles.fontSizeRow}>
            <Text style={[{ color: themeColors.textMuted, fontSize: 12 }]}>A</Text>
            <View style={styles.fontSizeSlider}>
              {[14, 15, 16, 17, 18].map((size) => (
                <Pressable
                  key={size}
                  style={[
                    styles.fontSizeOption,
                    {
                      backgroundColor:
                        currentFontSize === size
                          ? themeColors.accentPrimary
                          : themeColors.bgTertiary,
                    },
                  ]}
                  onPress={() => setFontSize(size)}
                >
                  <Text
                    style={{
                      color: currentFontSize === size ? '#fff' : themeColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'gg-sans-semibold',
                    }}
                  >
                    {size}
                  </Text>
                </Pressable>
              ))}
            </View>
            <Text style={[{ color: themeColors.textMuted, fontSize: 18 }]}>A</Text>
          </View>
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  sectionHeader: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginHorizontal: spacing.md + spacing.sm,
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: 12,
    overflow: 'hidden',
  },
  themeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  themeInfo: {
    flex: 1,
  },
  themeLabel: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  themeDesc: {
    ...typography.caption,
    marginTop: 2,
  },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  radioInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  fontSizeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    gap: spacing.sm,
  },
  fontSizeSlider: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  fontSizeOption: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
