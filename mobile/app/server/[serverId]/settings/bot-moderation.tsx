/**
 * Moderation Bot Settings
 * Route: /server/[serverId]/settings/bot-moderation
 */
import React from 'react';
import { useLocalSearchParams } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as botService from '@shared/services/botService';
import {
  BotSettingsScreen,
  SettingsSection,
  ToggleField,
  InfoField,
} from '../../../../components/bots/BotSettingsScreen';

export default function ModerationBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'moderation'],
    queryFn: () => botService.getModSettings(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'moderation', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'moderation'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Moderation"
      emoji="🛡️"
      description="Kick, ban, mute, warn and manage your server."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="Escalation">
        <ToggleField
          label="Auto-Escalate Warnings"
          hint="Automatically mute/kick/ban when warning thresholds are reached"
          value={settings?.auto_escalate ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, auto_escalate: v })}
        />
        <InfoField label="Mute at warnings" value={settings?.warn_threshold_mute ?? 3} />
        <InfoField label="Kick at warnings" value={settings?.warn_threshold_kick ?? 5} />
        <InfoField label="Ban at warnings" value={settings?.warn_threshold_ban ?? 7} />
      </SettingsSection>

      <SettingsSection title="Logging">
        <InfoField
          label="Mod Log Channel"
          value={settings?.mod_log_channel_id ? 'Configured' : 'Not set'}
        />
        <InfoField
          label="Mute Role"
          value={settings?.mute_role_id ? 'Configured' : 'Not set'}
        />
      </SettingsSection>

      <SettingsSection title="Commands">
        <InfoField label="/kick" value="Kick a member from the server" />
        <InfoField label="/ban" value="Ban a member from the server" />
        <InfoField label="/unban" value="Unban a previously banned user" />
        <InfoField label="/mute" value="Mute a member (with optional duration)" />
        <InfoField label="/warn" value="Issue a warning to a member" />
        <InfoField label="/warnings" value="View warnings for a user" />
        <InfoField label="/purge" value="Bulk delete messages" />
        <InfoField label="/slowmode" value="Set channel slow mode" />
        <InfoField label="/modlog" value="View recent moderation actions" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}
