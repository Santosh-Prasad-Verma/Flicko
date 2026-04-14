/**
 * MentionAutocomplete Component
 *
 * Dropdown autocomplete for @user, #channel, and @role mentions.
 * Appears above the input when user types @ or #.
 * Requirements: Feature 20 (Mention System)
 */
import React, { memo, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

export type MentionType = 'user' | 'channel' | 'role';

export interface MentionSuggestion {
  id: string;
  type: MentionType;
  name: string;
  displayName?: string;
  color?: string;
  icon?: string;
}

interface MentionAutocompleteProps {
  visible: boolean;
  query: string;
  suggestions: MentionSuggestion[];
  onSelect: (suggestion: MentionSuggestion) => void;
}

export const MentionAutocomplete = memo(function MentionAutocomplete({
  visible,
  query,
  suggestions,
  onSelect,
}: MentionAutocompleteProps) {
  const { themeColors } = useTheme();

  const filtered = useMemo(() => {
    if (!query) return suggestions.slice(0, 10);
    const q = query.toLowerCase();
    return suggestions.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        (s.displayName && s.displayName.toLowerCase().includes(q)),
    ).slice(0, 10);
  }, [suggestions, query]);

  if (!visible || filtered.length === 0) return null;

  const getIcon = (type: MentionType): keyof typeof Ionicons.glyphMap => {
    switch (type) {
      case 'user': return 'person';
      case 'channel': return 'chatbubble-outline';
      case 'role': return 'shield-outline';
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}>
      <FlatList
        data={filtered}
        keyExtractor={(item) => `${item.type}-${item.id}`}
        keyboardShouldPersistTaps="always"
        renderItem={({ item }) => (
          <Pressable
            style={({ pressed }) => [
              styles.row,
              pressed && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => onSelect(item)}
          >
            <Ionicons
              name={getIcon(item.type)}
              size={16}
              color={item.color || themeColors.textMuted}
            />
            <Text
              style={[
                styles.name,
                { color: item.color || themeColors.textPrimary },
              ]}
              numberOfLines={1}
            >
              {item.type === 'channel' ? '#' : '@'}
              {item.displayName || item.name}
            </Text>
            {item.type === 'user' && item.displayName && item.displayName !== item.name && (
              <Text style={[styles.username, { color: themeColors.textMuted }]} numberOfLines={1}>
                @{item.name}
              </Text>
            )}
          </Pressable>
        )}
        style={styles.list}
      />
    </View>
  );
});

/**
 * Parses text input and detects if the user is currently typing a mention.
 * Returns { active, type, query, startIndex } or null.
 */
export function detectMention(text: string, cursorPosition: number): {
  active: boolean;
  type: MentionType;
  query: string;
  startIndex: number;
} | null {
  if (cursorPosition <= 0) return null;
  const before = text.slice(0, cursorPosition);

  // Find last @ or # before cursor
  const atIdx = before.lastIndexOf('@');
  const hashIdx = before.lastIndexOf('#');

  if (atIdx === -1 && hashIdx === -1) return null;

  const triggerIdx = Math.max(atIdx, hashIdx);
  const triggerChar = before[triggerIdx];
  const afterTrigger = before.slice(triggerIdx + 1);

  // Check no spaces in the query (mention ends at space)
  if (afterTrigger.includes(' ')) return null;

  // Must be at start or after a space/newline
  if (triggerIdx > 0 && !/[\s\n]/.test(before[triggerIdx - 1])) return null;

  return {
    active: true,
    type: triggerChar === '#' ? 'channel' : 'user', // role detection can be added
    query: afterTrigger,
    startIndex: triggerIdx,
  };
}

/**
 * Inserts a mention into text, replacing the trigger+query.
 */
export function insertMention(
  text: string,
  startIndex: number,
  cursorPosition: number,
  suggestion: MentionSuggestion,
): { text: string; newCursorPosition: number } {
  const prefix = text.slice(0, startIndex);
  const suffix = text.slice(cursorPosition);
  const mentionText =
    suggestion.type === 'channel'
      ? `#${suggestion.name} `
      : `@${suggestion.displayName || suggestion.name} `;

  return {
    text: prefix + mentionText + suffix,
    newCursorPosition: (prefix + mentionText).length,
  };
}

const styles = StyleSheet.create({
  container: {
    borderWidth: 1,
    borderRadius: borderRadius.md,
    maxHeight: 200,
    marginHorizontal: spacing.md,
    marginBottom: spacing.xs,
    overflow: 'hidden',
  },
  list: { maxHeight: 200 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
    gap: spacing.sm,
  },
  name: { ...typography.bodySmall, fontFamily: 'gg-sans-medium' },
  username: { ...typography.caption },
});
