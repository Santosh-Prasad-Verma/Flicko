/**
 * OnlineFriendsRow Component — Horizontal scrollable online friends
 */
import React from 'react';
import { View, Text, ScrollView, StyleSheet, Pressable } from 'react-native';
import { OnlineAvatar } from './OnlineAvatar';
import { useTheme } from '../../hooks/useTheme';
import { spacing } from '../../constants/Colors';
import type { DMParticipant } from '../../types/dm';

interface OnlineFriendsRowProps {
  friends: DMParticipant[];
  onPressFriend?: (friend: DMParticipant) => void;
}

export const OnlineFriendsRow = React.memo<OnlineFriendsRowProps>(function OnlineFriendsRow({
  friends,
  onPressFriend,
}: OnlineFriendsRowProps) {
  const { themeColors } = useTheme();

  if (friends.length === 0) return null;

  return (
    <View style={styles.container}>
      <Text style={[styles.title, { color: themeColors.textMuted }]}>
        ONLINE — {friends.length}
      </Text>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {friends.map((friend: DMParticipant) => (
          <Pressable
            key={friend.id}
            onPress={() => onPressFriend?.(friend)}
            style={styles.friendItem}
          >
            <OnlineAvatar participant={friend} size={56} />
            <Text
              style={[styles.friendName, { color: themeColors.textSecondary }]}
              numberOfLines={1}
            >
              {friend.name}
            </Text>
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    paddingVertical: spacing.sm,
  },
  title: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    paddingHorizontal: spacing.lg,
    marginBottom: spacing.sm,
  },
  scrollContent: {
    paddingHorizontal: spacing.lg,
    gap: spacing.md,
  },
  friendItem: {
    alignItems: 'center',
    width: 64,
  },
  friendName: {
    fontSize: 12,
    marginTop: spacing.xs,
    textAlign: 'center',
  },
});
