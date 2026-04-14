/**
 * AttachmentPreview Component
 *
 * Shows a horizontal scroll of pending file attachments in the message input.
 * Displays thumbnails for images, file icons for documents, with progress
 * indicators and remove buttons.
 *
 * Requirements: Feature 9 (File Upload Infrastructure)
 */
import React, { memo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Modal,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { useUploadStore, type UploadItem, type UploadStore } from '@stores/uploadStore';
import { isImageFile, formatFileSize } from '@services/fileUploadService';

interface AttachmentPreviewProps {
  channelId: string;
  onRemove?: (uploadId: string) => void;
}

export const AttachmentPreview = memo(function AttachmentPreview({
  channelId,
  onRemove,
}: AttachmentPreviewProps) {
  const uploads = useUploadStore((s: UploadStore) => s.getChannelUploads(channelId));
  const cancelUpload = useUploadStore((s: UploadStore) => s.cancelUpload);
  const removeUpload = useUploadStore((s: UploadStore) => s.removeUpload);
  const setAltText = useUploadStore((s: UploadStore) => s.setAltText);
  const { themeColors } = useTheme();

  const [altModalVisible, setAltModalVisible] = useState(false);
  const [altModalUploadId, setAltModalUploadId] = useState<string | null>(null);
  const [altModalText, setAltModalText] = useState('');

  if (uploads.length === 0) return null;

  const handleRemove = (item: UploadItem) => {
    if (item.status === 'uploading') {
      cancelUpload(item.id);
    } else {
      removeUpload(item.id);
    }
    onRemove?.(item.id);
  };

  const handleOpenAlt = (item: UploadItem) => {
    setAltModalUploadId(item.id);
    setAltModalText(item.altText || '');
    setAltModalVisible(true);
  };

  const handleSaveAlt = () => {
    if (altModalUploadId) {
      setAltText(altModalUploadId, altModalText.trim());
    }
    setAltModalVisible(false);
  };

  return (
    <>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.container}
        contentContainerStyle={styles.content}
      >
        {uploads.map((item) => (
          <View
            key={item.id}
            style={[styles.item, { backgroundColor: themeColors.bgTertiary }]}
          >
            {/* Thumbnail or file icon */}
            {isImageFile(item.contentType) ? (
              <>
                <Image
                  source={{ uri: item.localUri }}
                  style={styles.thumbnail}
                  contentFit="cover"
                />
                <Pressable
                  onPress={() => handleOpenAlt(item)}
                  style={[styles.altBtn, { backgroundColor: themeColors.bgSecondary }]}
                >
                  <Text style={[styles.altBtnText, { color: themeColors.text }]}>ALT</Text>
                </Pressable>
              </>
            ) : (
              <View style={[styles.fileIcon, { backgroundColor: themeColors.bgSecondary }]}>
                <Ionicons
                  name={getFileIcon(item.contentType)}
                  size={24}
                  color={themeColors.accentPrimary}
                />
              </View>
            )}

            {/* Overlay for uploading state */}
            {item.status === 'uploading' && (
              <View style={styles.overlay}>
                <ActivityIndicator size="small" color="#FFFFFF" />
                <Text style={styles.progressText}>
                  {Math.round(item.progress * 100)}%
                </Text>
              </View>
            )}

            {/* Error overlay */}
            {item.status === 'failed' && (
              <View style={[styles.overlay, styles.errorOverlay]}>
                <Ionicons name="alert-circle" size={20} color="#ED4245" />
                <Text style={styles.errorText} numberOfLines={1}>
                  {item.error || 'Failed'}
                </Text>
              </View>
            )}

            {/* Filename */}
            <Text
              style={[styles.filename, { color: themeColors.textSecondary }]}
              numberOfLines={1}
            >
              {item.filename}
            </Text>

            {/* File size */}
            <Text style={[styles.fileSize, { color: themeColors.textMuted }]}>
              {formatFileSize(item.size)}
            </Text>

            {/* Remove button */}
            <Pressable
              onPress={() => handleRemove(item)}
              style={[styles.removeBtn, { backgroundColor: themeColors.bgSecondary }]}
              hitSlop={8}
            >
              <Ionicons name="close" size={14} color={themeColors.textMuted} />
            </Pressable>
          </View>
        ))}
      </ScrollView>

      {/* Alt Text Modal */}
      <Modal
        visible={altModalVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setAltModalVisible(false)}
      >
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.modalContainer}
        >
          <View style={[styles.modalContent, { backgroundColor: themeColors.bgPrimary }]}>
            <Text style={[styles.modalTitle, { color: themeColors.text }]}>Image Description</Text>
            <Text style={[styles.modalSubtitle, { color: themeColors.textSecondary }]}>
              Describe this image for users who are visually impaired.
            </Text>
            <TextInput
              style={[styles.modalInput, { color: themeColors.text, borderColor: themeColors.bgTertiary, backgroundColor: themeColors.bgSecondary }]}
              value={altModalText}
              onChangeText={setAltModalText}
              placeholder="A cool image..."
              placeholderTextColor={themeColors.textMuted}
              maxLength={1000}
              multiline
              autoFocus
            />
            <View style={styles.modalActions}>
              <Pressable
                style={styles.modalCancelBtn}
                onPress={() => setAltModalVisible(false)}
              >
                <Text style={[styles.modalBtnText, { color: themeColors.textSecondary }]}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalSaveBtn, { backgroundColor: themeColors.accentPrimary }]}
                onPress={handleSaveAlt}
              >
                <Text style={[styles.modalBtnText, { color: '#FFFFFF' }]}>Save</Text>
              </Pressable>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </>
  );
});

function getFileIcon(mimeType: string): keyof typeof Ionicons.glyphMap {
  if (mimeType.startsWith('video/')) return 'videocam';
  if (mimeType.startsWith('audio/')) return 'musical-notes';
  if (mimeType === 'application/pdf') return 'document-text';
  return 'document';
}

const styles = StyleSheet.create({
  container: {
    maxHeight: 120,
  },
  content: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  item: {
    width: 90,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
    marginRight: spacing.sm,
  },
  thumbnail: {
    width: 90,
    height: 64,
  },
  fileIcon: {
    width: 90,
    height: 64,
    justifyContent: 'center',
    alignItems: 'center',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    height: 64,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorOverlay: {
    backgroundColor: 'rgba(0,0,0,0.7)',
  },
  progressText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
    marginTop: 2,
  },
  errorText: {
    color: '#ED4245',
    fontSize: 10,
    marginTop: 2,
  },
  filename: {
    fontSize: 11,
    paddingHorizontal: spacing.xs,
    paddingTop: spacing.xs,
  },
  fileSize: {
    fontSize: 10,
    paddingHorizontal: spacing.xs,
    paddingBottom: spacing.xs,
  },
  removeBtn: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 20,
    height: 20,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  altBtn: {
    position: 'absolute',
    bottom: 4,
    left: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  altBtnText: {
    fontSize: 9,
    fontFamily: 'gg-sans-bold',
  },
  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)',
    padding: spacing.lg,
  },
  modalContent: {
    borderRadius: borderRadius.md,
    padding: spacing.md,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.25,
        shadowRadius: 8,
      },
      android: {
        elevation: 8,
      },
      web: {
        boxShadow: '0 4px 8px rgba(0,0,0,0.25)',
      },
    }),
  },
  modalTitle: {
    fontFamily: 'gg-sans-bold',
    fontSize: 20,
    marginBottom: spacing.xs,
  },
  modalSubtitle: {
    fontFamily: 'gg-sans-medium',
    fontSize: 14,
    marginBottom: spacing.md,
  },
  modalInput: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    padding: spacing.sm,
    minHeight: 100,
    textAlignVertical: 'top',
    fontFamily: 'gg-sans-regular',
    fontSize: 14,
    marginBottom: spacing.md,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.sm,
  },
  modalCancelBtn: {
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    justifyContent: 'center',
  },
  modalSaveBtn: {
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    borderRadius: borderRadius.sm,
    justifyContent: 'center',
  },
  modalBtnText: {
    fontFamily: 'gg-sans-semibold',
    fontSize: 14,
  },
});
