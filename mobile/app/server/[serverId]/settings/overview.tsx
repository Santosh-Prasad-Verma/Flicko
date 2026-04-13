/**
 * Server Overview Settings
 *
 * Edit server name, description, icon, and banner.
 * Route: /server/[serverId]/settings/overview
 */
import React, { useState, useCallback, useEffect } from 'react';
import { notifyMemberLeave } from '@shared/services/botService';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Image } from 'expo-image';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';
import { uploadServerIcon, uploadServerBanner } from '@services/cloudinaryService';
import { supabase } from '../../../../services/supabase';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

async function getAuthToken(): Promise<string> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Not authenticated');
  return session.access_token;
}

export default function OverviewScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: server, isLoading } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('servers')
        .select('*')
        .eq('id', serverId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId,
  });

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [iconUri, setIconUri] = useState<string | null>(null);
  const [bannerUri, setBannerUri] = useState<string | null>(null);
  const [hasChanges, setHasChanges] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{ icon?: number; banner?: number }>({});

  useEffect(() => {
    if (server) {
      setName(server.name || '');
      setDescription(server.description || '');
      setIconUri(server.icon || null);
      setBannerUri(server.banner || null);
    }
  }, [server]);

  const updateMutation = useMutation({
    mutationFn: async () => {
      const updates: Record<string, any> = {};
      if (name !== server?.name) updates.name = name.trim();
      if (description !== (server?.description || '')) updates.description = description.trim() || null;
      if (iconUri !== server?.icon) updates.icon = iconUri;
      if (bannerUri !== server?.banner) updates.banner = bannerUri;

      if (Object.keys(updates).length === 0) return;

      const { error } = await supabase
        .from('servers')
        .update(updates)
        .eq('id', serverId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server', serverId] });
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      setHasChanges(false);
      Alert.alert('Saved', 'Server settings updated.');
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  const pickImage = useCallback(async (type: 'icon' | 'banner') => {
    // First pick without editing to detect GIFs (native crop strips animation)
    const preview = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'] as any,
      allowsEditing: false,
      quality: 1,
    });
    if (preview.canceled || !preview.assets?.[0]) return;

    const previewAsset = preview.assets[0];
    const isGif = previewAsset.mimeType === 'image/gif' ||
      previewAsset.uri.toLowerCase().endsWith('.gif');

    let file = previewAsset;

    // For non-GIF images, re-pick with crop UI
    if (!isGif) {
      const cropped = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'] as any,
        allowsEditing: true,
        aspect: type === 'icon' ? [1, 1] as [number, number] : [16, 9] as [number, number],
        quality: 1,
      });
      if (cropped.canceled || !cropped.assets?.[0]) return;
      file = cropped.assets[0];
    }
    const uri = file.uri;
    const mimeType = file.mimeType || 'image/jpeg';

    try {
      setUploadProgress((prev) => ({ ...prev, [type]: 0 }));

      const fileInfo = await FileSystem.getInfoAsync(uri);
      const resolvedSize = 'size' in fileInfo && typeof fileInfo.size === 'number'
        ? fileInfo.size
        : undefined;
      const fileSizeBytes = resolvedSize ?? file.fileSize ?? 0;
      const fileSizeMB = fileSizeBytes / (1024 * 1024);

      // Warn for very large files
      if (fileSizeMB > 25) {
        Alert.alert('File Too Large', 'Please select a file smaller than 25MB.');
        setUploadProgress((prev) => ({ ...prev, [type]: undefined }));
        return;
      }

      if (fileSizeMB > 10) {
        Alert.alert(
          'Large File',
          `This file is ${fileSizeMB.toFixed(1)}MB. Upload may take a while. Continue?`,
          [
            { text: 'Cancel', style: 'cancel', onPress: () => setUploadProgress((prev) => ({ ...prev, [type]: undefined })) },
            { text: 'Upload', onPress: () => doCloudinaryUpload(uri, mimeType, type) }
          ]
        );
        return;
      }

      await doCloudinaryUpload(uri, mimeType, type);
    } catch (err: any) {
      Alert.alert('Upload Failed', err.message ?? 'Could not upload image');
      setUploadProgress((prev) => ({ ...prev, [type]: undefined }));
    }
  }, [serverId]);

  const doCloudinaryUpload = async (uri: string, mimeType: string, type: 'icon' | 'banner') => {
    try {
      const token = await getAuthToken();
      const result = type === 'icon'
        ? await uploadServerIcon(uri, mimeType, serverId!, token)
        : await uploadServerBanner(uri, mimeType, serverId!, token);

      const publicUrl = result.secure_url;

      if (type === 'icon') {
        setIconUri(publicUrl);
      } else {
        setBannerUri(publicUrl);
      }
      setHasChanges(true);
      setUploadProgress((prev) => ({ ...prev, [type]: undefined }));
    } catch (err: any) {
      Alert.alert('Upload Failed', err.message ?? 'Could not upload');
      setUploadProgress((prev) => ({ ...prev, [type]: undefined }));
    }
  };

  const handleNameChange = (v: string) => {
    setName(v);
    setHasChanges(true);
  };

  const handleDescChange = (v: string) => {
    setDescription(v);
    setHasChanges(true);
  };

  if (isLoading) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary, justifyContent: 'center', alignItems: 'center' }]}>
        <ActivityIndicator size="large" color={themeColors.accentPrimary} />
      </View>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.backBtn, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Overview</Text>
          <Pressable
            onPress={() => updateMutation.mutate()}
            disabled={!hasChanges || updateMutation.isPending}
            style={[styles.saveBtn, { backgroundColor: themeColors.bgTertiary, opacity: hasChanges ? 1 : 0.4 }]}
          >
            {updateMutation.isPending ? (
              <ActivityIndicator size="small" color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.saveText, { color: themeColors.accentPrimary }]}>Save</Text>
            )}
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={{ paddingBottom: insets.bottom + 40 }} showsVerticalScrollIndicator={false}>
          {/* Server Preview Card */}
          <View style={[styles.previewCard, { backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}>
            {/* Banner */}
            <Pressable onPress={() => pickImage('banner')} style={styles.bannerContainer} disabled={uploadProgress.banner !== undefined}>
              {bannerUri ? (
                <Image source={{ uri: bannerUri }} style={styles.bannerImage} contentFit="cover" cachePolicy="memory-disk" autoplay={true} />
              ) : (
                <View style={[styles.bannerPlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
                  <Ionicons name="image-outline" size={32} color={themeColors.textMuted} />
                  <Text style={[styles.placeholderText, { color: themeColors.textMuted }]}>Add Banner</Text>
                </View>
              )}
              {uploadProgress.banner !== undefined ? (
                <View style={styles.uploadOverlay}>
                  <ActivityIndicator size="large" color="#fff" />
                  <Text style={styles.uploadText}>Uploading...</Text>
                </View>
              ) : (
                <View style={styles.bannerOverlay}>
                  <Ionicons name="camera" size={20} color="#fff" />
                </View>
              )}
            </Pressable>

            {/* Icon overlapping banner */}
            <View style={styles.iconOverlap}>
              <Pressable onPress={() => pickImage('icon')} disabled={uploadProgress.icon !== undefined}>
                <View style={[styles.iconContainer, { backgroundColor: themeColors.bgSecondary }]}>
                  {iconUri ? (
                    <Image source={{ uri: iconUri }} style={styles.iconImage} contentFit="cover" cachePolicy="memory-disk" autoplay={true} />
                  ) : (
                    <View style={[styles.iconPlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
                      <Ionicons name="server-outline" size={32} color={themeColors.textMuted} />
                    </View>
                  )}
                </View>
                {uploadProgress.icon !== undefined ? (
                  <View style={styles.iconUploadBadge}>
                    <ActivityIndicator size="small" color="#fff" />
                  </View>
                ) : (
                  <View style={styles.iconBadge}>
                    <Ionicons name="camera" size={12} color="#fff" />
                  </View>
                )}
              </Pressable>
              <View style={styles.serverInfo}>
                <Text style={[styles.serverName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                  {name || 'Server Name'}
                </Text>
                {description ? (
                  <Text style={[styles.serverDesc, { color: themeColors.textSecondary }]} numberOfLines={2}>
                    {description}
                  </Text>
                ) : null}
              </View>
            </View>
          </View>

          {/* Form Fields */}
          <View style={styles.formSection}>
            <Text style={[styles.label, { color: themeColors.textMuted }]}>SERVER NAME</Text>
            <TextInput
              value={name}
              onChangeText={handleNameChange}
              maxLength={100}
              style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}
              placeholderTextColor={themeColors.textMuted}
              placeholder="Enter server name"
            />

            <Text style={[styles.label, { color: themeColors.textMuted, marginTop: spacing.lg }]}>DESCRIPTION</Text>
            <TextInput
              value={description}
              onChangeText={handleDescChange}
              maxLength={1024}
              multiline
              numberOfLines={4}
              style={[styles.input, styles.multiline, { color: themeColors.textPrimary, backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}
              placeholderTextColor={themeColors.textMuted}
              placeholder="Tell people what your server is about"
            />
            <Text style={[styles.charCount, { color: themeColors.textMuted }]}>
              {description.length}/1024
            </Text>
          </View>

          {/* Leave Server Section */}
          <View style={[styles.dangerSection, { marginTop: spacing.xl }]}>
            <Text style={[styles.dangerLabel, { color: themeColors.danger }]}>DANGER ZONE</Text>
            <Pressable
              onPress={() => {
                Alert.alert(
                  'Leave Server',
                  `Are you sure you want to leave ${server?.name}? You won't be able to rejoin unless you are re-invited.`,
                  [
                    { text: 'Cancel', style: 'cancel' },
                    {
                      text: 'Leave Server',
                      style: 'destructive',
                      onPress: async () => {
                        try {
                          await notifyMemberLeave(serverId);
                          const { error } = await supabase
                            .from('server_members')
                            .delete()
                            .eq('server_id', serverId)
                            .eq('user_id', (await supabase.auth.getUser()).data.user?.id);
                          if (error) throw error;
                          queryClient.invalidateQueries({ queryKey: ['servers'] });
                          Alert.alert('Left Server', 'You have left the server.');
                          router.replace('/(tabs)');
                        } catch (err: any) {
                          Alert.alert('Error', err.message || 'Failed to leave server');
                        }
                      },
                    },
                  ]
                );
              }}
              style={[styles.dangerButton, { backgroundColor: themeColors.danger + '20', borderColor: themeColors.danger }]}
            >
              <Ionicons name="exit-outline" size={20} color={themeColors.danger} />
              <Text style={[styles.dangerButtonText, { color: themeColors.danger }]}>Leave Server</Text>
            </Pressable>
          </View>
        </ScrollView>
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
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  saveBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveText: { fontSize: 16, fontFamily: 'gg-sans-semibold' },

  previewCard: {
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    borderRadius: 12,
    overflow: 'hidden',
    borderWidth: 1,
  },
  bannerContainer: {
    height: 120,
    position: 'relative',
  },
  bannerImage: {
    width: '100%',
    height: '100%',
  },
  bannerPlaceholder: {
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  placeholderText: {
    fontSize: 13,
    marginTop: 4,
    fontFamily: 'gg-sans-medium',
  },
  bannerOverlay: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  uploadOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.7)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  uploadText: {
    color: '#fff',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    marginTop: 8,
  },
  iconOverlap: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    marginTop: -32,
    gap: spacing.md,
  },
  iconContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 4,
    overflow: 'hidden',
  },
  iconImage: {
    width: '100%',
    height: '100%',
  },
  iconPlaceholder: {
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconBadge: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#5865F2',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: '#1e1f22',
  },
  iconUploadBadge: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#5865F2',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: '#1e1f22',
  },
  serverInfo: {
    flex: 1,
  },
  serverName: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  serverDesc: {
    fontSize: 13,
    marginTop: 2,
  },

  formSection: {
    paddingHorizontal: spacing.lg,
    marginTop: spacing.lg,
  },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.sm,
  },
  input: {
    borderWidth: 1,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
  multiline: {
    minHeight: 100,
    textAlignVertical: 'top',
  },
  charCount: {
    fontSize: 12,
    textAlign: 'right',
    marginTop: 4,
  },
  dangerSection: {
    marginHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)',
  },
  dangerLabel: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.sm,
  },
  dangerButton: {
    borderWidth: 1,
    borderRadius: 8,
    minHeight: MINIMUM_TOUCH_TARGET,
    paddingHorizontal: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
  },
  dangerButtonText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
});
