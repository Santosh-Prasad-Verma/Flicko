/**
 * PinnedMessagesModal
 *
 * Displays pinned messages for a channel in a bottom sheet modal.
 * Requirements: Feature 11 (Pinned Messages)
 */
import React, { memo, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  FlatList,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface PinnedMessage {
  id: string;
  content: string;
  created_at: string;
  author?: { username: string; display_name?: string; avatar_url?: string };
}

interface PinnedMessagesModalProps {
  visible: boolean;
  onClose: () => void;
  channelId: string;
  canManage?: boolean;
  onJumpToMessage?: (messageId: string) => void;
}

export const PinnedMessagesModal = memo(function PinnedMessagesModal({
  visible,
  onClose,
  channelId,
  canManage = false,
  onJumpToMessage,
}: PinnedMessagesModalProps) {
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: pinned = [], isLoading } = useQuery({
    queryKey: ['pinned-messages', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('messages')
        .select('id, content, created_at, author:profiles!author_id(username, display_name, avatar_url:avatar)')
        .eq('channel_id', channelId)
        .eq('pinned', true)
        .order('created_at', { ascending: false });
      if (error) throw error;
      // Supabase returns joined relations; normalise author to a single object
      return (data ?? []).map((row: any) => ({
        ...row,
        author: Array.isArray(row.author) ? row.author[0] : row.author,
      })) as PinnedMessage[];
    },
    enabled: visible && !!channelId,
  });

  const unpinMutation = useMutation({
    mutationFn: async (messageId: string) => {
      const { error } = await supabase
        .from('messages')
        .update({ pinned: false })
        .eq('id', messageId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pinned-messages', channelId] });
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  const formatTime = (ts: string) => {
    const d = new Date(ts);
    return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  const renderPin = useCallback(
    ({ item }: { item: PinnedMessage }) => (
      <Pressable
        style={[styles.pinCard, { backgroundColor: themeColors.bgTertiary }]}
        onPress={() => {
          onJumpToMessage?.(item.id);
          onClose();
        }}
      >
        <View style={styles.pinHeader}>
          <Text style={[styles.pinAuthor, { color: themeColors.accentPrimary }]}>
            {item.author?.display_name || item.author?.username || 'Unknown'}
          </Text>
          <Text style={[styles.pinDate, { color: themeColors.textMuted }]}>
            {formatTime(item.created_at)}
          </Text>
        </View>
        <Text style={[styles.pinContent, { color: themeColors.textPrimary }]} numberOfLines={3}>
          {item.content}
        </Text>
        {canManage && (
          <Pressable
            onPress={() => unpinMutation.mutate(item.id)}
            style={styles.unpinBtn}
            hitSlop={8}
          >
            <Ionicons name="close-circle-outline" size={16} color={themeColors.textMuted} />
            <Text style={[styles.unpinText, { color: themeColors.textMuted }]}>Unpin</Text>
          </Pressable>
        )}
      </Pressable>
    ),
    [themeColors, canManage, unpinMutation, onClose, onJumpToMessage],
  );

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <Pressable style={[styles.overlay, { backgroundColor: themeColors.overlay }]} onPress={onClose}>
        <Pressable style={[styles.sheet, { backgroundColor: themeColors.bgSecondary }]} onPress={() => {}}>
          <View style={[styles.sheetHeader, { borderBottomColor: themeColors.border }]}>
            <Ionicons name="pin" size={18} color={themeColors.accentPrimary} />
            <Text style={[styles.sheetTitle, { color: themeColors.textPrimary }]}>
              Pinned Messages
            </Text>
            <Pressable onPress={onClose} hitSlop={12}>
              <Ionicons name="close" size={24} color={themeColors.textSecondary} />
            </Pressable>
          </View>
          <FlatList
            data={pinned}
            renderItem={renderPin}
            keyExtractor={(item) => item.id}
            contentContainerStyle={styles.list}
            ListEmptyComponent={
              isLoading ? (
                <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
              ) : (
                <View style={styles.emptyState}>
                  <Ionicons name="pin-outline" size={40} color={themeColors.textMuted} />
                  <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                    No pinned messages
                  </Text>
                </View>
              )
            }
          />
        </Pressable>
      </Pressable>
    </Modal>
  );
});

const styles = StyleSheet.create({
  overlay: { flex: 1, justifyContent: 'flex-end' },
  sheet: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl, maxHeight: '70%' },
  sheetHeader: { flexDirection: 'row', alignItems: 'center', padding: spacing.lg, borderBottomWidth: 1, gap: spacing.sm },
  sheetTitle: { ...typography.headingS, flex: 1 },
  list: { padding: spacing.md, gap: spacing.sm },
  pinCard: { padding: spacing.md, borderRadius: borderRadius.md },
  pinHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.xs },
  pinAuthor: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  pinDate: { ...typography.caption },
  pinContent: { ...typography.bodySmall },
  unpinBtn: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, marginTop: spacing.sm },
  unpinText: { ...typography.micro },
  loader: { marginTop: spacing.xxxxl },
  emptyState: { alignItems: 'center', paddingTop: spacing.xxxxl, gap: spacing.md },
  emptyText: { ...typography.bodySmall },
});
