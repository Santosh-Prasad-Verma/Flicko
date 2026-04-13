/**
 * Music Bot Settings
 * Route: /server/[serverId]/settings/bot-music
 */
import React from 'react';
import { useLocalSearchParams } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as botService from '@shared/services/botService';
import {
  BotSettingsScreen,
  SettingsSection,
  InfoField,
} from '../../../../components/bots/BotSettingsScreen';

export default function MusicBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['bot-settings', serverId, 'music'],
    queryFn: () => botService.getBotSettings(serverId!, 'music'),
    enabled: !!serverId,
  });

  const mutation = useMutation({
    mutationFn: (s: Record<string, any>) =>
      botService.updateBotSettings(serverId!, 'music', s),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['bot-settings', serverId, 'music'] }),
  });

  const toggle = (enabled: boolean) => mutation.mutate({ ...settings, enabled });

  return (
    <BotSettingsScreen
      title="Music"
      emoji="🎵"
      description="Play music, manage queues, create playlists and DJ controls."
      enabled={settings?.enabled ?? false}
      onToggle={toggle}
      isLoading={isLoading}
    >
      <SettingsSection title="Configuration">
        <InfoField label="Default Volume" value={`${settings?.default_volume ?? 50}%`} />
        <InfoField
          label="DJ Role"
          value={settings?.dj_role_id ? 'Configured' : 'Not set'}
        />
      </SettingsSection>

      <SettingsSection title="Playback Commands">
        <InfoField label="/play" value="Play a song by URL or search" />
        <InfoField label="/skip" value="Skip the current track" />
        <InfoField label="/pause" value="Pause playback" />
        <InfoField label="/resume" value="Resume playback" />
        <InfoField label="/stop" value="Stop playback and clear queue" />
        <InfoField label="/nowplaying" value="Show current track info" />
        <InfoField label="/volume" value="Set playback volume" />
      </SettingsSection>

      <SettingsSection title="Queue Commands">
        <InfoField label="/queue" value="View the current queue" />
        <InfoField label="/shuffle" value="Shuffle the queue" />
        <InfoField label="/repeat" value="Set repeat mode (off/song/queue)" />
      </SettingsSection>

      <SettingsSection title="Playlist Commands">
        <InfoField label="/playlist create" value="Create a new playlist" />
        <InfoField label="/playlist add" value="Add current track to playlist" />
        <InfoField label="/playlist load" value="Load a playlist into queue" />
        <InfoField label="/playlist list" value="View your playlists" />
        <InfoField label="/playlist delete" value="Delete a playlist" />
      </SettingsSection>

      <SettingsSection title="Other">
        <InfoField label="/history" value="View recently played tracks" />
        <InfoField label="/music-config" value="Configure music settings" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}
