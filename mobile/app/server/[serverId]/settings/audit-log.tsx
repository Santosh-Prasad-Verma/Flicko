/**
 * Audit Log Screen
 *
 * View server audit log entries with action filter.
 * Requirements: Feature 25 (Audit Log)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  ActivityIndicator,
  Image,
} from 'react-native';
import { useLocalSearchParams, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  AuditLogEntry,
  AuditLogAction,
  AUDIT_ACTION_LABELS,
  getAuditLog,
} from '@services/auditLogService';

const ACTION_ICONS: Record<string, keyof typeof Ionicons.glyphMap> = {
  server_update: 'settings',
  channel_create: 'add-circle',
  channel_update: 'create',
  channel_delete: 'remove-circle',
  role_create: 'shield',
  role_update: 'shield-checkmark',
  role_delete: 'shield-outline',
  member_kick: 'exit',
  member_ban: 'ban',
  member_unban: 'checkmark-circle',
  member_role_update: 'people',
  message_delete: 'trash',
  message_pin: 'pin',
  message_unpin: 'pin-outline',
  invite_create: 'mail',
  invite_delete: 'mail-open',
  webhook_create: 'link',
  webhook_update: 'link',
  webhook_delete: 'unlink',
  emoji_create: 'happy',
  emoji_delete: 'happy-outline',
  automod_rule_create: 'flash',
  automod_rule_update: 'flash',
  automod_rule_delete: 'flash-outline',
};

export default function AuditLogScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const { themeColors: c } = useTheme();

  const [entries, setEntries] = useState<AuditLogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterAction, setFilterAction] = useState<AuditLogAction | undefined>();
  const [showFilter, setShowFilter] = useState(false);

  const fetchLog = useCallback(async () => {
    if (!serverId) return;
    setLoading(true);
    try {
      const data = await getAuditLog(serverId, { action: filterAction, limit: 100 });
      setEntries(data);
    } catch {}
    setLoading(false);
  }, [serverId, filterAction]);

  useEffect(() => { fetchLog(); }, [fetchLog]);

  const formatTime = (iso: string) => {
    const d = new Date(iso);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return d.toLocaleDateString();
  };

  const renderEntry = ({ item }: { item: AuditLogEntry }) => (
    <View style={[styles.entry, { backgroundColor: c.bgSecondary }]}>
      <View style={styles.entryHeader}>
        <Ionicons
          name={ACTION_ICONS[item.action] || 'ellipse'}
          size={18}
          color={c.accentPrimary}
        />
        <View style={styles.entryInfo}>
          <Text style={[styles.entryAction, { color: c.textPrimary }]}>
            {AUDIT_ACTION_LABELS[item.action] || item.action}
          </Text>
          <Text style={[styles.entryUser, { color: c.textSecondary }]}>
            by {item.user?.username || 'Unknown'} • {formatTime(item.created_at)}
          </Text>
        </View>
      </View>
      {item.reason && (
        <Text style={[styles.reason, { color: c.textMuted }]}>Reason: {item.reason}</Text>
      )}
      {item.changes && Object.keys(item.changes).length > 0 && (
        <View style={styles.changes}>
          {Object.entries(item.changes).slice(0, 3).map(([key, val]) => (
            <Text key={key} style={[styles.changeText, { color: c.textMuted }]} numberOfLines={1}>
              {key}: {JSON.stringify(val.old)} → {JSON.stringify(val.new)}
            </Text>
          ))}
        </View>
      )}
    </View>
  );

  const filterActions = Object.keys(AUDIT_ACTION_LABELS) as AuditLogAction[];

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'Audit Log',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
          headerRight: () => (
            <Pressable onPress={() => setShowFilter(!showFilter)}>
              <Ionicons name="filter" size={22} color={filterAction ? c.accentPrimary : c.textMuted} />
            </Pressable>
          ),
        }}
      />

      {showFilter && (
        <FlatList
          data={[undefined, ...filterActions]}
          keyExtractor={(item) => item ?? 'all'}
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.filterBar}
          renderItem={({ item }) => {
            const selected = filterAction === item;
            return (
              <Pressable
                style={[styles.filterChip, { backgroundColor: selected ? c.accentPrimary : c.bgSecondary }]}
                onPress={() => { setFilterAction(item); setShowFilter(false); }}
              >
                <Text style={[styles.filterChipText, { color: selected ? c.textPrimary : c.textSecondary }]}>
                  {item ? AUDIT_ACTION_LABELS[item] : 'All'}
                </Text>
              </Pressable>
            );
          }}
        />
      )}

      {loading ? (
        <View style={styles.center}><ActivityIndicator color={c.accentPrimary} /></View>
      ) : entries.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="document-text-outline" size={48} color={c.textMuted} />
          <Text style={[styles.emptyText, { color: c.textSecondary }]}>No audit log entries</Text>
        </View>
      ) : (
        <FlatList
          data={entries}
          keyExtractor={(item) => item.id}
          renderItem={renderEntry}
          contentContainerStyle={{ padding: spacing.md, gap: spacing.xs }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md },
  filterBar: { paddingHorizontal: spacing.md, paddingVertical: spacing.sm, gap: spacing.xs },
  filterChip: { paddingHorizontal: spacing.md, paddingVertical: spacing.sm, borderRadius: borderRadius.full },
  filterChipText: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  entry: { borderRadius: borderRadius.md, padding: spacing.md },
  entryHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  entryInfo: { flex: 1 },
  entryAction: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  entryUser: { ...typography.caption },
  reason: { ...typography.caption, marginTop: spacing.xs, paddingLeft: spacing.xxl },
  changes: { marginTop: spacing.xs, paddingLeft: spacing.xxl },
  changeText: { ...typography.micro },
  emptyText: { ...typography.body },
});
