/**
 * CreateThreadModal
 *
 * Modal for creating a new thread from a message.
 * User provides thread name and auto-archive duration.
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  Alert,
} from 'react-native';
import { Modal } from '../ui/Modal';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface CreateThreadModalProps {
  visible: boolean;
  onClose: () => void;
  onSubmit: (name: string, autoArchiveDuration: number) => void;
  parentMessagePreview?: string;
}

const ARCHIVE_OPTIONS = [
  { label: '1 Hour', value: 60 },
  { label: '24 Hours', value: 1440 },
  { label: '3 Days', value: 4320 },
  { label: '1 Week', value: 10080 },
];

export const CreateThreadModal = memo(function CreateThreadModal({
  visible,
  onClose,
  onSubmit,
  parentMessagePreview,
}: CreateThreadModalProps) {
  const { themeColors } = useTheme();
  const [name, setName] = useState('');
  const [archiveDuration, setArchiveDuration] = useState(1440);

  const handleSubmit = useCallback(() => {
    const trimmed = name.trim();
    if (!trimmed) {
      Alert.alert('Error', 'Thread name cannot be empty');
      return;
    }
    if (trimmed.length > 100) {
      Alert.alert('Error', 'Thread name must be 100 characters or less');
      return;
    }
    onSubmit(trimmed, archiveDuration);
    setName('');
    setArchiveDuration(1440);
  }, [name, archiveDuration, onSubmit]);

  return (
    <Modal visible={visible} onClose={onClose}>
      <View style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}>
        <Text style={[styles.title, { color: themeColors.textPrimary }]}>
          Create Thread
        </Text>

        {/* Parent message preview */}
        {parentMessagePreview && (
          <View style={[styles.preview, { borderLeftColor: themeColors.accentPrimary, backgroundColor: themeColors.bgTertiary }]}>
            <Text style={[styles.previewText, { color: themeColors.textMuted }]} numberOfLines={2}>
              {parentMessagePreview}
            </Text>
          </View>
        )}

        {/* Thread name */}
        <Text style={[styles.label, { color: themeColors.textSecondary }]}>
          THREAD NAME
        </Text>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="e.g. Discussion about..."
          placeholderTextColor={themeColors.textMuted}
          maxLength={100}
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

        {/* Auto-archive duration */}
        <Text style={[styles.label, { color: themeColors.textSecondary }]}>
          AUTO-ARCHIVE AFTER INACTIVITY
        </Text>
        <View style={styles.archiveRow}>
          {ARCHIVE_OPTIONS.map((opt) => (
            <Pressable
              key={opt.value}
              onPress={() => setArchiveDuration(opt.value)}
              style={[
                styles.archiveChip,
                {
                  backgroundColor:
                    archiveDuration === opt.value
                      ? themeColors.accentPrimary
                      : themeColors.bgTertiary,
                  borderColor:
                    archiveDuration === opt.value
                      ? themeColors.accentPrimary
                      : themeColors.border,
                },
              ]}
            >
              <Text
                style={[
                  styles.archiveChipText,
                  {
                    color:
                      archiveDuration === opt.value
                        ? '#FFFFFF'
                        : themeColors.textSecondary,
                  },
                ]}
              >
                {opt.label}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* Actions */}
        <View style={styles.actions}>
          <Pressable onPress={onClose} style={styles.cancelBtn}>
            <Text style={{ color: themeColors.textMuted, fontSize: 15 }}>Cancel</Text>
          </Pressable>
          <Pressable
            onPress={handleSubmit}
            style={[styles.submitBtn, { backgroundColor: themeColors.accentPrimary }]}
          >
            <Text style={{ color: '#FFFFFF', fontSize: 15, fontFamily: 'gg-sans-semibold' }}>
              Create Thread
            </Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
});

const styles = StyleSheet.create({
  container: {
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
  },
  title: {
    ...typography.headingM,
    marginBottom: spacing.md,
  },
  preview: {
    borderLeftWidth: 3,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.sm,
    marginBottom: spacing.md,
  },
  previewText: {
    ...typography.bodySmall,
  },
  label: {
    ...typography.overline,
    marginBottom: spacing.xs,
    marginTop: spacing.md,
  },
  input: {
    ...typography.body,
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  archiveRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
  archiveChip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.full,
    borderWidth: 1,
  },
  archiveChipText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  cancelBtn: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
  },
  submitBtn: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
  },
});
