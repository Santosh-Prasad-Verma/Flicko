/**
 * TypingIndicator Component
 *
 * Shows bouncing dots and "X is typing..." text, mirroring the web TypingIndicator atom.
 */
import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

export interface TypingIndicatorProps {
  usernames: string[];
}

function BouncingDot({ delay }: { delay: number }) {
  const anim = useRef(new Animated.Value(0)).current;
  const { themeColors } = useTheme();

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.delay(delay),
        Animated.timing(anim, { toValue: -4, duration: 300, useNativeDriver: true }),
        Animated.timing(anim, { toValue: 0, duration: 300, useNativeDriver: true }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [anim, delay]);

  return (
    <Animated.View
      style={[
        styles.dot,
        { backgroundColor: themeColors.textMuted, transform: [{ translateY: anim }] },
      ]}
    />
  );
}

export function TypingIndicator({ usernames }: TypingIndicatorProps) {
  const { themeColors } = useTheme();

  if (usernames.length === 0) return null;

  let text: string;
  if (usernames.length === 1) {
    text = `${usernames[0]} is typing...`;
  } else if (usernames.length === 2) {
    text = `${usernames[0]} and ${usernames[1]} are typing...`;
  } else if (usernames.length === 3) {
    text = `${usernames[0]}, ${usernames[1]}, and ${usernames[2]} are typing...`;
  } else {
    text = 'Several people are typing...';
  }

  return (
    <View style={styles.container}>
      <View style={styles.dots}>
        <BouncingDot delay={0} />
        <BouncingDot delay={150} />
        <BouncingDot delay={300} />
      </View>
      <Text style={[styles.text, { color: themeColors.textMuted }]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    gap: spacing.xs,
  },
  dots: {
    flexDirection: 'row',
    gap: 3,
    alignItems: 'center',
    height: 16,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  text: {
    ...typography.bodySmall,
  },
});
