/**
 * Webhook Management UI (Feature 30)
 *
 * Full management interface for server webhooks:
 * - Create / edit / delete webhooks
 * - Copy webhook URL
 * - Test webhook
 * - Custom name + avatar + channel assignment
 */
import React, { memo, useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Modal,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import { supabase } from '@services/supabase';

interface Webhook {
  id: string;
  name: string;
  avatar_url?: string;
  channel_id: string;
  channel_name?: string;
  token: string;
  created_at: string;
}

interface Props {
  serverId: string;
  channels: { id: string; name: string }[];
}

export const WebhookManagement = memo(function WebhookManagement({
  serverId,
  channels,
}: Props) {
  const { themeColors } = useTheme();
  const [webhooks, setWebhooks] = useState<Webhook[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  // Create/edit form state
  const [formName, setFormName] = useState('');
  const [formChannel, setFormChannel] = useState('');

  const fetchWebhooks = useCallback(async () => {
    const { data } = await supabase
      .from('webhooks')
      .select('*, channels(name)')
      .eq('server_id', serverId)
      .order('created_at', { ascending: true });
    if (data) {
      setWebhooks(
        data.map((w: any) => ({
          ...w,
          channel_name: w.channels?.name,
        }))
      );
    }
    setLoading(false);
  }, [serverId]);

  useEffect(() => {
    fetchWebhooks();
  }, [fetchWebhooks]);

  const handleCreate = useCallback(async () => {
    if (!formName.trim() || !formChannel) return;
    const token = crypto.randomUUID();
    const { error } = await supabase.from('webhooks').insert({
      server_id: serverId,
      channel_id: formChannel,
      name: formName.trim(),
      token,
    });
    if (error) {
      Alert.alert('Error', 'Failed to create webhook');
    } else {
      setShowCreate(false);
      setFormName('');
      setFormChannel('');
      fetchWebhooks();
    }
  }, [serverId, formName, formChannel, fetchWebhooks]);

  const handleEdit = useCallback(
    async (webhookId: string) => {
      if (!formName.trim()) return;
      await supabase
        .from('webhooks')
        .update({ name: formName.trim(), channel_id: formChannel || undefined })
        .eq('id', webhookId);
      setEditingId(null);
      setFormName('');
      setFormChannel('');
      fetchWebhooks();
    },
    [formName, formChannel, fetchWebhooks]
  );

  const handleDelete = useCallback(
    async (webhookId: string) => {
      Alert.alert('Delete Webhook', 'This action cannot be undone.', [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await supabase.from('webhooks').delete().eq('id', webhookId);
            fetchWebhooks();
          },
        },
      ]);
    },
    [fetchWebhooks]
  );

  const handleCopyUrl = useCallback(async (webhook: Webhook) => {
    const url = `${process.env.EXPO_PUBLIC_API_URL}/api/v1/webhooks/${webhook.id}/${webhook.token}`;
    await Clipboard.setStringAsync(url);
    Alert.alert('Copied', 'Webhook URL copied to clipboard');
  }, []);

  const handleTest = useCallback(async (webhook: Webhook) => {
    const url = `${process.env.EXPO_PUBLIC_API_URL}/api/v1/webhooks/${webhook.id}/${webhook.token}`;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          content: '🧪 This is a test webhook message!',
          username: webhook.name,
        }),
      });
      if (res.ok) Alert.alert('Success', 'Test message sent!');
      else Alert.alert('Error', 'Webhook test failed');
    } catch {
      Alert.alert('Error', 'Could not reach webhook endpoint');
    }
  }, []);

  if (loading) {
    return (
      <View style={[styles.center, { backgroundColor: themeColors.bgPrimary }]}>
        <ActivityIndicator color={themeColors.accentPrimary} />
      </View>
    );
  }

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>Webhooks</Text>
      <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
        Webhooks allow external services to send messages to your channels.
      </Text>

      {webhooks.map((wh) => (
        <View key={wh.id} style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={styles.whHeader}>
            {wh.avatar_url ? (
              <Image source={{ uri: wh.avatar_url }} style={styles.whAvatar} />
            ) : (
              <View style={[styles.whAvatarPlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
                <Ionicons name="link" size={18} color={themeColors.textMuted} />
              </View>
            )}
            <View style={{ flex: 1 }}>
              <Text style={[styles.whName, { color: themeColors.textPrimary }]}>{wh.name}</Text>
              <Text style={[styles.whChannel, { color: themeColors.textMuted }]}>
                #{wh.channel_name || 'unknown'}
              </Text>
            </View>
          </View>

          <View style={styles.whActions}>
            <Pressable style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]} onPress={() => handleCopyUrl(wh)}>
              <Ionicons name="copy-outline" size={16} color={themeColors.textMuted} />
              <Text style={[styles.actionText, { color: themeColors.textPrimary }]}>Copy URL</Text>
            </Pressable>
            <Pressable style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]} onPress={() => handleTest(wh)}>
              <Ionicons name="flask-outline" size={16} color={themeColors.textMuted} />
              <Text style={[styles.actionText, { color: themeColors.textPrimary }]}>Test</Text>
            </Pressable>
            <Pressable
              style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
              onPress={() => {
                setEditingId(wh.id);
                setFormName(wh.name);
                setFormChannel(wh.channel_id);
              }}
            >
              <Ionicons name="pencil" size={16} color={themeColors.textMuted} />
            </Pressable>
            <Pressable
              style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
              onPress={() => handleDelete(wh.id)}
            >
              <Ionicons name="trash-outline" size={16} color={themeColors.danger} />
            </Pressable>
          </View>
        </View>
      ))}

      <Pressable
        style={[styles.createBtn, { backgroundColor: themeColors.accentPrimary }]}
        onPress={() => {
          setFormName('');
          setFormChannel(channels[0]?.id ?? '');
          setShowCreate(true);
        }}
      >
        <Ionicons name="add" size={20} color="#fff" />
        <Text style={styles.createBtnText}>Create Webhook</Text>
      </Pressable>

      {/* Create / Edit Modal */}
      <Modal visible={showCreate || !!editingId} transparent animationType="fade">
        <Pressable
          style={styles.overlay}
          onPress={() => {
            setShowCreate(false);
            setEditingId(null);
          }}
        >
          <Pressable
            style={[styles.modal, { backgroundColor: themeColors.bgSecondary }]}
            onPress={(e) => e.stopPropagation()}
          >
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>
              {editingId ? 'Edit Webhook' : 'Create Webhook'}
            </Text>

            <Text style={[styles.label, { color: themeColors.textMuted }]}>NAME</Text>
            <TextInput
              style={[styles.input, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
              value={formName}
              onChangeText={setFormName}
              placeholder="Webhook name"
              placeholderTextColor={themeColors.textMuted}
              maxLength={80}
            />

            <Text style={[styles.label, { color: themeColors.textMuted }]}>CHANNEL</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.chipRow}>
              {channels.map((ch) => (
                <Pressable
                  key={ch.id}
                  style={[
                    styles.chip,
                    { backgroundColor: formChannel === ch.id ? themeColors.accentPrimary : themeColors.bgTertiary },
                  ]}
                  onPress={() => setFormChannel(ch.id)}
                >
                  <Text
                    style={[styles.chipText, { color: formChannel === ch.id ? '#fff' : themeColors.textPrimary }]}
                  >
                    #{ch.name}
                  </Text>
                </Pressable>
              ))}
            </ScrollView>

            <View style={styles.modalActions}>
              <Pressable
                style={[styles.cancelBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => { setShowCreate(false); setEditingId(null); }}
              >
                <Text style={[styles.cancelBtnText, { color: themeColors.textPrimary }]}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.saveBtn, { backgroundColor: themeColors.accentPrimary, opacity: formName.trim() ? 1 : 0.5 }]}
                onPress={() => editingId ? handleEdit(editingId) : handleCreate()}
                disabled={!formName.trim()}
              >
                <Text style={styles.saveBtnText}>{editingId ? 'Save' : 'Create'}</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
    </ScrollView>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  subtitle: { ...typography.body, marginBottom: spacing.md },
  card: { borderRadius: 12, padding: spacing.sm, marginBottom: spacing.sm },
  whHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.xs },
  whAvatar: { width: 36, height: 36, borderRadius: 18 },
  whAvatarPlaceholder: { width: 36, height: 36, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  whName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  whChannel: { ...typography.caption },
  whActions: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  actionBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 10, paddingVertical: 6, borderRadius: 6 },
  actionText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  createBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 12, borderRadius: 8, gap: 6, marginTop: spacing.sm },
  createBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },
  overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', padding: spacing.md },
  modal: { borderRadius: 16, padding: spacing.md },
  modalTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  label: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: spacing.xs, marginTop: spacing.sm },
  input: { borderRadius: 8, padding: 12, fontSize: 15, fontFamily: 'gg-sans' },
  chipRow: { flexDirection: 'row', marginTop: 4 },
  chip: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16, marginRight: 8 },
  chipText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.md },
  cancelBtn: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  cancelBtnText: { fontFamily: 'gg-sans-medium', fontSize: 14 },
  saveBtn: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: 8 },
  saveBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
});
