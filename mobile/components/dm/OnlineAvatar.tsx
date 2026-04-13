/**
 * OnlineAvatar Component — Avatar with status dot and bot badge
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Avatar } from '../ui/Avatar';
import { useTheme } from '../../hooks/useTheme';
import type { DMParticipant } from '../../types/dm';

interface OnlineAvatarProps {
  participant: DMParticipant;
  size?: number;
  showStatus?: boolean;
}

export const OnlineAvatar = React.memo<OnlineAvatarProps>(function OnlineAvatar({
  participant,
  size = 40,
  showStatus = true,
}) {
  const { themeColors } = useTheme();

  return (
    <View style={styles.container}>
      <Avatar
        name={participant.name}
        imageUrl={participant.avatar}
        size={size}
        status={showStatus ? participant.status : null}
      />
      {participant.isBot && (
        <View style={[styles.botBadge, { backgroundColor: themeColors.accentPrimary }]}>
          <Text style={styles.botText}>BOT</Text>
        </View>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  botBadge: {
    position: 'absolute',
    bottom: -4,
    right: -4,
    paddingHorizontal: 4,
    paddingVertical: 1,
    borderRadius: 3,
  },
  botText: {
    fontSize: 8,
    fontFamily: 'gg-sans-bold',
    color: '#FFFFFF',
  },
});
