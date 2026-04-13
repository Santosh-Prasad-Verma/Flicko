/**
 * Leaderboard Screen
 * Route: /server/[serverId]/settings/leaderboard
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Image,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as botService from '@shared/services/botService';
import type { LeaderboardEntry } from '@shared/services/botService';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function LeaderboardScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const { data: entries = [], isLoading } = useQuery({
    queryKey: ['leaderboard', serverId],
    queryFn: () => botService.getLeaderboard(serverId!),
    enabled: !!serverId,
  });

  const getRankColor = (rank: number) => {
    if (rank === 1) return '#FFD700';
    if (rank === 2) return '#C0C0C0';
    if (rank === 3) return '#CD7F32';
    return themeColors.textMuted;
  };

  const getRankEmoji = (rank: number) => {
    if (rank === 1) return '🥇';
    if (rank === 2) return '🥈';
    if (rank === 3) return '🥉';
    return `#${rank}`;
  };

  const xpForLevel = (level: number) => 5 * level * level + 50 * level + 100;

  const renderEntry = ({ item }: { item: LeaderboardEntry }) => {
    const needed = xpForLevel(item.level);
    const progress = Math.min(1, (item.xp % needed) / needed);

    return (
      <View style={[styles.entry, { backgroundColor: themeColors.bgSecondary }]}>
        <Text style={[styles.rank, { color: getRankColor(item.rank) }]}>
          {getRankEmoji(item.rank)}
        </Text>
        <View style={styles.avatar}>
          {item.avatar_url ? (
            <Image source={{ uri: item.avatar_url }} style={styles.avatarImage} />
          ) : (
            <View style={[styles.avatarPlaceholder, { backgroundColor: themeColors.accentPrimary }]}>
              <Text style={styles.avatarText}>{item.username[0]?.toUpperCase()}</Text>
            </View>
          )}
        </View>
        <View style={styles.info}>
          <Text style={[styles.username, { color: themeColors.textPrimary }]}>
            {item.username}
          </Text>
          <View style={styles.xpRow}>
            <Text style={[styles.level, { color: themeColors.accentPrimary }]}>
              Lv. {item.level}
            </Text>
            <View style={[styles.progressBar, { backgroundColor: themeColors.bgTertiary }]}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${progress * 100}%`, backgroundColor: themeColors.accentPrimary },
                ]}
              />
            </View>
          </View>
          <Text style={[styles.xpText, { color: themeColors.textMuted }]}>
            {item.xp.toLocaleString()} XP • {item.message_count.toLocaleString()} messages
          </Text>
        </View>
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      <Stack.Screen options={{ headerShown: false }} />

      <View
        style={[
          styles.header,
          { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgPrimary },
        ]}
      >
        <Pressable style={styles.backButton} onPress={() => router.back()} hitSlop={8}>
          <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
        </Pressable>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
          🏆 Leaderboard
        </Text>
        <View style={{ width: 40 }} />
      </View>

      {isLoading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
        </View>
      ) : entries.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            No XP data yet. Enable the Leveling bot and start chatting!
          </Text>
        </View>
      ) : (
        <FlatList
          data={entries}
          renderItem={renderEntry}
          keyExtractor={(i) => i.user_id}
          contentContainerStyle={[
            styles.list,
            { paddingBottom: insets.bottom + spacing.lg },
          ]}
          showsVerticalScrollIndicator={false}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
  },
  backButton: {
    width: 40,
    height: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
  },
  headerTitle: { ...typography.headingM },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.xxxl,
  },
  emptyText: {
    ...typography.body,
    textAlign: 'center',
  },
  list: {
    paddingHorizontal: spacing.lg,
    gap: spacing.sm,
  },
  entry: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.lg,
    gap: spacing.md,
  },
  rank: {
    ...typography.bodyBold,
    width: 32,
    textAlign: 'center',
    fontSize: 16,
  },
  avatar: {},
  avatarImage: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  avatarPlaceholder: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: '#fff',
    fontFamily: 'gg-sans-bold',
    fontSize: 16,
  },
  info: {
    flex: 1,
    gap: 2,
  },
  username: { ...typography.bodyBold },
  xpRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  level: {
    ...typography.caption,
    fontFamily: 'gg-sans-bold',
  },
  progressBar: {
    flex: 1,
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  xpText: { ...typography.caption },
});
