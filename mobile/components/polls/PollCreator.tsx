/**
 * PollCreator Component
 *
 * Modal form for creating polls with 2-10 options, duration selection,
 * and multi-select toggle. Validates inputs before submission.
 *
 * Requirements: Feature 21 (Polls System)
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  ScrollView,
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { supabase } from '@lib/supabase';

// ── Types ─────────────────────────────────────────────────────────────────

interface PollCreatorProps {
  channelId: string;
  onClose: () => void;
  onCreated?: (pollId: string) => void;
}

interface PollOption {
  id: string;
  text: string;
}

const DURATION_OPTIONS = [
  { label: '1 hour', value: 1 },
  { label: '4 hours', value: 4 },
  { label: '24 hours', value: 24 },
  { label: '3 days', value: 72 },
  { label: '1 week', value: 168 },
];

const MIN_OPTIONS = 2;
const MAX_OPTIONS = 10;
const MAX_QUESTION_LENGTH = 300;
const MAX_OPTION_LENGTH = 100;

// ── Component ─────────────────────────────────────────────────────────────

export const PollCreator = memo(function PollCreator({
  channelId,
  onClose,
  onCreated,
}: PollCreatorProps) {
  const { themeColors } = useTheme();
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState<PollOption[]>([
    { id: '1', text: '' },
    { id: '2', text: '' },
  ]);
  const [multiSelect, setMultiSelect] = useState(false);
  const [durationHours, setDurationHours] = useState(24);
  const [submitting, setSubmitting] = useState(false);

  const addOption = useCallback(() => {
    if (options.length >= MAX_OPTIONS) return;
    setOptions((prev) => [
      ...prev,
      { id: String(Date.now()), text: '' },
    ]);
  }, [options.length]);

  const removeOption = useCallback((id: string) => {
    if (options.length <= MIN_OPTIONS) return;
    setOptions((prev) => prev.filter((o) => o.id !== id));
  }, [options.length]);

  const updateOption = useCallback((id: string, text: string) => {
    setOptions((prev) =>
      prev.map((o) => (o.id === id ? { ...o, text } : o)),
    );
  }, []);

  const validate = (): string | null => {
    if (!question.trim()) return 'Please enter a question';
    if (question.trim().length > MAX_QUESTION_LENGTH)
      return `Question must be ${MAX_QUESTION_LENGTH} characters or less`;

    const filledOptions = options.filter((o) => o.text.trim());
    if (filledOptions.length < MIN_OPTIONS)
      return `At least ${MIN_OPTIONS} options are required`;

    for (const opt of filledOptions) {
      if (opt.text.trim().length > MAX_OPTION_LENGTH) {
        return `Each option must be ${MAX_OPTION_LENGTH} characters or less`;
      }
    }

    // Check for duplicates
    const texts = filledOptions.map((o) => o.text.trim().toLowerCase());
    const unique = new Set(texts);
    if (unique.size !== texts.length) return 'Options must be unique';

    return null;
  };

  const handleSubmit = useCallback(async () => {
    const error = validate();
    if (error) {
      Alert.alert('Invalid Poll', error);
      return;
    }

    setSubmitting(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const expiresAt = new Date(
        Date.now() + durationHours * 60 * 60 * 1000,
      ).toISOString();

      // Create poll
      const { data: poll, error: pollErr } = await supabase
        .from('polls')
        .insert({
          channel_id: channelId,
          creator_id: user.id,
          question: question.trim(),
          allow_multiselect: multiSelect,
          duration_hours: durationHours,
          expires_at: expiresAt,
        })
        .select()
        .single();

      if (pollErr) throw pollErr;

      // Create options
      const filledOptions = options
        .filter((o) => o.text.trim())
        .map((o, idx) => ({
          poll_id: poll.id,
          text: o.text.trim(),
          position: idx,
        }));

      const { error: optErr } = await supabase
        .from('poll_options')
        .insert(filledOptions);

      if (optErr) throw optErr;

      onCreated?.(poll.id);
      onClose();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to create poll';
      Alert.alert('Error', msg);
    } finally {
      setSubmitting(false);
    }
  }, [question, options, multiSelect, durationHours, channelId, onCreated, onClose]);

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={[styles.title, { color: themeColors.textPrimary }]}>Create Poll</Text>
        <Pressable onPress={onClose} hitSlop={12}>
          <Ionicons name="close" size={22} color={themeColors.textMuted} />
        </Pressable>
      </View>

      <ScrollView style={styles.form} showsVerticalScrollIndicator={false}>
        {/* Question */}
        <Text style={[styles.label, { color: themeColors.textSecondary }]}>Question</Text>
        <TextInput
          value={question}
          onChangeText={setQuestion}
          placeholder="Ask a question..."
          placeholderTextColor={themeColors.textMuted}
          maxLength={MAX_QUESTION_LENGTH}
          multiline
          style={[
            styles.questionInput,
            {
              color: themeColors.textPrimary,
              backgroundColor: themeColors.bgTertiary,
              borderColor: themeColors.border,
            },
          ]}
        />
        <Text style={[styles.charCount, { color: themeColors.textMuted }]}>
          {question.length}/{MAX_QUESTION_LENGTH}
        </Text>

        {/* Options */}
        <Text style={[styles.label, { color: themeColors.textSecondary }]}>Options</Text>
        {options.map((opt, idx) => (
          <View key={opt.id} style={styles.optionRow}>
            <TextInput
              value={opt.text}
              onChangeText={(t) => updateOption(opt.id, t)}
              placeholder={`Option ${idx + 1}`}
              placeholderTextColor={themeColors.textMuted}
              maxLength={MAX_OPTION_LENGTH}
              style={[
                styles.optionInput,
                {
                  color: themeColors.textPrimary,
                  backgroundColor: themeColors.bgTertiary,
                  borderColor: themeColors.border,
                },
              ]}
            />
            {options.length > MIN_OPTIONS && (
              <Pressable
                onPress={() => removeOption(opt.id)}
                hitSlop={8}
                style={styles.removeOptionBtn}
              >
                <Ionicons name="close-circle" size={20} color={themeColors.textMuted} />
              </Pressable>
            )}
          </View>
        ))}

        {options.length < MAX_OPTIONS && (
          <Pressable
            onPress={addOption}
            style={[styles.addOptionBtn, { borderColor: themeColors.border }]}
          >
            <Ionicons name="add" size={18} color={themeColors.accentPrimary} />
            <Text style={[styles.addOptionText, { color: themeColors.accentPrimary }]}>
              Add Option
            </Text>
          </Pressable>
        )}

        {/* Duration */}
        <Text style={[styles.label, { color: themeColors.textSecondary, marginTop: spacing.lg }]}>
          Duration
        </Text>
        <View style={styles.durationRow}>
          {DURATION_OPTIONS.map((dur) => (
            <Pressable
              key={dur.value}
              onPress={() => setDurationHours(dur.value)}
              style={[
                styles.durationPill,
                {
                  backgroundColor:
                    durationHours === dur.value
                      ? themeColors.accentPrimary
                      : themeColors.bgTertiary,
                },
              ]}
            >
              <Text
                style={[
                  styles.durationText,
                  {
                    color:
                      durationHours === dur.value
                        ? '#FFFFFF'
                        : themeColors.textSecondary,
                  },
                ]}
              >
                {dur.label}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* Multi-select toggle */}
        <View style={styles.toggleRow}>
          <View style={styles.toggleLabel}>
            <Text style={[styles.toggleTitle, { color: themeColors.textPrimary }]}>
              Allow multiple answers
            </Text>
            <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
              Members can select more than one option
            </Text>
          </View>
          <Switch
            value={multiSelect}
            onValueChange={setMultiSelect}
            trackColor={{ true: themeColors.accentPrimary, false: themeColors.bgTertiary }}
            thumbColor="#FFFFFF"
          />
        </View>
      </ScrollView>

      {/* Submit */}
      <Pressable
        onPress={handleSubmit}
        disabled={submitting}
        style={[
          styles.submitBtn,
          { backgroundColor: themeColors.accentPrimary, opacity: submitting ? 0.6 : 1 },
        ]}
      >
        <Text style={styles.submitText}>
          {submitting ? 'Creating...' : 'Create Poll'}
        </Text>
      </Pressable>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderTopLeftRadius: borderRadius.xl,
    borderTopRightRadius: borderRadius.xl,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  title: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  form: {
    flex: 1,
    paddingHorizontal: spacing.lg,
  },
  label: {
    fontSize: 13,
    fontFamily: 'gg-sans-semibold',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: spacing.sm,
    marginTop: spacing.md,
  },
  questionInput: {
    borderWidth: 1,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    fontSize: 15,
    minHeight: 60,
    maxHeight: 120,
    textAlignVertical: 'top',
  },
  charCount: {
    fontSize: 11,
    textAlign: 'right',
    marginTop: 4,
  },
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
    gap: spacing.sm,
  },
  optionInput: {
    flex: 1,
    borderWidth: 1,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  removeOptionBtn: {
    padding: 4,
  },
  addOptionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.sm,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderRadius: borderRadius.md,
    marginTop: spacing.xs,
  },
  addOptionText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  durationRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  durationPill: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.full,
  },
  durationText: {
    fontSize: 13,
    fontFamily: 'gg-sans-medium',
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: spacing.lg,
    paddingBottom: spacing.xl,
  },
  toggleLabel: {
    flex: 1,
    marginRight: spacing.md,
  },
  toggleTitle: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  toggleDesc: {
    fontSize: 12,
    marginTop: 2,
  },
  submitBtn: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    alignItems: 'center',
  },
  submitText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
});
