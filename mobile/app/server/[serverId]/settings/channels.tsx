/**
 * Channels Settings Screen
 *
 * List, create, edit, and delete channels. Supports reordering.
 * Route: /server/[serverId]/settings/channels
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  TextInput,
  Alert,
  Modal,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as channelService from '@services/channelService';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

type ChannelType = 'text' | 'voice' | 'announcement' | 'forum' | 'stage' | 'category';

const CHANNEL_TYPE_ICONS: Record<string, keyof typeof Ionicons.glyphMap> = {
  text: 'chatbubble-outline',
  voice: 'volume-high-outline',
  announcement: 'megaphone-outline',
  forum: 'newspaper-outline',
  stage: 'mic-outline',
  category: 'folder-outline',
};

const CHANNEL_TYPES: { value: ChannelType; label: string }[] = [
  { value: 'text', label: 'Text' },
  { value: 'voice', label: 'Voice' },
  { value: 'announcement', label: 'Announcement' },
  { value: 'forum', label: 'Forum' },
  { value: 'stage', label: 'Stage' },
  { value: 'category', label: 'Category' },
];

export default function ChannelsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newType, setNewType] = useState<ChannelType>('text');
  const [newTopic, setNewTopic] = useState('');
  const [newNsfw, setNewNsfw] = useState(false);

  // Edit modal state
  const [editChannel, setEditChannel] = useState<any | null>(null);
  const [editName, setEditName] = useState('');
  const [editTopic, setEditTopic] = useState('');
  const [editNsfw, setEditNsfw] = useState(false);

  const { data: channels = [], isLoading } = useQuery({
    queryKey: ['channels', serverId],
    queryFn: () => channelService.getChannels(serverId!),
    enabled: !!serverId,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      channelService.createChannel({
        serverId: serverId!,
        name: newName.trim(),
        type: newType,
        topic: newTopic.trim() || null,
        nsfw: newNsfw,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['channels', serverId] });
      setShowCreate(false);
      resetCreateForm();
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      channelService.updateChannel(editChannel.id, {
        name: editName.trim(),
        topic: editTopic.trim() || null,
        nsfw: editNsfw,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['channels', serverId] });
      setEditChannel(null);
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (channelId: string) => channelService.deleteChannel(channelId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['channels', serverId] }),
  });

  const resetCreateForm = () => {
    setNewName('');
    setNewType('text');
    setNewTopic('');
    setNewNsfw(false);
  };

  const handleDelete = useCallback((channel: any) => {
    Alert.alert(
      'Delete Channel',
      `Delete #${channel.name}? All messages will be lost.`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: () => deleteMutation.mutate(channel.id) },
      ],
    );
  }, [deleteMutation]);

  const handleEdit = useCallback((channel: any) => {
    setEditChannel(channel);
    setEditName(channel.name);
    setEditTopic(channel.topic || '');
    setEditNsfw(channel.nsfw || false);
  }, []);

  // Group channels by category
  const categories = channels.filter((c: any) => c.type === 'category');
  const ungrouped = channels.filter((c: any) => c.type !== 'category' && !c.parent_id);
  const grouped = categories.map((cat: any) => ({
    ...cat,
    children: channels.filter((c: any) => c.parent_id === cat.id),
  }));

  const renderChannel = useCallback(
    (channel: any, indent = false) => (
      <View
        key={channel.id}
        style={[
          styles.channelRow,
          { backgroundColor: themeColors.bgSecondary, marginLeft: indent ? spacing.lg : 0 },
        ]}
      >
        <Ionicons
          name={CHANNEL_TYPE_ICONS[channel.type] || 'chatbubble-outline'}
          size={18}
          color={themeColors.textMuted}
        />
        <View style={styles.channelInfo}>
          <Text style={[styles.channelName, { color: themeColors.textPrimary }]}>
            {channel.name}
          </Text>
          {channel.topic ? (
            <Text style={[styles.channelTopic, { color: themeColors.textMuted }]} numberOfLines={1}>
              {channel.topic}
            </Text>
          ) : null}
        </View>
        {channel.nsfw && (
          <View style={[styles.nsfwBadge, { backgroundColor: themeColors.danger + '20' }]}>
            <Text style={[styles.nsfwText, { color: themeColors.danger }]}>NSFW</Text>
          </View>
        )}
        <Pressable onPress={() => handleEdit(channel)} hitSlop={8} style={styles.actionBtn}>
          <Ionicons name="pencil-outline" size={16} color={themeColors.textSecondary} />
        </Pressable>
        <Pressable onPress={() => handleDelete(channel)} hitSlop={8} style={styles.actionBtn}>
          <Ionicons name="trash-outline" size={16} color={themeColors.danger} />
        </Pressable>
      </View>
    ),
    [themeColors, handleEdit, handleDelete],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Channels ({channels.length})
          </Text>
          <Pressable onPress={() => setShowCreate(true)} hitSlop={8} style={styles.addBtn}>
            <Ionicons name="add" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        {isLoading ? (
          <View style={styles.centered}>
            <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          </View>
        ) : (
          <FlatList
            data={[]}
            renderItem={() => null}
            ListHeaderComponent={
              <View style={{ padding: spacing.md }}>
                {/* Ungrouped channels */}
                {ungrouped.length > 0 && (
                  <View style={styles.section}>
                    <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>CHANNELS</Text>
                    {ungrouped.map((ch: any) => renderChannel(ch))}
                  </View>
                )}

                {/* Grouped by category */}
                {grouped.map((cat: any) => (
                  <View key={cat.id} style={styles.section}>
                    <View style={styles.categoryRow}>
                      <Ionicons name="chevron-down" size={12} color={themeColors.textMuted} />
                      <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
                        {cat.name.toUpperCase()}
                      </Text>
                      <View style={{ flex: 1 }} />
                      <Pressable onPress={() => handleEdit(cat)} hitSlop={8}>
                        <Ionicons name="pencil-outline" size={14} color={themeColors.textMuted} />
                      </Pressable>
                      <Pressable onPress={() => handleDelete(cat)} hitSlop={8} style={{ marginLeft: spacing.sm }}>
                        <Ionicons name="trash-outline" size={14} color={themeColors.danger} />
                      </Pressable>
                    </View>
                    {cat.children.map((ch: any) => renderChannel(ch, true))}
                    {cat.children.length === 0 && (
                      <Text style={[styles.emptyNote, { color: themeColors.textMuted }]}>
                        No channels in this category
                      </Text>
                    )}
                  </View>
                ))}

                {channels.length === 0 && (
                  <View style={styles.centered}>
                    <Ionicons name="chatbubbles-outline" size={48} color={themeColors.textMuted} />
                    <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>No channels</Text>
                    <Text style={[styles.emptyDesc, { color: themeColors.textMuted }]}>
                      Create your first channel to get started
                    </Text>
                  </View>
                )}
              </View>
            }
            contentContainerStyle={{ paddingBottom: insets.bottom + 40 }}
          />
        )}

        {/* Create Modal */}
        <Modal visible={showCreate} animationType="slide" transparent>
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: themeColors.bgSecondary }]}>
              <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Create Channel</Text>

              <Text style={[styles.label, { color: themeColors.textMuted }]}>CHANNEL TYPE</Text>
              <View style={styles.typeRow}>
                {CHANNEL_TYPES.map((t) => (
                  <Pressable
                    key={t.value}
                    onPress={() => setNewType(t.value)}
                    style={[
                      styles.typeChip,
                      {
                        backgroundColor: newType === t.value ? themeColors.accentPrimary + '20' : themeColors.bgTertiary,
                        borderColor: newType === t.value ? themeColors.accentPrimary : 'transparent',
                      },
                    ]}
                  >
                    <Ionicons
                      name={CHANNEL_TYPE_ICONS[t.value]}
                      size={14}
                      color={newType === t.value ? themeColors.accentPrimary : themeColors.textMuted}
                    />
                    <Text style={[styles.typeLabel, {
                      color: newType === t.value ? themeColors.accentPrimary : themeColors.textSecondary,
                    }]}>
                      {t.label}
                    </Text>
                  </Pressable>
                ))}
              </View>

              <Text style={[styles.label, { color: themeColors.textMuted }]}>NAME</Text>
              <TextInput
                value={newName}
                onChangeText={setNewName}
                maxLength={100}
                placeholder="new-channel"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>TOPIC (optional)</Text>
              <TextInput
                value={newTopic}
                onChangeText={setNewTopic}
                maxLength={1024}
                placeholder="What is this channel about?"
                placeholderTextColor={themeColors.textMuted}
                multiline
                style={[styles.input, styles.multiline, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <View style={styles.switchRow}>
                <Text style={[styles.switchLabel, { color: themeColors.textPrimary }]}>NSFW</Text>
                <Switch value={newNsfw} onValueChange={setNewNsfw} />
              </View>

              <View style={styles.modalButtons}>
                <Pressable
                  onPress={() => { setShowCreate(false); resetCreateForm(); }}
                  style={[styles.modalBtn, { backgroundColor: themeColors.bgTertiary }]}
                >
                  <Text style={{ color: themeColors.textPrimary }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={() => createMutation.mutate()}
                  disabled={!newName.trim() || createMutation.isPending}
                  style={[styles.modalBtn, { backgroundColor: themeColors.accentPrimary, opacity: newName.trim() ? 1 : 0.4 }]}
                >
                  {createMutation.isPending ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Create</Text>
                  )}
                </Pressable>
              </View>
            </View>
          </View>
        </Modal>

        {/* Edit Modal */}
        <Modal visible={!!editChannel} animationType="slide" transparent>
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: themeColors.bgSecondary }]}>
              <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>
                Edit #{editChannel?.name}
              </Text>

              <Text style={[styles.label, { color: themeColors.textMuted }]}>NAME</Text>
              <TextInput
                value={editName}
                onChangeText={setEditName}
                maxLength={100}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>TOPIC</Text>
              <TextInput
                value={editTopic}
                onChangeText={setEditTopic}
                maxLength={1024}
                multiline
                style={[styles.input, styles.multiline, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <View style={styles.switchRow}>
                <Text style={[styles.switchLabel, { color: themeColors.textPrimary }]}>NSFW</Text>
                <Switch value={editNsfw} onValueChange={setEditNsfw} />
              </View>

              <View style={styles.modalButtons}>
                <Pressable
                  onPress={() => setEditChannel(null)}
                  style={[styles.modalBtn, { backgroundColor: themeColors.bgTertiary }]}
                >
                  <Text style={{ color: themeColors.textPrimary }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={() => updateMutation.mutate()}
                  disabled={!editName.trim() || updateMutation.isPending}
                  style={[styles.modalBtn, { backgroundColor: themeColors.accentPrimary, opacity: editName.trim() ? 1 : 0.4 }]}
                >
                  {updateMutation.isPending ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Save</Text>
                  )}
                </Pressable>
              </View>
            </View>
          </View>
        </Modal>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  addBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingTop: 60 },
  section: { marginBottom: spacing.lg },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.sm,
  },
  categoryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginBottom: spacing.sm,
  },
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.xs,
    gap: spacing.sm,
  },
  channelInfo: { flex: 1 },
  channelName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  channelTopic: { fontSize: 12, marginTop: 2 },
  nsfwBadge: { paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 },
  nsfwText: { fontSize: 10, fontFamily: 'gg-sans-bold' },
  actionBtn: { padding: 8 },
  emptyNote: { fontSize: 13, fontStyle: 'italic', marginLeft: spacing.lg, marginTop: spacing.xs },
  emptyTitle: { fontSize: 18, fontFamily: 'gg-sans-semibold', marginTop: spacing.md },
  emptyDesc: { fontSize: 14, marginTop: spacing.xs, textAlign: 'center' },
  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: spacing.lg,
    paddingBottom: 40,
  },
  modalTitle: { ...typography.headingS, marginBottom: spacing.lg },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
    marginTop: spacing.md,
  },
  input: {
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  typeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  typeChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
    borderRadius: borderRadius.full,
    borderWidth: 1,
  },
  typeLabel: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: spacing.lg,
  },
  switchLabel: { fontSize: 11, fontFamily: 'gg-sans-bold', letterSpacing: 0.6 },
  modalButtons: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  modalBtn: {
    flex: 1,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
