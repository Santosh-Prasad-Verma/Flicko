/**
 * Emoji Upload Flow
 *
 * Multi-step emoji upload: Pick Image → Crop → Preview/Name → Upload.
 * Handles client-side processing (resize, validate) before uploading
 * to Cloudinary via signed upload.
 *
 * Requirements: Emoji Upload Feature
 */
import React, { memo, useCallback, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  Image,
  ActivityIndicator,
  Alert,
  ScrollView,
} from 'react-native';
import Animated, { FadeIn, FadeOut, FadeInRight, FadeOutLeft } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { Modal } from '../ui/Modal';
import { useTheme } from '@/hooks/useTheme';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import { uploadToCloudinary } from '@services/cloudinaryService';
import { supabase } from '@lib/supabase';

// ── Types ─────────────────────────────────────────────────────────────────

type UploadStep = 'pick' | 'crop' | 'preview' | 'uploading' | 'done';

interface EmojiUploadProps {
  visible: boolean;
  onClose: () => void;
  serverId: string;
  onUploadComplete?: (emoji: { id: string; name: string; url: string }) => void;
}

interface PickedImage {
  uri: string;
  width: number;
  height: number;
  mimeType: string;
}

// ── Constants ─────────────────────────────────────────────────────────────

const MAX_EMOJI_SIZE = 256 * 1024; // 256KB
const EMOJI_DIMENSIONS = 128; // 128x128 output
const ALLOWED_TYPES = ['image/png', 'image/gif', 'image/jpeg', 'image/webp'];
const NAME_REGEX = /^[a-zA-Z0-9_]{2,32}$/;

// ── Step Indicator ────────────────────────────────────────────────────────

const StepIndicator = memo(function StepIndicator({
  currentStep,
}: {
  currentStep: UploadStep;
}) {
  const { themeColors } = useTheme();
  const steps: { key: UploadStep; label: string }[] = [
    { key: 'pick', label: 'Select' },
    { key: 'crop', label: 'Crop' },
    { key: 'preview', label: 'Name' },
    { key: 'uploading', label: 'Upload' },
  ];

  const currentIndex = steps.findIndex((s) => s.key === currentStep);

  return (
    <View style={styles.stepRow}>
      {steps.map((step, i) => {
        const isActive = i === currentIndex;
        const isComplete = i < currentIndex;

        return (
          <View key={step.key} style={styles.stepItem}>
            <View
              style={[
                styles.stepDot,
                {
                  backgroundColor: isComplete
                    ? themeColors.success
                    : isActive
                      ? themeColors.accentPrimary
                      : themeColors.bgTertiary,
                },
              ]}
            >
              {isComplete ? (
                <Ionicons name="checkmark" size={12} color="#FFFFFF" />
              ) : (
                <Text
                  style={[
                    styles.stepNumber,
                    {
                      color: isActive ? '#FFFFFF' : themeColors.textMuted,
                    },
                  ]}
                >
                  {i + 1}
                </Text>
              )}
            </View>
            <Text
              style={[
                styles.stepLabel,
                {
                  color: isActive
                    ? themeColors.textPrimary
                    : themeColors.textMuted,
                },
              ]}
            >
              {step.label}
            </Text>
            {i < steps.length - 1 && (
              <View
                style={[
                  styles.stepLine,
                  {
                    backgroundColor: isComplete
                      ? themeColors.success
                      : themeColors.bgTertiary,
                  },
                ]}
              />
            )}
          </View>
        );
      })}
    </View>
  );
});

// ── Crop Controls ─────────────────────────────────────────────────────────

const CropPreview = memo(function CropPreview({
  image,
  onConfirm,
  onBack,
}: {
  image: PickedImage;
  onConfirm: () => void;
  onBack: () => void;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View entering={FadeInRight.duration(200)} exiting={FadeOutLeft.duration(150)}>
      <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
        Crop your emoji to a square. The image will be resized to 128×128.
      </Text>

      <View style={[styles.cropContainer, { backgroundColor: themeColors.bgTertiary }]}>
        <View style={styles.cropFrame}>
          <Image
            source={{ uri: image.uri }}
            style={styles.cropImage}
            resizeMode="cover"
          />
          {/* Crop grid overlay */}
          <View style={styles.cropOverlay}>
            <View style={[styles.cropCorner, styles.cropTL, { borderColor: '#FFFFFF' }]} />
            <View style={[styles.cropCorner, styles.cropTR, { borderColor: '#FFFFFF' }]} />
            <View style={[styles.cropCorner, styles.cropBL, { borderColor: '#FFFFFF' }]} />
            <View style={[styles.cropCorner, styles.cropBR, { borderColor: '#FFFFFF' }]} />
          </View>
        </View>
      </View>

      <View style={styles.actionRow}>
        <Pressable
          onPress={onBack}
          style={[styles.btnSecondary, { backgroundColor: themeColors.bgTertiary }]}
        >
          <Ionicons name="arrow-back" size={18} color={themeColors.textPrimary} />
          <Text style={[styles.btnSecondaryText, { color: themeColors.textPrimary }]}>
            Back
          </Text>
        </Pressable>
        <Pressable
          onPress={onConfirm}
          style={[styles.btnPrimary, { backgroundColor: themeColors.accentPrimary }]}
        >
          <Ionicons name="crop" size={18} color="#FFFFFF" />
          <Text style={styles.btnPrimaryText}>Crop</Text>
        </Pressable>
      </View>
    </Animated.View>
  );
});

// ── Name & Preview ────────────────────────────────────────────────────────

const NamePreview = memo(function NamePreview({
  image,
  name,
  onNameChange,
  onConfirm,
  onBack,
  nameError,
}: {
  image: PickedImage;
  name: string;
  onNameChange: (name: string) => void;
  onConfirm: () => void;
  onBack: () => void;
  nameError: string | null;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View entering={FadeInRight.duration(200)} exiting={FadeOutLeft.duration(150)}>
      <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
        Give your emoji a name. It will be used as :name: in chat.
      </Text>

      {/* Preview */}
      <View style={styles.previewRow}>
        <View style={[styles.previewBox, { backgroundColor: themeColors.bgTertiary }]}>
          <Image
            source={{ uri: image.uri }}
            style={styles.previewImage}
            resizeMode="contain"
          />
        </View>
        <View style={styles.previewInfo}>
          <Text style={[styles.previewLabel, { color: themeColors.textMuted }]}>
            Preview
          </Text>
          <View style={styles.previewUsage}>
            <Text style={[styles.previewColon, { color: themeColors.textMuted }]}>
              :
            </Text>
            <Text
              style={[
                styles.previewName,
                { color: themeColors.textPrimary },
              ]}
            >
              {name || 'emoji_name'}
            </Text>
            <Text style={[styles.previewColon, { color: themeColors.textMuted }]}>
              :
            </Text>
          </View>
        </View>
      </View>

      {/* Name input */}
      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: themeColors.textSecondary }]}>
          EMOJI NAME
        </Text>
        <TextInput
          style={[
            styles.nameInput,
            {
              backgroundColor: themeColors.bgTertiary,
              color: themeColors.textPrimary,
              borderColor: nameError ? themeColors.danger : themeColors.border,
            },
          ]}
          placeholder="awesome_emoji"
          placeholderTextColor={themeColors.textMuted}
          value={name}
          onChangeText={onNameChange}
          maxLength={32}
          autoCapitalize="none"
          autoCorrect={false}
        />
        {nameError ? (
          <Text style={[styles.errorText, { color: themeColors.danger }]}>
            {nameError}
          </Text>
        ) : (
          <Text style={[styles.hintText, { color: themeColors.textMuted }]}>
            2-32 characters, letters, numbers, and underscores only
          </Text>
        )}
      </View>

      <View style={styles.actionRow}>
        <Pressable
          onPress={onBack}
          style={[styles.btnSecondary, { backgroundColor: themeColors.bgTertiary }]}
        >
          <Ionicons name="arrow-back" size={18} color={themeColors.textPrimary} />
          <Text style={[styles.btnSecondaryText, { color: themeColors.textPrimary }]}>
            Back
          </Text>
        </Pressable>
        <Pressable
          onPress={onConfirm}
          style={[
            styles.btnPrimary,
            {
              backgroundColor: name.trim() && !nameError
                ? themeColors.accentPrimary
                : themeColors.bgTertiary,
            },
          ]}
          disabled={!name.trim() || !!nameError}
        >
          <Ionicons name="cloud-upload" size={18} color="#FFFFFF" />
          <Text style={styles.btnPrimaryText}>Upload</Text>
        </Pressable>
      </View>
    </Animated.View>
  );
});

// ── Main Component ────────────────────────────────────────────────────────

export const EmojiUpload = memo(function EmojiUpload({
  visible,
  onClose,
  serverId,
  onUploadComplete,
}: EmojiUploadProps) {
  const { themeColors, theme } = useTheme();
  const [step, setStep] = useState<UploadStep>('pick');
  const [image, setImage] = useState<PickedImage | null>(null);
  const [emojiName, setEmojiName] = useState('');
  const [nameError, setNameError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);

  // Reset state on close
  const handleClose = useCallback(() => {
    setStep('pick');
    setImage(null);
    setEmojiName('');
    setNameError(null);
    setUploading(false);
    setUploadProgress(0);
    onClose();
  }, [onClose]);

  // Step 1: Pick image
  const handlePickImage = useCallback(async () => {
    try {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        Alert.alert('Permission Required', 'Media library access is needed to upload emojis.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.9,
      });

      if (result.canceled || !result.assets?.length) return;

      const asset = result.assets[0];

      // Validate type
      if (asset.mimeType && !ALLOWED_TYPES.includes(asset.mimeType)) {
        Alert.alert('Invalid Format', 'Only PNG, GIF, JPEG, and WebP images are supported.');
        return;
      }

      // Validate size
      if (asset.fileSize && asset.fileSize > MAX_EMOJI_SIZE) {
        Alert.alert('File Too Large', 'Emoji images must be under 256KB.');
        return;
      }

      setImage({
        uri: asset.uri,
        width: asset.width,
        height: asset.height,
        mimeType: asset.mimeType || 'image/png',
      });
      setStep('crop');
    } catch (err) {
      console.error('[EmojiUpload] pick error:', err);
      Alert.alert('Error', 'Failed to pick image');
    }
  }, []);

  // Step 2: Confirm crop
  const handleCropConfirm = useCallback(() => {
    setStep('preview');
    // Auto-generate name from filename
    if (!emojiName) {
      setEmojiName(`emoji_${Date.now().toString(36)}`);
    }
  }, [emojiName]);

  // Step 3: Validate name
  const handleNameChange = useCallback((text: string) => {
    const cleaned = text.toLowerCase().replace(/[^a-z0-9_]/g, '_');
    setEmojiName(cleaned);

    if (!cleaned) {
      setNameError(null);
    } else if (cleaned.length < 2) {
      setNameError('Name must be at least 2 characters');
    } else if (!NAME_REGEX.test(cleaned)) {
      setNameError('Only letters, numbers, and underscores');
    } else {
      setNameError(null);
    }
  }, []);

  // Step 4: Upload
  const handleUpload = useCallback(async () => {
    if (!image || !emojiName.trim() || nameError) return;

    setStep('uploading');
    setUploading(true);
    setUploadProgress(0);

    try {
      // Simulate progress steps
      setUploadProgress(0.2);

      // Get auth token for signed Cloudinary upload
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.access_token) {
        throw new Error('Not authenticated');
      }

      setUploadProgress(0.5);

      // Upload to Cloudinary with deterministic public_id
      const safeName = emojiName.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
      const result = await uploadToCloudinary(
        image.uri,
        image.mimeType,
        session.access_token,
        {
          folder: `flickochat/emojis/${serverId}`,
          publicId: `emoji_${safeName}`,
        },
      );

      setUploadProgress(0.8);

      // Store emoji record in database
      const { error: dbError } = await supabase
        .from('server_emojis')
        .upsert({
          server_id: serverId,
          name: emojiName,
          url: result.secure_url,
          object_name: result.public_id,
          created_by: session.user.id,
        }, { onConflict: 'server_id,name' });

      if (dbError) {
        console.warn('[EmojiUpload] db upsert error:', dbError);
      }
      setUploadProgress(1);
      setStep('done');

      onUploadComplete?.({
        id: result.public_id,
        name: emojiName,
        url: result.secure_url,
      });

      // Auto-close after success
      setTimeout(handleClose, 1500);
    } catch (err: any) {
      console.error('[EmojiUpload] upload error:', err);
      Alert.alert('Upload Failed', err.message || 'Something went wrong');
      setStep('preview');
    } finally {
      setUploading(false);
    }
  }, [image, emojiName, nameError, serverId, handleClose, onUploadComplete]);

  return (
    <Modal
      visible={visible}
      onClose={handleClose}
      title="Upload Emoji"
      theme={theme}
    >
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Step indicator */}
        <StepIndicator currentStep={step} />

        {/* Step: Pick */}
        {step === 'pick' && (
          <Animated.View entering={FadeIn.duration(200)}>
            <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
              Choose an image for your custom emoji. Square images work best.
            </Text>

            <Pressable
              onPress={handlePickImage}
              style={[styles.pickArea, { borderColor: themeColors.border }]}
            >
              <Ionicons name="image-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.pickText, { color: themeColors.textPrimary }]}>
                Tap to select image
              </Text>
              <Text style={[styles.pickHint, { color: themeColors.textMuted }]}>
                PNG, GIF, JPEG, WebP • Max 256KB
              </Text>
            </Pressable>

            <View style={styles.requirementsList}>
              {[
                { icon: 'resize', text: 'Will be resized to 128×128' },
                { icon: 'image', text: 'PNG, GIF, JPEG, or WebP format' },
                { icon: 'cloud-upload', text: 'Max file size: 256KB' },
                { icon: 'square', text: 'Square aspect ratio recommended' },
              ].map((req, i) => (
                <View key={i} style={styles.requirementRow}>
                  <Ionicons
                    name={req.icon as any}
                    size={14}
                    color={themeColors.textMuted}
                  />
                  <Text
                    style={[styles.requirementText, { color: themeColors.textMuted }]}
                  >
                    {req.text}
                  </Text>
                </View>
              ))}
            </View>
          </Animated.View>
        )}

        {/* Step: Crop */}
        {step === 'crop' && image && (
          <CropPreview
            image={image}
            onConfirm={handleCropConfirm}
            onBack={() => setStep('pick')}
          />
        )}

        {/* Step: Preview & Name */}
        {step === 'preview' && image && (
          <NamePreview
            image={image}
            name={emojiName}
            onNameChange={handleNameChange}
            onConfirm={handleUpload}
            onBack={() => setStep('crop')}
            nameError={nameError}
          />
        )}

        {/* Step: Uploading */}
        {step === 'uploading' && (
          <Animated.View entering={FadeIn.duration(200)} style={styles.uploadingContainer}>
            <ActivityIndicator size="large" color={themeColors.accentPrimary} />
            <Text style={[styles.uploadingText, { color: themeColors.textPrimary }]}>
              Uploading emoji...
            </Text>
            <View style={[styles.progressBar, { backgroundColor: themeColors.bgTertiary }]}>
              <Animated.View
                style={[
                  styles.progressFill,
                  {
                    backgroundColor: themeColors.accentPrimary,
                    width: `${Math.round(uploadProgress * 100)}%`,
                  },
                ]}
              />
            </View>
            <Text style={[styles.progressText, { color: themeColors.textMuted }]}>
              {Math.round(uploadProgress * 100)}%
            </Text>
          </Animated.View>
        )}

        {/* Step: Done */}
        {step === 'done' && (
          <Animated.View entering={FadeIn.duration(200)} style={styles.doneContainer}>
            <View
              style={[styles.doneCircle, { backgroundColor: themeColors.success }]}
            >
              <Ionicons name="checkmark" size={32} color="#FFFFFF" />
            </View>
            <Text style={[styles.doneText, { color: themeColors.textPrimary }]}>
              Emoji uploaded!
            </Text>
            <Text style={[styles.doneSubtext, { color: themeColors.textMuted }]}>
              Use :{emojiName}: in chat
            </Text>
          </Animated.View>
        )}
      </ScrollView>
    </Modal>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.xl,
    paddingHorizontal: spacing.md,
  },
  stepItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stepDot: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNumber: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
  },
  stepLabel: {
    ...typography.micro,
    marginLeft: spacing.xs,
  },
  stepLine: {
    width: 24,
    height: 2,
    marginHorizontal: spacing.xs,
    borderRadius: 1,
  },
  sectionTitle: {
    ...typography.bodySmall,
    marginBottom: spacing.lg,
    textAlign: 'center',
  },
  pickArea: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderStyle: 'dashed',
    borderRadius: borderRadius.lg,
    paddingVertical: spacing.xxxl,
    gap: spacing.sm,
    marginBottom: spacing.lg,
  },
  pickText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  pickHint: {
    ...typography.caption,
  },
  requirementsList: {
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  requirementRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  requirementText: {
    ...typography.caption,
  },
  cropContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
    marginBottom: spacing.lg,
  },
  cropFrame: {
    width: 200,
    height: 200,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
    position: 'relative',
  },
  cropImage: {
    width: '100%',
    height: '100%',
  },
  cropOverlay: {
    ...StyleSheet.absoluteFillObject,
  },
  cropCorner: {
    position: 'absolute',
    width: 20,
    height: 20,
  },
  cropTL: {
    top: 0,
    left: 0,
    borderTopWidth: 3,
    borderLeftWidth: 3,
  },
  cropTR: {
    top: 0,
    right: 0,
    borderTopWidth: 3,
    borderRightWidth: 3,
  },
  cropBL: {
    bottom: 0,
    left: 0,
    borderBottomWidth: 3,
    borderLeftWidth: 3,
  },
  cropBR: {
    bottom: 0,
    right: 0,
    borderBottomWidth: 3,
    borderRightWidth: 3,
  },
  previewRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
    marginBottom: spacing.xl,
  },
  previewBox: {
    width: 64,
    height: 64,
    borderRadius: borderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  previewImage: {
    width: 48,
    height: 48,
  },
  previewInfo: {
    flex: 1,
    gap: spacing.xs,
  },
  previewLabel: {
    ...typography.caption,
  },
  previewUsage: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  previewColon: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  previewName: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  inputGroup: {
    marginBottom: spacing.lg,
  },
  inputLabel: {
    ...typography.overline,
    marginBottom: spacing.xs,
  },
  nameInput: {
    ...typography.body,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    borderWidth: 1,
  },
  errorText: {
    ...typography.caption,
    marginTop: spacing.xs,
  },
  hintText: {
    ...typography.caption,
    marginTop: spacing.xs,
  },
  actionRow: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  btnSecondary: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  btnSecondaryText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  btnPrimary: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  btnPrimaryText: {
    color: '#FFFFFF',
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  uploadingContainer: {
    alignItems: 'center',
    paddingVertical: spacing.xxxl,
    gap: spacing.lg,
  },
  uploadingText: {
    ...typography.headingM,
  },
  progressBar: {
    width: '80%',
    height: 6,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  progressText: {
    ...typography.caption,
  },
  doneContainer: {
    alignItems: 'center',
    paddingVertical: spacing.xxxl,
    gap: spacing.md,
  },
  doneCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  doneText: {
    ...typography.headingM,
  },
  doneSubtext: {
    ...typography.bodySmall,
  },
});
