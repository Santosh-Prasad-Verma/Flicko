/**
 * Welcome Bot Settings
 * Route: /server/[serverId]/settings/bot-welcome
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

export default function WelcomeBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'welcome'],
    queryFn: () => botService.getWelcomeSettings(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'welcome', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'welcome'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Welcome"
      emoji="👋"
      description="Greet new members, assign auto-roles and send goodbye messages."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="Welcome Message">
        <InfoField
          label="Channel"
          value={settings?.channel_id ? 'Configured' : 'Not set'}
        />
        <InfoField
          label="Message"
          value={settings?.message || 'Welcome {{user}} to **{{server}}**! 🎉'}
        />
      </SettingsSection>

      <SettingsSection title="Leave Message">
        <InfoField
          label="Leave Message"
          value={settings?.leave_message || 'Not configured'}
        />
      </SettingsSection>

      <SettingsSection title="Features">
        <ToggleField
          label="DM on Join"
          hint="Send a private message to new members"
          value={settings?.dm_enabled ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, dm_enabled: v })}
        />
        <ToggleField
          label="Welcome Card"
          hint="Generate a visual welcome card image"
          value={settings?.card_enabled ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, card_enabled: v })}
        />
        <InfoField
          label="Auto Roles"
          value={`${(settings?.auto_roles ?? []).length} roles`}
        />
      </SettingsSection>

      <SettingsSection title="Template Variables">
        <InfoField label="{{user}}" value="Mention the user" />
        <InfoField label="{{username}}" value="User's display name" />
        <InfoField label="{{server}}" value="Server name" />
        <InfoField label="{{memberCount}}" value="Total member count" />
      </SettingsSection>

      <SettingsSection title="Commands">
        <InfoField label="/welcome setup" value="Set welcome channel" />
        <InfoField label="/welcome message" value="Customize welcome message" />
        <InfoField label="/welcome test" value="Send a test welcome" />
        <InfoField label="/welcome leave" value="Set leave message" />
        <InfoField label="/welcome autorole" value="Add auto-assigned role" />
        <InfoField label="/welcome dm" value="Configure DM settings" />
        <InfoField label="/welcome card" value="Toggle welcome card" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}
