/**
 * Server Channel List Screen
 *
 * Displays channels for a specific server with header and navigation.
 * Route: /server/[serverId]
 * Requirements: 4.2, 4.3, 4.7, 4.8, 16.2
 */
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Image } from 'expo-image';
import Animated, { FadeIn } from 'react-native-reanimated';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../services/supabase';
import { ChannelList } from '../../../components/channels/ChannelList';
import { LoadingSpinner } from '../../../components/shared/LoadingSpinner';
import { Button } from '../../../components/ui/Button';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useTheme } from '../../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';

export default function ServerChannelListScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const queryClient = useQueryClient();

  // Check if the current user is a member of this server
  const { data: membership, isLoading: membershipLoading } = useQuery({
    queryKey: ['server-membership', serverId, user?.id],
    queryFn: async () => {
      if (!user?.id) return null;
      const { data, error } = await supabase
        .from('server_members')
        .select('id')
        .eq('server_id', serverId)
        .eq('user_id', user.id)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId && !!user?.id,
  });

  const isMember = !!membership;

  const joinMutation = useMutation({
    mutationFn: async () => {
      if (!user?.id) throw new Error('Not logged in');
      const { error } = await supabase.from('server_members').insert({
        server_id: serverId,
        user_id: user.id,
        role: 'member',
      });
      if (error) throw error;

      // Post a system welcome message in the first text channel
      try {
        const { data: firstChannel } = await supabase
          .from('channels')
          .select('id')
          .eq('server_id', serverId)
          .in('type', ['text', 'announcement'])
          .order('position', { ascending: true })
          .limit(1)
          .maybeSingle();

        if (firstChannel) {
          const displayName = user.display_name || user.username || 'Someone';
          await supabase.from('messages').insert({
            channel_id: firstChannel.id,
            content: `${displayName} joined the server.`,
            type: 'system',
            system_type: 'join',
            author_id: user.id,
          });
        }
      } catch (e) {
        console.warn('Failed to post welcome message:', e);
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      queryClient.invalidateQueries({ queryKey: ['discover-servers'] });
      queryClient.invalidateQueries({ queryKey: ['server-membership', serverId, user?.id] });
    },
  });

  const { data: server } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('servers')
        .select('*, owner_id')
        .eq('id', serverId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId,
  });

  const isOwner = server?.owner_id === user?.id;

  const {
    data: channels = [],
    isLoading,
    refetch,
  } = useQuery({
    queryKey: ['channels', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channels')
        .select('*')
        .eq('server_id', serverId)
        .order('position', { ascending: true });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!serverId,
  });

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: false,
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + spacing.sm,
              backgroundColor: themeColors.bgSecondary,
              borderBottomColor: themeColors.border,
            },
          ]}
        >
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={[styles.iconButton, { backgroundColor: themeColors.bgTertiary }]}
            accessibilityRole="button"
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <Text style={[styles.serverName, { color: themeColors.textPrimary }]} numberOfLines={1}>
              {server?.name || 'Server'}
            </Text>
            <Text style={[styles.memberCount, { color: themeColors.textMuted }]}>
              {channels.length} channel{channels.length !== 1 ? 's' : ''}
            </Text>
          </View>
          {/* Owner: settings gear; Members: three-dot with member options */}
          {isOwner ? (
            <Pressable
              onPress={() => router.push(`/server/${serverId}/settings` as any)}
              hitSlop={12}
              style={[styles.iconButton, { backgroundColor: themeColors.bgTertiary }]}
              accessibilityRole="button"
              accessibilityLabel="Server settings"
            >
              <Ionicons name="settings-outline" size={22} color={themeColors.textSecondary} />
            </Pressable>
          ) : isMember ? (
            <Pressable
              onPress={() => router.push(`/server/${serverId}/server-options` as any)}
              hitSlop={12}
              style={[styles.iconButton, { backgroundColor: themeColors.bgTertiary }]}
              accessibilityRole="button"
              accessibilityLabel="Server options"
            >
              <Ionicons name="ellipsis-vertical" size={22} color={themeColors.textSecondary} />
            </Pressable>
          ) : null}
        </View>

        {/* Server Banner */}
        {server?.banner && (
          <Animated.View entering={FadeIn.duration(400)}>
            <Image
              source={{ uri: server.banner }}
              style={styles.serverBanner}
              contentFit="cover"
              transition={300}
              autoplay={true}
              cachePolicy="disk"
            />
          </Animated.View>
        )}

        {/* Channel List */}
        {membershipLoading || isLoading ? (
          <LoadingSpinner fullScreen message="Loading channels..." />
        ) : !isMember ? (
          <View style={styles.notMemberContainer}>
            <Ionicons name="lock-closed-outline" size={48} color={themeColors.textMuted} />
            <Text style={[styles.notMemberTitle, { color: themeColors.textPrimary }]}>
              You haven't joined this server
            </Text>
            <Text style={[styles.notMemberDesc, { color: themeColors.textMuted }]}>
              Join this server to see its channels and start chatting.
            </Text>
            <Button
              title={joinMutation.isPending ? 'Joining...' : 'Join Server'}
              onPress={() => joinMutation.mutate()}
              variant="primary"
              size="md"
              disabled={joinMutation.isPending}
            />
          </View>
        ) : (
          <ChannelList
            channels={channels}
            serverId={serverId!}
            refreshing={isLoading}
            onRefresh={() => refetch()}
          />
        )}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  iconButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerInfo: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  serverName: {
    ...typography.headingM,
  },
  memberCount: {
    ...typography.caption,
    marginTop: 2,
  },
  serverBanner: {
    width: '100%',
    height: 130,
  },
  notMemberContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.xl,
    gap: spacing.md,
  },
  notMemberTitle: {
    ...typography.headingM,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  notMemberDesc: {
    ...typography.body,
    textAlign: 'center',
    marginBottom: spacing.md,
  },
});
