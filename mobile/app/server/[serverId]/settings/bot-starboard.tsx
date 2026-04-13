/**
 * Starboard Bot Settings
 * Route: /server/[serverId]/settings/bot-starboard
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as botService from '@shared/services/botService';
import type { StarboardEntry } from '@shared/services/botService';
import {
  BotSettingsScreen,
  SettingsSection,
  ToggleField,
  InfoField,
} from '../../../../components/bots/BotSettingsScreen';
import { spacing, typography } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function StarboardBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();
  const { themeColors } = useTheme();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'starboard'],
    queryFn: () => botService.getStarboardSettings(serverId!),
    enabled: !!serverId,
  });

  const { data: entries = [] } = useQuery({
    queryKey: ['starboard-entries', serverId],
    queryFn: () => botService.getStarboardEntries(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'starboard', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'starboard'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Starboard"
      emoji="⭐"
      description="Highlight the best messages by tracking star reactions."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="Configuration">
        <InfoField
          label="Starboard Channel"
          value={settings?.channel_id ? 'Configured' : 'Not set'}
        />
        <InfoField label="Star Threshold" value={settings?.threshold ?? 3} />
        <InfoField label="Star Emoji" value={settings?.emoji ?? '⭐'} />
        <ToggleField
          label="Allow Self-Star"
          hint="Let users star their own messages"
          value={settings?.self_star ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, self_star: v })}
        />
        <InfoField
          label="Ignored Channels"
          value={`${(settings?.ignore_channels ?? []).length} channels`}
        />
      </SettingsSection>

      {entries.length > 0 && (
        <SettingsSection title={`Top Starred Messages (${entries.length})`}>
          {entries.slice(0, 10).map((entry: StarboardEntry) => (
            <View key={entry.id} style={styles.entryRow}>
              <Text style={[styles.starCount, { color: themeColors.accentPrimary }]}>
                {settings?.emoji ?? '⭐'} {entry.star_count}
              </Text>
              <View style={{ flex: 1 }}>
                <Text
                  style={[styles.entryContent, { color: themeColors.textPrimary }]}
                  numberOfLines={2}
                >
                  {entry.content || '(media)'}
                </Text>
                <Text style={[styles.entryAuthor, { color: themeColors.textMuted }]}>
                  by {entry.author_name}
                </Text>
              </View>
            </View>
          ))}
        </SettingsSection>
      )}

      <SettingsSection title="Commands">
        <InfoField label="/starboard setup" value="Set starboard channel" />
        <InfoField label="/starboard threshold" value="Set minimum star count" />
        <InfoField label="/starboard emoji" value="Change the star emoji" />
        <InfoField label="/starboard self-star" value="Toggle self-starring" />
        <InfoField label="/starboard ignore" value="Ignore a channel" />
        <InfoField label="/stars" value="View star stats for a user" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}

const styles = StyleSheet.create({
  entryRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.md,
    paddingVertical: spacing.sm,
  },
  starCount: {
    ...typography.bodyBold,
    minWidth: 50,
  },
  entryContent: {
    ...typography.bodySmall,
  },
  entryAuthor: {
    ...typography.caption,
  },
});
