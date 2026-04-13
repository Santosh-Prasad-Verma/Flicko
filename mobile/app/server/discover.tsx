/**
 * Server Discovery Screen
 *
 * Mirrors web ServerDiscoveryPanel. Shows recommended public servers
 * to browse and join.
 * Route: /server/discover
 * Requirements: 3.7, 3.8
 */
import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  ActivityIndicator,
  TextInput,
  GestureResponderEvent,
} from 'react-native';
import { Image } from 'expo-image';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { useAuthStore } from '@stores/authStore';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface DiscoverableServer {
  id: string;
  name: string;
  icon?: string;
  banner?: string;
  description?: string;
  member_count: number;
  online_count?: number;
  is_member: boolean;
}

export default function ServerDiscoveryScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);
  const [search, setSearch] = useState('');
  // Track which server ID is currently being joined (per-item loading).
  const [joiningId, setJoiningId] = useState<string | null>(null);

  const { data: servers, isLoading } = useQuery({
    queryKey: ['discover-servers', user?.id, search],
    queryFn: async () => {
      if (!user?.id) throw new Error('Not authenticated');

      const q = search.trim();
      let query = supabase
        .from('servers')
        .select(`
          id,
          name,
          icon,
          banner,
          description,
          members:server_members(count)
        `);
      
      if (q) {
        query = query.ilike('name', `%${q}%`);
      }

      const { data, error } = await query.limit(20);
      if (error) throw error;

      if (!data || data.length === 0) return [];

      const serverIds = data.map((s) => s.id);

      const { data: memberships } = await supabase
        .from('server_members')
        .select('server_id')
        .eq('user_id', user.id)
        .in('server_id', serverIds);

      const membershipSet = new Set(memberships?.map((m) => m.server_id) || []);

      return data.map((s: any) => ({
        id: s.id,
        name: s.name,
        icon: s.icon,
        banner: s.banner,
        description: s.description,
        member_count: s.members?.[0]?.count || 1,
        online_count: Math.floor((s.members?.[0]?.count || 1) * 0.3),
        is_member: membershipSet.has(s.id),
      })) as DiscoverableServer[];
    },
  });

  const filteredServers = useMemo(() => {
    if (!servers) return [];
    if (!search.trim()) return servers;
    const q = search.trim().toLowerCase();
    return servers.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.description?.toLowerCase().includes(q),
    );
  }, [servers, search]);

  const joinMutation = useMutation({
    mutationFn: async (sid: string) => {
      if (!user?.id) throw new Error('Not logged in');
      setJoiningId(sid);
      try {
        const { error } = await supabase.from('server_members').insert({
          server_id: sid,
          user_id: user.id,
        });
        if (error) throw error;

        // Post a system welcome message in the first text channel
        try {
          const { data: firstChannel } = await supabase
            .from('channels')
            .select('id')
            .eq('server_id', sid)
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
          // Non-critical, don't block join
          console.warn('Failed to post welcome message:', e);
        }
        return sid;
      } catch (e) {
        throw e;
      }
    },
    onSettled: () => setJoiningId(null),
    onSuccess: (sid) => {
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      queryClient.invalidateQueries({ queryKey: ['discover-servers'] });
      router.push(`/server/${sid}`);
    },
  });

  const renderServer = ({ item, index }: { item: DiscoverableServer; index: number }) => (
    <View>
      <Pressable
        style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}
        onPress={() => router.push(`/server/${item.id}`)}
      >
        {/* Banner */}
        {item.banner ? (
          <Image
            source={{ uri: item.banner }}
            style={styles.banner}
            contentFit="cover"
            transition={300}
            autoplay={true}
            cachePolicy="disk"
          />
        ) : (
          <View style={[styles.banner, { backgroundColor: themeColors.accentPrimary }]} />
        )}

        <View style={styles.cardBody}>
          <Avatar
            name={item.name}
            imageUrl={item.icon || undefined}
            size={40}
          />
          <Text
            style={[styles.cardName, { color: themeColors.textPrimary }]}
            numberOfLines={1}
          >
            {item.name}
          </Text>

          {item.description ? (
            <Text
              style={[styles.cardDesc, { color: themeColors.textMuted }]}
              numberOfLines={2}
            >
              {item.description}
            </Text>
          ) : null}

          <View style={styles.cardMeta}>
            <View style={styles.metaItem}>
              <View style={[styles.metaDot, { backgroundColor: '#23a559' }]} />
              <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
                {item.online_count ?? 0} Online
              </Text>
            </View>
            <View style={styles.metaItem}>
              <View style={[styles.metaDot, { backgroundColor: themeColors.textMuted }]} />
              <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
                {item.member_count} Members
              </Text>
            </View>
          </View>

          {item.is_member ? (
            <View style={[styles.joinedBadge, { backgroundColor: themeColors.bgTertiary }]}>
              <Ionicons name="checkmark-circle" size={16} color={themeColors.success} />
              <Text style={[styles.joinedText, { color: themeColors.success }]}>Joined</Text>
            </View>
          ) : (
            // Intercept touch here so it does NOT propagate to the outer card Pressable.
            // Without this, tapping "Join Server" would also trigger card navigation.
            <View
              onStartShouldSetResponder={() => true}
              onTouchEnd={(e: GestureResponderEvent) => e.stopPropagation()}
            >
              <Button
                title={joiningId === item.id ? 'Joining...' : 'Join Server'}
                onPress={() => {
                  if (joiningId !== null) return; // one join at a time
                  joinMutation.mutate(item.id);
                }}
                variant="primary"
                size="sm"
                disabled={joiningId !== null}
              />
            </View>
          )}
        </View>
      </Pressable>
    </View>
  );

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: false,
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
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
          >
            <Ionicons name="arrow-back" size={22} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Discover Servers</Text>
          <View style={styles.iconButton} />
        </View>

        {/* Search Bar */}
        <View style={[styles.searchBar, { backgroundColor: themeColors.inputBg }]}> 
          <Ionicons name="search" size={18} color={themeColors.textMuted} />
          <TextInput
            style={[styles.searchInput, { color: themeColors.textPrimary }]}
            value={search}
            onChangeText={setSearch}
            placeholder="Search servers..."
            placeholderTextColor={themeColors.textMuted}
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="search"
          />
          {search.length > 0 && (
            <Pressable onPress={() => setSearch('')} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </View>

        {isLoading ? (
          <View style={styles.center}>
            <ActivityIndicator color={themeColors.accentPrimary} size="large" />
          </View>
        ) : !filteredServers || filteredServers.length === 0 ? (
          <View style={styles.center}>
            <Text style={{ fontSize: 48, marginBottom: spacing.md }}>
              {search.trim() ? '😕' : '🔍'}
            </Text>
            <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>
              {search.trim() ? 'No Servers Found' : 'No Servers to Discover'}
            </Text>
            <Text style={[styles.emptyDesc, { color: themeColors.textMuted }]}>
              {search.trim()
                ? `No servers match "${search.trim()}". Try a different search.`
                : 'Check back later for recommended communities to join.'}
            </Text>
          </View>
        ) : (
          <FlatList
            data={filteredServers}
            renderItem={renderServer}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{
              padding: spacing.md,
              paddingBottom: insets.bottom + spacing.xxl,
            }}
            ItemSeparatorComponent={() => <View style={{ height: spacing.md }} />}
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
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.sm,
    borderBottomWidth: 1,
  },
  headerTitle: {
    ...typography.headingS,
  },
  iconButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    marginBottom: spacing.xs,
    paddingHorizontal: spacing.sm,
    borderRadius: 6,
    height: 36,
    gap: spacing.xs,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    paddingVertical: 0,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  emptyTitle: {
    ...typography.headingM,
    marginBottom: spacing.xs,
  },
  emptyDesc: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  card: {
    borderRadius: 12,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.06)',
  },
  banner: {
    height: 80,
    width: '100%',
    borderTopLeftRadius: 12,
    borderTopRightRadius: 12,
  },
  cardBody: {
    padding: spacing.md,
    gap: spacing.sm,
  },
  cardName: {
    ...typography.headingM,
  },
  cardDesc: {
    ...typography.bodySmall,
    lineHeight: 20,
  },
  cardMeta: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  metaDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  metaText: {
    ...typography.caption,
  },
  joinedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: 6,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: 6,
  },
  joinedText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
});
