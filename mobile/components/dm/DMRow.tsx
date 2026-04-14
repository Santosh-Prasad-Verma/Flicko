/**
 * DMRow Component — Swipeable DM conversation row with Discord features
 */
import React, { useCallback } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  runOnJS,
} from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { Ionicons } from '@expo/vector-icons';
import { OnlineAvatar } from './OnlineAvatar';
import { useTheme } from '@/hooks/useTheme';
import { spacing } from '../../constants/Colors';
import { SPRING_SNAPPY, PRESS_SCALE_CARD } from '../../constants/Animations';
import type { DMConversation } from '../../types/dm';

interface DMRowProps {
  conversation: DMConversation;
  onPress: () => void;
  onDelete?: () => void;
  onMute?: () => void;
}

function formatTime(dateString?: string): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) {
    return date.toLocaleDateString([], { weekday: 'short' });
  }
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

export const DMRow = React.memo<DMRowProps>(function DMRow({
  conversation,
  onPress,
  onDelete,
  onMute,
}) {
  const { themeColors } = useTheme();
  const translateX = useSharedValue(0);
  const scale = useSharedValue(1);

  const handleDelete = useCallback(() => {
    onDelete?.();
  }, [onDelete]);

  const handleMute = useCallback(() => {
    onMute?.();
  }, [onMute]);

  const panGesture = Gesture.Pan()
    .activeOffsetX([-10, 10])
    .onUpdate((event) => {
      // Only allow left swipe (negative translation)
      if (event.translationX < 0) {
        translateX.value = Math.max(event.translationX, -160);
      }
    })
    .onEnd(() => {
      if (translateX.value < -80) {
        translateX.value = withSpring(-160, SPRING_SNAPPY);
      } else {
        translateX.value = withSpring(0, SPRING_SNAPPY);
      }
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { scale: scale.value },
    ],
  }));

  const actionButtonsStyle = useAnimatedStyle(() => ({
    opacity: translateX.value < -20 ? 1 : 0,
  }));

  const unreadCount = conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString();

  return (
    <View style={styles.container}>
      {/* Action buttons (revealed on swipe) */}
      <Animated.View style={[styles.actionsContainer, actionButtonsStyle]}>
        <Pressable
          style={[styles.actionButton, { backgroundColor: themeColors.warning }]}
          onPress={handleMute}
        >
          <Ionicons
            name={conversation.isMuted ? 'volume-high' : 'volume-mute'}
            size={20}
            color="#FFFFFF"
          />
        </Pressable>
        <Pressable
          style={[styles.actionButton, { backgroundColor: themeColors.danger }]}
          onPress={handleDelete}
        >
          <Ionicons name="trash" size={20} color="#FFFFFF" />
        </Pressable>
      </Animated.View>

      {/* Main row content */}
      <GestureDetector gesture={panGesture}>
        <Animated.View style={animatedStyle}>
          <Pressable
            onPressIn={() => {
              scale.value = withSpring(PRESS_SCALE_CARD, SPRING_SNAPPY);
            }}
            onPressOut={() => {
              scale.value = withSpring(1, SPRING_SNAPPY);
              translateX.value = withSpring(0, SPRING_SNAPPY);
            }}
            onPress={onPress}
            style={[styles.row, { backgroundColor: themeColors.bgPrimary }]}
          >
            <OnlineAvatar participant={conversation.participant} size={40} />
            <View style={styles.content}>
              <View style={styles.header}>
                <View style={styles.nameRow}>
                  <Text
                    style={[
                      styles.name,
                      {
                        color: conversation.unreadCount > 0
                          ? themeColors.textPrimary
                          : themeColors.textSecondary,
                      },
                    ]}
                    numberOfLines={1}
                  >
                    {conversation.participant.name}
                  </Text>
                  {conversation.isMuted && (
                    <Ionicons
                      name="volume-mute"
                      size={14}
                      color={themeColors.textMuted}
                      style={styles.mutedIcon}
                    />
                  )}
                </View>
                <Text style={[styles.time, { color: themeColors.textMuted }]}>
                  {formatTime(conversation.lastMessageAt)}
                </Text>
              </View>
              <View style={styles.messageRow}>
                {conversation.isTyping ? (
                  <Text style={[styles.typing, { color: themeColors.textLink }]}>
                    is typing...
                  </Text>
                ) : (
                  <Text
                    style={[styles.message, { color: themeColors.textMuted }]}
                    numberOfLines={1}
                  >
                    {conversation.lastMessage || 'No messages yet'}
                  </Text>
                )}
                {conversation.unreadCount > 0 && (
                  <View style={[styles.badge, { backgroundColor: themeColors.badgeRed }]}>
                    <Text style={styles.badgeText}>{unreadCount}</Text>
                  </View>
                )}
              </View>
            </View>
          </Pressable>
        </Animated.View>
      </GestureDetector>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  actionsContainer: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingRight: spacing.lg,
  },
  actionButton: {
    width: 60,
    height: 60,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 11,
  },
  content: {
    flex: 1,
    marginLeft: spacing.md,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginRight: spacing.sm,
  },
  name: {
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
  },
  mutedIcon: {
    marginLeft: spacing.xs,
  },
  time: {
    fontSize: 12,
  },
  messageRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 3,
  },
  message: {
    fontSize: 14,
    flex: 1,
  },
  typing: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
    flex: 1,
  },
  badge: {
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 5,
    marginLeft: spacing.sm,
  },
  badgeText: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    color: '#FFFFFF',
  },
});
