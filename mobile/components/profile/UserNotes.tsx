/**
 * UserNotes
 *
 * Private per-user notes component. Notes are stored locally in
 * AsyncStorage (zero-cost) keyed by the target user's ID.
 *
 * Requirements: Feature 24 (User Notes)
 */
import React, { memo, useState, useEffect, useCallback, useRef } from 'react';
import { View, Text, TextInput, StyleSheet, Pressable } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';

const NOTES_PREFIX = '@flicko:user_note:';

interface UserNotesProps {
  userId: string;
  editable?: boolean;
}

export const UserNotes = memo(function UserNotes({ userId, editable = true }: UserNotesProps) {
  const { themeColors } = useTheme();
  const [note, setNote] = useState('');
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const inputRef = useRef<TextInput>(null);

  // Load note
  useEffect(() => {
    AsyncStorage.getItem(`${NOTES_PREFIX}${userId}`).then((val) => {
      if (val) setNote(val);
    });
  }, [userId]);

  const handleSave = useCallback(async () => {
    setSaving(true);
    try {
      if (note.trim()) {
        await AsyncStorage.setItem(`${NOTES_PREFIX}${userId}`, note.trim());
      } else {
        await AsyncStorage.removeItem(`${NOTES_PREFIX}${userId}`);
      }
    } catch (err) {
      console.error('[UserNotes] save error:', err);
    } finally {
      setSaving(false);
      setEditing(false);
    }
  }, [userId, note]);

  const handleStartEdit = useCallback(() => {
    setEditing(true);
    setTimeout(() => inputRef.current?.focus(), 100);
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: themeColors.textMuted }]}>NOTE</Text>
        {editable && !editing && (
          <Pressable onPress={handleStartEdit} hitSlop={10}>
            <Ionicons name="pencil" size={14} color={themeColors.textMuted} />
          </Pressable>
        )}
        {editing && (
          <Pressable onPress={handleSave} hitSlop={10} disabled={saving}>
            <Ionicons name="checkmark" size={16} color={themeColors.accentPrimary} />
          </Pressable>
        )}
      </View>

      {editing ? (
        <TextInput
          ref={inputRef}
          value={note}
          onChangeText={setNote}
          onBlur={handleSave}
          multiline
          maxLength={256}
          placeholder="Click to add a note"
          placeholderTextColor={themeColors.textMuted}
          style={[
            styles.input,
            {
              color: themeColors.textPrimary,
              backgroundColor: themeColors.bgTertiary,
              borderColor: themeColors.accentPrimary,
            },
          ]}
        />
      ) : (
        <Pressable onPress={editable ? handleStartEdit : undefined}>
          <Text style={[styles.noteText, { color: note ? themeColors.textSecondary : themeColors.textMuted }]}>
            {note || 'Click to add a note'}
          </Text>
        </Pressable>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    paddingVertical: spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  title: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
  },
  input: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
    fontSize: 13,
    maxHeight: 100,
    minHeight: 60,
  },
  noteText: {
    fontSize: 13,
    lineHeight: 18,
  },
});
