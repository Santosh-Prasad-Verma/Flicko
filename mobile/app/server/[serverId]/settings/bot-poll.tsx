/**
 * Poll Bot Settings
 * Route: /server/[serverId]/settings/bot-poll
 */
import React, { useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, Pressable } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import * as botService from '@shared/services/botService';
import type { Poll } from '@shared/services/botService';
import {
  BotSettingsScreen,
  SettingsSection,
  InfoField,
} from '../../../../components/bots/BotSettingsScreen';
import { spacing, borderRadius, typography } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function PollBotSettings() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const { themeColors } = useTheme();

  const { data: polls = [], isLoading } = useQuery({
    queryKey: ['server-polls', serverId],
    queryFn: () => botService.getActivePolls(serverId!),
    enabled: !!serverId,
  });

  return (
    <BotSettingsScreen
      title="Polls"
      emoji="📊"
      description="Create polls with multiple options, anonymous voting and expiry."
      enabled={true}
      onToggle={() => {}}
      isLoading={isLoading}
    >
      {polls.length > 0 && (
        <SettingsSection title={`Active Polls (${polls.length})`}>
          {polls.map((poll: Poll) => (
            <View key={poll.id} style={styles.pollItem}>
              <Text style={[styles.pollQuestion, { color: themeColors.textPrimary }]}>
                {poll.question}
              </Text>
              <Text style={[styles.pollMeta, { color: themeColors.textMuted }]}>
                {poll.options.length} options • {poll.anonymous ? 'Anonymous' : 'Public'}
                {poll.multi_vote ? ' • Multi-vote' : ''}
              </Text>
              {/* Option bars */}
              {poll.options.map((opt) => {
                const totalVotes = poll.options.reduce((sum, o) => sum + o.votes, 0);
                const pct = totalVotes > 0 ? Math.round((opt.votes / totalVotes) * 100) : 0;
                return (
                  <View key={opt.id} style={styles.optionRow}>
                    <Text style={[styles.optionLabel, { color: themeColors.textPrimary }]}>
                      {opt.emoji} {opt.label}
                    </Text>
                    <View style={[styles.bar, { backgroundColor: themeColors.bgTertiary }]}>
                      <View
                        style={[
                          styles.barFill,
                          {
                            width: `${pct}%`,
                            backgroundColor: themeColors.accentPrimary,
                          },
                        ]}
                      />
                    </View>
                    <Text style={[styles.optionVotes, { color: themeColors.textMuted }]}>
                      {opt.votes} ({pct}%)
                    </Text>
                  </View>
                );
              })}
            </View>
          ))}
        </SettingsSection>
      )}

      {polls.length === 0 && (
        <SettingsSection title="No Active Polls">
          <InfoField label="Tip" value="Use /poll create to start a new poll" />
        </SettingsSection>
      )}

      <SettingsSection title="Commands">
        <InfoField label="/poll create" value="Create a poll with up to 10 options" />
        <InfoField label="/poll close" value="Close a poll and show results" />
        <InfoField label="/poll results" value="View results of any poll" />
        <InfoField label="/quickpoll" value="Quick yes/no poll" />
      </SettingsSection>
    </BotSettingsScreen>
  );
}

const styles = StyleSheet.create({
  pollItem: {
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  pollQuestion: {
    ...typography.bodyBold,
  },
  pollMeta: {
    ...typography.caption,
  },
  optionRow: {
    gap: 4,
  },
  optionLabel: {
    ...typography.bodySmall,
  },
  bar: {
    height: 6,
    borderRadius: 3,
    overflow: 'hidden',
  },
  barFill: {
    height: '100%',
    borderRadius: 3,
  },
  optionVotes: {
    ...typography.caption,
    textAlign: 'right',
  },
});
