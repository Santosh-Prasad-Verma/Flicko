/**
 * Webhooks Settings Screen
 *
 * List, create, copy URL, and delete webhooks for a server.
 * Requirements: Feature 22 (Webhooks)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  Modal,
  TextInput,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  Webhook,
  getServerWebhooks,
  createWebhook,
  deleteWebhook,
  getWebhookUrl,
} from '@services/webhookService';
import { useAuthStore } from '@stores/authStore';

const API_BASE = 'https://api.flicko.app'; // placeholder

export default function WebhooksScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const userId = useAuthStore((s: any) => s.user?.id);
  const { themeColors: c } = useTheme();

  const [webhooks, setWebhooks] = useState<Webhook[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const fetchWebhooks = useCallback(async () => {
    if (!serverId) return;
    try {
      const data = await getServerWebhooks(serverId);
      setWebhooks(data);
    } catch {}
    setLoading(false);
  }, [serverId]);

  useEffect(() => { fetchWebhooks(); }, [fetchWebhooks]);

  const handleCopyUrl = async (wh: Webhook) => {
    const url = getWebhookUrl(wh, API_BASE);
    await Clipboard.setStringAsync(url);
    Alert.alert('Copied', 'Webhook URL copied to clipboard');
  };

  const handleDelete = (wh: Webhook) => {
    Alert.alert('Delete Webhook', `Delete "${wh.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          setWebhooks((prev) => prev.filter((w) => w.id !== wh.id));
          try { await deleteWebhook(wh.id); } catch { fetchWebhooks(); }
        },
      },
    ]);
  };

  const renderWebhook = ({ item }: { item: Webhook }) => (
    <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
      <View style={styles.row}>
        <View style={[styles.avatar, { backgroundColor: c.bgTertiary }]}>
          <Ionicons name="link" size={20} color={c.accentPrimary} />
        </View>
        <View style={styles.info}>
          <Text style={[styles.name, { color: c.textPrimary }]}>{item.name}</Text>
          <Text style={[styles.meta, { color: c.textMuted }]}>
            Created {new Date(item.created_at).toLocaleDateString()}
          </Text>
        </View>
      </View>
      <View style={styles.actions}>
        <Pressable style={[styles.actionBtn, { backgroundColor: c.bgTertiary }]} onPress={() => handleCopyUrl(item)}>
          <Ionicons name="copy-outline" size={16} color={c.accentSecondary} />
          <Text style={[styles.actionText, { color: c.accentSecondary }]}>Copy URL</Text>
        </Pressable>
        <Pressable style={[styles.actionBtn, { backgroundColor: c.bgTertiary }]} onPress={() => handleDelete(item)}>
          <Ionicons name="trash-outline" size={16} color={c.danger} />
          <Text style={[styles.actionText, { color: c.danger }]}>Delete</Text>
        </Pressable>
      </View>
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'Webhooks',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
          headerRight: () => (
            <Pressable onPress={() => setShowCreate(true)}>
              <Ionicons name="add" size={24} color={c.accentPrimary} />
            </Pressable>
          ),
        }}
      />

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={c.accentPrimary} />
        </View>
      ) : webhooks.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="link-outline" size={48} color={c.textMuted} />
          <Text style={[styles.emptyText, { color: c.textSecondary }]}>No webhooks yet</Text>
          <Pressable
            style={[styles.createBtn, { backgroundColor: c.accentPrimary }]}
            onPress={() => setShowCreate(true)}
          >
            <Text style={[styles.createBtnText, { color: c.textPrimary }]}>Create Webhook</Text>
          </Pressable>
        </View>
      ) : (
        <FlatList
          data={webhooks}
          keyExtractor={(item) => item.id}
          renderItem={renderWebhook}
          contentContainerStyle={{ padding: spacing.md, gap: spacing.sm }}
        />
      )}

      <CreateWebhookModal
        visible={showCreate}
        onClose={() => setShowCreate(false)}
        serverId={serverId!}
        userId={userId!}
        onCreated={(wh) => {
          setWebhooks((prev) => [...prev, wh]);
          setShowCreate(false);
        }}
      />
    </View>
  );
}

function CreateWebhookModal({
  visible,
  onClose,
  serverId,
  userId,
  onCreated,
}: {
  visible: boolean;
  onClose: () => void;
  serverId: string;
  userId: string;
  onCreated: (wh: Webhook) => void;
}) {
  const { themeColors: c } = useTheme();
  const [name, setName] = useState('');
  const [channelId, setChannelId] = useState('');
  const [saving, setSaving] = useState(false);

  const handleCreate = async () => {
    if (!name.trim() || !channelId.trim()) return;
    setSaving(true);
    try {
      const wh = await createWebhook(serverId, userId, {
        channel_id: channelId.trim(),
        name: name.trim(),
      });
      onCreated(wh);
      setName('');
      setChannelId('');
    } catch (e: any) {
      Alert.alert('Error', e?.message || 'Failed to create webhook');
    }
    setSaving(false);
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: c.overlay }]}>
        <View style={[styles.modalContent, { backgroundColor: c.bgSecondary }]}>
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: c.textPrimary }]}>New Webhook</Text>
            <Pressable onPress={onClose}>
              <Ionicons name="close" size={24} color={c.textMuted} />
            </Pressable>
          </View>

          <View style={styles.modalBody}>
            <Text style={[styles.fieldLabel, { color: c.textSecondary }]}>Name</Text>
            <TextInput
              style={[styles.input, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
              value={name}
              onChangeText={setName}
              placeholder="My Webhook"
              placeholderTextColor={c.textMuted}
            />
            <Text style={[styles.fieldLabel, { color: c.textSecondary }]}>Channel ID</Text>
            <TextInput
              style={[styles.input, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
              value={channelId}
              onChangeText={setChannelId}
              placeholder="Paste channel ID"
              placeholderTextColor={c.textMuted}
            />
          </View>

          <Pressable
            style={[styles.saveButton, { backgroundColor: c.accentPrimary, opacity: saving || !name.trim() ? 0.5 : 1 }]}
            onPress={handleCreate}
            disabled={saving || !name.trim()}
          >
            {saving ? (
              <ActivityIndicator color={c.textPrimary} size="small" />
            ) : (
              <Text style={[styles.saveBtnText, { color: c.textPrimary }]}>Create</Text>
            )}
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md },
  card: { borderRadius: borderRadius.md, padding: spacing.lg },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  avatar: { width: 40, height: 40, borderRadius: borderRadius.full, justifyContent: 'center', alignItems: 'center' },
  info: { flex: 1 },
  name: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  meta: { ...typography.caption, marginTop: 2 },
  actions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.md, justifyContent: 'flex-end' },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.sm,
  },
  actionText: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  emptyText: { ...typography.body },
  createBtn: { paddingHorizontal: spacing.xl, paddingVertical: spacing.md, borderRadius: borderRadius.md },
  createBtnText: { ...typography.bodyBold },
  // Modal
  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.lg },
  modalTitle: { ...typography.headingM },
  modalBody: { paddingHorizontal: spacing.lg },
  fieldLabel: { ...typography.caption, fontFamily: 'gg-sans-semibold', marginTop: spacing.md, marginBottom: spacing.xs },
  input: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.md,
    height: MINIMUM_TOUCH_TARGET,
    ...typography.bodySmall,
  },
  saveButton: {
    margin: spacing.lg,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveBtnText: { ...typography.bodyBold },
});
