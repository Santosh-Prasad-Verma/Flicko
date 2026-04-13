import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { spacing } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface Attachment {
  url: string;
  content_type: string;
  filename: string;
  size: number;
  width?: number;
  height?: number;
}

interface AttachmentListProps {
  attachments: Attachment[];
  onLongPress?: () => void;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function AttachmentList({ attachments, onLongPress }: AttachmentListProps) {
  const { themeColors } = useTheme();

  if (!attachments || attachments.length === 0) return null;

  return (
    <View style={styles.container}>
      {attachments.map((attachment, index) => {
        const isImage = attachment.content_type?.startsWith('image/');
        const isVideo = attachment.content_type?.startsWith('video/');

        if (isImage) {
          return (
            <Pressable key={index} style={styles.imageContainer} onLongPress={onLongPress}>
              <Image
                source={{ uri: attachment.url }}
                style={styles.image}
                contentFit="cover"
                cachePolicy="memory-disk"
              />
            </Pressable>
          );
        }

        if (isVideo) {
          return (
            <Pressable key={index} style={styles.videoContainer} onLongPress={onLongPress}>
              <Ionicons name="play-circle" size={48} color="#fff" />
              <Text style={styles.videoLabel}>{attachment.filename}</Text>
            </Pressable>
          );
        }

        return (
          <Pressable
            key={index}
            style={[styles.fileContainer, { backgroundColor: themeColors.bgTertiary }]}
            onLongPress={onLongPress}
          >
            <Ionicons name="document-outline" size={24} color={themeColors.textPrimary} />
            <View style={styles.fileInfo}>
              <Text style={[styles.fileName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {attachment.filename}
              </Text>
              <Text style={[styles.fileSize, { color: themeColors.textMuted }]}>
                {formatFileSize(attachment.size)}
              </Text>
            </View>
            <Ionicons name="download-outline" size={20} color={themeColors.textMuted} />
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: spacing.sm,
    gap: spacing.xs,
  },
  imageContainer: {
    borderRadius: 8,
    overflow: 'hidden',
  },
  image: {
    width: 300,
    height: 200,
    borderRadius: 8,
  },
  videoContainer: {
    width: 300,
    height: 200,
    borderRadius: 8,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  videoLabel: {
    color: '#fff',
    marginTop: 8,
    fontSize: 12,
  },
  fileContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 8,
    gap: spacing.sm,
  },
  fileInfo: {
    flex: 1,
  },
  fileName: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  fileSize: {
    fontSize: 12,
    marginTop: 2,
  },
});
