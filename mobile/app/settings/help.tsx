/**
 * Help & Support Screen
 * Route: /settings/help
 *
 * Provides links to documentation, FAQ, community, and contact options.
 */
import React from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable, Linking, Alert } from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface HelpRow {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  description: string;
  onPress: () => void;
}

export default function HelpSupportScreen() {
  const { themeColors } = useTheme();

  const helpRows: HelpRow[] = [
    {
      icon: 'book-outline',
      label: 'FAQ',
      description: 'Frequently asked questions',
      onPress: () => Alert.alert('FAQ', 'FAQ section coming soon.'),
    },
    {
      icon: 'chatbubbles-outline',
      label: 'Community',
      description: 'Join our community server',
      onPress: () => Alert.alert('Community', 'Community invite coming soon.'),
    },
    {
      icon: 'document-text-outline',
      label: 'Terms of Service',
      description: 'Read our terms of service',
      onPress: () => Linking.openURL('https://flicko.dev/terms'),
    },
    {
      icon: 'shield-checkmark-outline',
      label: 'Privacy Policy',
      description: 'Read our privacy policy',
      onPress: () => Linking.openURL('https://flicko.dev/privacy'),
    },
    {
      icon: 'bug-outline',
      label: 'Report a Bug',
      description: 'Help us fix issues',
      onPress: () => Linking.openURL('mailto:support@flicko.dev?subject=Bug%20Report'),
    },
    {
      icon: 'information-circle-outline',
      label: 'App Version',
      description: 'Flicko v1.0.0',
      onPress: () => {},
    },
  ];

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Help & Support',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={styles.section}>
          {helpRows.map((row, index) => (
            <Pressable
              key={row.label}
              onPress={row.onPress}
              style={({ pressed }) => [
                styles.row,
                index < helpRows.length - 1 && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border },
                pressed && { opacity: 0.7 },
              ]}
              accessibilityRole="button"
              accessibilityLabel={row.label}
            >
              <Ionicons name={row.icon} size={22} color={themeColors.accentPrimary} style={styles.rowIcon} />
              <View style={styles.rowInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>{row.label}</Text>
                <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>{row.description}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
            </Pressable>
          ))}
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  section: {
    marginTop: spacing.lg,
    paddingHorizontal: spacing.md,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  rowIcon: {
    marginRight: spacing.md,
    width: 24,
  },
  rowInfo: {
    flex: 1,
  },
  rowLabel: {
    ...typography.body,
    fontFamily: 'gg-sans-medium',
  },
  rowDesc: {
    ...typography.caption,
    marginTop: 2,
  },
});
