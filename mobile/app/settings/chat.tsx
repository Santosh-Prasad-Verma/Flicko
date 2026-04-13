/**
 * Chat Settings
 *
 * Route: /settings/chat
 */
import React from 'react';
import { View, Text, StyleSheet, Switch, ScrollView, Pressable } from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

export default function ChatSettingsScreen() {
  const { themeColors } = useTheme();
  const chatPrefs = useSettingsStore((s) => s.chatPreferences);
  const updateChatPreferences = useSettingsStore((s) => s.updateChatPreferences);

  const sections = [
    {
      title: 'CHAT BEHAVIOR',
      items: [
        { label: 'Show Link Previews', description: 'Display inline previews for links', key: 'linkPreviews' as const },
        { label: 'Show Embeds', description: 'Display embedded content from links', key: 'embeds' as const },
        { label: 'Show Emoji Reactions', description: 'Display reactions on messages', key: 'emojiReactions' as const },
      ],
    },
    {
      title: 'MEDIA',
      items: [
        { label: 'Auto-play GIFs', description: 'Automatically play animated GIFs', key: 'autoPlayGifs' as const },
        { label: 'Auto-download Media', description: 'Download images and files on Wi-Fi', key: 'autoDownload' as const },
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
          headerTitle: 'Chat',
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
                  key={item.key}
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
                    value={chatPrefs[item.key]}
                    onValueChange={() => updateChatPreferences({ [item.key]: !chatPrefs[item.key] })}
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
  sectionTitle: {
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
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  rowInfo: { flex: 1, paddingRight: spacing.sm },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowDesc: { ...typography.caption, marginTop: 2 },
});
