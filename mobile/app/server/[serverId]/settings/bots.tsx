/**
 * Bot Management Screen
 *
 * Overview of all available bots with enable/disable toggles.
 * Tap a bot to configure its settings.
 * Route: /server/[serverId]/settings/bots
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import * as botService from '@shared/services/botService';
import type { BotInfo } from '@shared/services/botService';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function BotsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: bots = [], isLoading } = useQuery({
    queryKey: ['server-bots', serverId],
    queryFn: () => botService.getAllBotStatuses(serverId!),
    enabled: !!serverId,
    staleTime: 60_000,
    gcTime: 300_000,
  });

  const toggleMutation = useMutation({
    mutationFn: async ({ botName, enabled }: { botName: string; enabled: boolean }) => {
      try {
        return await botService.toggleBot(serverId!, botName, enabled);
      } catch (error: any) {
        // If backend API fails, try direct Supabase update as fallback
        const tableMap: Record<string, string> = {
          moderation: 'mod_settings',
          automod: 'automod_settings',
          welcome: 'welcome_settings',
          leveling: 'level_settings',
          ticket: 'ticket_settings',
          starboard: 'starboard_settings',
          music: 'music_settings',
        };
        
        const table = tableMap[botName];
        if (!table) throw new Error(`Unknown bot: ${botName}`);
        
        // Try to update existing settings
        const { data: existing } = await supabase
          .from(table)
          .select('*')
          .eq('server_id', serverId!)
          .single();
        
        if (existing) {
          // Update existing
          const { error: updateError } = await supabase
            .from(table)
            .update({ enabled })
            .eq('server_id', serverId!);
          if (updateError) throw updateError;
        } else {
          // Insert new settings
          const { error: insertError } = await supabase
            .from(table)
            .insert({ server_id: serverId!, enabled });
          if (insertError) throw insertError;
        }
        
        return { success: true, enabled };
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-bots', serverId] });
    },
    onError: (error: any) => {
      console.error('Failed to toggle bot:', error);
      // Show error to user
      alert(`Failed to toggle bot: ${error.message}`);
    },
  });

  const handleToggle = useCallback(
    (bot: BotInfo, value: boolean) => {
      toggleMutation.mutate({ botName: bot.name, enabled: value });
    },
    [toggleMutation]
  );

  const handleBotPress = useCallback(
    (bot: BotInfo) => {
      router.push(`/server/${serverId}/settings/bot-${bot.name}` as any);
    },
    [serverId]
  );

  const renderBot = useCallback(
    ({ item }: { item: BotInfo }) => (
      <Pressable
        style={[styles.botCard, { backgroundColor: themeColors.bgSecondary }]}
        onPress={() => handleBotPress(item)}
      >
        <View style={styles.botHeader}>
          <Text style={styles.botAvatar}>{item.avatar}</Text>
          <View style={styles.botInfo}>
            <Text style={[styles.botName, { color: themeColors.textPrimary }]}>
              {item.display_name}
            </Text>
            <Text
              style={[styles.botDescription, { color: themeColors.textMuted }]}
              numberOfLines={2}
            >
              {item.description}
            </Text>
          </View>
          <Switch
            value={item.enabled}
            onValueChange={(v) => handleToggle(item, v)}
            trackColor={{
              false: themeColors.bgTertiary,
              true: themeColors.accentPrimary + '80',
            }}
            thumbColor={
              item.enabled ? themeColors.accentPrimary : themeColors.textMuted
            }
          />
        </View>
        <View style={styles.botFooter}>
          <Text style={[styles.statusBadge, {
            color: item.enabled ? '#43b581' : themeColors.textMuted,
            backgroundColor: item.enabled ? '#43b58120' : themeColors.bgTertiary,
          }]}>
            {item.enabled ? 'Active' : 'Inactive'}
          </Text>
          <Ionicons
            name="chevron-forward"
            size={18}
            color={themeColors.textMuted}
          />
        </View>
      </Pressable>
    ),
    [themeColors, handleBotPress, handleToggle]
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      <Stack.Screen options={{ headerShown: false }} />

      {/* Header */}
      <View
        style={[
          styles.header,
          { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgPrimary },
        ]}
      >
        <Pressable
          style={styles.backButton}
          onPress={() => router.back()}
          hitSlop={8}
        >
          <Ionicons
            name="arrow-back"
            size={24}
            color={themeColors.textPrimary}
          />
        </Pressable>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
          Bots
        </Text>
        <View style={{ width: 40 }} />
      </View>

      {/* Description */}
      <View style={[styles.descriptionBox, { backgroundColor: themeColors.bgSecondary }]}>
        <Ionicons name="hardware-chip-outline" size={20} color={themeColors.accentPrimary} />
        <Text style={[styles.descriptionText, { color: themeColors.textMuted }]}>
          Enable bots to add moderation, leveling, tickets and more to your server.
          Tap a bot to configure its settings.
        </Text>
      </View>

      {isLoading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
        </View>
      ) : (
        <FlatList
          data={bots}
          renderItem={renderBot}
          keyExtractor={(item) => item.name}
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
  container: {
    flex: 1,
  },
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
  headerTitle: {
    ...typography.headingM,
  },
  descriptionBox: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginHorizontal: spacing.lg,
    marginBottom: spacing.md,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    gap: spacing.sm,
  },
  descriptionText: {
    ...typography.bodySmall,
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  list: {
    paddingHorizontal: spacing.lg,
    gap: spacing.md,
  },
  botCard: {
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
    gap: spacing.md,
  },
  botHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  botAvatar: {
    fontSize: 28,
  },
  botInfo: {
    flex: 1,
    gap: 2,
  },
  botName: {
    ...typography.bodyBold,
  },
  botDescription: {
    ...typography.bodySmall,
  },
  botFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  statusBadge: {
    ...typography.caption,
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
  },
});
