/**
 * Ticket Bot Settings
 * Route: /server/[serverId]/settings/bot-ticket
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

export default function TicketBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'ticket'],
    queryFn: () => botService.getTicketSettings(serverId!),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'ticket', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'ticket'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Tickets"
      emoji="🎫"
      description="Support ticket system with panels, priorities and auto-close."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="General">
        <InfoField
          label="Staff Role"
          value={settings?.staff_role_id ? 'Configured' : 'Not set'}
        />
        <InfoField
          label="Log Channel"
          value={settings?.log_channel_id ? 'Configured' : 'Not set'}
        />
        <InfoField
          label="Max Open Tickets"
          value={settings?.max_open_tickets ?? 3}
        />
        <InfoField
          label="Auto-Close After"
          value={`${settings?.auto_close_hours ?? 48} hours`}
        />
      </SettingsSection>

      <SettingsSection title="Welcome Message">
        <InfoField
          label="Ticket Welcome"
          value={settings?.welcome_message || 'A staff member will be with you shortly.'}
        />
      </SettingsSection>

      <SettingsSection title="Commands">
        <InfoField label="/ticket new" value="Create a new support ticket" />
        <InfoField label="/ticket close" value="Close the current ticket" />
        <InfoField label="/ticket add" value="Add a user to a ticket" />
        <InfoField label="/ticket remove" value="Remove a user from a ticket" />
        <InfoField label="/ticket claim" value="Claim a ticket as staff" />
        <InfoField label="/ticket priority" value="Set ticket priority" />
        <InfoField label="/ticket panels" value="Create a ticket panel" />
        <InfoField label="/ticket-config" value="Configure ticket settings" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}
