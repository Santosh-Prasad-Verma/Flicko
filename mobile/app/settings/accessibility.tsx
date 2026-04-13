/**
 * Accessibility Settings
 * Features: 4 (TTS toggle), store-backed reduce motion & high contrast
 * Route: /settings/accessibility
 */
import React from 'react';
import { View, Text, StyleSheet, Switch, ScrollView } from 'react-native';
import { Stack, router } from 'expo-router';
import { Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

export default function AccessibilitySettingsScreen() {
  const { themeColors } = useTheme();
  const accessibility = useSettingsStore((s) => s.accessibility);
  const updateAccessibility = useSettingsStore((s) => s.updateAccessibility);

  const sections = [
    {
      title: 'MOTION',
      items: [
        { label: 'Reduce Motion', description: 'Minimizes animations throughout the app', value: accessibility.reducedMotion, onToggle: () => updateAccessibility({ reducedMotion: !accessibility.reducedMotion }) },
      ],
    },
    {
      title: 'TEXT & DISPLAY',
      items: [
        { label: 'Increase Contrast', description: 'Higher contrast colors for readability', value: accessibility.highContrast, onToggle: () => updateAccessibility({ highContrast: !accessibility.highContrast }) },
      ],
    },
    {
      title: 'TEXT-TO-SPEECH',
      items: [
        { label: 'Allow TTS Messages', description: 'Play text-to-speech when /tts messages are received', value: accessibility.allowTTS, onToggle: () => updateAccessibility({ allowTTS: !accessibility.allowTTS }) },
      ],
    },
  ];

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Accessibility',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {sections.map((section) => (
          <View key={section.title}>
            <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>{section.title}</Text>
            <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
              {section.items.map((item, i) => (
                <View
                  key={item.label}
                  style={[
                    styles.toggleRow,
                    i < section.items.length - 1 && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border },
                  ]}
                >
                  <View style={styles.rowInfo}>
                    <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>{item.label}</Text>
                    <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>{item.description}</Text>
                  </View>
                  <Switch
                    value={item.value}
                    onValueChange={item.onToggle}
                    trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
                    thumbColor="#fff"
                  />
                </View>
              ))}
            </View>
          </View>
        ))}
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  sectionTitle: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', paddingHorizontal: spacing.md + spacing.sm, marginTop: spacing.lg, marginBottom: spacing.sm },
  card: { marginHorizontal: spacing.md, borderRadius: 12, overflow: 'hidden' },
  toggleRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, minHeight: MINIMUM_TOUCH_TARGET },
  rowInfo: { flex: 1, marginRight: spacing.md },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowDesc: { ...typography.caption, marginTop: 2 },
});
