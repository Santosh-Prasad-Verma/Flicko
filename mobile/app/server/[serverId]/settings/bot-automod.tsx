/**
 * AutoMod Bot Settings
 * Route: /server/[serverId]/settings/bot-automod
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

export default function AutoModBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'automod'],
    queryFn: () => botService.getAutoModSettings(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'automod', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'automod'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="AutoMod"
      emoji="🤖"
      description="Automatically filter spam, links, excessive caps and more."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="Filters">
        <ToggleField
          label="Invite Link Filter"
          hint="Block Discord/server invite links"
          value={settings?.invite_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, invite_filter: v })}
        />
        <ToggleField
          label="URL Filter"
          hint="Block all URLs"
          value={settings?.link_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, link_filter: v })}
        />
        <ToggleField
          label="Caps Filter"
          hint={`Block excessive caps (threshold: ${settings?.caps_threshold ?? 70}%)`}
          value={settings?.caps_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, caps_filter: v })}
        />
        <ToggleField
          label="Emoji Spam Filter"
          hint={`Block messages with ${settings?.emoji_max ?? 10}+ emojis`}
          value={settings?.emoji_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, emoji_filter: v })}
        />
        <ToggleField
          label="Mention Spam Filter"
          hint={`Block messages with ${settings?.mention_max ?? 5}+ mentions`}
          value={settings?.mention_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, mention_filter: v })}
        />
        <ToggleField
          label="Duplicate Message Filter"
          hint="Block repeated messages"
          value={settings?.duplicate_filter ?? false}
          onValueChange={(v) => mutation.mutate({ ...settings, duplicate_filter: v })}
        />
      </SettingsSection>

      <SettingsSection title="Exemptions">
        <InfoField
          label="Exempt Roles"
          value={`${(settings?.exempt_roles ?? []).length} roles`}
        />
        <InfoField
          label="Exempt Channels"
          value={`${(settings?.exempt_channels ?? []).length} channels`}
        />
      </SettingsSection>

      <SettingsSection title="Commands">
        <InfoField label="/automod enable" value="Enable AutoMod for this server" />
        <InfoField label="/automod disable" value="Disable AutoMod" />
        <InfoField label="/automod status" value="View current filter status" />
        <InfoField label="/automod configure" value="Toggle individual filters" />
        <InfoField label="/automod-exempt" value="Exempt a role from filters" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}
