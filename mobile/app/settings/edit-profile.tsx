/**
 * Edit Profile Screen — Discord-style
 *
 * Full-screen profile editor with banner, overlapping avatar,
 * inline profile card preview, and grouped input fields.
 * Supports avatar upload, banner upload (image/GIF), avatar decorations,
 * and profile banner color selection.
 * Route: /settings/edit-profile
 */
import React, { useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
  Modal as RNModal,
  FlatList,
  Platform,
  Dimensions,
} from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { uploadAvatar, uploadBanner } from '@services/cloudinaryService';
import type { CloudinaryUploadResult } from '@services/cloudinaryService';
import { supabase } from '../../services/supabase';
import { uploadProfileImageToSupabase } from '../../services/profileMediaUpload';
import { Avatar } from '../../components/ui/Avatar';
import { spacing, typography, borderRadius } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { darken } from '../../lib/colorUtils';

/**
 * Extract the most vibrant dominant color from Cloudinary color analysis.
 * Prefers saturated colors over greys/whites/blacks.
 */
function extractDominantColor(result: CloudinaryUploadResult): string | null {
  if (!result.colors || result.colors.length === 0) return null;

  // result.colors is [["#hex", weight], ...] sorted by weight descending
  for (const [hex] of result.colors) {
    // Skip near-white, near-black, and very grey colors
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const lightness = (max + min) / 2 / 255;
    const saturation = max === min ? 0 : (max - min) / (lightness > 0.5 ? (510 - max - min) : (max + min));

    // Accept if it has some color (saturation > 0.15) and isn't extreme lightness
    if (saturation > 0.15 && lightness > 0.08 && lightness < 0.92) {
      return hex;
    }
  }

  // Fallback to the most dominant color if all are grey/neutral
  return result.colors[0]?.[0] ?? null;
}

const { width: SCREEN_WIDTH } = Dimensions.get('window');

/* ─── Avatar decoration presets ─── */
const AVATAR_DECORATIONS = [
  { id: 'none', label: 'None', ring: null },
  { id: 'gold-ring', label: 'Gold Ring', ring: '#FFD700' },
  { id: 'rainbow', label: 'Rainbow', ring: ['#FF0000', '#FF7F00', '#FFFF00', '#00FF00', '#0000FF', '#8B00FF'] },
  { id: 'blurple-ring', label: 'Blurple', ring: '#5865F2' },
  { id: 'green-glow', label: 'Green Glow', ring: '#57F287' },
  { id: 'red-ring', label: 'Red Ring', ring: '#ED4245' },
  { id: 'cyan-glow', label: 'Cyan', ring: '#00CECE' },
  { id: 'pink-ring', label: 'Pink', ring: '#EB459E' },
  { id: 'purple-ring', label: 'Purple', ring: '#9B59B6' },
  { id: 'orange-ring', label: 'Orange', ring: '#E67E22' },
] as const;

/* ─── Banner color presets (Discord-style) ─── */
const BANNER_COLORS: { id: string; label: string; value: [string, string] }[] = [
  { id: 'blurple', label: 'Blurple', value: ['#5865F2', '#3A45C3'] },
  { id: 'green', label: 'Green', value: ['#57F287', '#2D7D46'] },
  { id: 'yellow', label: 'Yellow', value: ['#FEE75C', '#D4A017'] },
  { id: 'fuchsia', label: 'Fuchsia', value: ['#EB459E', '#A03070'] },
  { id: 'red', label: 'Red', value: ['#ED4245', '#A12D2F'] },
  { id: 'white', label: 'White', value: ['#FFFFFF', '#D0D0D0'] },
  { id: 'black', label: 'Black', value: ['#23272A', '#111111'] },
  { id: 'teal', label: 'Teal', value: ['#1ABC9C', '#117864'] },
  { id: 'navy', label: 'Navy', value: ['#34495E', '#1C2833'] },
  { id: 'sunset', label: 'Sunset', value: ['#FF6B6B', '#FF8E53'] },
  { id: 'ocean', label: 'Ocean', value: ['#667EEA', '#764BA2'] },
  { id: 'forest', label: 'Forest', value: ['#11998E', '#38EF7D'] },
  { id: 'candy', label: 'Candy', value: ['#FC5C7D', '#6A82FB'] },
  { id: 'midnight', label: 'Midnight', value: ['#2C3E50', '#4CA1AF'] },
  { id: 'fire', label: 'Fire', value: ['#F12711', '#F5AF19'] },
  { id: 'lavender', label: 'Lavender', value: ['#C471F5', '#FA71CD'] },
];

/* ─── Helper: pick image from library ─── */
async function pickImage(options?: {
  allowGif?: boolean;
  aspect?: [number, number];
}): Promise<ImagePicker.ImagePickerAsset | null> {
  const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Permission Needed', 'Please allow access to your photo library to upload images.');
    return null;
  }

  // First pick without editing to check if it's a GIF
  const preview = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images' as ImagePicker.MediaType],
    allowsEditing: false,
    quality: 1,
    allowsMultipleSelection: false,
  });

  if (preview.canceled || !preview.assets?.[0]) return null;
  const asset = preview.assets[0];

  const isGif = asset.mimeType === 'image/gif' ||
    asset.uri.toLowerCase().endsWith('.gif');

  // If it's a GIF, return directly without cropping (crop UI strips animation)
  if (isGif && options?.allowGif) {
    return asset;
  }

  // For non-GIF images, re-pick with crop UI
  const cropped = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images' as ImagePicker.MediaType],
    allowsEditing: true,
    aspect: options?.aspect,
    quality: 1,
    allowsMultipleSelection: false,
  });

  if (cropped.canceled || !cropped.assets?.[0]) return null;
  return cropped.assets[0];
}

/* ─── Helper: get auth token for Cloudinary signed uploads ─── */
async function getAuthToken(): Promise<string> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Not authenticated');
  return session.access_token;
}

export default function EditProfileScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors: c } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);
  const setUser = useAuthStore((s: AuthStore) => s.setUser);
  const queryClient = useQueryClient();

  const username =
    (user as any)?.user_metadata?.username ||
    (user as any)?.email?.split('@')[0] ||
    user?.username ||
    'User';
  const initialDisplayName =
    (user as any)?.user_metadata?.display_name || user?.display_name || username;
  const initialAvatarUrl =
    (user as any)?.user_metadata?.avatar_url || user?.avatar || null;
  const initialBannerUrl = user?.banner || null;

  /* ─── Form state ─── */
  const [displayName, setDisplayName] = useState(initialDisplayName);
  const [bio, setBio] = useState(user?.bio || '');
  const [pronouns, setPronouns] = useState(user?.pronouns || '');
  const [avatarUri, setAvatarUri] = useState<string | null>(initialAvatarUrl);
  const [bannerUri, setBannerUri] = useState<string | null>(initialBannerUrl);
  const [bannerColors, setBannerColors] = useState<[string, string]>(['#5865F2', '#3A45C3']);
  const [avatarDecoration, setAvatarDecoration] = useState<string>('none');
  const [isUploadingAvatar, setIsUploadingAvatar] = useState(false);
  const [isUploadingBanner, setIsUploadingBanner] = useState(false);

  /* ─── Modal state ─── */
  const [showAvatarSheet, setShowAvatarSheet] = useState(false);
  const [showBannerSheet, setShowBannerSheet] = useState(false);
  const [showDecorationModal, setShowDecorationModal] = useState(false);
  const [showBannerColorModal, setShowBannerColorModal] = useState(false);

  /* Track if images changed (state so save button re-renders) */
  const [avatarChanged, setAvatarChanged] = useState(false);
  const [bannerChanged, setBannerChanged] = useState(false);

  /* ─── Avatar pick + upload ─── */
  const handlePickAvatar = useCallback(async () => {
    setShowAvatarSheet(false);
    try {
      const asset = await pickImage({ allowGif: true, aspect: [1, 1] });
      if (!asset) return;

      setAvatarUri(asset.uri);
      setAvatarChanged(true);

      if (!user?.id) {
        Alert.alert('Error', 'User not found. Please log in again.');
        return;
      }
      
      setIsUploadingAvatar(true);

      try {
        const token = await getAuthToken();
        const mimeType = asset.mimeType || 'image/jpeg';
        let publicUrl: string;
        let cloudResult: CloudinaryUploadResult | null = null;
        try {
          cloudResult = await uploadAvatar(asset.uri, mimeType, user.id, token);
          publicUrl = cloudResult.secure_url;
        } catch {
          publicUrl = await uploadProfileImageToSupabase(asset.uri, mimeType, user.id, 'avatar');
        }

        const dominantColor = cloudResult ? extractDominantColor(cloudResult) : null;
        const profileUpdate: Record<string, any> = {
          avatar: publicUrl,
          updated_at: new Date().toISOString(),
        };
        if (dominantColor) {
          profileUpdate.accent_color = dominantColor;
          setBannerColors([dominantColor, darken(dominantColor, 15)]);
        }

        const { error } = await supabase
          .from('profiles')
          .update(profileUpdate)
          .eq('id', user.id);

        if (error) throw error;

        if (user) {
          setUser({ ...user, avatar: publicUrl });
        }
        queryClient.invalidateQueries({ queryKey: ['profile', user.id] });
        setAvatarUri(publicUrl);
        setAvatarChanged(false);
        
        Alert.alert('Success', 'Avatar uploaded successfully!');
      } catch (uploadErr: any) {
        console.error('Avatar upload error:', uploadErr);
        Alert.alert('Upload Failed', uploadErr.message || 'Could not upload avatar. Please check your internet connection and try again.');
        // Revert UI
        setAvatarUri(initialAvatarUrl);
        setAvatarChanged(false);
      }
    } catch (err: any) {
      console.error('Image picker error:', err);
      Alert.alert('Error', err.message || 'Could not pick image.');
    } finally {
      setIsUploadingAvatar(false);
    }
  }, [user, setUser, queryClient, initialAvatarUrl]);

  const handleRemoveAvatar = useCallback(async () => {
    setShowAvatarSheet(false);
    if (!user?.id) return;
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ avatar: null, updated_at: new Date().toISOString() })
        .eq('id', user.id);
      if (error) throw error;
      setAvatarUri(null);
      if (user) setUser({ ...user, avatar: null });
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }, [user, setUser, queryClient]);

  /* ─── Banner pick + upload ─── */
  const handlePickBanner = useCallback(async () => {
    setShowBannerSheet(false);
    try {
      const asset = await pickImage({ allowGif: true, aspect: [16, 9] });
      if (!asset) return;

      setBannerUri(asset.uri);
      setBannerChanged(true);

      if (!user?.id) {
        Alert.alert('Error', 'User not found. Please log in again.');
        return;
      }
      
      setIsUploadingBanner(true);

      try {
        const token = await getAuthToken();
        const mimeType = asset.mimeType || 'image/jpeg';
        let publicUrl: string;
        let cloudResult: CloudinaryUploadResult | null = null;
        try {
          cloudResult = await uploadBanner(asset.uri, mimeType, user.id, token);
          publicUrl = cloudResult.secure_url;
        } catch {
          publicUrl = await uploadProfileImageToSupabase(asset.uri, mimeType, user.id, 'banner');
        }

        const dominantColor = cloudResult ? extractDominantColor(cloudResult) : null;
        const profileUpdate: Record<string, any> = {
          banner: publicUrl,
          updated_at: new Date().toISOString(),
        };
        if (dominantColor) {
          profileUpdate.accent_color = dominantColor;
          setBannerColors([dominantColor, darken(dominantColor, 15)]);
        }

        const { error } = await supabase
          .from('profiles')
          .update(profileUpdate)
          .eq('id', user.id);

        if (error) throw error;

        if (user) {
          setUser({ ...user, banner: publicUrl });
        }
        queryClient.invalidateQueries({ queryKey: ['profile', user.id] });
        setBannerUri(publicUrl);
        setBannerChanged(false);
        
        Alert.alert('Success', 'Banner uploaded successfully!');
      } catch (uploadErr: any) {
        console.error('Banner upload error:', uploadErr);
        Alert.alert('Upload Failed', uploadErr.message || 'Could not upload banner. Please check your internet connection and try again.');
        // Revert UI
        setBannerUri(initialBannerUrl);
        setBannerChanged(false);
      }
    } catch (err: any) {
      console.error('Image picker error:', err);
      Alert.alert('Error', err.message || 'Could not pick image.');
    } finally {
      setIsUploadingBanner(false);
    }
  }, [user, setUser, queryClient, initialBannerUrl]);

  const handleRemoveBanner = useCallback(async () => {
    setShowBannerSheet(false);
    if (!user?.id) return;
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ banner: null, updated_at: new Date().toISOString() })
        .eq('id', user.id);
      if (error) throw error;
      setBannerUri(null);
      if (user) setUser({ ...user, banner: null });
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }, [user, setUser, queryClient]);

  /* ─── Save text fields (HIGH-004: with input validation) ─── */
  const updateMutation = useMutation({
    mutationFn: async () => {
      if (!user?.id) throw new Error('Not logged in');

      // Validate display name
      const trimmedName = displayName.trim();
      if (trimmedName && trimmedName.length > 32) {
        throw new Error('Display name must be 32 characters or less');
      }
      if (trimmedName && !/^[\w\s\-.']+$/u.test(trimmedName)) {
        throw new Error('Display name contains invalid characters');
      }

      // Validate bio
      const trimmedBio = bio.trim();
      if (trimmedBio && trimmedBio.length > 190) {
        throw new Error('Bio must be 190 characters or less');
      }

      // Validate pronouns
      const trimmedPronouns = pronouns.trim();
      if (trimmedPronouns && trimmedPronouns.length > 40) {
        throw new Error('Pronouns must be 40 characters or less');
      }

      // Strip any HTML tags from bio to prevent XSS
      const sanitizedBio = trimmedBio.replace(/<[^>]*>/g, '');

      const { error } = await supabase
        .from('profiles')
        .update({
          display_name: trimmedName || null,
          bio: sanitizedBio || null,
          pronouns: trimmedPronouns || null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id);
      if (error) throw error;
    },
    onSuccess: () => {
      if (user) {
        setUser({
          ...user,
          display_name: displayName.trim() || null,
          bio: bio.trim() || null,
          pronouns: pronouns.trim() || null,
        });
      }
      queryClient.invalidateQueries({ queryKey: ['profile', user?.id] });
      Alert.alert('Success', 'Profile updated successfully.');
      router.back();
    },
    onError: (err: Error) => {
      Alert.alert('Error', err.message);
    },
  });

  const hasChanges =
    displayName !== initialDisplayName ||
    bio !== (user?.bio || '') ||
    pronouns !== (user?.pronouns || '') ||
    avatarChanged ||
    bannerChanged;

  const handleSave = useCallback(() => {
    updateMutation.mutate();
  }, [updateMutation]);

  /* ─── Decoration ring helper ─── */
  const activeDecoration = AVATAR_DECORATIONS.find((d) => d.id === avatarDecoration);
  const ringColor = activeDecoration?.ring;

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.screen, { backgroundColor: c.bgPrimary }]}>
        {/* ─── Top bar ─── */}
        <View style={[styles.topBar, { paddingTop: insets.top + 4 }]}>
          <Pressable onPress={() => router.back()} style={styles.topBtn} hitSlop={12}>
            <Ionicons name="close" size={24} color={c.textPrimary} />
          </Pressable>
          <Text style={[styles.topTitle, { color: c.textPrimary }]}>Edit Profile</Text>
          <Pressable
            onPress={handleSave}
            disabled={!hasChanges || updateMutation.isPending}
            style={[
              styles.saveChip,
              {
                backgroundColor: hasChanges ? c.accentPrimary : c.bgTertiary,
                opacity: hasChanges ? 1 : 0.4,
              },
            ]}
            hitSlop={8}
          >
            {updateMutation.isPending ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.saveChipText}>Save</Text>
            )}
          </Pressable>
        </View>

        <ScrollView
          style={styles.scroll}
          contentContainerStyle={{ paddingBottom: insets.bottom + 40 }}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {/* ─── Profile card (banner + avatar + name) ─── */}
          <View style={styles.profileCard}>
            {/* Banner */}
            <View style={styles.bannerWrap}>
              {bannerUri ? (
                <Image
                  key={bannerUri}
                  source={{ uri: bannerUri }}
                  style={StyleSheet.absoluteFillObject}
                  contentFit="cover"
                  cachePolicy="memory-disk"
                  recyclingKey={bannerUri}
                />
              ) : (
                <LinearGradient
                  colors={bannerColors}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={StyleSheet.absoluteFillObject}
                />
              )}
              <Pressable
                style={styles.bannerEditBtn}
                onPress={() => setShowBannerSheet(true)}
                hitSlop={8}
              >
                {isUploadingBanner ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Ionicons name="camera" size={18} color="#fff" />
                )}
              </Pressable>
            </View>

            {/* Avatar (overlapping banner) */}
            <View style={styles.avatarRow}>
              <View style={styles.avatarContainer}>
                <Pressable
                  style={[
                    styles.avatarWrap,
                    ringColor && typeof ringColor === 'string'
                      ? { borderColor: ringColor, borderWidth: 3 }
                      : null,
                  ]}
                  onPress={() => setShowAvatarSheet(true)}
                >
                  {avatarUri ? (
                    <Image
                      key={avatarUri}
                      source={{ uri: avatarUri }}
                      style={styles.avatarImage}
                      contentFit="cover"
                      cachePolicy="memory-disk"
                      recyclingKey={avatarUri}
                    />
                  ) : (
                    <Avatar
                      name={displayName || username}
                      size={78}
                    />
                  )}
                </Pressable>
                <View style={styles.avatarBadge}>
                  {isUploadingAvatar ? (
                    <ActivityIndicator size={10} color="#fff" />
                  ) : (
                    <Ionicons name="camera" size={14} color="#fff" />
                  )}
                </View>
              </View>
            </View>

            {/* Name preview inside card */}
            <View style={styles.nameBlock}>
              <Text style={[styles.previewDisplayName, { color: c.textPrimary }]}>
                {displayName || username}
              </Text>
              <Text style={[styles.previewUsername, { color: c.textSecondary }]}>
                {username}
              </Text>
              {pronouns ? (
                <Text style={[styles.previewPronouns, { color: c.textSecondary }]}>
                  {pronouns}
                </Text>
              ) : null}
              {bio ? (
                <View style={[styles.aboutMeSection, { borderColor: c.border }]}>
                  <Text style={[styles.aboutMeLabel, { color: c.textPrimary }]}>
                    ABOUT ME
                  </Text>
                  <Text
                    style={[styles.previewBio, { color: c.textSecondary }]}
                    numberOfLines={3}
                  >
                    {bio}
                  </Text>
                </View>
              ) : null}
            </View>
          </View>

          {/* ─── Fields ─── */}
          <View style={styles.section}>
            <Text style={[styles.sectionLabel, { color: c.textMuted }]}>DISPLAY NAME</Text>
            <View
              style={[styles.inputWrap, { backgroundColor: c.bgSecondary, borderColor: c.border }]}
            >
              <TextInput
                style={[styles.input, { color: c.textPrimary }]}
                value={displayName}
                onChangeText={setDisplayName}
                placeholder="How others see you"
                placeholderTextColor={c.textMuted}
                maxLength={32}
                returnKeyType="done"
              />
            </View>
          </View>

          <View style={styles.section}>
            <Text style={[styles.sectionLabel, { color: c.textMuted }]}>PRONOUNS</Text>
            <View
              style={[styles.inputWrap, { backgroundColor: c.bgSecondary, borderColor: c.border }]}
            >
              <TextInput
                style={[styles.input, { color: c.textPrimary }]}
                value={pronouns}
                onChangeText={setPronouns}
                placeholder="Add your pronouns"
                placeholderTextColor={c.textMuted}
                maxLength={40}
                returnKeyType="done"
              />
            </View>
          </View>

          <View style={styles.section}>
            <View style={styles.sectionLabelRow}>
              <Text style={[styles.sectionLabel, { color: c.textMuted }]}>ABOUT ME</Text>
              <Text style={[styles.charCount, { color: c.textMuted }]}>{bio.length}/190</Text>
            </View>
            <View
              style={[
                styles.inputWrap,
                styles.bioWrap,
                { backgroundColor: c.bgSecondary, borderColor: c.border },
              ]}
            >
              <TextInput
                style={[styles.input, styles.bioInput, { color: c.textPrimary }]}
                value={bio}
                onChangeText={setBio}
                placeholder="Tell the world a little bit about yourself"
                placeholderTextColor={c.textMuted}
                multiline
                maxLength={190}
                textAlignVertical="top"
              />
            </View>
          </View>

          {/* ─── Extra rows ─── */}
          <Pressable
            onPress={() => setShowDecorationModal(true)}
            style={({ pressed }) => [
              styles.decorationRow,
              { backgroundColor: c.bgSecondary, borderColor: c.border },
              pressed && { opacity: 0.7 },
            ]}
          >
            <Ionicons name="sparkles-outline" size={20} color={c.accentPrimary} />
            <Text style={[styles.decorationText, { color: c.textPrimary }]}>
              Avatar Decorations
            </Text>
            {avatarDecoration !== 'none' && (
              <View
                style={[
                  styles.activeIndicator,
                  {
                    backgroundColor:
                      typeof ringColor === 'string' ? ringColor : c.accentPrimary,
                  },
                ]}
              />
            )}
            <Ionicons name="chevron-forward" size={18} color={c.textMuted} />
          </Pressable>

          <Pressable
            onPress={() => setShowBannerColorModal(true)}
            style={({ pressed }) => [
              styles.decorationRow,
              { backgroundColor: c.bgSecondary, borderColor: c.border, marginTop: spacing.xs },
              pressed && { opacity: 0.7 },
            ]}
          >
            <Ionicons name="color-palette-outline" size={20} color={c.accentPrimary} />
            <Text style={[styles.decorationText, { color: c.textPrimary }]}>
              Profile Banner Color
            </Text>
            <View style={styles.colorPreviewRow}>
              <LinearGradient
                colors={bannerColors}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={styles.colorPreviewSwatch}
              />
            </View>
            <Ionicons name="chevron-forward" size={18} color={c.textMuted} />
          </Pressable>
        </ScrollView>
      </View>

      {/* ═══════════════════════════════════════════
          Avatar Action Sheet
         ═══════════════════════════════════════════ */}
      <RNModal
        visible={showAvatarSheet}
        transparent
        animationType="fade"
        onRequestClose={() => setShowAvatarSheet(false)}
      >
        <Pressable
          style={styles.sheetBackdrop}
          onPress={() => setShowAvatarSheet(false)}
        />
        <View style={[styles.sheetContainer, { paddingBottom: insets.bottom + 16 }]}>
          <View style={[styles.sheetContent, { backgroundColor: c.bgSecondary }]}>
            <View style={styles.sheetHandle} />
            <Text style={[styles.sheetTitle, { color: c.textPrimary }]}>
              Profile Photo
            </Text>

            <Pressable
              style={({ pressed }) => [
                styles.sheetOption,
                { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
              ]}
              onPress={handlePickAvatar}
            >
              <Ionicons name="image-outline" size={22} color={c.accentPrimary} />
              <Text style={[styles.sheetOptionText, { color: c.textPrimary }]}>
                Upload Photo
              </Text>
            </Pressable>

            {avatarUri && (
              <Pressable
                style={({ pressed }) => [
                  styles.sheetOption,
                  { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
                ]}
                onPress={handleRemoveAvatar}
              >
                <Ionicons name="trash-outline" size={22} color={c.danger} />
                <Text style={[styles.sheetOptionText, { color: c.danger }]}>
                  Remove Photo
                </Text>
              </Pressable>
            )}

            <Pressable
              style={({ pressed }) => [
                styles.sheetOption,
                { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
              ]}
              onPress={() => setShowAvatarSheet(false)}
            >
              <Ionicons name="close-outline" size={22} color={c.textSecondary} />
              <Text style={[styles.sheetOptionText, { color: c.textSecondary }]}>
                Cancel
              </Text>
            </Pressable>
          </View>
        </View>
      </RNModal>

      {/* ═══════════════════════════════════════════
          Banner Action Sheet
         ═══════════════════════════════════════════ */}
      <RNModal
        visible={showBannerSheet}
        transparent
        animationType="fade"
        onRequestClose={() => setShowBannerSheet(false)}
      >
        <Pressable
          style={styles.sheetBackdrop}
          onPress={() => setShowBannerSheet(false)}
        />
        <View style={[styles.sheetContainer, { paddingBottom: insets.bottom + 16 }]}>
          <View style={[styles.sheetContent, { backgroundColor: c.bgSecondary }]}>
            <View style={styles.sheetHandle} />
            <Text style={[styles.sheetTitle, { color: c.textPrimary }]}>
              Profile Banner
            </Text>

            <Pressable
              style={({ pressed }) => [
                styles.sheetOption,
                { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
              ]}
              onPress={handlePickBanner}
            >
              <Ionicons name="image-outline" size={22} color={c.accentPrimary} />
              <Text style={[styles.sheetOptionText, { color: c.textPrimary }]}>
                Upload Image or GIF
              </Text>
            </Pressable>

            <Pressable
              style={({ pressed }) => [
                styles.sheetOption,
                { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
              ]}
              onPress={() => {
                setShowBannerSheet(false);
                setShowBannerColorModal(true);
              }}
            >
              <Ionicons name="color-palette-outline" size={22} color={c.accentPrimary} />
              <Text style={[styles.sheetOptionText, { color: c.textPrimary }]}>
                Choose Banner Color
              </Text>
            </Pressable>

            {bannerUri && (
              <Pressable
                style={({ pressed }) => [
                  styles.sheetOption,
                  { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
                ]}
                onPress={handleRemoveBanner}
              >
                <Ionicons name="trash-outline" size={22} color={c.danger} />
                <Text style={[styles.sheetOptionText, { color: c.danger }]}>
                  Remove Banner
                </Text>
              </Pressable>
            )}

            <Pressable
              style={({ pressed }) => [
                styles.sheetOption,
                { backgroundColor: pressed ? c.bgTertiary : 'transparent' },
              ]}
              onPress={() => setShowBannerSheet(false)}
            >
              <Ionicons name="close-outline" size={22} color={c.textSecondary} />
              <Text style={[styles.sheetOptionText, { color: c.textSecondary }]}>
                Cancel
              </Text>
            </Pressable>
          </View>
        </View>
      </RNModal>

      {/* ═══════════════════════════════════════════
          Avatar Decoration Modal
         ═══════════════════════════════════════════ */}
      <RNModal
        visible={showDecorationModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowDecorationModal(false)}
      >
        <Pressable
          style={styles.sheetBackdrop}
          onPress={() => setShowDecorationModal(false)}
        />
        <View style={[styles.modalContainer, { paddingBottom: insets.bottom + 16 }]}>
          <View style={[styles.modalContent, { backgroundColor: c.bgSecondary }]}>
            <View style={styles.sheetHandle} />
            <Text style={[styles.modalTitle, { color: c.textPrimary }]}>
              Avatar Decorations
            </Text>
            <Text style={[styles.modalSubtitle, { color: c.textSecondary }]}>
              Add a ring effect around your avatar
            </Text>

            {/* Preview */}
            <View style={styles.decoPreviewWrap}>
              <View
                style={[
                  styles.decoPreviewRing,
                  {
                    borderColor:
                      ringColor && typeof ringColor === 'string'
                        ? ringColor
                        : c.bgTertiary,
                    borderWidth: ringColor ? 3 : 0,
                  },
                ]}
              >
                {avatarUri ? (
                  <Image
                    key={avatarUri}
                    source={{ uri: avatarUri }}
                    style={styles.decoPreviewAvatar}
                    contentFit="cover"
                    cachePolicy="memory-disk"
                    recyclingKey={avatarUri}
                  />
                ) : (
                  <Avatar name={displayName || username} size={72} />
                )}
              </View>
            </View>

            {/* Grid of decorations */}
            <FlatList
              data={AVATAR_DECORATIONS}
              keyExtractor={(item) => item.id}
              numColumns={5}
              contentContainerStyle={styles.decoGrid}
              renderItem={({ item }) => {
                const isActive = avatarDecoration === item.id;
                const color =
                  item.ring && typeof item.ring === 'string' ? item.ring : c.bgTertiary;
                return (
                  <Pressable
                    onPress={() => setAvatarDecoration(item.id)}
                    style={[
                      styles.decoItem,
                      isActive && { borderColor: c.accentPrimary, borderWidth: 2 },
                    ]}
                  >
                    {item.ring ? (
                      <View
                        style={[
                          styles.decoCircle,
                          {
                            borderColor: color,
                            borderWidth: 3,
                          },
                        ]}
                      />
                    ) : (
                      <View style={[styles.decoCircle, { backgroundColor: c.bgTertiary }]}>
                        <Ionicons name="close" size={18} color={c.textMuted} />
                      </View>
                    )}
                    <Text
                      style={[styles.decoLabel, { color: c.textSecondary }]}
                      numberOfLines={1}
                    >
                      {item.label}
                    </Text>
                  </Pressable>
                );
              }}
            />

            <Pressable
              onPress={() => setShowDecorationModal(false)}
              style={[styles.modalDoneBtn, { backgroundColor: c.accentPrimary }]}
            >
              <Text style={styles.modalDoneBtnText}>Done</Text>
            </Pressable>
          </View>
        </View>
      </RNModal>

      {/* ═══════════════════════════════════════════
          Banner Color Modal
         ═══════════════════════════════════════════ */}
      <RNModal
        visible={showBannerColorModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowBannerColorModal(false)}
      >
        <Pressable
          style={styles.sheetBackdrop}
          onPress={() => setShowBannerColorModal(false)}
        />
        <View style={[styles.modalContainer, { paddingBottom: insets.bottom + 16 }]}>
          <View style={[styles.modalContent, { backgroundColor: c.bgSecondary }]}>
            <View style={styles.sheetHandle} />
            <Text style={[styles.modalTitle, { color: c.textPrimary }]}>
              Banner Color
            </Text>
            <Text style={[styles.modalSubtitle, { color: c.textSecondary }]}>
              Choose a gradient for your profile banner
            </Text>

            {/* Preview */}
            <View style={styles.bannerColorPreview}>
              <LinearGradient
                colors={bannerColors}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.bannerColorPreviewGradient}
              />
            </View>

            {/* Color grid */}
            <FlatList
              data={BANNER_COLORS}
              keyExtractor={(item) => item.id}
              numColumns={4}
              contentContainerStyle={styles.colorGrid}
              renderItem={({ item }) => {
                const isActive =
                  bannerColors[0] === item.value[0] &&
                  bannerColors[1] === item.value[1];
                return (
                  <Pressable
                    onPress={() => {
                      setBannerColors(item.value);
                      setBannerUri(null); // clear uploaded banner when choosing color
                    }}
                    style={[
                      styles.colorItem,
                      isActive && {
                        borderColor: '#fff',
                        borderWidth: 2,
                      },
                    ]}
                  >
                    <LinearGradient
                      colors={item.value}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.colorSwatch}
                    />
                    <Text
                      style={[styles.colorLabel, { color: c.textSecondary }]}
                      numberOfLines={1}
                    >
                      {item.label}
                    </Text>
                    {isActive && (
                      <View style={styles.colorCheckWrap}>
                        <Ionicons name="checkmark" size={14} color="#fff" />
                      </View>
                    )}
                  </Pressable>
                );
              }}
            />

            <Pressable
              onPress={() => setShowBannerColorModal(false)}
              style={[styles.modalDoneBtn, { backgroundColor: c.accentPrimary }]}
            >
              <Text style={styles.modalDoneBtnText}>Done</Text>
            </Pressable>
          </View>
        </View>
      </RNModal>
    </>
  );
}

/* ═══════════════════════════════════════════════════════
   Styles
   ═══════════════════════════════════════════════════════ */
const styles = StyleSheet.create({
  screen: { flex: 1 },

  /* ── Top bar ── */
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: 10,
  },
  topBtn: {
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  topTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontFamily: 'gg-sans-semibold',
  },
  saveChip: {
    paddingHorizontal: 16,
    paddingVertical: 7,
    borderRadius: 16,
    minWidth: 56,
    alignItems: 'center',
  },
  saveChipText: { color: '#FFFFFF', fontSize: 14, fontFamily: 'gg-sans-semibold' },

  /* ── Scroll ── */
  scroll: { flex: 1 },

  /* ── Profile card ── */
  profileCard: {
    marginHorizontal: spacing.md,
    marginTop: spacing.sm,
    backgroundColor: '#111119',
    borderRadius: 16,
    overflow: 'hidden',
    marginBottom: spacing.lg,
  },
  bannerWrap: { height: 130, position: 'relative' },
  bannerEditBtn: {
    position: 'absolute',
    top: 12,
    right: 12,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },

  avatarRow: { paddingHorizontal: spacing.md, marginTop: -42 },
  avatarContainer: { position: 'relative', width: 84, height: 84 },
  avatarWrap: {
    width: 84,
    height: 84,
    borderRadius: 42,
    borderWidth: 4,
    borderColor: '#111119',
    overflow: 'hidden',
    backgroundColor: '#111119',
  },
  avatarImage: { width: '100%', height: '100%', borderRadius: 40 },
  avatarBadge: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#5865F2',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: '#111119',
  },

  nameBlock: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    paddingBottom: spacing.lg,
  },
  previewDisplayName: { fontSize: 20, fontFamily: 'gg-sans-bold' },
  previewUsername: { fontSize: 14, marginTop: 2 },
  previewPronouns: { fontSize: 12, marginTop: 2, fontStyle: 'italic' },
  aboutMeSection: {
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  aboutMeLabel: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  previewBio: { fontSize: 13, lineHeight: 18 },

  /* ── Input sections ── */
  section: { marginHorizontal: spacing.md, marginBottom: spacing.lg },
  sectionLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.xs,
  },
  sectionLabelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  charCount: { fontSize: 12, fontFamily: 'gg-sans-medium' },
  inputWrap: { borderRadius: 8, borderWidth: 1, overflow: 'hidden' },
  input: { paddingHorizontal: 14, paddingVertical: 12, fontSize: 15 },
  bioWrap: {},
  bioInput: { minHeight: 100, textAlignVertical: 'top' },

  /* ── Extra rows ── */
  decorationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.md,
    paddingHorizontal: 14,
    paddingVertical: 14,
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    marginTop: spacing.sm,
  },
  decorationText: { flex: 1, fontSize: 15, fontFamily: 'gg-sans-medium' },
  activeIndicator: { width: 8, height: 8, borderRadius: 4 },
  colorPreviewRow: { marginRight: 4 },
  colorPreviewSwatch: { width: 24, height: 24, borderRadius: 12 },

  /* ── Action sheet (avatar / banner) ── */
  sheetBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.55)',
  },
  sheetContainer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheetContent: {
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  sheetHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignSelf: 'center',
    marginBottom: spacing.md,
  },
  sheetTitle: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
    marginBottom: spacing.md,
    textAlign: 'center',
  },
  sheetOption: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingVertical: 14,
    paddingHorizontal: 8,
    borderRadius: 8,
  },
  sheetOptionText: { fontSize: 16, fontFamily: 'gg-sans-medium' },

  /* ── Full modal (decorations / colors) ── */
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
    maxHeight: '80%',
  },
  modalTitle: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
    marginBottom: 4,
  },
  modalSubtitle: {
    fontSize: 13,
    textAlign: 'center',
    marginBottom: spacing.md,
  },
  modalDoneBtn: {
    marginTop: spacing.md,
    marginBottom: spacing.sm,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  modalDoneBtnText: { color: '#fff', fontSize: 16, fontFamily: 'gg-sans-semibold' },

  /* ── Decoration grid ── */
  decoPreviewWrap: { alignItems: 'center', marginBottom: spacing.lg },
  decoPreviewRing: {
    width: 84,
    height: 84,
    borderRadius: 42,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  decoPreviewAvatar: { width: 72, height: 72, borderRadius: 36 },
  decoGrid: { paddingBottom: spacing.sm },
  decoItem: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.sm,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: 'transparent',
    maxWidth: SCREEN_WIDTH / 5 - spacing.lg,
    marginHorizontal: 2,
  },
  decoCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  decoLabel: { fontSize: 10, marginTop: 4, textAlign: 'center' },

  /* ── Color grid ── */
  bannerColorPreview: {
    height: 60,
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: spacing.md,
  },
  bannerColorPreviewGradient: { flex: 1 },
  colorGrid: { paddingBottom: spacing.sm },
  colorItem: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.sm,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: 'transparent',
    maxWidth: SCREEN_WIDTH / 4 - spacing.lg,
    marginHorizontal: 2,
    position: 'relative',
  },
  colorSwatch: {
    width: 48,
    height: 48,
    borderRadius: 12,
  },
  colorLabel: { fontSize: 10, marginTop: 4, textAlign: 'center' },
  colorCheckWrap: {
    position: 'absolute',
    top: spacing.sm + 14,
    alignSelf: 'center',
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
