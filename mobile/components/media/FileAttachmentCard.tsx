/**
 * FileAttachmentCard Component
 *
 * Renders a message attachment card for non-image files (PDF, audio, video, etc.)
 * with file icon, name, size, and download functionality.
 *
 * Requirements: Feature 12 (Media Players)
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Linking,
} from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius } from '../../constants/Colors';
import { formatFileSize } from '@services/fileUploadService';

interface FileAttachmentCardProps {
  filename: string;
  url: string;
  size: number;
  contentType: string;
  onPress?: () => void;
}

function getFileIcon(mimeType: string): {
  name: keyof typeof Ionicons.glyphMap;
  color: string;
} {
  if (mimeType.startsWith('video/')) return { name: 'videocam', color: '#FF6B6B' };
  if (mimeType.startsWith('audio/')) return { name: 'musical-notes', color: '#4ECDC4' };
  if (mimeType === 'application/pdf') return { name: 'document-text', color: '#FF4757' };
  if (mimeType.includes('spreadsheet') || mimeType.includes('excel'))
    return { name: 'grid', color: '#2ECC71' };
  if (mimeType.includes('presentation') || mimeType.includes('powerpoint'))
    return { name: 'easel', color: '#E67E22' };
  if (mimeType.includes('word') || mimeType.includes('document'))
    return { name: 'document', color: '#3498DB' };
  if (mimeType.includes('zip') || mimeType.includes('archive'))
    return { name: 'file-tray-full', color: '#9B59B6' };
  return { name: 'document-outline', color: '#95A5A6' };
}

export const FileAttachmentCard = memo(function FileAttachmentCard({
  filename,
  url,
  size,
  contentType,
  onPress,
}: FileAttachmentCardProps) {
  const { themeColors } = useTheme();
  const [downloading, setDownloading] = useState(false);
  const icon = getFileIcon(contentType);

  const handlePress = useCallback(async () => {
    if (onPress) {
      onPress();
      return;
    }

    // Open file URL
    try {
      await Linking.openURL(url);
    } catch {
      console.error('[FileAttachmentCard] Cannot open URL:', url);
    }
  }, [url, onPress]);

  const handleDownload = useCallback(async () => {
    setDownloading(true);
    try {
      const localUri = `${FileSystem.documentDirectory}${filename}`;
      await FileSystem.downloadAsync(url, localUri);
      // Could show toast "File saved"
    } catch (err) {
      console.error('[FileAttachmentCard] download error:', err);
    } finally {
      setDownloading(false);
    }
  }, [url, filename]);

  return (
    <Pressable
      onPress={handlePress}
      style={[styles.container, { backgroundColor: themeColors.bgTertiary }]}
    >
      {/* File icon */}
      <View style={[styles.iconContainer, { backgroundColor: icon.color + '20' }]}>
        <Ionicons name={icon.name} size={24} color={icon.color} />
      </View>

      {/* File info */}
      <View style={styles.infoContainer}>
        <Text
          style={[styles.filename, { color: themeColors.accentPrimary }]}
          numberOfLines={1}
        >
          {filename}
        </Text>
        <Text style={[styles.fileSize, { color: themeColors.textMuted }]}>
          {formatFileSize(size)}
        </Text>
      </View>

      {/* Download button */}
      <Pressable onPress={handleDownload} hitSlop={12} style={styles.downloadBtn}>
        {downloading ? (
          <ActivityIndicator size="small" color={themeColors.textMuted} />
        ) : (
          <Ionicons name="download-outline" size={20} color={themeColors.textMuted} />
        )}
      </Pressable>
    </Pressable>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginVertical: spacing.xs,
    gap: spacing.md,
  },
  iconContainer: {
    width: 44,
    height: 44,
    borderRadius: borderRadius.sm,
    justifyContent: 'center',
    alignItems: 'center',
  },
  infoContainer: {
    flex: 1,
  },
  filename: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  fileSize: {
    fontSize: 12,
    marginTop: 2,
  },
  downloadBtn: {
    padding: spacing.sm,
  },
});
