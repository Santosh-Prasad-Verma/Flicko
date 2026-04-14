/**
 * Audit Log with Filters (Feature 26)
 *
 * Detailed audit log viewer with filtering by:
 * - Action type (message deleted, member banned, role created, etc.)
 * - User who performed the action
 * - Target user/entity
 * - Date range
 * Shows before/after diffs for changes.
 */
import React, { memo, useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  TextInput,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import { supabase } from '@services/supabase';

export const AUDIT_ACTION_TYPES = [
  'CHANNEL_CREATE', 'CHANNEL_UPDATE', 'CHANNEL_DELETE',
  'CHANNEL_OVERWRITE_CREATE', 'CHANNEL_OVERWRITE_UPDATE', 'CHANNEL_OVERWRITE_DELETE',
  'MEMBER_KICK', 'MEMBER_BAN_ADD', 'MEMBER_BAN_REMOVE',
  'MEMBER_UPDATE', 'MEMBER_DISCONNECT', 'MEMBER_MOVE',
  'ROLE_CREATE', 'ROLE_UPDATE', 'ROLE_DELETE',
  'INVITE_CREATE', 'INVITE_DELETE',
  'WEBHOOK_CREATE', 'WEBHOOK_UPDATE', 'WEBHOOK_DELETE',
  'EMOJI_CREATE', 'EMOJI_UPDATE', 'EMOJI_DELETE',
  'MESSAGE_DELETE', 'MESSAGE_BULK_DELETE', 'MESSAGE_PIN', 'MESSAGE_UNPIN',
  'THREAD_CREATE', 'THREAD_UPDATE', 'THREAD_DELETE',
  'AUTOMOD_RULE_CREATE', 'AUTOMOD_RULE_UPDATE', 'AUTOMOD_RULE_DELETE',
  'AUTOMOD_BLOCK_MESSAGE',
  'SERVER_UPDATE',
  'BOT_ADD',
] as const;

export type AuditActionType = typeof AUDIT_ACTION_TYPES[number];

const ACTION_ICONS: Record<string, string> = {
  CHANNEL_CREATE: 'add-circle-outline',
  CHANNEL_UPDATE: 'pencil-outline',
  CHANNEL_DELETE: 'trash-outline',
  MEMBER_KICK: 'exit-outline',
  MEMBER_BAN_ADD: 'ban-outline',
  MEMBER_BAN_REMOVE: 'checkmark-circle-outline',
  MEMBER_UPDATE: 'person-outline',
  ROLE_CREATE: 'shield-outline',
  ROLE_UPDATE: 'shield-outline',
  ROLE_DELETE: 'shield-outline',
  MESSAGE_DELETE: 'chatbubble-outline',
  MESSAGE_BULK_DELETE: 'chatbubbles-outline',
  MESSAGE_PIN: 'pin-outline',
  SERVER_UPDATE: 'settings-outline',
  BOT_ADD: 'hardware-chip-outline',
};

interface AuditLogEntry {
  id: string;
  action_type: string;
  user_id: string;
  username: string;
  user_avatar?: string;
  target_id?: string;
  target_name?: string;
  changes?: { key: string; old_value: string; new_value: string }[];
  reason?: string;
  created_at: string;
}

interface Filters {
  actionType: string | null;
  userId: string;
  targetId: string;
}

interface Props {
  serverId: string;
}

export const AuditLogViewer = memo(function AuditLogViewer({ serverId }: Props) {
  const { themeColors: c } = useTheme();
  const [entries, setEntries] = useState<AuditLogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<Filters>({
    actionType: null,
    userId: '',
    targetId: '',
  });
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const fetchLogs = useCallback(
    async (reset = false) => {
      if (reset) setLoading(true);
      else setLoadingMore(true);

      let query = supabase
        .from('audit_log')
        .select('*')
        .eq('server_id', serverId)
        .order('created_at', { ascending: false })
        .limit(50);

      if (filters.actionType) {
        query = query.eq('action_type', filters.actionType);
      }
      if (filters.userId.trim()) {
        query = query.eq('user_id', filters.userId.trim());
      }
      if (filters.targetId.trim()) {
        query = query.eq('target_id', filters.targetId.trim());
      }
      if (!reset && entries.length > 0) {
        query = query.lt('created_at', entries[entries.length - 1].created_at);
      }

      const { data } = await query;
      if (data) {
        setEntries(reset ? data : [...entries, ...data]);
      }
      setLoading(false);
      setLoadingMore(false);
    },
    [serverId, filters, entries]
  );

  useEffect(() => {
    fetchLogs(true);
  }, [serverId, filters.actionType, filters.userId, filters.targetId]);

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const renderEntry = ({ item }: { item: AuditLogEntry }) => {
    const expanded = expandedId === item.id;
    const icon = ACTION_ICONS[item.action_type] ?? 'ellipse-outline';

    return (
      <Pressable
        style={[styles.entryCard, { backgroundColor: c.bgSecondary }]}
        onPress={() => setExpandedId(expanded ? null : item.id)}
      >
        <View style={styles.entryRow}>
          <Ionicons name={icon as any} size={18} color={c.accentPrimary} />
          <View style={styles.entryInfo}>
            <Text style={[styles.entryAction, { color: c.textPrimary }]}>
              {item.action_type.replace(/_/g, ' ')}
            </Text>
            <Text style={[styles.entryMeta, { color: c.textMuted }]}>
              by {item.username} • {formatDate(item.created_at)}
            </Text>
          </View>
          <Ionicons
            name={expanded ? 'chevron-up' : 'chevron-down'}
            size={16}
            color={c.textMuted}
          />
        </View>

        {expanded && (
          <View style={[styles.entryDetails, { borderTopColor: c.bgTertiary }]}>
            {item.target_name && (
              <Text style={[styles.detailText, { color: c.textMuted }]}>
                Target: {item.target_name}
              </Text>
            )}
            {item.reason && (
              <Text style={[styles.detailText, { color: c.textMuted }]}>
                Reason: {item.reason}
              </Text>
            )}
            {item.changes && item.changes.length > 0 && (
              <View style={styles.changesContainer}>
                <Text style={[styles.changesLabel, { color: c.textMuted }]}>Changes:</Text>
                {item.changes.map((change, i) => (
                  <View key={i} style={styles.changeRow}>
                    <Text style={[styles.changeKey, { color: c.textMuted }]}>
                      {change.key}:
                    </Text>
                    <Text style={[styles.changeOld, { color: '#ED4245' }]}>
                      − {change.old_value || '(empty)'}
                    </Text>
                    <Text style={[styles.changeNew, { color: '#57F287' }]}>
                      + {change.new_value || '(empty)'}
                    </Text>
                  </View>
                ))}
              </View>
            )}
          </View>
        )}
      </Pressable>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      {/* Header with filter button */}
      <View style={styles.header}>
        <Text style={[styles.title, { color: c.textPrimary }]}>Audit Log</Text>
        <Pressable
          style={[styles.filterBtn, { backgroundColor: c.bgSecondary }]}
          onPress={() => setShowFilters(true)}
        >
          <Ionicons name="filter" size={18} color={c.textPrimary} />
          <Text style={[styles.filterBtnText, { color: c.textPrimary }]}>Filter</Text>
        </Pressable>
      </View>

      {/* Active filters display */}
      {(filters.actionType || filters.userId || filters.targetId) && (
        <View style={styles.activeFilters}>
          {filters.actionType && (
            <Pressable
              style={[styles.filterChip, { backgroundColor: c.bgTertiary }]}
              onPress={() => setFilters((f) => ({ ...f, actionType: null }))}
            >
              <Text style={[styles.filterChipText, { color: c.textPrimary }]}>
                {filters.actionType.replace(/_/g, ' ')}
              </Text>
              <Ionicons name="close" size={14} color={c.textMuted} />
            </Pressable>
          )}
          {filters.userId && (
            <Pressable
              style={[styles.filterChip, { backgroundColor: c.bgTertiary }]}
              onPress={() => setFilters((f) => ({ ...f, userId: '' }))}
            >
              <Text style={[styles.filterChipText, { color: c.textPrimary }]}>
                User: {filters.userId.slice(0, 8)}...
              </Text>
              <Ionicons name="close" size={14} color={c.textMuted} />
            </Pressable>
          )}
        </View>
      )}

      {loading ? (
        <ActivityIndicator color={c.accentPrimary} style={{ marginTop: 40 }} />
      ) : (
        <FlatList
          data={entries}
          keyExtractor={(e) => e.id}
          renderItem={renderEntry}
          contentContainerStyle={styles.listContent}
          onEndReached={() => !loadingMore && fetchLogs(false)}
          onEndReachedThreshold={0.3}
          ListFooterComponent={
            loadingMore ? (
              <ActivityIndicator color={c.accentPrimary} style={{ padding: 16 }} />
            ) : null
          }
          ListEmptyComponent={
            <Text style={[styles.emptyText, { color: c.textMuted }]}>
              No audit log entries found
            </Text>
          }
        />
      )}

      {/* Filter Modal */}
      <Modal visible={showFilters} transparent animationType="fade">
        <Pressable style={styles.modalOverlay} onPress={() => setShowFilters(false)}>
          <Pressable
            style={[styles.filterModal, { backgroundColor: c.bgSecondary }]}
            onPress={(e) => e.stopPropagation()}
          >
            <Text style={[styles.filterModalTitle, { color: c.textPrimary }]}>Filters</Text>

            <Text style={[styles.label, { color: c.textMuted }]}>ACTION TYPE</Text>
            <FlatList
              data={[{ type: null, label: 'All Actions' }, ...AUDIT_ACTION_TYPES.map((t) => ({ type: t, label: t.replace(/_/g, ' ') }))]}
              keyExtractor={(item) => item.type ?? 'all'}
              style={styles.actionTypeList}
              renderItem={({ item }) => (
                <Pressable
                  style={[
                    styles.actionTypeOption,
                    filters.actionType === item.type && { backgroundColor: c.bgTertiary },
                  ]}
                  onPress={() => {
                    setFilters((f) => ({ ...f, actionType: item.type }));
                    setShowFilters(false);
                  }}
                >
                  <Text style={[styles.actionTypeText, { color: c.textPrimary }]}>
                    {item.label}
                  </Text>
                  {filters.actionType === item.type && (
                    <Ionicons name="checkmark" size={18} color={c.accentPrimary} />
                  )}
                </Pressable>
              )}
            />

            <Text style={[styles.label, { color: c.textMuted }]}>USER ID</Text>
            <TextInput
              style={[styles.filterInput, { backgroundColor: c.bgTertiary, color: c.textPrimary }]}
              value={filters.userId}
              onChangeText={(v) => setFilters((f) => ({ ...f, userId: v }))}
              placeholder="Filter by user ID"
              placeholderTextColor={c.textMuted}
            />

            <Text style={[styles.label, { color: c.textMuted }]}>TARGET ID</Text>
            <TextInput
              style={[styles.filterInput, { backgroundColor: c.bgTertiary, color: c.textPrimary }]}
              value={filters.targetId}
              onChangeText={(v) => setFilters((f) => ({ ...f, targetId: v }))}
              placeholder="Filter by target ID"
              placeholderTextColor={c.textMuted}
            />

            <Pressable
              style={[styles.applyBtn, { backgroundColor: c.accentPrimary }]}
              onPress={() => setShowFilters(false)}
            >
              <Text style={styles.applyBtnText}>Apply Filters</Text>
            </Pressable>
          </Pressable>
        </Pressable>
      </Modal>
    </View>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: spacing.md,
  },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold' },
  filterBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    gap: 6,
  },
  filterBtnText: { fontSize: 14, fontFamily: 'gg-sans-medium' },
  activeFilters: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: spacing.md,
    gap: 6,
    marginBottom: spacing.sm,
  },
  filterChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  filterChipText: { fontSize: 12, fontFamily: 'gg-sans-medium' },
  listContent: { padding: spacing.md, paddingTop: 0 },
  entryCard: {
    borderRadius: 10,
    padding: spacing.sm,
    marginBottom: 8,
  },
  entryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  entryInfo: { flex: 1 },
  entryAction: { fontSize: 14, fontFamily: 'gg-sans-medium' },
  entryMeta: { fontSize: 12, fontFamily: 'gg-sans', marginTop: 1 },
  entryDetails: {
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
  },
  detailText: { fontSize: 13, fontFamily: 'gg-sans', marginBottom: 4 },
  changesContainer: { marginTop: 4 },
  changesLabel: { fontSize: 12, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  changeRow: { marginBottom: 4, marginLeft: 8 },
  changeKey: { fontSize: 12, fontFamily: 'gg-sans-medium' },
  changeOld: { fontSize: 12, fontFamily: 'gg-sans' },
  changeNew: { fontSize: 12, fontFamily: 'gg-sans' },
  emptyText: { textAlign: 'center', marginTop: 40, ...typography.body },

  // Filter Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    padding: spacing.md,
  },
  filterModal: {
    borderRadius: 16,
    padding: spacing.md,
    maxHeight: '80%',
  },
  filterModalTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  label: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 6,
    marginTop: spacing.sm,
  },
  actionTypeList: { maxHeight: 200 },
  actionTypeOption: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    paddingHorizontal: 8,
    borderRadius: 6,
  },
  actionTypeText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  filterInput: {
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    fontFamily: 'gg-sans',
  },
  applyBtn: {
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  applyBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },
});
