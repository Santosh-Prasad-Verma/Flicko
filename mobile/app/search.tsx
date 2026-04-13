/**
 * Search Screen with User Search & Friend Requests
 */
import React, { useState, useMemo, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  FlatList,
  Pressable,
  ActivityIndicator,
  Alert,
  ScrollView,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../services/supabase';
import { Avatar } from '../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../constants/Colors';
import { useTheme } from '../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import {
  useMusicSearch,
  MusicSearchType,
  MusicSearchResult,
  MusicTrack,
  MusicAlbum,
  MusicArtist,
} from '../services/musicApi.service';
import { TrackCard, AlbumCard, ArtistCard } from '../components/music';

type SearchTab = 'users' | 'channels' | 'messages' | 'music';

interface SearchableChannel {
  id: string;
  name: string;
  type: string;
  server_id: string;
  server_name: string;
}

interface MessageResult {
  id: string;
  content: string;
  created_at: string;
  channel_id: string;
  author?: { username: string; display_name?: string };
  channel?: { name: string; server_id: string };
}

interface UserResult {
  id: string;
  username: string;
  display_name?: string;
  avatar?: string;
  status?: string;
  is_friend?: boolean;
  has_pending_request?: boolean;
}

export default function SearchScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: AuthStore) => s.user);
  const [query, setQuery] = useState('');
  const [activeTab, setActiveTab] = useState<SearchTab>('users');
  const [musicType, setMusicType] = useState<MusicSearchType>('track');

  // User search
  const { data: users = [], isLoading: usersLoading } = useQuery({
    queryKey: ['search-users', query.trim()],
    queryFn: async () => {
      const trimmed = query.trim();
      if (!trimmed || trimmed.length < 2) return [];

      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, username, display_name, avatar, status')
        .or(`username.ilike.%${trimmed}%,display_name.ilike.%${trimmed}%`)
        .neq('id', user?.id)
        .limit(20);

      if (!profiles) return [];

      // Check friendship status via friend_requests table
      const profileIds = profiles.map(p => p.id);

      // Check sent requests
      const { data: sentRequests } = await supabase
        .from('friend_requests')
        .select('receiver_id, status')
        .eq('sender_id', user?.id)
        .in('receiver_id', profileIds);

      // Check received requests
      const { data: receivedRequests } = await supabase
        .from('friend_requests')
        .select('sender_id, status')
        .eq('receiver_id', user?.id)
        .in('sender_id', profileIds);

      const sentMap = new Map(sentRequests?.map(r => [r.receiver_id, r.status]) || []);
      const recvMap = new Map(receivedRequests?.map(r => [r.sender_id, r.status]) || []);

      return profiles.map(p => {
        const sentStatus = sentMap.get(p.id);
        const recvStatus = recvMap.get(p.id);
        const isFriend = sentStatus === 'accepted' || recvStatus === 'accepted';
        const isPending = sentStatus === 'pending' || recvStatus === 'pending';
        return {
          ...p,
          is_friend: isFriend,
          has_pending_request: isPending,
        };
      });
    },
    enabled: activeTab === 'users' && query.trim().length >= 2,
  });

  // Send friend request mutation
  const sendRequestMutation = useMutation({
    mutationFn: async (friendId: string) => {
      const { error } = await supabase
        .from('friend_requests')
        .insert({
          sender_id: user?.id,
          receiver_id: friendId,
          status: 'pending',
        });
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['search-users'] });
      Alert.alert('Success', 'Friend request sent!');
    },
    onError: (error: Error) => {
      Alert.alert('Error', error.message);
    },
  });

  // Channels
  const { data: channels, isLoading: channelsLoading } = useQuery({
    queryKey: ['search-channels'],
    queryFn: async () => {
      const { data: memberships } = await supabase
        .from('server_members')
        .select('server_id, servers!inner(id, name)')
        .eq('user_id', user?.id);

      if (!memberships || memberships.length === 0) return [];

      const serverIds = memberships.map((m: any) => m.server_id);
      const serverMap = new Map<string, string>();
      memberships.forEach((m: any) => {
        const server = (m as any).servers;
        if (server) serverMap.set(server.id, server.name);
      });

      const { data: allChannels } = await supabase
        .from('channels')
        .select('id, name, type, server_id')
        .in('server_id', serverIds)
        .order('name');

      return (allChannels ?? []).map((c): SearchableChannel => ({
        ...c,
        server_name: serverMap.get(c.server_id) || 'Unknown Server',
      }));
    },
    enabled: activeTab === 'channels',
  });

  const filteredChannels = useMemo(() => {
    if (!channels) return [];
    if (!query.trim()) return channels;
    const q = query.toLowerCase();
    return channels.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.server_name.toLowerCase().includes(q),
    );
  }, [channels, query]);

  // Messages
  const trimmed = query.trim();
  const { data: messageResults = [], isLoading: messagesLoading } = useQuery({
    queryKey: ['search-messages', trimmed],
    queryFn: async () => {
      if (!trimmed || trimmed.length < 2) return [];
      const { data, error } = await supabase
        .from('messages')
        .select(`
          id, content, created_at, channel_id,
          author:profiles!author_id(username, display_name),
          channel:channels!channel_id(name, server_id)
        `)
        .textSearch('content', trimmed)
        .order('created_at', { ascending: false })
        .limit(30);
      if (error) throw error;
      return (data ?? []).map((row: any): MessageResult => ({
        id: row.id,
        content: row.content,
        created_at: row.created_at,
        channel_id: row.channel_id,
        author: Array.isArray(row.author) ? row.author[0] : row.author,
        channel: Array.isArray(row.channel) ? row.channel[0] : row.channel,
      }));
    },
    enabled: activeTab === 'messages' && trimmed.length >= 2,
  });

  // Music search
  const {
    data: musicResults = [],
    isLoading: musicLoading,
  } = useMusicSearch({
    query: trimmed,
    type: musicType,
    limit: 30,
    enabled: activeTab === 'music',
  });

  const musicSearchEnabled = activeTab === 'music' && trimmed.length >= 2;

  const formatTime = (ts: string) => {
    const d = new Date(ts);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    if (diff < 86400000) return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  const renderUser = useCallback(({ item }: { item: UserResult }) => (
    <Pressable
      style={({ pressed }) => [
        styles.resultRow,
        pressed && { backgroundColor: themeColors.bgTertiary },
      ]}
      onPress={() => router.push(`/profile/${item.id}`)}
    >
      <Avatar name={item.display_name || item.username} imageUrl={item.avatar} size={40} />
      <View style={styles.resultInfo}>
        <Text style={[styles.resultName, { color: themeColors.textPrimary }]} numberOfLines={1}>
          {item.display_name || item.username}
        </Text>
        <Text style={[styles.resultServer, { color: themeColors.textMuted }]} numberOfLines={1}>
          @{item.username}
        </Text>
      </View>
      {item.is_friend ? (
        <View style={[styles.badge, { backgroundColor: themeColors.success }]}>
          <Text style={styles.badgeText}>Friend</Text>
        </View>
      ) : item.has_pending_request ? (
        <View style={[styles.badge, { backgroundColor: themeColors.warning }]}>
          <Text style={styles.badgeText}>Pending</Text>
        </View>
      ) : (
        <Pressable
          style={[styles.addButton, { backgroundColor: themeColors.accentPrimary }]}
          onPress={() => sendRequestMutation.mutate(item.id)}
          disabled={sendRequestMutation.isPending}
        >
          {sendRequestMutation.isPending ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Ionicons name="person-add" size={18} color="#fff" />
          )}
        </Pressable>
      )}
    </Pressable>
  ), [themeColors, sendRequestMutation]);

  const renderMessage = useCallback(({ item }: { item: MessageResult }) => (
    <Pressable
      style={[styles.resultRow, { minHeight: 56 }]}
      onPress={() => {
        if (item.channel?.server_id) {
          router.push(`/server/${item.channel.server_id}/channel/${item.channel_id}` as any);
        }
      }}
    >
      <Ionicons name="chatbox" size={20} color={themeColors.textMuted} />
      <View style={styles.resultInfo}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
          <Text style={[styles.resultName, { color: themeColors.accentPrimary }]} numberOfLines={1}>
            {item.author?.display_name || item.author?.username || 'Unknown'}
          </Text>
          {item.channel && (
            <Text style={[styles.resultServer, { color: themeColors.textMuted }]}>
              #{item.channel.name}
            </Text>
          )}
          <Text style={[styles.resultServer, { color: themeColors.textMuted, marginLeft: 'auto' }]}>
            {formatTime(item.created_at)}
          </Text>
        </View>
        <Text style={[styles.resultServer, { color: themeColors.textPrimary }]} numberOfLines={2}>
          {item.content}
        </Text>
      </View>
    </Pressable>
  ), [themeColors]);

  const renderMusicResult = useCallback(({ item }: { item: MusicSearchResult }) => {
    switch (item.type) {
      case 'track':
        return <TrackCard track={item as MusicTrack} />;
      case 'album':
        return <AlbumCard album={item as MusicAlbum} />;
      case 'artist':
        return <ArtistCard artist={item as MusicArtist} />;
      default:
        return null;
    }
  }, []);

  const renderChannel = ({ item }: { item: SearchableChannel }) => (
    <Pressable
      style={({ pressed }) => [
        styles.resultRow,
        pressed && { backgroundColor: themeColors.bgTertiary },
      ]}
      onPress={() => router.push(`/server/${item.server_id}/channel/${item.id}`)}
    >
      <Ionicons
        name={item.type === 'voice' ? 'volume-high' : 'chatbox'}
        size={20}
        color={themeColors.textMuted}
      />
      <View style={styles.resultInfo}>
        <Text style={[styles.resultName, { color: themeColors.textPrimary }]} numberOfLines={1}>
          {item.name}
        </Text>
        <Text style={[styles.resultServer, { color: themeColors.textMuted }]} numberOfLines={1}>
          {item.server_name}
        </Text>
      </View>
    </Pressable>
  );

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Search',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8} accessibilityLabel="Go back" accessibilityRole="button">
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
          headerRight: () => (
            <Pressable
              onPress={() => router.push('/advanced-search')}
              hitSlop={8}
              accessibilityLabel="Advanced search"
              accessibilityRole="button"
            >
              <Ionicons name="options" size={22} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.searchBox, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="search" size={18} color={themeColors.textMuted} />
          <TextInput
            style={[styles.searchInput, { color: themeColors.textPrimary }]}
            placeholder="Search users, channels & messages..."
            placeholderTextColor={themeColors.textMuted}
            value={query}
            onChangeText={setQuery}
            autoFocus
            returnKeyType="search"
            accessibilityLabel="Search users, channels and messages"
          />
          {query.length > 0 && (
            <Pressable onPress={() => setQuery('')} hitSlop={8} accessibilityLabel="Clear search" accessibilityRole="button">
              <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </View>

        <View style={styles.tabRow}>
          {(['users', 'channels', 'messages', 'music'] as SearchTab[]).map((tab) => (
            <Pressable
              key={tab}
              style={[
                styles.tab,
                activeTab === tab && { borderBottomColor: themeColors.accentPrimary, borderBottomWidth: 2 },
              ]}
              onPress={() => setActiveTab(tab)}
              accessibilityLabel={`Search ${tab} tab`}
              accessibilityRole="tab"
              accessibilityState={{ selected: activeTab === tab }}
            >
              <Text style={[styles.tabText, { color: activeTab === tab ? themeColors.accentPrimary : themeColors.textMuted }]}>
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
              </Text>
            </Pressable>
          ))}
        </View>

        {activeTab === 'users' ? (
          usersLoading ? (
            <View style={styles.center}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : users.length === 0 ? (
            <View style={styles.center}>
              <Ionicons name="people-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                {query.trim().length < 2 ? 'Type at least 2 characters' : 'No users found'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={users}
              renderItem={renderUser}
              keyExtractor={(item) => item.id}
              contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
              keyboardShouldPersistTaps="handled"
            />
          )
        ) : activeTab === 'channels' ? (
          channelsLoading ? (
            <View style={styles.center}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : filteredChannels.length === 0 ? (
            <View style={styles.center}>
              <Ionicons name="search-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                {query.trim() ? 'No results found' : 'Start typing to search channels'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={filteredChannels}
              renderItem={renderChannel}
              keyExtractor={(item) => item.id}
              contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
              keyboardShouldPersistTaps="handled"
            />
          )
        ) : activeTab === 'messages' ? (
          messagesLoading ? (
            <View style={styles.center}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : messageResults.length === 0 ? (
            <View style={styles.center}>
              <Ionicons name="chatbox-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                {trimmed.length < 2 ? 'Type at least 2 characters' : 'No messages found'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={messageResults}
              renderItem={renderMessage}
              keyExtractor={(item) => item.id}
              contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
              keyboardShouldPersistTaps="handled"
            />
          )
        ) : (
          /* Music Tab */
          <View style={styles.musicContainer}>
            {/* Music Type Filters */}
            <View style={styles.filterRow}>
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={styles.filterScroll}
              >
                {(['track', 'album', 'artist'] as MusicSearchType[]).map((type) => (
                  <Pressable
                    key={type}
                    style={[
                      styles.filterChip,
                      { backgroundColor: musicType === type ? themeColors.accentPrimary : themeColors.bgTertiary },
                    ]}
                    onPress={() => setMusicType(type)}
                  >
                    <Text
                      style={[
                        styles.filterChipText,
                        { color: musicType === type ? '#fff' : themeColors.textMuted },
                      ]}
                    >
                      {type.charAt(0).toUpperCase() + type.slice(1)}s
                    </Text>
                  </Pressable>
                ))}
                {/* Apple Music badge */}
                <View style={[styles.filterChip, styles.sourceBadge]}>
                  <Ionicons name="logo-apple" size={14} color="#FA57C1" />
                  <Text style={[styles.filterChipText, { color: '#FA57C1' }]}>
                    Apple Music
                  </Text>
                </View>
              </ScrollView>
            </View>

            {/* Music Results */}
            {musicLoading && musicSearchEnabled ? (
              <View style={styles.center}>
                <ActivityIndicator color={themeColors.accentPrimary} />
              </View>
            ) : musicResults.length === 0 ? (
              <View style={styles.center}>
                <Ionicons name="musical-notes-outline" size={48} color={themeColors.textMuted} />
                <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                  {trimmed.length < 2 ? 'Type at least 2 characters' : 'No music found'}
                </Text>
              </View>
            ) : (
              <FlatList
                data={musicResults}
                renderItem={renderMusicResult}
                keyExtractor={(item) => `${item.source}-${item.id}`}
                contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
                keyboardShouldPersistTaps="handled"
              />
            )}
          </View>
        )}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: spacing.md,
    paddingHorizontal: spacing.sm,
    borderRadius: 8,
    height: 40,
    gap: spacing.xs,
  },
  searchInput: {
    flex: 1,
    ...typography.body,
    paddingVertical: 0,
  },
  tabRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.1)',
    paddingHorizontal: spacing.md,
  },
  tab: {
    paddingVertical: spacing.sm,
    marginRight: spacing.lg,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.md,
  },
  emptyText: {
    ...typography.body,
    textAlign: 'center',
  },
  resultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  resultInfo: { flex: 1 },
  resultName: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  resultServer: {
    ...typography.caption,
    marginTop: 1,
  },
  badge: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    borderRadius: 12,
  },
  badgeText: {
    color: '#fff',
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  addButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  musicContainer: {
    flex: 1,
  },
  filterRow: {
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.1)',
  },
  filterScroll: {
    paddingHorizontal: spacing.md,
    gap: spacing.xs,
    flexDirection: 'row',
  },
  filterChip: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 6,
    borderRadius: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  filterChipText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  sourceBadge: {
    backgroundColor: 'rgba(250, 87, 193, 0.15)',
    marginLeft: spacing.sm,
  },
});
