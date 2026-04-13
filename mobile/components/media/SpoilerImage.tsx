/**
 * SpoilerImage Component
 *
 * Blurred image overlay that reveals on tap, like Discord spoiler images.
 * Tap to reveal, tap again to re-hide.
 */
import React, { memo, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Image } from 'expo-image';
import { BlurView } from 'expo-blur';
import { Ionicons } from '@expo/vector-icons';
import { borderRadius, spacing } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface SpoilerImageProps {
  uri: string;
  width?: number;
  height?: number;
  alt?: string;
  onLongPress?: () => void;
}

export const SpoilerImage = memo(function SpoilerImage({
  uri,
  width = 300,
  height = 200,
  alt,
  onLongPress,
}: SpoilerImageProps) {
  const [revealed, setRevealed] = useState(false);
  const { themeColors } = useTheme();

  return (
    <Pressable
      onPress={() => setRevealed((v) => !v)}
      onLongPress={onLongPress}
      style={[styles.container, { width, height }]}
    >
      <Image
        source={{ uri }}
        style={[styles.image, { width, height }]}
        contentFit="cover"
        accessibilityLabel={alt || 'Spoiler image'}
      />
      {!revealed && (
        <View style={[styles.overlay, { backgroundColor: themeColors.bgTertiary + 'EE' }]}>
          <BlurView intensity={80} tint="dark" style={StyleSheet.absoluteFill} />
          <View style={styles.spoilerLabel}>
            <Ionicons name="eye-off" size={24} color="#fff" />
            <Text style={styles.spoilerText}>SPOILER</Text>
          </View>
        </View>
      )}
    </Pressable>
  );
});

const styles = StyleSheet.create({
  container: {
    borderRadius: borderRadius.md,
    overflow: 'hidden',
    marginVertical: spacing.xs,
  },
  image: {
    borderRadius: borderRadius.md,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: borderRadius.md,
  },
  spoilerLabel: {
    alignItems: 'center',
    gap: 4,
    zIndex: 1,
  },
  spoilerText: {
    color: '#fff',
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 1,
  },
});
