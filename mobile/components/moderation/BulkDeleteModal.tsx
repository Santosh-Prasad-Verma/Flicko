/**
 * Bulk Message Delete / Prune (Feature 29)
 *
 * Moderator tool to delete many messages at once with filters:
 * - /purge <count>
 * - /purge @user <count>
 * - /purge bots <count>
 * - /purge links <count>
 * - /purge attachments <count>
 * Maximum 100 messages, only <14 days old.
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import { supabase } from '@services/supabase';

type PurgeFilter = 'all' | 'user' | 'bots' | 'links' | 'attachments';

const FILTER_OPTIONS: { key: PurgeFilter; label: string; icon: string }[] = [
  { key: 'all', label: 'All Messages', icon: 'chatbubbles-outline' },
  { key: 'user', label: 'From User', icon: 'person-outline' },
  { key: 'bots', label: 'Bot Messages', icon: 'hardware-chip-outline' },
  { key: 'links', label: 'With Links', icon: 'link-outline' },
  { key: 'attachments', label: 'With Attachments', icon: 'attach-outline' },
];

interface Props {
  channelId: string;
  visible: boolean;
  onClose: () => void;
  onComplete?: (deletedCount: number) => void;
}

export const BulkDeleteModal = memo(function BulkDeleteModal({
  channelId,
  visible,
  onClose,
  onComplete,
}: Props) {
  const { themeColors: c } = useTheme();
  const [filter, setFilter] = useState<PurgeFilter>('all');
  const [count, setCount] = useState('25');
  const [userId, setUserId] = useState('');
  const [deleting, setDeleting] = useState(false);

  const handlePurge = useCallback(async () => {
    const numCount = Math.min(parseInt(count, 10) || 25, 100);
    if (numCount <= 0) return;

    const confirmMsg = `Delete up to ${numCount} messages${filter !== 'all' ? ` (${filter})` : ''}?`;
    Alert.alert('Bulk Delete', confirmMsg, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          setDeleting(true);
          try {
            const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();

            let query = supabase
              .from('messages')
              .select('id')
              .eq('channel_id', channelId)
              .gte('created_at', fourteenDaysAgo)
              .order('created_at', { ascending: false })
              .limit(numCount);

            if (filter === 'user' && userId.trim()) {
              query = query.eq('user_id', userId.trim());
            } else if (filter === 'bots') {
              query = query.eq('is_bot', true);
            } else if (filter === 'links') {
              query = query.like('content', '%http%');
            } else if (filter === 'attachments') {
              query = query.not('attachments', 'is', null);
            }

            const { data: messages } = await query;
            if (!messages || messages.length === 0) {
              Alert.alert('No Messages', 'No messages matched your filter criteria.');
              setDeleting(false);
              return;
            }

            const messageIds = messages.map((m) => m.id);

            // Bulk delete via RPC or direct delete
            const { error } = await supabase
              .from('messages')
              .delete()
              .in('id', messageIds);

            if (error) {
              Alert.alert('Error', 'Failed to delete messages.');
            } else {
              onComplete?.(messageIds.length);
              onClose();
            }
          } catch (err) {
            Alert.alert('Error', 'An unexpected error occurred.');
          } finally {
            setDeleting(false);
          }
        },
      },
    ]);
  }, [channelId, filter, count, userId, onClose, onComplete]);

  return (
    <Modal visible={visible} transparent animationType="fade">
      <Pressable style={styles.overlay} onPress={onClose}>
        <Pressable
          style={[styles.modal, { backgroundColor: c.bgSecondary }]}
          onPress={(e) => e.stopPropagation()}
        >
          <Text style={[styles.modalTitle, { color: c.textPrimary }]}>Bulk Delete Messages</Text>
          <Text style={[styles.hint, { color: c.textMuted }]}>
            Only messages less than 14 days old can be deleted. Max 100.
          </Text>

          {/* Count Input */}
          <Text style={[styles.label, { color: c.textMuted }]}>NUMBER OF MESSAGES</Text>
          <TextInput
            style={[styles.input, { backgroundColor: c.bgTertiary, color: c.textPrimary }]}
            value={count}
            onChangeText={setCount}
            keyboardType="numeric"
            placeholder="25"
            placeholderTextColor={c.textMuted}
          />

          {/* Filter Options */}
          <Text style={[styles.label, { color: c.textMuted }]}>FILTER</Text>
          <View style={styles.filterGrid}>
            {FILTER_OPTIONS.map((f) => (
              <Pressable
                key={f.key}
                style={[
                  styles.filterOption,
                  {
                    backgroundColor: filter === f.key ? c.accentPrimary : c.bgTertiary,
                  },
                ]}
                onPress={() => setFilter(f.key)}
              >
                <Ionicons
                  name={f.icon as any}
                  size={16}
                  color={filter === f.key ? '#fff' : c.textMuted}
                />
                <Text
                  style={[
                    styles.filterLabel,
                    { color: filter === f.key ? '#fff' : c.textPrimary },
                  ]}
                >
                  {f.label}
                </Text>
              </Pressable>
            ))}
          </View>

          {/* User ID input for 'user' filter */}
          {filter === 'user' && (
            <>
              <Text style={[styles.label, { color: c.textMuted }]}>USER ID</Text>
              <TextInput
                style={[styles.input, { backgroundColor: c.bgTertiary, color: c.textPrimary }]}
                value={userId}
                onChangeText={setUserId}
                placeholder="Enter user ID"
                placeholderTextColor={c.textMuted}
              />
            </>
          )}

          {/* Actions */}
          <View style={styles.actions}>
            <Pressable
              style={[styles.btn, { backgroundColor: c.bgTertiary }]}
              onPress={onClose}
            >
              <Text style={[styles.btnText, { color: c.textPrimary }]}>Cancel</Text>
            </Pressable>
            <Pressable
              style={[styles.btn, { backgroundColor: '#ED4245', opacity: deleting ? 0.6 : 1 }]}
              onPress={handlePurge}
              disabled={deleting}
            >
              {deleting ? (
                <ActivityIndicator color="#fff" size="small" />
              ) : (
                <Text style={[styles.btnText, { color: '#fff' }]}>Delete</Text>
              )}
            </Pressable>
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
});

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    padding: spacing.md,
  },
  modal: { borderRadius: 16, padding: spacing.md },
  modalTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  hint: { ...typography.caption, marginBottom: spacing.md },
  label: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 6,
    marginTop: spacing.sm,
  },
  input: {
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    fontFamily: 'gg-sans',
  },
  filterGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  filterOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    gap: 6,
  },
  filterLabel: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  actions: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  btn: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  btnText: { fontFamily: 'gg-sans-bold', fontSize: 15 },
});
