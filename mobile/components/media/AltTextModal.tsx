/**
 * Image Alt Text Input (Feature 11)
 *
 * Overlay shown before sending an image, letting users add alt text descriptions
 * for accessibility. Shows ALT badge on images that have descriptions.
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  Modal,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface AltTextModalProps {
  visible: boolean;
  imageUri: string;
  onSave: (altText: string) => void;
  onClose: () => void;
  initialAltText?: string;
}

export const AltTextModal = memo(function AltTextModal({
  visible,
  imageUri,
  onSave,
  onClose,
  initialAltText = '',
}: AltTextModalProps) {
  const { themeColors } = useTheme();
  const [altText, setAltText] = useState(initialAltText);

  const handleSave = useCallback(() => {
    onSave(altText.trim());
    onClose();
  }, [altText, onSave, onClose]);

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.overlay} onPress={onClose}>
        <Pressable style={[styles.sheet, { backgroundColor: themeColors.bgSecondary }]}>
          <Text style={[styles.title, { color: themeColors.textPrimary }]}>Add Description</Text>
          <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
            Describe this image for people who use screen readers.
          </Text>

          <Image source={{ uri: imageUri }} style={styles.preview} contentFit="cover" />

          <TextInput
            value={altText}
            onChangeText={setAltText}
            placeholder="Describe this image..."
            placeholderTextColor={themeColors.textMuted}
            multiline
            maxLength={1000}
            style={[
              styles.input,
              {
                color: themeColors.textPrimary,
                backgroundColor: themeColors.bgTertiary,
                borderColor: themeColors.border,
              },
            ]}
            autoFocus
          />

          <View style={styles.actions}>
            <Pressable onPress={onClose} style={[styles.btn, { backgroundColor: themeColors.bgTertiary }]}>
              <Text style={[styles.btnText, { color: themeColors.textPrimary }]}>Cancel</Text>
            </Pressable>
            <Pressable onPress={handleSave} style={[styles.btn, { backgroundColor: themeColors.accentPrimary }]}>
              <Text style={[styles.btnText, { color: '#fff' }]}>Save</Text>
            </Pressable>
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
});

/** ALT badge displayed on images with alt text (Feature 11) */
export const AltBadge = memo(function AltBadge({
  altText,
  onPress,
}: {
  altText: string;
  onPress?: () => void;
}) {
  const { themeColors } = useTheme();
  if (!altText) return null;

  return (
    <Pressable
      onPress={onPress}
      style={[styles.altBadge, { backgroundColor: themeColors.bgPrimary + 'CC' }]}
      accessibilityLabel={`Image description: ${altText}`}
    >
      <Text style={[styles.altLabel, { color: themeColors.textPrimary }]}>ALT</Text>
    </Pressable>
  );
});

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  sheet: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: spacing.lg,
    maxHeight: '80%',
  },
  title: {
    ...typography.headingM,
    marginBottom: spacing.xs,
  },
  subtitle: {
    ...typography.bodySmall,
    marginBottom: spacing.md,
  },
  preview: {
    width: '100%',
    height: 160,
    borderRadius: 12,
    marginBottom: spacing.md,
  },
  input: {
    fontSize: 15,
    fontFamily: 'gg-sans',
    lineHeight: 20,
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minHeight: 80,
    maxHeight: 140,
    textAlignVertical: 'top',
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  btn: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: 8,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  btnText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  altBadge: {
    position: 'absolute',
    bottom: 8,
    left: 8,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  altLabel: {
    fontSize: 10,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
  },
});
