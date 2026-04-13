/**
 * Leveling & XP Bot Settings
 * Route: /server/[serverId]/settings/bot-leveling
 */
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as botService from '@shared/services/botService';
import {
  BotSettingsScreen,
  SettingsSection,
  ToggleField,
  InfoField,
} from '../../../../components/bots/BotSettingsScreen';
import { spacing, borderRadius, typography } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function LevelingBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();
  const { themeColors } = useTheme();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'leveling'],
    queryFn: () => botService.getLevelSettings(serverId!),
    enabled: !!serverId,
  });

  const { data: rewards = [] } = useQuery({
    queryKey: ['level-rewards', serverId],
    queryFn: () => botService.getLevelRewards(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'leveling', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'leveling'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Leveling & XP"
      emoji="⭐"
      description="Reward active members with XP, levels and role rewards."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="XP Configuration">
        <InfoField label="XP per message" value={`${settings?.xp_min ?? 15} – ${settings?.xp_max ?? 25}`} />
        <InfoField label="XP Cooldown" value={`${settings?.xp_cooldown ?? 60}s`} />
        <ToggleField
          label="Stack Role Rewards"
          hint="Keep all earned role rewards instead of replacing"
          value={settings?.stack_rewards ?? true}
          onValueChange={(v) => mutation.mutate({ ...settings, stack_rewards: v })}
        />
      </SettingsSection>

      <SettingsSection title="Level-Up Announcements">
        <InfoField
          label="Announce Channel"
          value={settings?.announce_channel_id ? 'Configured' : 'Current channel'}
        />
        <InfoField
          label="Message"
          value={settings?.announce_message || '🎉 {user} reached level {level}!'}
        />
      </SettingsSection>

      {rewards.length > 0 && (
        <SettingsSection title={`Role Rewards (${rewards.length})`}>
          {rewards.map((r: any) => (
            <InfoField
              key={r.id}
              label={`Level ${r.level}`}
              value={r.role_name || r.role_id}
            />
          ))}
        </SettingsSection>
      )}

      {/* Leaderboard Quick Link */}
      <Pressable
        style={[styles.linkCard, { backgroundColor: themeColors.bgSecondary }]}
        onPress={() => router.push(`/server/${serverId}/settings/leaderboard` as any)}
      >
        <Ionicons name="trophy-outline" size={20} color={themeColors.accentPrimary} />
        <Text style={[styles.linkText, { color: themeColors.textPrimary }]}>
          View Leaderboard
        </Text>
        <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
      </Pressable>

      <SettingsSection title="Commands">
        <InfoField label="/rank" value="View your rank and XP" />
        <InfoField label="/leaderboard" value="Server XP leaderboard" />
        <InfoField label="/xp set" value="Set a user's XP (admin)" />
        <InfoField label="/xp add" value="Add XP to a user" />
        <InfoField label="/xp remove" value="Remove XP from a user" />
        <InfoField label="/level-config" value="Configure leveling settings" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}

const styles = StyleSheet.create({
  linkCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.lg,
    borderRadius: borderRadius.lg,
    gap: spacing.md,
  },
  linkText: {
    ...typography.body,
    flex: 1,
  },
});
