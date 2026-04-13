/**
 * ReactionDetailModal
 *
 * Shows who reacted with a specific emoji on a message.
 * Displayed when long-pressing a reaction chip.
 */
import React, { memo, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { Modal } from '../ui/Modal';
import { Avatar } from '../ui/Avatar';
import { spacing, typography, borderRadius } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { supabase } from '../../services/supabase';

interface ReactionUser {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
}

interface ReactionDetailModalProps {
  visible: boolean;
  messageId: string | null;
  emoji: string | null;
  onClose: () => void;
  onUserPress?: (userId: string) => void;
}

export const ReactionDetailModal = memo(function ReactionDetailModal({
  visible,
  messageId,
  emoji,
  onClose,
  onUserPress,
}: ReactionDetailModalProps) {
  const { themeColors } = useTheme();
  const [users, setUsers] = useState<ReactionUser[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!visible || !messageId || !emoji) {
      setUsers([]);
      return;
    }

    let cancelled = false;
    setLoading(true);

    (async () => {
      try {
        const { data: reactions, error } = await supabase
          .from('reactions')
          .select('user_id, user:profiles!user_id(id, username, display_name, avatar_url:avatar)')
          .eq('message_id', messageId)
          .eq('emoji', emoji);

        if (error) throw error;
        if (!cancelled) {
          setUsers(
            (reactions ?? []).map((r: any) => ({
              id: r.user?.id ?? r.user_id,
              username: r.user?.username ?? 'Unknown',
              display_name: r.user?.display_name ?? null,
              avatar_url: r.user?.avatar_url ?? null,
            }))
          );
        }
      } catch (err) {
        console.warn('[ReactionDetailModal] Failed to fetch:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [visible, messageId, emoji]);

  const renderUser = ({ item }: { item: ReactionUser }) => (
    <Pressable
      style={styles.userRow}
      onPress={() => onUserPress?.(item.id)}
    >
      <Avatar
        name={item.display_name || item.username}
        imageUrl={item.avatar_url}
        size={36}
      />
      <View style={styles.userInfo}>
        <Text style={[styles.displayName, { color: themeColors.textPrimary }]}>
          {item.display_name || item.username}
        </Text>
        <Text style={[styles.username, { color: themeColors.textMuted }]}>
          @{item.username}
        </Text>
      </View>
    </Pressable>
  );

  return (
    <Modal visible={visible} onClose={onClose}>
      <View style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.emojiDisplay}>{emoji}</Text>
          <Text style={[styles.title, { color: themeColors.textPrimary }]}>
            Reactions · {users.length}
          </Text>
          <Pressable onPress={onClose} hitSlop={12}>
            <Text style={{ color: themeColors.textMuted, fontSize: 18 }}>✕</Text>
          </Pressable>
        </View>

        {/* User list */}
        {loading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="small" color={themeColors.accentPrimary} />
          </View>
        ) : (
          <FlatList
            data={users}
            renderItem={renderUser}
            keyExtractor={(item) => item.id}
            contentContainerStyle={styles.list}
            ItemSeparatorComponent={() => (
              <View style={[styles.separator, { backgroundColor: themeColors.border }]} />
            )}
          />
        )}
      </View>
    </Modal>
  );
});

const styles = StyleSheet.create({
  container: {
    borderRadius: borderRadius.lg,
    maxHeight: 400,
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  emojiDisplay: {
    fontSize: 24,
  },
  title: {
    ...typography.headingS,
    flex: 1,
  },
  loadingContainer: {
    padding: spacing.xxxl,
    alignItems: 'center',
  },
  list: {
    paddingVertical: spacing.sm,
  },
  userRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  userInfo: {
    marginLeft: spacing.md,
  },
  displayName: {
    ...typography.bodyBold,
  },
  username: {
    ...typography.caption,
  },
  separator: {
    height: 1,
    marginHorizontal: spacing.lg,
  },
});
