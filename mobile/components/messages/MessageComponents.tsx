// ============================================
// Message Components — Buttons, Select Menus, Action Rows
// Renders interactive components on messages
// ============================================
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
} from 'react-native';
import Animated, { FadeIn, useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { SPRING_SNAPPY } from '../../constants/Animations';
import {
  ActionRow,
  MessageComponent,
  ButtonComponent,
  SelectMenuComponent,
  SelectOption,
  ButtonStyle,
} from '@stores/interactionStore';
import { submitComponentInteraction } from '@services/commandService';

// ---- Button Style Colors ----

const BUTTON_COLORS: Record<number, { bg: string; text: string }> = {
  1: { bg: '#5865F2', text: '#FFFFFF' }, // primary (blurple)
  2: { bg: '#4F545C', text: '#FFFFFF' }, // secondary (grey)
  3: { bg: '#3BA55D', text: '#FFFFFF' }, // success (green)
  4: { bg: '#ED4245', text: '#FFFFFF' }, // danger (red)
  5: { bg: '#4F545C', text: '#FFFFFF' }, // link (grey)
};

// ---- Props ----

interface MessageComponentsProps {
  components: ActionRow[];
  guildId: string;
  channelId: string;
  messageId: string;
  onInteractionResponse?: (response: any) => void;
}

// ---- Main Component ----

export function MessageComponents({
  components,
  guildId,
  channelId,
  messageId,
  onInteractionResponse,
}: MessageComponentsProps) {
  const themeColors = useTheme();

  if (!components || components.length === 0) return null;

  return (
    <View style={styles.container}>
      {components.map((row, rowIndex) => (
        <View key={`row-${rowIndex}`} style={styles.actionRow}>
          {row.components.map((component, compIndex) => {
            if (component.type === 2) {
              return (
                <ComponentButton
                  key={`btn-${rowIndex}-${compIndex}`}
                  button={component as ButtonComponent}
                  guildId={guildId}
                  channelId={channelId}
                  onResponse={onInteractionResponse}
                  themeColors={themeColors}
                />
              );
            }
            if (component.type >= 3) {
              return (
                <ComponentSelectMenu
                  key={`sel-${rowIndex}-${compIndex}`}
                  select={component as SelectMenuComponent}
                  guildId={guildId}
                  channelId={channelId}
                  onResponse={onInteractionResponse}
                  themeColors={themeColors}
                />
              );
            }
            return null;
          })}
        </View>
      ))}
    </View>
  );
}

// ---- Button Component ----

function ComponentButton({
  button,
  guildId,
  channelId,
  onResponse,
  themeColors,
}: {
  button: ButtonComponent;
  guildId: string;
  channelId: string;
  onResponse?: (response: any) => void;
  themeColors: any;
}) {
  const [isPressed, setIsPressed] = useState(false);
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const colors = BUTTON_COLORS[button.style] ?? BUTTON_COLORS[2];

  const handlePress = useCallback(async () => {
    if (button.disabled) return;

    // Link button — open URL
    if (button.style === 5 && button.url) {
      try { await Linking.openURL(button.url); } catch {}
      return;
    }

    // Interactive button — submit component interaction
    if (button.custom_id) {
      setIsPressed(true);
      try {
        const response = await submitComponentInteraction(
          guildId,
          channelId,
          button.custom_id,
          2 // button type
        );
        onResponse?.(response);
      } catch (err) {
        console.warn('Button interaction failed:', err);
      } finally {
        setIsPressed(false);
      }
    }
  }, [button, guildId, channelId]);

  return (
    <Animated.View style={animatedStyle}>
      <TouchableOpacity
        style={[
          styles.button,
          {
            backgroundColor: button.disabled ? `${colors.bg}80` : colors.bg,
            opacity: button.disabled ? 0.5 : 1,
          },
        ]}
        onPress={handlePress}
        onPressIn={() => { scale.value = withSpring(0.95, SPRING_SNAPPY); }}
        onPressOut={() => { scale.value = withSpring(1, SPRING_SNAPPY); }}
        disabled={button.disabled || isPressed}
        activeOpacity={0.8}
      >
        {button.emoji && (
          <Text style={styles.buttonEmoji}>{button.emoji.name}</Text>
        )}
        {button.label && (
          <Text style={[styles.buttonLabel, { color: colors.text }]}>{button.label}</Text>
        )}
        {button.style === 5 && (
          <Ionicons name="open-outline" size={12} color={colors.text} style={{ marginLeft: 4 }} />
        )}
      </TouchableOpacity>
    </Animated.View>
  );
}

// ---- Select Menu Component ----

function ComponentSelectMenu({
  select,
  guildId,
  channelId,
  onResponse,
  themeColors,
}: {
  select: SelectMenuComponent;
  guildId: string;
  channelId: string;
  onResponse?: (response: any) => void;
  themeColors: any;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedValues, setSelectedValues] = useState<string[]>([]);
  const isMulti = (select.max_values ?? 1) > 1;

  const handleSelect = useCallback(
    async (value: string) => {
      let newValues: string[];

      if (isMulti) {
        newValues = selectedValues.includes(value)
          ? selectedValues.filter((v) => v !== value)
          : [...selectedValues, value];
        setSelectedValues(newValues);

        // Auto-submit when max reached
        if (newValues.length >= (select.max_values ?? 1)) {
          setIsOpen(false);
          try {
            const response = await submitComponentInteraction(
              guildId,
              channelId,
              select.custom_id,
              select.type,
              newValues
            );
            onResponse?.(response);
          } catch (err) {
            console.warn('Select interaction failed:', err);
          }
        }
      } else {
        newValues = [value];
        setSelectedValues(newValues);
        setIsOpen(false);

        try {
          const response = await submitComponentInteraction(
            guildId,
            channelId,
            select.custom_id,
            select.type,
            newValues
          );
          onResponse?.(response);
        } catch (err) {
          console.warn('Select interaction failed:', err);
        }
      }
    },
    [select, guildId, channelId, selectedValues, isMulti]
  );

  const displayText = selectedValues.length > 0
    ? select.options
        ?.filter((o) => selectedValues.includes(o.value))
        .map((o) => o.label)
        .join(', ')
    : select.placeholder ?? 'Make a selection';

  return (
    <View style={styles.selectContainer}>
      <TouchableOpacity
        style={[
          styles.selectTrigger,
          {
            backgroundColor: themeColors.background,
            borderColor: isOpen ? themeColors.primary : themeColors.border,
          },
        ]}
        onPress={() => !select.disabled && setIsOpen(!isOpen)}
        disabled={select.disabled}
        activeOpacity={0.7}
      >
        <Text
          style={[
            styles.selectText,
            { color: selectedValues.length > 0 ? themeColors.text : themeColors.textSecondary },
          ]}
          numberOfLines={1}
        >
          {displayText}
        </Text>
        <Ionicons
          name={isOpen ? 'chevron-up' : 'chevron-down'}
          size={16}
          color={themeColors.textSecondary}
        />
      </TouchableOpacity>

      {isOpen && select.options && (
        <Animated.View
          entering={FadeIn.duration(150)}
          style={[styles.selectDropdown, { backgroundColor: themeColors.surface, borderColor: themeColors.border }]}
        >
          {select.options.map((option) => (
            <TouchableOpacity
              key={option.value}
              style={[
                styles.selectOption,
                selectedValues.includes(option.value) && { backgroundColor: `${themeColors.primary}20` },
                { borderBottomColor: themeColors.border },
              ]}
              onPress={() => handleSelect(option.value)}
            >
              {option.emoji && <Text style={styles.optionEmoji}>{option.emoji.name}</Text>}
              <View style={styles.optionInfo}>
                <Text style={[styles.optionLabel, { color: themeColors.text }]}>{option.label}</Text>
                {option.description && (
                  <Text style={[styles.optionDesc, { color: themeColors.textSecondary }]} numberOfLines={1}>
                    {option.description}
                  </Text>
                )}
              </View>
              {selectedValues.includes(option.value) && (
                <Ionicons name="checkmark" size={16} color={themeColors.primary} />
              )}
            </TouchableOpacity>
          ))}
        </Animated.View>
      )}
    </View>
  );
}

// ---- Ephemeral Message Banner ----

export function EphemeralBanner({ themeColors }: { themeColors: any }) {
  return (
    <View style={[styles.ephemeralBanner, { backgroundColor: `${themeColors.primary}15` }]}>
      <Ionicons name="eye-off-outline" size={14} color={themeColors.primary} />
      <Text style={[styles.ephemeralText, { color: themeColors.primary }]}>
        Only you can see this message
      </Text>
    </View>
  );
}

// ---- Styles ----

const styles = StyleSheet.create({
  container: {
    marginTop: spacing.xs,
    gap: spacing.xs,
  },
  actionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  // Button
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs + 2,
    borderRadius: borderRadius.sm,
    minWidth: 60,
    gap: 4,
  },
  buttonEmoji: {
    fontSize: 14,
  },
  buttonLabel: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  // Select
  selectContainer: {
    flex: 1,
    maxWidth: '100%',
  },
  selectTrigger: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs + 2,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
  },
  selectText: {
    flex: 1,
    fontSize: 14,
  },
  selectDropdown: {
    marginTop: 2,
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
    maxHeight: 200,
  },
  selectOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.xs,
  },
  optionEmoji: {
    fontSize: 16,
  },
  optionInfo: {
    flex: 1,
  },
  optionLabel: {
    fontSize: 14,
  },
  optionDesc: {
    fontSize: 12,
    marginTop: 1,
  },
  // Ephemeral
  ephemeralBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.sm,
    marginTop: spacing.xs,
  },
  ephemeralText: {
    fontSize: 12,
    fontFamily: 'gg-sans-medium',
  },
});
