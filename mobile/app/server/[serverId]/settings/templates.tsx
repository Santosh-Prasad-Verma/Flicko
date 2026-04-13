/**
 * Server Templates Screen
 *
 * Snapshot server structure as a template, list existing templates.
 * Requirements: Feature 23 (Server Templates)
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
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  ServerTemplate,
  getServerTemplates,
  createTemplate,
  deleteTemplate,
} from '@services/templateService';
import { useAuthStore } from '@stores/authStore';
import { supabase } from '../../../../services/supabase';

const STARTER_PRESETS: {
  id: string;
  title: string;
  description: string;
  serialized_data: ServerTemplate['serialized_data'];
}[] = [
  {
    id: 'gaming',
    title: 'Gaming server',
    description: 'General, LFG, voice lounge, and staff role',
    serialized_data: {
      channels: [
        { name: 'welcome', type: 'text', position: 0 },
        { name: 'general', type: 'text', position: 1 },
        { name: 'lfg', type: 'text', position: 2 },
        { name: 'clips', type: 'text', position: 3 },
        { name: 'Lounge', type: 'voice', position: 4 },
      ],
      roles: [
        { name: 'Admin', permissions: '0', color: '#ED4245', hoist: true },
        { name: 'Member', permissions: '0', color: '#99AAB5', hoist: false },
      ],
    },
  },
  {
    id: 'study',
    title: 'Study group',
    description: 'Quiet rooms, homework help, announcements',
    serialized_data: {
      channels: [
        { name: 'announcements', type: 'text', position: 0 },
        { name: 'general', type: 'text', position: 1 },
        { name: 'homework-help', type: 'text', position: 2 },
        { name: 'Study Room 1', type: 'voice', position: 3 },
      ],
      roles: [
        { name: 'Moderator', permissions: '0', color: '#5865F2', hoist: true },
        { name: 'Student', permissions: '0', color: '#57F287', hoist: false },
      ],
    },
  },
  {
    id: 'community',
    title: 'Community hub',
    description: 'Introductions, off-topic, and events',
    serialized_data: {
      channels: [
        { name: 'rules', type: 'text', position: 0 },
        { name: 'introductions', type: 'text', position: 1 },
        { name: 'general', type: 'text', position: 2 },
        { name: 'off-topic', type: 'text', position: 3 },
        { name: 'events', type: 'text', position: 4 },
      ],
      roles: [{ name: 'Member', permissions: '0', color: '#EB459E', hoist: false }],
    },
  },
];

export default function TemplatesScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const userId = useAuthStore((s: any) => s.user?.id);
  const { themeColors: c } = useTheme();

  const [templates, setTemplates] = useState<ServerTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [addingPreset, setAddingPreset] = useState<string | null>(null);

  const fetch = useCallback(async () => {
    if (!serverId) return;
    try { setTemplates(await getServerTemplates(serverId)); } catch {}
    setLoading(false);
  }, [serverId]);

  useEffect(() => { fetch(); }, [fetch]);

  const addPreset = async (preset: (typeof STARTER_PRESETS)[number]) => {
    if (!serverId || !userId) return;
    setAddingPreset(preset.id);
    try {
      const { data, error } = await supabase
        .from('server_templates')
        .insert({
          name: preset.title,
          description: preset.description,
          source_server_id: serverId,
          creator_id: userId,
          serialized_data: preset.serialized_data,
          usage_count: 0,
        })
        .select()
        .single();
      if (error) throw error;
      if (data) setTemplates((p) => [data as ServerTemplate, ...p]);
    } catch (e: any) {
      Alert.alert('Could not add template', e?.message || 'Unknown error');
    } finally {
      setAddingPreset(null);
    }
  };

  const handleDelete = (t: ServerTemplate) => {
    Alert.alert('Delete Template', `Delete "${t.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          setTemplates((prev) => prev.filter((x) => x.id !== t.id));
          try { await deleteTemplate(t.id); } catch { fetch(); }
        },
      },
    ]);
  };

  const renderTemplate = ({ item }: { item: ServerTemplate }) => {
    const chs = item.serialized_data?.channels?.length ?? 0;
    const rls = item.serialized_data?.roles?.length ?? 0;
    return (
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        <View style={styles.cardHeader}>
          <Ionicons name="copy-outline" size={20} color={c.accentPrimary} />
          <View style={styles.cardInfo}>
            <Text style={[styles.cardName, { color: c.textPrimary }]}>{item.name}</Text>
            {item.description ? (
              <Text style={[styles.cardDesc, { color: c.textSecondary }]} numberOfLines={2}>{item.description}</Text>
            ) : null}
            <Text style={[styles.cardMeta, { color: c.textMuted }]}>
              {chs} channel{chs !== 1 ? 's' : ''} • {rls} role{rls !== 1 ? 's' : ''} • Used {item.usage_count ?? 0} times
            </Text>
          </View>
        </View>
        <Pressable style={styles.deleteRow} onPress={() => handleDelete(item)}>
          <Ionicons name="trash-outline" size={16} color={c.danger} />
          <Text style={[styles.deleteText, { color: c.danger }]}>Delete</Text>
        </Pressable>
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'Templates',
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
        <View style={styles.center}><ActivityIndicator color={c.accentPrimary} /></View>
      ) : (
        <FlatList
          data={templates}
          keyExtractor={(i) => i.id}
          renderItem={renderTemplate}
          ListHeaderComponent={
            <View style={{ paddingHorizontal: spacing.md, paddingTop: spacing.md, gap: spacing.sm }}>
              <Text style={[styles.presetHeading, { color: c.textMuted }]}>STARTER TEMPLATES</Text>
              <Text style={[styles.presetHint, { color: c.textSecondary }]}>
                Add a ready-made channel and role layout to this server as a reusable template.
              </Text>
              {STARTER_PRESETS.map((p) => (
                <Pressable
                  key={p.id}
                  onPress={() => addPreset(p)}
                  disabled={!!addingPreset}
                  style={[styles.presetCard, { backgroundColor: c.bgSecondary, borderColor: c.border }]}
                >
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.presetTitle, { color: c.textPrimary }]}>{p.title}</Text>
                    <Text style={[styles.presetDesc, { color: c.textSecondary }]}>{p.description}</Text>
                  </View>
                  {addingPreset === p.id ? (
                    <ActivityIndicator color={c.accentPrimary} />
                  ) : (
                    <Ionicons name="add-circle-outline" size={26} color={c.accentPrimary} />
                  )}
                </Pressable>
              ))}
              <Text style={[styles.presetHeading, { color: c.textMuted, marginTop: spacing.md }]}>YOUR TEMPLATES</Text>
            </View>
          }
          ListEmptyComponent={
            <View style={styles.center}>
              <Ionicons name="documents-outline" size={48} color={c.textMuted} />
              <Text style={[styles.emptyText, { color: c.textSecondary }]}>No saved templates yet</Text>
              <Text style={[styles.emptyHint, { color: c.textMuted }]}>Use starters above or snapshot your current server</Text>
              <Pressable style={[styles.createBtn, { backgroundColor: c.accentPrimary }]} onPress={() => setShowCreate(true)}>
                <Text style={[styles.createBtnText, { color: '#FFFFFF' }]}>Create from server</Text>
              </Pressable>
            </View>
          }
          contentContainerStyle={{ paddingBottom: spacing.xl, gap: spacing.sm }}
        />
      )}

      <CreateTemplateModal visible={showCreate} onClose={() => setShowCreate(false)} serverId={serverId!} userId={userId!} onCreated={(t) => { setTemplates((p) => [t, ...p]); setShowCreate(false); }} />
    </View>
  );
}

function CreateTemplateModal({ visible, onClose, serverId, userId, onCreated }: { visible: boolean; onClose: () => void; serverId: string; userId: string; onCreated: (t: ServerTemplate) => void }) {
  const { themeColors: c } = useTheme();
  const [name, setName] = useState('');
  const [desc, setDesc] = useState('');
  const [saving, setSaving] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const t = await createTemplate(serverId, userId, { name: name.trim(), description: desc.trim() || undefined });
      onCreated(t);
      setName(''); setDesc('');
    } catch (e: any) { Alert.alert('Error', e?.message || 'Failed'); }
    setSaving(false);
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: c.overlay }]}>
        <View style={[styles.modalContent, { backgroundColor: c.bgSecondary }]}>
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: c.textPrimary }]}>Create Template</Text>
            <Pressable onPress={onClose}><Ionicons name="close" size={24} color={c.textMuted} /></Pressable>
          </View>
          <View style={styles.modalBody}>
            <Text style={[styles.label, { color: c.textSecondary }]}>Name</Text>
            <TextInput style={[styles.input, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]} value={name} onChangeText={setName} placeholder="Template name" placeholderTextColor={c.textMuted} />
            <Text style={[styles.label, { color: c.textSecondary }]}>Description (optional)</Text>
            <TextInput style={[styles.input, styles.multiline, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]} value={desc} onChangeText={setDesc} placeholder="What's this template for?" placeholderTextColor={c.textMuted} multiline />
          </View>
          <Pressable style={[styles.saveBtn, { backgroundColor: c.accentPrimary, opacity: saving || !name.trim() ? 0.5 : 1 }]} onPress={handleCreate} disabled={saving || !name.trim()}>
            {saving ? <ActivityIndicator color={c.textPrimary} size="small" /> : <Text style={[styles.saveBtnText, { color: c.textPrimary }]}>Create</Text>}
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  presetHeading: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
  },
  presetHint: { fontSize: 13, lineHeight: 18 },
  presetCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    gap: spacing.md,
  },
  presetTitle: { fontSize: 16, fontFamily: 'gg-sans-semibold' },
  presetDesc: { fontSize: 13, marginTop: 4 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md, padding: spacing.xl },
  card: { borderRadius: borderRadius.md, padding: spacing.lg },
  cardHeader: { flexDirection: 'row', gap: spacing.md },
  cardInfo: { flex: 1 },
  cardName: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  cardDesc: { ...typography.caption, marginTop: 2 },
  cardMeta: { ...typography.caption, marginTop: spacing.xs },
  deleteRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, marginTop: spacing.sm, alignSelf: 'flex-end' },
  deleteText: { ...typography.caption },
  emptyText: { ...typography.body },
  emptyHint: { ...typography.bodySmall, textAlign: 'center' },
  createBtn: { paddingHorizontal: spacing.xl, paddingVertical: spacing.md, borderRadius: borderRadius.md, marginTop: spacing.sm },
  createBtnText: { ...typography.bodyBold },
  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.lg },
  modalTitle: { ...typography.headingM },
  modalBody: { paddingHorizontal: spacing.lg },
  label: { ...typography.caption, fontFamily: 'gg-sans-semibold', marginTop: spacing.md, marginBottom: spacing.xs },
  input: { borderWidth: 1, borderRadius: borderRadius.sm, paddingHorizontal: spacing.md, height: MINIMUM_TOUCH_TARGET, ...typography.bodySmall },
  multiline: { height: 80, textAlignVertical: 'top', paddingTop: spacing.sm },
  saveBtn: { margin: spacing.lg, height: MINIMUM_TOUCH_TARGET, borderRadius: borderRadius.md, justifyContent: 'center', alignItems: 'center' },
  saveBtnText: { ...typography.bodyBold },
});
