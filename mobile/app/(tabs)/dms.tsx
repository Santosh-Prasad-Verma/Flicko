/**
 * Messages Tab — Discord Mobile Style
 *
 * Lists DM conversations exactly like Discord mobile:
 * - Search bar at top
 * - Online friends row (horizontal scrollable avatars)
 * - Conversation list with avatar, name, last message, timestamp
 * - Swipe actions (mute, delete)
 * - Typing indicators
 * - Pinned sections
 * - Bot badges
 * - 99+ badge cap
 */
import React, { useCallback, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  SectionList,
  StyleSheet,
  Pressable,
  RefreshControl,
} from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { LoadingSpinner } from '../../components/shared/LoadingSpinner';
import { EmptyState } from '../../components/shared/EmptyState';
import { spacing, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import { OnlineFriendsRow } from '../../components/dm/OnlineFriendsRow';
import { DMRow } from '../../components/dm/DMRow';
import type { DMConversation, DMParticipant, UserStatus } from '../../types/dm';
import { fetchPrivacyMaskedProfileFields } from '@shared/services/privacySettingsService';

interface ConversationSection {
  title: string;
  data: DMConversation[];
}

function toParticipantStatus(raw: string | null | undefined): UserStatus {
  return raw === 'online' || raw === 'idle' || raw === 'dnd' || raw === 'offline' ? raw : 'offline';
}

export default function DMsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s) => s.user);

  const {
    data: rawConversations = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery<DMConversation[]>({
    queryKey: ['dm-conversations', user?.id],
    queryFn: async () => {
      // Get the latest message per conversation partner (limit to 500 most recent messages)
      const { data: messages, error } = await supabase
        .from('direct_messages')
        .select('*, sender:profiles!sender_id(id, username, display_name, avatar, online_status), recipient:profiles!recipient_id(id, username, display_name, avatar, online_status)')
        .or(`sender_id.eq.${user?.id},recipient_id.eq.${user?.id}`)
        .order('created_at', { ascending: false })
        .limit(500);
      if (error) throw error;

      // Group messages by conversation partner to build conversation list
      const conversationMap = new Map<string, DMConversation>();
      for (const msg of messages ?? []) {
        const otherUserId = msg.sender_id === user?.id ? msg.recipient_id : msg.sender_id;
        const otherUser = msg.sender_id === user?.id ? msg.recipient : msg.sender;
        const rawStatus = (otherUser as { online_status?: string } | null)?.online_status;
        const status = toParticipantStatus(rawStatus);
        if (!conversationMap.has(otherUserId)) {
          conversationMap.set(otherUserId, {
            id: otherUserId,
            participant: {
              id: otherUserId,
              name: otherUser?.display_name || otherUser?.username || 'User',
              avatar: otherUser?.avatar,
              status,
              isBot: false, // TODO: Get from user metadata
            },
            lastMessage: msg.content,
            lastMessageAt: msg.created_at,
            unreadCount: 0, // TODO: Calculate from read receipts
            isPinned: false, // TODO: Get from user preferences
            isMuted: false, // TODO: Get from user preferences
            isTyping: false,
          });
        }
      }
      const list = Array.from(conversationMap.values());
      const partnerIds = list.map((c) => c.id);
      const mask = await fetchPrivacyMaskedProfileFields(partnerIds);
      return list.map((c) => {
        const m = mask.get(c.id);
        const raw = m?.online_status ?? c.participant.status;
        return {
          ...c,
          participant: {
            ...c.participant,
            status: toParticipantStatus(raw),
          },
        };
      });
    },
    enabled: !!user?.id,
    staleTime: 30000, // 30 seconds
    gcTime: 300000, // 5 minutes (formerly cacheTime)
    refetchOnMount: false,
    refetchOnWindowFocus: false,
  });

  const conversations = useMemo(() => rawConversations, [rawConversations]);

  // Organize conversations into sections
  const sections = useMemo((): ConversationSection[] => {
    const pinned = conversations.filter((c: DMConversation) => c.isPinned);
    const unpinned = conversations.filter((c: DMConversation) => !c.isPinned);

    const result: ConversationSection[] = [];
    if (pinned.length > 0) {
      result.push({ title: 'PINNED', data: pinned });
    }
    if (unpinned.length > 0) {
      result.push({ title: 'DIRECT MESSAGES', data: unpinned });
    }
    return result;
  }, [conversations]);

  // Extract online friends for the top row
  const onlineFriends = useMemo((): DMParticipant[] => {
    return conversations
      .filter((c: DMConversation) => c.participant.status === 'online')
      .map((c: DMConversation) => c.participant)
      .slice(0, 20); // Limit to 20 for performance
  }, [conversations]);

  // Real-time subscription: auto-refresh DM list when new messages arrive
  useEffect(() => {
    if (!user?.id) return;

          // We need two channels because Supabase realtime filters don't support OR conditions
          const senderChannel = supabase
            .channel('dm-conversations-sender')
            .on(
              'postgres_changes',
              {
                event: '*',
                schema: 'public',
                table: 'direct_messages',
                filter: `sender_id=eq.${user.id}`,
              },
              () => {
                refetch();
              },
            )
            .subscribe();

          const recipientChannel = supabase
            .channel('dm-conversations-recipient')
            .on(
              'postgres_changes',
              {
                event: '*',
                schema: 'public',
                table: 'direct_messages',
                filter: `recipient_id=eq.${user.id}`,
              },
              () => {
                refetch();
              },
            )
            .subscribe();

          return () => {
            supabase.removeChannel(senderChannel);
            supabase.removeChannel(recipientChannel);
          };
  }, [user?.id, refetch]);

  const handlePressFriend = useCallback((friend: DMParticipant) => {
    router.push(`/dm/${friend.id}`);
  }, []);

  const handlePressConversation = useCallback((conversation: DMConversation) => {
    router.push(`/dm/${conversation.id}`);
  }, []);

  const handleDeleteConversation = useCallback((conversationId: string) => {
    // TODO: Implement delete conversation
    console.log('Delete conversation:', conversationId);
  }, []);

  const handleMuteConversation = useCallback((conversationId: string) => {
    // TODO: Implement mute/unmute conversation
    console.log('Mute conversation:', conversationId);
  }, []);

  const renderSectionHeader = useCallback(
    ({ section }: { section: ConversationSection; index: number }) => (
      <View style={[styles.sectionHeader, { backgroundColor: themeColors.bgPrimary }]}>
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
          {section.title}
        </Text>
      </View>
    ),
    [themeColors],
  );

  const renderItem = useCallback(
    ({ item }: { item: DMConversation; index: number }) => (
      <DMRow
        conversation={item}
        onPress={() => handlePressConversation(item)}
        onDelete={() => handleDeleteConversation(item.id)}
        onMute={() => handleMuteConversation(item.id)}
      />
    ),
    [handlePressConversation, handleDeleteConversation, handleMuteConversation],
  );

  const renderListHeader = useCallback(() => (
    <OnlineFriendsRow friends={onlineFriends} onPressFriend={handlePressFriend} />
  ), [onlineFriends, handlePressFriend]);

  return (
    <View style={{ flex: 1 }}>
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + 8,
              backgroundColor: themeColors.bgSecondary,
              borderBottomColor: themeColors.border,
            },
          ]}
        >
          <View style={styles.headerLeftBlock}>
            <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Messages</Text>
            <Pressable
              onPress={() => router.push('/search')}
              hitSlop={12}
              style={[styles.headerSearchPill, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons name="search" size={16} color={themeColors.textMuted} />
              <Text style={[styles.headerSearchPlaceholder, { color: themeColors.textMuted }]}>Search</Text>
            </Pressable>
          </View>
          <View style={styles.headerActions}>
            <Pressable
              onPress={() => {/* TODO: new DM */}}
              hitSlop={12}
              style={[styles.newBtn, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons name="create-outline" size={22} color={themeColors.textSecondary} />
            </Pressable>
          </View>
        </View>

        {isLoading && conversations.length === 0 ? (
          <LoadingSpinner fullScreen message="Loading messages..." />
        ) : isError ? (
          <View style={styles.errorContainer}>
            <Text style={[styles.errorText, { color: themeColors.danger }]}>
              {error instanceof Error ? error.message : 'Failed to load messages'}
            </Text>
            <Pressable
              style={[styles.retryButton, { backgroundColor: themeColors.accentPrimary }]}
              onPress={() => refetch()}
            >
              <Text style={styles.retryText}>Retry</Text>
            </Pressable>
          </View>
        ) : conversations.length === 0 ? (
          <EmptyState
            icon="chatbubble-ellipses-outline"
            title="No conversations yet"
            message="Messages from friends will show up here"
          />
        ) : (
          <SectionList
            sections={sections}
            renderItem={renderItem}
            renderSectionHeader={renderSectionHeader}
            ListHeaderComponent={renderListHeader}
            keyExtractor={(item: DMConversation) => item.id}
            contentContainerStyle={{ paddingBottom: insets.bottom + 80 }}
            stickySectionHeadersEnabled={false}
            refreshControl={
              <RefreshControl
                refreshing={isLoading}
                onRefresh={() => refetch()}
                tintColor={themeColors.accentPrimary}
                colors={[themeColors.accentPrimary]}
              />
            }
          />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  headerLeftBlock: {
    flex: 1,
    marginRight: spacing.sm,
    gap: spacing.sm,
  },
  headerTitle: {
    fontSize: 22,
    fontFamily: 'gg-sans-bold',
    marginBottom: 2,
  },
  headerSearchPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 14,
    maxWidth: 280,
  },
  headerSearchPlaceholder: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  headerBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  newBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 34,
    borderRadius: 4,
    paddingHorizontal: spacing.sm,
    gap: spacing.sm,
  },
  searchPlaceholder: {
    fontSize: 14,
  },
  sectionHeader: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  errorText: {
    fontSize: 16,
    textAlign: 'center',
    marginBottom: spacing.lg,
  },
  retryButton: {
    paddingHorizontal: spacing.xl,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
  },
  retryText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    color: '#FFFFFF',
  },
});
