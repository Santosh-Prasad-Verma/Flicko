/**
 * Create Server Screen — Discord-style multi-step flow
 *
 * Step 1: "Create Your Server" — choose a template or custom
 * Step 2: "Tell us more about your server" — For me and friends / Community
 * Step 3: "Customise your server" — name + icon + create
 *
 * Route: /server/create
 * Requirements: 3.1, 3.2
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import Animated, { FadeIn, FadeOut, SlideInRight, SlideOutLeft } from 'react-native-reanimated';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { uploadServerIcon, uploadServerBanner } from '@services/cloudinaryService';
import { useAuthStore } from '@stores/authStore';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

/* ─── Step definitions ─── */
type Step = 'template' | 'purpose' | 'customize';
type Template = 'custom' | 'gaming' | 'school' | 'study' | 'friends' | 'creators' | 'community';
type Purpose = 'friends' | 'community';

interface TemplateOption {
  id: Template;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  color: string;
}

const TEMPLATES: TemplateOption[] = [
  { id: 'custom', label: 'Create My Own', icon: 'add-circle-outline', color: '#5865F2' },
  { id: 'gaming', label: 'Gaming', icon: 'game-controller', color: '#57F287' },
  { id: 'school', label: 'School Club', icon: 'school', color: '#FEE75C' },
  { id: 'study', label: 'Study Group', icon: 'book', color: '#EB459E' },
  { id: 'friends', label: 'Friends', icon: 'people', color: '#ED4245' },
  { id: 'creators', label: 'Artists & Creators', icon: 'color-palette', color: '#5865F2' },
  { id: 'community', label: 'Local Community', icon: 'earth', color: '#57F287' },
];

/* ─── Default channel presets per template ─── */
const TEMPLATE_CHANNELS: Record<Template, { name: string; type: 'text' | 'voice' }[]> = {
  custom: [
    { name: 'general', type: 'text' },
  ],
  gaming: [
    { name: 'general', type: 'text' },
    { name: 'game-chat', type: 'text' },
    { name: 'looking-for-group', type: 'text' },
    { name: 'clips-and-highlights', type: 'text' },
    { name: 'Gaming Voice', type: 'voice' },
    { name: 'AFK', type: 'voice' },
  ],
  school: [
    { name: 'general', type: 'text' },
    { name: 'announcements', type: 'text' },
    { name: 'homework-help', type: 'text' },
    { name: 'resources', type: 'text' },
    { name: 'off-topic', type: 'text' },
    { name: 'Study Room', type: 'voice' },
  ],
  study: [
    { name: 'general', type: 'text' },
    { name: 'study-resources', type: 'text' },
    { name: 'questions', type: 'text' },
    { name: 'homework-help', type: 'text' },
    { name: 'Study Session', type: 'voice' },
    { name: 'Quiet Study', type: 'voice' },
  ],
  friends: [
    { name: 'general', type: 'text' },
    { name: 'memes', type: 'text' },
    { name: 'games', type: 'text' },
    { name: 'music', type: 'text' },
    { name: 'Hangout', type: 'voice' },
    { name: 'Music', type: 'voice' },
  ],
  creators: [
    { name: 'general', type: 'text' },
    { name: 'show-your-work', type: 'text' },
    { name: 'feedback', type: 'text' },
    { name: 'resources', type: 'text' },
    { name: 'collaborations', type: 'text' },
    { name: 'Creative Voice', type: 'voice' },
  ],
  community: [
    { name: 'general', type: 'text' },
    { name: 'introductions', type: 'text' },
    { name: 'announcements', type: 'text' },
    { name: 'events', type: 'text' },
    { name: 'off-topic', type: 'text' },
    { name: 'Community Voice', type: 'voice' },
    { name: 'Events', type: 'voice' },
  ],
};

async function getAuthToken(): Promise<string> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Not authenticated');
  return session.access_token;
}

/* Upload helper — works for icons AND banners, supports GIF */
async function uploadServerImage(
  type: 'icon' | 'banner',
  serverId: string,
  asset: ImagePicker.ImagePickerAsset,
): Promise<string> {
  const mimeType = asset.mimeType || 'image/jpeg';
  const token = await getAuthToken();

  const result = type === 'icon'
    ? await uploadServerIcon(asset.uri, mimeType, serverId, token)
    : await uploadServerBanner(asset.uri, mimeType, serverId, token);

  return result.secure_url;
}

export default function CreateServerScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors: c } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);

  /* ─── Multi-step state ─── */
  const [step, setStep] = useState<Step>('template');
  const [selectedTemplate, setSelectedTemplate] = useState<Template>('custom');
  const [purpose, setPurpose] = useState<Purpose>('friends');
  const [name, setName] = useState('');
  const [iconUri, setIconUri] = useState<string | null>(null);
  const [iconAsset, setIconAsset] = useState<ImagePicker.ImagePickerAsset | null>(null);
  const [bannerUri, setBannerUri] = useState<string | null>(null);
  const [bannerAsset, setBannerAsset] = useState<ImagePicker.ImagePickerAsset | null>(null);
  const [error, setError] = useState('');

  const username = user?.display_name || user?.username || 'User';

  /* ─── Icon pick ─── */
  const requestMediaPermission = useCallback(async () => {
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission Needed', 'Please allow access to your photo library.');
      return false;
    }
    return true;
  }, []);

  const handlePickIcon = useCallback(async () => {
    if (!(await requestMediaPermission())) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images' as ImagePicker.MediaType],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });
    if (!result.canceled && result.assets?.[0]) {
      setIconUri(result.assets[0].uri);
      setIconAsset(result.assets[0]);
    }
  }, [requestMediaPermission]);

  const handlePickBanner = useCallback(async () => {
    if (!(await requestMediaPermission())) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images' as ImagePicker.MediaType],
      allowsEditing: true,
      aspect: [16, 9],
      quality: 0.8,
    });
    if (!result.canceled && result.assets?.[0]) {
      setBannerUri(result.assets[0].uri);
      setBannerAsset(result.assets[0]);
    }
  }, [requestMediaPermission]);

  /* ─── Create mutation ─── */
  const createMutation = useMutation({
    mutationFn: async () => {
      if (!user?.id) throw new Error('Not logged in');
      const trimmedName = name.trim();
      if (!trimmedName) throw new Error('Server name is required');
      if (trimmedName.length > 100) throw new Error('Server name must be 100 characters or less');

      // Create server via SECURITY DEFINER RPC (bypasses RLS reliably)
      const { data: server, error: rpcErr } = await supabase.rpc('create_server_rpc', {
        p_name: trimmedName,
      });
      if (rpcErr) throw new Error(rpcErr.message);
      if (!server?.id) throw new Error('Server creation failed: no data returned');

      let iconFailed = false;
      // Upload icon if selected
      if (iconAsset) {
        try {
          const iconUrl = await uploadServerImage('icon', server.id, iconAsset);
          await supabase.from('servers').update({ icon: iconUrl }).eq('id', server.id);
        } catch {
          iconFailed = true;
        }
      }

      let bannerFailed = false;
      // Upload banner if selected
      if (bannerAsset) {
        try {
          const bannerUrl = await uploadServerImage('banner', server.id, bannerAsset);
          await supabase.from('servers').update({ banner: bannerUrl }).eq('id', server.id);
        } catch {
          bannerFailed = true;
        }
      }

      // Create template channels (trigger already creates 'general' at position 0)
      const channels = (TEMPLATE_CHANNELS[selectedTemplate] || [{ name: 'general', type: 'text' }])
        .filter((ch) => ch.name !== 'general'); // skip 'general' — created by trigger
      
      for (let i = 0; i < channels.length; i++) {
        await supabase.from('channels').insert({
          name: channels[i].name,
          type: channels[i].type,
          server_id: server.id,
          position: i + 1, // offset by 1 since 'general' is at 0
        });
      }

      if (iconFailed || bannerFailed) {
        // We throw a custom error object containing the server ID so onSuccess can still navigate
        throw { isPartialSuccess: true, server, message: 'Server created, but image upload failed. You can upload it later in server settings.' };
      }

      return server;
    },
    onSuccess: (server) => {
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      router.replace(`/server/${server.id}`);
    },
    onError: (err: any) => {
      if (err.isPartialSuccess && err.server) {
        queryClient.invalidateQueries({ queryKey: ['servers'] });
        setError(err.message);
        setTimeout(() => {
          router.replace(`/server/${err.server.id}`);
        }, 3000);
      } else {
        setError(err.message);
      }
    },
  });

  const handleCreate = () => {
    setError('');
    if (!name.trim()) {
      setError('Server name is required');
      return;
    }
    createMutation.mutate();
  };

  /* ─── Navigation helpers ─── */
  const handleBack = () => {
    if (step === 'customize') setStep('purpose');
    else if (step === 'purpose') setStep('template');
    else router.back();
  };

  const handleTemplateSelect = (template: Template) => {
    setSelectedTemplate(template);
    setStep('purpose');
  };

  const handlePurposeSelect = (p: Purpose) => {
    setPurpose(p);
    if (!name) setName(`${username}'s server`);
    setStep('customize');
  };

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: false,
          animation: 'slide_from_bottom',
          presentation: 'modal',
        }}
      />
      <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
        {/* Top Bar */}
        <View
          style={[
            styles.topBar,
            {
              paddingTop: insets.top + 8,
              backgroundColor: c.bgSecondary,
              borderBottomColor: c.border,
            },
          ]}
        >
          <Pressable onPress={handleBack} hitSlop={12} style={[styles.backBtn, { backgroundColor: c.bgTertiary }]}>
            {step === 'template' ? (
              <Ionicons name="close" size={24} color={c.textPrimary} />
            ) : (
              <Ionicons name="arrow-back" size={24} color={c.textPrimary} />
            )}
          </Pressable>
        </View>

        {/* ═══ STEP 1: Choose a template ═══ */}
        {step === 'template' && (
          <Animated.ScrollView
            entering={SlideInRight.springify()}
            exiting={SlideOutLeft.duration(200)}
            contentContainerStyle={styles.stepContent}
            showsVerticalScrollIndicator={false}
          >
            <Text style={[styles.heading, { color: c.textPrimary }]}>
              Create Your Server
            </Text>
            <Text style={[styles.subtitle, { color: c.textSecondary }]}>
              Your server is where you and your friends hang out.{'\n'}
              Make yours and start talking.
            </Text>

            <View style={styles.templateList}>
              {TEMPLATES.map((tpl) => (
                <Pressable
                  key={tpl.id}
                  onPress={() => handleTemplateSelect(tpl.id)}
                  style={({ pressed }) => [
                    styles.templateRow,
                    {
                      backgroundColor: pressed ? c.bgTertiary : c.bgSecondary,
                      borderColor: c.border,
                    },
                  ]}
                >
                  <View style={[styles.templateIcon, { backgroundColor: tpl.color + '20' }]}>
                    <Ionicons name={tpl.icon} size={22} color={tpl.color} />
                  </View>
                  <Text style={[styles.templateLabel, { color: c.textPrimary }]}>
                    {tpl.label}
                  </Text>
                  <Ionicons name="chevron-forward" size={18} color={c.textMuted} />
                </Pressable>
              ))}
            </View>

            {/* Join server section */}
            <View style={[styles.joinSection, { borderColor: c.border }]}>
              <Text style={[styles.joinTitle, { color: c.textPrimary }]}>
                Have an invite already?
              </Text>
              <Pressable
                style={[styles.joinBtn, { backgroundColor: c.bgSecondary }]}
                onPress={() => {}}
              >
                <Text style={[styles.joinBtnText, { color: c.textPrimary }]}>
                  Join a Server
                </Text>
              </Pressable>
            </View>
          </Animated.ScrollView>
        )}

        {/* ═══ STEP 2: Purpose ═══ */}
        {step === 'purpose' && (
          <Animated.ScrollView
            entering={SlideInRight.springify()}
            exiting={SlideOutLeft.duration(200)}
            contentContainerStyle={styles.stepContent}
            showsVerticalScrollIndicator={false}
          >
            <Text style={[styles.heading, { color: c.textPrimary }]}>
              Tell us more about{'\n'}your server
            </Text>
            <Text style={[styles.subtitle, { color: c.textSecondary }]}>
              In order to help you with your setup, is your new server for
              just a few friends or a larger community?
            </Text>

            <Pressable
              onPress={() => handlePurposeSelect('friends')}
              style={({ pressed }) => [
                styles.purposeCard,
                {
                  backgroundColor: pressed ? c.bgTertiary : c.bgSecondary,
                  borderColor: c.border,
                },
              ]}
            >
              <View style={styles.purposeRow}>
                <View style={[styles.purposeIconWrap, { backgroundColor: '#5865F220' }]}>
                  <Ionicons name="people" size={28} color="#5865F2" />
                </View>
                <View style={styles.purposeTextBlock}>
                  <Text style={[styles.purposeTitle, { color: c.textPrimary }]}>
                    For me and my friends
                  </Text>
                  <Text style={[styles.purposeDesc, { color: c.textSecondary }]}>
                    A small, private space for close friends
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color={c.textMuted} />
              </View>
            </Pressable>

            <Pressable
              onPress={() => handlePurposeSelect('community')}
              style={({ pressed }) => [
                styles.purposeCard,
                {
                  backgroundColor: pressed ? c.bgTertiary : c.bgSecondary,
                  borderColor: c.border,
                },
              ]}
            >
              <View style={styles.purposeRow}>
                <View style={[styles.purposeIconWrap, { backgroundColor: '#57F28720' }]}>
                  <Ionicons name="earth" size={28} color="#57F287" />
                </View>
                <View style={styles.purposeTextBlock}>
                  <Text style={[styles.purposeTitle, { color: c.textPrimary }]}>
                    For a Club or Community
                  </Text>
                  <Text style={[styles.purposeDesc, { color: c.textSecondary }]}>
                    A larger space with organization features
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color={c.textMuted} />
              </View>
            </Pressable>

            <Text style={[styles.skipText, { color: c.textMuted }]}>
              Not sure? You can skip this and set it up later.
            </Text>
          </Animated.ScrollView>
        )}

        {/* ═══ STEP 3: Customize ═══ */}
        {step === 'customize' && (
          <Animated.View
            style={styles.flex1}
            entering={SlideInRight.springify()}
            exiting={SlideOutLeft.duration(200)}
          >
            <KeyboardAvoidingView
              style={styles.flex1}
              behavior={Platform.OS === 'ios' ? 'padding' : undefined}
            >
              <ScrollView
                contentContainerStyle={[
                styles.stepContent,
                { paddingBottom: insets.bottom + spacing.xxl },
              ]}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
            >
              <Text style={[styles.heading, { color: c.textPrimary }]}>
                Customise your server
              </Text>
              <Text style={[styles.subtitle, { color: c.textSecondary }]}>
                Give your new server a personality with a name and an icon.
                You can always change it later.
              </Text>

              {/* Banner Upload */}
              <Pressable
                style={[styles.bannerUpload, { borderColor: c.textMuted, backgroundColor: c.bgTertiary }]}
                onPress={handlePickBanner}
              >
                {bannerUri ? (
                  <Image
                    source={{ uri: bannerUri }}
                    style={styles.bannerImage}
                    contentFit="cover"
                  />
                ) : (
                  <View style={styles.bannerPlaceholder}>
                    <Ionicons name="image-outline" size={24} color={c.textMuted} />
                    <Text style={[styles.bannerUploadText, { color: c.textMuted }]}>
                      Upload Banner
                    </Text>
                  </View>
                )}
              </Pressable>

              {/* Icon Upload */}
              <View style={styles.iconSection}>
                <Pressable
                  style={[styles.iconUpload, { borderColor: c.textMuted }]}
                  onPress={handlePickIcon}
                >
                  {iconUri ? (
                    <Image
                      source={{ uri: iconUri }}
                      style={styles.iconImage}
                      contentFit="cover"
                    />
                  ) : (
                    <>
                      <View style={styles.iconUploadInner}>
                        <Ionicons name="camera-outline" size={28} color={c.textMuted} />
                        <Text style={[styles.iconUploadText, { color: c.textMuted }]}>
                          UPLOAD
                        </Text>
                      </View>
                      {/* Plus badge */}
                      <View style={[styles.iconPlusBadge, { backgroundColor: c.accentPrimary }]}>
                        <Ionicons name="add" size={14} color="#fff" />
                      </View>
                    </>
                  )}
                </Pressable>
              </View>

              {/* Server Name */}
              <Text style={[styles.fieldLabel, { color: c.textMuted }]}>
                SERVER NAME
              </Text>
              <TextInput
                style={[
                  styles.input,
                  {
                    color: c.textPrimary,
                    backgroundColor: c.bgTertiary,
                    borderColor: error ? '#ED4245' : 'transparent',
                  },
                ]}
                value={name}
                onChangeText={(v) => {
                  setName(v);
                  if (error) setError('');
                }}
                placeholder={`${username}'s server`}
                placeholderTextColor={c.textMuted}
                autoFocus
                maxLength={100}
                returnKeyType="done"
                onSubmitEditing={handleCreate}
              />
              {error ? (
                <Text style={styles.errorText}>{error}</Text>
              ) : null}

              <Text style={[styles.tos, { color: c.textMuted }]}>
                By creating a server, you agree to Flicko's{' '}
                <Text style={{ color: c.accentPrimary }}>
                  Community Guidelines
                </Text>
                .
              </Text>

              {/* Create Button */}
              <Pressable
                onPress={handleCreate}
                disabled={!name.trim() || createMutation.isPending}
                style={[
                  styles.createBtn,
                  {
                    backgroundColor: name.trim() ? c.accentPrimary : c.bgTertiary,
                    opacity: name.trim() ? 1 : 0.5,
                  },
                ]}
              >
                {createMutation.isPending ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.createBtnText}>Create Server</Text>
                )}
              </Pressable>
            </ScrollView>
          </KeyboardAvoidingView>
          </Animated.View>
        )}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  flex1: { flex: 1 },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.sm,
    borderBottomWidth: 1,
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepContent: {
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.sm,
    paddingBottom: spacing.xxl,
  },
  heading: {
    fontSize: 26,
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
    marginBottom: spacing.md,
    lineHeight: 32,
  },
  subtitle: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: spacing.xl,
  },

  /* ─── Template list ─── */
  templateList: {
    gap: spacing.sm,
  },
  templateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderRadius: 12,
    borderWidth: 1,
    gap: spacing.md,
  },
  templateIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  templateLabel: {
    flex: 1,
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },

  /* ─── Join section ─── */
  joinSection: {
    marginTop: spacing.xl,
    paddingTop: spacing.lg,
    borderTopWidth: 1,
    alignItems: 'center',
    gap: spacing.sm,
  },
  joinTitle: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
  joinBtn: {
    paddingVertical: spacing.sm + 2,
    paddingHorizontal: spacing.xxl,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  joinBtnText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },

  /* ─── Purpose cards ─── */
  purposeCard: {
    borderRadius: 12,
    borderWidth: 1,
    padding: spacing.lg,
    marginBottom: spacing.md,
  },
  purposeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  purposeIconWrap: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  purposeTextBlock: {
    flex: 1,
  },
  purposeTitle: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
  purposeDesc: {
    fontSize: 13,
    marginTop: 2,
  },
  skipText: {
    textAlign: 'center',
    fontSize: 13,
    marginTop: spacing.lg,
  },

  /* ─── Customize step ─── */
  iconSection: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  iconUpload: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 2,
    borderStyle: 'dashed',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
  iconUploadInner: {
    alignItems: 'center',
  },
  iconUploadText: {
    fontSize: 10,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginTop: 2,
  },
  iconImage: {
    width: 80,
    height: 80,
    borderRadius: 40,
  },
  iconPlusBadge: {
    position: 'absolute',
    top: -2,
    right: -2,
    width: 22,
    height: 22,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bannerUpload: {
    width: '100%',
    height: 120,
    borderRadius: 12,
    borderWidth: 2,
    borderStyle: 'dashed',
    marginBottom: spacing.md,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
  },
  bannerImage: {
    width: '100%',
    height: '100%',
  },
  bannerPlaceholder: {
    alignItems: 'center',
    gap: 4,
  },
  bannerUploadText: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  fieldLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.xs,
  },
  input: {
    borderRadius: 8,
    padding: spacing.sm,
    ...typography.body,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderWidth: 1,
  },
  errorText: {
    color: '#ED4245',
    fontSize: 13,
    marginTop: spacing.xs,
  },
  tos: {
    fontSize: 12,
    textAlign: 'center',
    marginVertical: spacing.lg,
    lineHeight: 18,
  },
  createBtn: {
    height: 48,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  createBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
  },
});
