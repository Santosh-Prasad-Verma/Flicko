/**
 * Stickers Settings Screen
 *
 * Upload and manage custom server stickers.
 * Route: /server/[serverId]/settings/stickers
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
  ActivityIndicator,
} from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { uploadSticker } from '@services/cloudinaryService';
import { useAuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

interface ServerSticker {
  id: string;
  server_id: string;
  name: string;
  description: string | null;
  image_url: string;
  tags: string | null;
  creator_id: string;
  created_at: string;
  creator?: { username: string };
}

export default function StickersScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);

  const [showUpload, setShowUpload] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newTag, setNewTag] = useState('');
  const [newImageUri, setNewImageUri] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);

  const { data: stickers = [], isLoading } = useQuery({
    queryKey: ['server-stickers', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('server_stickers')
        .select('*, creator:profiles!creator_id(username)')
        .eq('server_id', serverId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data ?? []) as ServerSticker[];
    },
    enabled: !!serverId,
  });

  const deleteMutation = useMutation({
    mutationFn: async (stickerId: string) => {
      const { error } = await supabase.from('server_stickers').delete().eq('id', stickerId);
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-stickers', serverId] }),
  });

  const handlePickImage = useCallback(async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 1,
    });
    if (result.canceled) return;
    const asset = result.assets[0];
    setNewImageUri(asset.uri);
    if (!newName) {
      const fileName = asset.uri.split('/').pop()?.split('.')[0] || '';
      setNewName(fileName.replace(/[^a-zA-Z0-9_ ]/g, '').slice(0, 30));
    }
  }, [newName]);

  const handleUpload = useCallback(async () => {
    if (!newImageUri || !newName.trim()) return;
    setUploading(true);
    try {
      const ext = newImageUri.split('.').pop() || 'png';
      const contentType = ext === 'gif' ? 'image/gif' : `image/${ext}`;

      // Get auth token
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.access_token) throw new Error('Not authenticated');

      // Upload to Cloudinary with deterministic public_id
      const result = await uploadSticker(newImageUri, contentType, serverId!, newName.trim(), session.access_token);

      const { error: insertError } = await supabase.from('server_stickers').insert({
        server_id: serverId,
        name: newName.trim(),
        description: newDesc.trim() || null,
        image_url: result.secure_url,
        tags: newTag.trim() || null,
        creator_id: user?.id,
      });

      if (insertError) throw insertError;

      queryClient.invalidateQueries({ queryKey: ['server-stickers', serverId] });
      setShowUpload(false);
      setNewName('');
      setNewDesc('');
      setNewTag('');
      setNewImageUri(null);
    } catch (err: any) {
      Alert.alert('Upload Failed', err.message);
    } finally {
      setUploading(false);
    }
  }, [newImageUri, newName, newDesc, newTag, serverId, user]);

  const handleDelete = useCallback((sticker: ServerSticker) => {
    Alert.alert('Delete Sticker', `Delete "${sticker.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteMutation.mutate(sticker.id) },
    ]);
  }, [deleteMutation]);

  const renderSticker = useCallback(
    ({ item }: { item: ServerSticker }) => (
      <View style={[styles.stickerCard, { backgroundColor: themeColors.bgSecondary }]}>
        <Image
          source={{ uri: item.image_url }}
          style={styles.stickerImage}
          contentFit="contain"
          transition={200}
        />
        <View style={styles.stickerInfo}>
          <Text style={[styles.stickerName, { color: themeColors.textPrimary }]}>{item.name}</Text>
          {item.description && (
            <Text style={[styles.stickerDesc, { color: themeColors.textMuted }]} numberOfLines={1}>
              {item.description}
            </Text>
          )}
          <Text style={[styles.stickerMeta, { color: themeColors.textMuted }]}>
            {item.tags ? `#${item.tags}` : 'No tags'}
            {item.creator ? ` · by ${item.creator.username}` : ''}
          </Text>
        </View>
        <Pressable onPress={() => handleDelete(item)} hitSlop={8} style={styles.deleteBtn}>
          <Ionicons name="trash-outline" size={16} color={themeColors.danger} />
        </Pressable>
      </View>
    ),
    [themeColors, handleDelete],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Stickers ({stickers.length})
          </Text>
          <Pressable onPress={() => setShowUpload(true)} hitSlop={8} style={styles.addBtn}>
            <Ionicons name="add" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        {isLoading ? (
          <View style={styles.centered}>
            <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          </View>
        ) : stickers.length === 0 ? (
          <View style={styles.centered}>
            <Ionicons name="images-outline" size={48} color={themeColors.textMuted} />
            <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>No stickers</Text>
            <Text style={[styles.emptyDesc, { color: themeColors.textMuted }]}>
              Upload custom stickers for your server
            </Text>
            <Pressable
              onPress={() => setShowUpload(true)}
              style={[styles.uploadBtn, { backgroundColor: themeColors.accentPrimary }]}
            >
              <Ionicons name="cloud-upload-outline" size={18} color="#fff" />
              <Text style={styles.uploadBtnText}>Upload Sticker</Text>
            </Pressable>
          </View>
        ) : (
          <FlatList
            data={stickers}
            renderItem={renderSticker}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{ padding: spacing.md, paddingBottom: insets.bottom + 40 }}
          />
        )}

        {/* Upload Modal */}
        <Modal visible={showUpload} animationType="slide" transparent>
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: themeColors.bgSecondary }]}>
              <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Upload Sticker</Text>

              <Pressable onPress={handlePickImage} style={[styles.imagePicker, { backgroundColor: themeColors.bgTertiary }]}>
                {newImageUri ? (
                  <Image source={{ uri: newImageUri }} style={styles.imagePreview} contentFit="contain" />
                ) : (
                  <>
                    <Ionicons name="image-outline" size={40} color={themeColors.textMuted} />
                    <Text style={[styles.imagePickerText, { color: themeColors.textMuted }]}>
                      Tap to select image
                    </Text>
                  </>
                )}
              </Pressable>
              <Text style={[styles.hint, { color: themeColors.textMuted }]}>
                320x320 recommended. PNG or APNG (max 512KB)
              </Text>

              <Text style={[styles.label, { color: themeColors.textMuted }]}>NAME</Text>
              <TextInput
                value={newName}
                onChangeText={setNewName}
                maxLength={30}
                placeholder="Sticker name"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>DESCRIPTION</Text>
              <TextInput
                value={newDesc}
                onChangeText={setNewDesc}
                maxLength={100}
                placeholder="What does this sticker represent?"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>RELATED EMOJI TAG</Text>
              <TextInput
                value={newTag}
                onChangeText={setNewTag}
                maxLength={20}
                placeholder="e.g. wave, hello"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <View style={styles.modalButtons}>
                <Pressable
                  onPress={() => { setShowUpload(false); setNewName(''); setNewDesc(''); setNewTag(''); setNewImageUri(null); }}
                  style={[styles.modalBtn, { backgroundColor: themeColors.bgTertiary }]}
                >
                  <Text style={{ color: themeColors.textPrimary }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={handleUpload}
                  disabled={!newImageUri || !newName.trim() || uploading}
                  style={[styles.modalBtn, {
                    backgroundColor: themeColors.accentPrimary,
                    opacity: newImageUri && newName.trim() ? 1 : 0.4,
                  }]}
                >
                  {uploading ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Upload</Text>
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
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  emptyTitle: { fontSize: 18, fontFamily: 'gg-sans-semibold', marginTop: spacing.md },
  emptyDesc: { fontSize: 14, marginTop: spacing.xs, textAlign: 'center' },
  uploadBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    marginTop: spacing.lg,
  },
  uploadBtnText: { color: '#fff', fontFamily: 'gg-sans-semibold', fontSize: 15 },
  stickerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.sm,
  },
  stickerImage: { width: 64, height: 64 },
  stickerInfo: { flex: 1, marginLeft: spacing.md },
  stickerName: { fontSize: 15, fontFamily: 'gg-sans-semibold' },
  stickerDesc: { fontSize: 13, marginTop: 2 },
  stickerMeta: { fontSize: 12, marginTop: 2 },
  deleteBtn: { padding: 8 },
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
  imagePicker: {
    width: 160,
    height: 160,
    borderRadius: borderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    overflow: 'hidden',
  },
  imagePreview: { width: 160, height: 160 },
  imagePickerText: { fontSize: 12, marginTop: spacing.xs },
  hint: { fontSize: 12, textAlign: 'center', marginTop: spacing.sm },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
    marginTop: spacing.lg,
  },
  input: {
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
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
