/**
 * Avatar Component
 *
 * Displays a user or server avatar with fallback initials,
 * online-status indicator, and accessibility labels.
 * Accepts size as named preset ('xs'..'xl') or numeric pixel value.
 * Accepts image source as `uri` or `imageUrl`.
 *
 * Requirements: 16.4
 */
import React, { useMemo } from 'react';
import { View, Text, StyleSheet, ViewStyle } from 'react-native';
import { Image } from 'expo-image';
import { borderRadius } from '../../constants/Colors';
import { layout } from '../../constants/Layout';
import { useTheme } from '@/hooks/useTheme';

type AvatarSizeName = 'xs' | 'sm' | 'md' | 'lg' | 'xl';
type StatusIndicator = 'online' | 'idle' | 'dnd' | 'offline' | null;

interface AvatarProps {
  /** Image URI — use `uri` or `imageUrl` */
  uri?: string | null;
  /** Alias for `uri` */
  imageUrl?: string | null;
  /** User/server display name (used for initials fallback) */
  name?: string;
  /** Named preset or pixel number */
  size?: AvatarSizeName | number;
  status?: StatusIndicator;
  accessibilityLabel?: string;
  style?: ViewStyle;
}

export const Avatar = React.memo<AvatarProps>(function Avatar({
  uri,
  imageUrl,
  name,
  size = 'md',
  status = null,
  accessibilityLabel,
  style,
}) {
  const { themeColors } = useTheme();
  const resolvedUri = uri ?? imageUrl;
  const dimension = typeof size === 'number' ? size : layout.avatarSizes[size];
  const label = accessibilityLabel ?? name ?? 'Avatar';

  const initials = useMemo(() => {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) {
      return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
    }
    return name[0]?.toUpperCase() ?? '?';
  }, [name]);

  const containerStyle = useMemo((): ViewStyle => ({
    width: dimension,
    height: dimension,
    borderRadius: borderRadius.full,
    // NOTE: No overflow:hidden here — it blocks GIF / animated-WebP frame
    // rendering on Android. Border-radius clipping is on the Image itself.
    backgroundColor: themeColors.bgTertiary,
    alignItems: 'center',
    justifyContent: 'center',
  }), [dimension, themeColors]);

  const statusSize = Math.round(dimension * 0.3);

  // Map status to theme color tokens
  const statusColor = useMemo(() => {
    if (!status) return null;
    switch (status) {
      case 'online':
        return themeColors.statusOnline;
      case 'idle':
        return themeColors.statusIdle;
      case 'dnd':
        return themeColors.statusDnd;
      case 'offline':
        return themeColors.statusOffline;
      default:
        return themeColors.statusOffline;
    }
  }, [status, themeColors]);

  return (
    <View
      style={[styles.root, style]}
      accessibilityLabel={label}
      accessibilityRole="image"
    >
      <View style={containerStyle}>
        {resolvedUri ? (
          <Image
            source={{ uri: resolvedUri }}
            style={{ width: dimension, height: dimension, borderRadius: borderRadius.full }}
            contentFit="cover"
            cachePolicy="disk"
            transition={200}
            autoplay={true}
          />
        ) : (
          <Text
            style={[
              styles.initials,
              {
                fontSize: dimension * 0.4,
                color: themeColors.textPrimary,
              },
            ]}
          >
            {initials}
          </Text>
        )}
      </View>

      {status ? (
        <View
          style={[
            styles.statusDot,
            {
              width: statusSize,
              height: statusSize,
              borderRadius: statusSize / 2,
              backgroundColor: statusColor,
              borderColor: themeColors.bgPrimary,
              borderWidth: 2,
              bottom: 0,
              right: 0,
            },
          ]}
          accessibilityLabel={`Status: ${status}`}
        />
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  root: {
    position: 'relative',
  },
  initials: {
    fontFamily: 'gg-sans-bold',
  },
  statusDot: {
    position: 'absolute',
  },
});
