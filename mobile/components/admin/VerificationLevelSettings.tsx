/**
 * Verification Level Settings (Feature 14)
 *
 * Admin screen to set server verification level.
 * Restricts what new members can do based on account age / verification status.
 */
import React, { memo, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  VerificationLevel,
  VERIFICATION_LABELS,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';

interface Props {
  serverId: string;
}

const LEVELS: { value: VerificationLevel; icon: string; desc: string }[] = [
  { value: 0, icon: 'shield-outline', desc: 'Unrestricted — anyone can send messages' },
  { value: 1, icon: 'mail-outline', desc: 'Must have a verified email on their account' },
  { value: 2, icon: 'time-outline', desc: 'Must be registered on Flicko for longer than 5 minutes' },
  { value: 3, icon: 'hourglass-outline', desc: 'Must be a member of this server for longer than 10 minutes' },
  { value: 4, icon: 'phone-portrait-outline', desc: 'Must have a verified phone number' },
];

export const VerificationLevelSettings = memo(function VerificationLevelSettings({ serverId }: Props) {
  const { themeColors } = useTheme();
  const currentLevel = useServerManagementStore(
    (s) => s.verificationLevels[serverId] ?? 0
  );
  const setLevel = useServerManagementStore((s) => s.setVerificationLevel);

  const handleSelect = useCallback(
    async (level: VerificationLevel) => {
      setLevel(serverId, level);
      await supabase
        .from('servers')
        .update({ verification_level: level })
        .eq('id', serverId);
    },
    [serverId, setLevel]
  );

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>
        Verification Level
      </Text>
      <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
        Restrict which members can send messages based on criteria.
      </Text>

      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        {LEVELS.map(({ value, icon, desc }) => {
          const selected = currentLevel === value;
          return (
            <Pressable
              key={value}
              style={[
                styles.option,
                selected && { backgroundColor: themeColors.bgTertiary },
              ]}
              onPress={() => handleSelect(value)}
            >
              <Ionicons
                name={selected ? 'radio-button-on' : 'radio-button-off'}
                size={22}
                color={selected ? themeColors.accentPrimary : themeColors.textMuted}
              />
              <View style={styles.optionContent}>
                <View style={styles.optionHeader}>
                  <Ionicons name={icon as any} size={18} color={themeColors.textPrimary} />
                  <Text style={[styles.optionLabel, { color: themeColors.textPrimary }]}>
                    {VERIFICATION_LABELS[value]}
                  </Text>
                </View>
                <Text style={[styles.optionDesc, { color: themeColors.textMuted }]}>
                  {desc}
                </Text>
              </View>
            </Pressable>
          );
        })}
      </View>
    </ScrollView>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  title: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
    marginBottom: 4,
  },
  subtitle: {
    ...typography.body,
    marginBottom: spacing.md,
  },
  card: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  option: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: spacing.sm,
    gap: spacing.sm,
  },
  optionContent: {
    flex: 1,
  },
  optionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginBottom: 2,
  },
  optionLabel: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  optionDesc: {
    ...typography.caption,
    lineHeight: 18,
  },
});
