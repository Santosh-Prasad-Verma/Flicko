/**
 * Friends Tab — Discord Mobile Style
 *
 * Shows friend list with tabs: Online / All / Pending / Blocked
 * Add Friend button, search, accept/decline friend requests.
 */
import React, { useCallback, useState, useMemo } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  Pressable,
  RefreshControl,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { supabase } from '../../services/supabase';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { LoadingSpinner } from '../../components/shared/LoadingSpinner';
import { EmptyState } from '../../components/shared/EmptyState';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import {
  applyMaskToProfileObject,
  fetchPrivacyMaskedProfileFields,
} from '@shared/services/privacySettingsService';

type FriendTab = 'online' | 'all' | 'pending' | 'blocked';
const TABS: FriendTab[] = ['online', 'all', 'pending', 'blocked'];

function tabLabel(tab: FriendTab): string {
  switch (tab) {
    case 'online': return 'Online';
    case 'all': return 'All';
    case 'pending': return 'Pending';
    case 'blocked': return 'Blocked';
  }
}

export default function FriendsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const [activeTab, setActiveTab] = useState<FriendTab>('online');
  const [showAddModal, setShowAddModal] = useState(false);
  const [addUsername, setAddUsername] = useState('');
  const [addError, setAddError] = useState('');
  const [addLoading, setAddLoading] = useState(false);

  const { data: friends = [], isLoading, refetch } = useQuery({
    queryKey: ['friends', user?.id, activeTab],
    queryFn: async () => {
      const uid = user?.id;
      const maskRows = async (rows: any[]) => {
        const ids = new Set<string>();
        for (const row of rows) {
          if (row.sender_id && row.sender_id !== uid) ids.add(row.sender_id);
          if (row.receiver_id && row.receiver_id !== uid) ids.add(row.receiver_id);
        }
        const mask = await fetchPrivacyMaskedProfileFields([...ids]);
        return rows.map((row) => ({
          ...row,
          sender: applyMaskToProfileObject(row.sender, mask),
          receiver: applyMaskToProfileObject(row.receiver, mask),
        }));
      };

      if (activeTab === 'pending') {
        const { data, error } = await supabase
          .from('friend_requests')
          .select('*, sender:profiles!sender_id(*), receiver:profiles!receiver_id(*)')
          .or(`sender_id.eq.${user?.id},receiver_id.eq.${user?.id}`)
          .eq('status', 'pending');
        if (error) throw error;
        return maskRows(data ?? []);
      }
      // All / Online / Blocked — get accepted friendships from friend_requests
      const { data, error } = await supabase
        .from('friend_requests')
        .select('*, sender:profiles!sender_id(*), receiver:profiles!receiver_id(*)')
        .or(`sender_id.eq.${user?.id},receiver_id.eq.${user?.id}`)
        .eq('status', 'accepted');
      if (error) throw error;
      return maskRows(data ?? []);
    },
    enabled: !!user?.id,
    staleTime: 30000, // 30 seconds
    gcTime: 300000, // 5 minutes
    refetchOnMount: false,
    refetchOnWindowFocus: false,
  });

  const handleAddFriend = useCallback(async () => {
    if (!addUsername.trim()) {
      setAddError('Enter a username');
      return;
    }
    setAddLoading(true);
    setAddError('');
    try {
      const { data: targetUser, error: findError } = await supabase
        .from('profiles')
        .select('id')
        .eq('username', addUsername.trim())
        .single();
      if (findError || !targetUser) {
        setAddError('User not found');
        return;
      }
      const { error } = await supabase.from('friend_requests').insert({
        sender_id: user?.id,
        receiver_id: targetUser.id,
        status: 'pending',
      });
      if (error) {
        setAddError(error.message);
        return;
      }
      setShowAddModal(false);
      setAddUsername('');
      refetch();
    } catch (err: any) {
      setAddError(err.message || 'Failed to send request');
    } finally {
      setAddLoading(false);
    }
  }, [addUsername, user?.id, refetch]);

  const handleAccept = useCallback(
    async (requestId: string) => {
      try {
        // Get the request details first
        const { data: req } = await supabase
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .eq('id', requestId)
          .single();

        // Update the friend request to accepted
        await supabase
          .from('friend_requests')
          .update({ status: 'accepted', responded_at: new Date().toISOString() })
          .eq('id', requestId);

        // Also create bidirectional rows in the friends table for compatibility
        if (req) {
          await supabase.from('friends').upsert([
            { user_id: req.sender_id, friend_id: req.receiver_id, status: 'accepted' },
            { user_id: req.receiver_id, friend_id: req.sender_id, status: 'accepted' },
          ], { onConflict: 'user_id,friend_id' }).then(() => {});
        }

        refetch();
      } catch (err) {
        console.error('Failed to accept friend request:', err);
      }
    },
    [refetch],
  );

  const handleDecline = useCallback(
    (requestId: string) => {
      supabase
        .from('friend_requests')
        .update({ status: 'declined' })
        .eq('id', requestId)
        .then(() => refetch());
    },
    [refetch],
  );

  const visibleFriends = useMemo(() => {
    if (activeTab !== 'online') return friends;
    return friends.filter((item: any) => {
      const fd = item.sender_id === user?.id ? item.receiver : item.sender;
      const st = fd?.online_status;
      return st === 'online' || st === 'idle';
    });
  }, [friends, activeTab, user?.id]);

  const renderFriendItem = useCallback(
    ({ item }: { item: any }) => {
      const friendData = activeTab === 'pending'
        ? (item.sender_id === user?.id ? item.receiver : item.sender)
        : (item.sender_id === user?.id ? item.receiver : item.sender);
      const name = friendData?.display_name || friendData?.username || 'User';
      const isPending = activeTab === 'pending';
      const isIncoming = isPending && item.sender_id !== user?.id;

      return (
        <Pressable
          style={({ pressed }) => [
            styles.friendRow,
            { backgroundColor: pressed ? themeColors.bgTertiary : 'transparent' },
          ]}
          onPress={() => router.push(`/profile/${friendData?.id}`)}
          accessibilityRole="button"
          accessibilityLabel={name}
        >
          {/* Avatar with status dot */}
          <View>
            <Avatar name={name} imageUrl={friendData?.avatar || friendData?.avatar_url} size={40} />
          </View>
          <View style={styles.friendInfo}>
            <Text style={[styles.friendName, { color: themeColors.textPrimary }]} numberOfLines={1}>
              {name}
            </Text>
            {friendData?.status_message ? (
              <Text style={[styles.friendStatus, { color: themeColors.textMuted }]} numberOfLines={1}>
                {friendData.status_message}
              </Text>
            ) : isPending ? (
              <Text style={[styles.friendStatus, { color: themeColors.textMuted }]} numberOfLines={1}>
                {isIncoming ? 'Incoming Friend Request' : 'Outgoing Friend Request'}
              </Text>
            ) : null}
          </View>
          {isIncoming && (
            <View style={styles.requestActions}>
              <Pressable
                onPress={() => handleAccept(item.id)}
                style={[styles.actionCircle, { backgroundColor: themeColors.bgTertiary }]}
                accessibilityLabel="Accept friend request"
              >
                <Ionicons name="checkmark" size={20} color={themeColors.success} />
              </Pressable>
              <Pressable
                onPress={() => handleDecline(item.id)}
                style={[styles.actionCircle, { backgroundColor: themeColors.bgTertiary }]}
                accessibilityLabel="Decline friend request"
              >
                <Ionicons name="close" size={20} color={themeColors.danger} />
              </Pressable>
            </View>
          )}
        </Pressable>
      );
    },
    [themeColors, activeTab, user?.id, handleAccept, handleDecline],
  );

  return (
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
        <Pressable
          onPress={() => router.push('/search')}
          hitSlop={12}
          style={[styles.headerBtn, { backgroundColor: themeColors.bgTertiary, marginRight: 'auto' }]}
        >
          <Ionicons name="search" size={24} color={themeColors.textPrimary} />
        </Pressable>

        <View style={styles.headerActions}>
          <Pressable
            onPress={() => setShowAddModal(true)}
            hitSlop={12}
            accessibilityRole="button"
            accessibilityLabel="Add friend"
            style={[styles.addButton, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Ionicons name="person-add" size={20} color={themeColors.textSecondary} />
          </Pressable>
        </View>
      </View>

      {/* Tab bar — Discord style pill tabs */}
      <View style={[styles.tabBar, { borderBottomColor: themeColors.border }]}>
        {TABS.map((tab) => {
          const isActive = activeTab === tab;
          return (
            <Pressable
              key={tab}
              onPress={() => setActiveTab(tab)}
              style={[
                styles.tabPill,
                {
                  backgroundColor: isActive ? themeColors.bgModifierSelected : 'transparent',
                },
              ]}
            >
              <Text
                style={[
                  styles.tabText,
                  { color: isActive ? themeColors.textPrimary : themeColors.textMuted },
                ]}
              >
                {tabLabel(tab)}
              </Text>
            </Pressable>
          );
        })}
      </View>

      {/* Add Friend banner */}
      <Pressable
        onPress={() => setShowAddModal(true)}
        style={[styles.addBanner, { backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}
      >
        <View style={[styles.addBannerIcon, { backgroundColor: themeColors.accentPrimary }]}>
          <Ionicons name="person-add" size={18} color="#FFFFFF" />
        </View>
        <Text style={[styles.addBannerText, { color: themeColors.textPrimary }]}>Add Friend</Text>
        <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
      </Pressable>

      {/* Friend count header row */}
      <View style={styles.countRow}>
        <Text style={[styles.countText, { color: themeColors.textMuted }]}>
          {tabLabel(activeTab).toUpperCase()} — {friends.length}
        </Text>
      </View>

      {isLoading && friends.length === 0 ? (
        <LoadingSpinner fullScreen message="Loading friends..." />
      ) : visibleFriends.length === 0 ? (
        <EmptyState
          icon="people-outline"
          title={activeTab === 'all' ? 'No friends yet' : activeTab === 'pending' ? 'No pending requests' : activeTab === 'online' ? 'No one online' : 'Nobody here'}
          message={activeTab === 'all' ? 'Add friends to start chatting' : activeTab === 'online' ? 'Friends will appear here when they are online or idle' : 'It\'s quiet here...'}
        />
      ) : (
        <FlatList
          data={visibleFriends}
          renderItem={renderFriendItem}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingBottom: insets.bottom + 80 }}
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

      {/* Add Friend Modal */}
      <Modal visible={showAddModal} onClose={() => { setShowAddModal(false); setAddError(''); setAddUsername(''); }} title="Add Friend">
        <Text style={[styles.modalDesc, { color: themeColors.textSecondary }]}>
          You can add friends with their Flicko username.
        </Text>
        <Input
          label=""
          placeholder="Enter a username"
          value={addUsername}
          onChangeText={(v: string) => { setAddUsername(v); setAddError(''); }}
          error={addError}
          autoCapitalize="none"
          autoCorrect={false}
          returnKeyType="done"
          onSubmitEditing={handleAddFriend}
        />
        <Button
          title="Send Friend Request"
          onPress={handleAddFriend}
          loading={addLoading}
          disabled={addLoading}
          fullWidth
        />
      </Modal>
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
  headerTitle: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
  },
  addButton: {
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
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    gap: spacing.xs,
    borderBottomWidth: 1,
  },
  tabPill: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  tabText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  addBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
    marginHorizontal: spacing.md,
    marginTop: spacing.xs,
    borderRadius: 8,
    borderWidth: 1,
  },
  addBannerIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addBannerText: {
    flex: 1,
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
    marginLeft: spacing.md,
  },
  countRow: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    marginTop: spacing.xs,
  },
  countText: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
  },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 11,
  },
  friendInfo: {
    flex: 1,
    marginLeft: spacing.md,
  },
  friendName: {
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
  },
  friendStatus: {
    fontSize: 13,
    marginTop: 2,
  },
  requestActions: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  actionCircle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalDesc: {
    fontSize: 14,
    marginBottom: spacing.md,
  },
});
