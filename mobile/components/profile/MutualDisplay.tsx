/**
 * Mutual Servers & Friends Display (Feature 13)
 *
 * Shows mutual servers and mutual friends when viewing a user profile.
 * Queries Supabase for shared servers and shared friendships.
 */
import React, { memo, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../ui/Avatar';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { supabase } from '@services/supabase';

interface MutualServer {
  id: string;
  name: string;
  icon_url?: string;
}

interface MutualFriend {
  id: string;
  username: string;
  display_name?: string;
  avatar_url?: string;
  status?: string;
}

interface MutualDisplayProps {
  currentUserId: string;
  targetUserId: string;
  onServerPress?: (serverId: string) => void;
  onFriendPress?: (userId: string) => void;
}

export const MutualDisplay = memo(function MutualDisplay({
  currentUserId,
  targetUserId,
  onServerPress,
  onFriendPress,
}: MutualDisplayProps) {
  const { themeColors } = useTheme();
  const [mutualServers, setMutualServers] = useState<MutualServer[]>([]);
  const [mutualFriends, setMutualFriends] = useState<MutualFriend[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!currentUserId || !targetUserId || currentUserId === targetUserId) return;
    let cancelled = false;

    (async () => {
      setLoading(true);
      try {
        // Mutual servers: servers where both users are members
        const { data: servers } = await supabase.rpc('get_mutual_servers', {
          user_a: currentUserId,
          user_b: targetUserId,
        });
        if (!cancelled && servers) setMutualServers(servers);

        // Mutual friends: users who are friends with both
        const { data: friends } = await supabase.rpc('get_mutual_friends', {
          user_a: currentUserId,
          user_b: targetUserId,
        });
        if (!cancelled && friends) setMutualFriends(friends);
      } catch (err) {
        console.error('[MutualDisplay] load failed:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [currentUserId, targetUserId]);

  if (loading || (mutualServers.length === 0 && mutualFriends.length === 0)) return null;

  return (
    <View style={styles.container}>
      {mutualServers.length > 0 && (
        <>
          <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
            {mutualServers.length} Mutual Server{mutualServers.length !== 1 ? 's' : ''}
          </Text>
          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
            {mutualServers.map((server) => (
              <Pressable
                key={server.id}
                style={styles.itemRow}
                onPress={() => onServerPress?.(server.id)}
              >
                {server.icon_url ? (
                  <Image source={{ uri: server.icon_url }} style={styles.serverIcon} />
                ) : (
                  <View style={[styles.serverIconPlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
                    <Text style={[styles.serverInitial, { color: themeColors.textMuted }]}>
                      {server.name.charAt(0).toUpperCase()}
                    </Text>
                  </View>
                )}
                <Text style={[styles.itemName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                  {server.name}
                </Text>
              </Pressable>
            ))}
          </View>
        </>
      )}

      {mutualFriends.length > 0 && (
        <>
          <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
            {mutualFriends.length} Mutual Friend{mutualFriends.length !== 1 ? 's' : ''}
          </Text>
          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
            {mutualFriends.map((friend) => (
              <Pressable
                key={friend.id}
                style={styles.itemRow}
                onPress={() => onFriendPress?.(friend.id)}
              >
                <Avatar
                  name={friend.display_name || friend.username}
                  imageUrl={friend.avatar_url}
                  size={32}
                />
                <View style={styles.friendInfo}>
                  <Text style={[styles.itemName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                    {friend.display_name || friend.username}
                  </Text>
                  {friend.status && (
                    <Text style={[styles.friendStatus, { color: themeColors.textMuted }]} numberOfLines={1}>
                      {friend.status}
                    </Text>
                  )}
                </View>
              </Pressable>
            ))}
          </View>
        </>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  sectionLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
  },
  card: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    gap: spacing.sm,
  },
  serverIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
  },
  serverIconPlaceholder: {
    width: 32,
    height: 32,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  serverInitial: {
    fontSize: 14,
    fontFamily: 'gg-sans-bold',
  },
  itemName: {
    ...typography.body,
    fontFamily: 'gg-sans-medium',
    flex: 1,
  },
  friendInfo: {
    flex: 1,
  },
  friendStatus: {
    ...typography.caption,
    marginTop: 1,
  },
});
