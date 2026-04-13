/**
 * Enhanced Profile Card
 *
 * Full user profile popover / bottom sheet with banner, avatar, bio,
 * custom status, accent color, badges, and mutual servers / friends.
 *
 * Requirements: Feature 22 (User Profiles), Feature 23 (Badges)
 */
import React, { memo, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  Dimensions,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeIn } from 'react-native-reanimated';
import { Avatar } from '../ui/Avatar';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { generateProfilePalette } from '../../lib/colorUtils';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const BANNER_HEIGHT = 120;

export interface Badge {
  id: string;
  name: string;
  icon: string; // Ionicons name
  color: string;
}

export interface ProfileUser {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  banner_url: string | null;
  bio: string | null;
  accent_color: string | null;
  online_status: 'online' | 'idle' | 'dnd' | 'offline';
  custom_status?: string | null;
  custom_status_emoji?: string | null;
  badges?: Badge[];
  created_at: string;
}

interface ProfileCardProps {
  user: ProfileUser;
  mutualServers?: { id: string; name: string; icon_url: string | null }[];
  mutualFriends?: number;
  isFriend?: boolean;
  onSendMessage?: () => void;
  onAddFriend?: () => void;
  onRemoveFriend?: () => void;
  onBlock?: () => void;
  onClose?: () => void;
}

const STATUS_COLORS: Record<string, string> = {
  online: '#2ECC71',
  idle: '#F0B232',
  dnd: '#ED4245',
  offline: '#72767D',
};

export const ProfileCard = memo(function ProfileCard({
  user,
  mutualServers = [],
  mutualFriends = 0,
  isFriend = false,
  onSendMessage,
  onAddFriend,
  onRemoveFriend,
  onBlock,
  onClose,
}: ProfileCardProps) {
  const { themeColors } = useTheme();
  const accentColor = user.accent_color ?? themeColors.accentPrimary;
  const palette = useMemo(() => generateProfilePalette(accentColor), [accentColor]);

  const joinDate = useMemo(() => {
    const d = new Date(user.created_at);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }, [user.created_at]);

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
    >
      {/* Banner */}
      <View style={[styles.banner, { backgroundColor: palette.accent }]}>
        {user.banner_url && (
          <Image
            source={{ uri: user.banner_url }}
            style={StyleSheet.absoluteFillObject}
            contentFit="cover"
          />
        )}
        {onClose && (
          <Pressable onPress={onClose} style={styles.closeBtn} hitSlop={12}>
            <Ionicons name="close" size={20} color="#FFFFFF" />
          </Pressable>
        )}
      </View>

      {/* Avatar with status indicator */}
      <View style={styles.avatarSection}>
        <View style={[styles.avatarBorder, { borderColor: themeColors.bgPrimary, shadowColor: palette.accent, shadowOpacity: 0.3, shadowRadius: 8, elevation: 4 }]}>
          <Avatar
            name={user.display_name ?? user.username}
            imageUrl={user.avatar_url}
            size={80}
          />
          <View
            style={[
              styles.statusDot,
              { backgroundColor: STATUS_COLORS[user.online_status] ?? STATUS_COLORS.offline },
              { borderColor: themeColors.bgPrimary },
            ]}
          />
        </View>
      </View>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
        showsVerticalScrollIndicator={false}
      >
        {/* Name & Username */}
        <Text style={[styles.displayName, { color: themeColors.textPrimary }]}>
          {user.display_name ?? user.username}
        </Text>
        <Text style={[styles.username, { color: themeColors.textSecondary }]}>
          @{user.username}
        </Text>

        {/* Custom Status */}
        {user.custom_status && (
          <View style={styles.customStatus}>
            {user.custom_status_emoji && (
              <Text style={styles.statusEmoji}>{user.custom_status_emoji}</Text>
            )}
            <Text style={[styles.statusText, { color: themeColors.textSecondary }]}>
              {user.custom_status}
            </Text>
          </View>
        )}

        {/* Badges */}
        {user.badges && user.badges.length > 0 && (
          <View style={styles.badgeRow}>
            {user.badges.map((badge) => (
              <View
                key={badge.id}
                style={[styles.badge, { backgroundColor: badge.color + '20' }]}
              >
                <Ionicons name={badge.icon as any} size={14} color={badge.color} />
                <Text style={[styles.badgeName, { color: badge.color }]}>{badge.name}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Divider */}
        <View style={[styles.divider, { backgroundColor: themeColors.border }]} />

        {/* Bio */}
        {user.bio && (
          <View style={[styles.section, { backgroundColor: palette.sectionBg, borderRadius: 8, padding: spacing.sm }]}>
            <Text style={[styles.sectionTitle, { color: palette.accentBright }]}>ABOUT ME</Text>
            <Text style={[styles.bioText, { color: themeColors.textPrimary }]}>
              {user.bio}
            </Text>
          </View>
        )}

        {/* Member Since */}
        <View style={[styles.section, { backgroundColor: palette.sectionBg, borderRadius: 8, padding: spacing.sm }]}>
          <Text style={[styles.sectionTitle, { color: palette.accentBright }]}>MEMBER SINCE</Text>
          <Text style={[styles.sectionValue, { color: themeColors.textSecondary }]}>
            {joinDate}
          </Text>
        </View>

        {/* Mutual Servers */}
        {mutualServers.length > 0 && (
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
              MUTUAL SERVERS — {mutualServers.length}
            </Text>
            <View style={styles.mutualRow}>
              {mutualServers.slice(0, 5).map((server) => (
                <View key={server.id} style={styles.mutualItem}>
                  {server.icon_url ? (
                    <Image source={{ uri: server.icon_url }} style={styles.mutualIcon} />
                  ) : (
                    <View style={[styles.mutualIconFallback, { backgroundColor: themeColors.bgTertiary }]}>
                      <Text style={[styles.mutualIconText, { color: themeColors.textMuted }]}>
                        {server.name.charAt(0)}
                      </Text>
                    </View>
                  )}
                  <Text
                    style={[styles.mutualName, { color: themeColors.textSecondary }]}
                    numberOfLines={1}
                  >
                    {server.name}
                  </Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* Mutual Friends */}
        {mutualFriends > 0 && (
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
              MUTUAL FRIENDS — {mutualFriends}
            </Text>
          </View>
        )}

        {/* Divider */}
        <View style={[styles.divider, { backgroundColor: themeColors.border }]} />

        {/* Action buttons */}
        <View style={styles.actions}>
          {onSendMessage && (
            <Pressable
              onPress={onSendMessage}
              style={[styles.actionBtn, { backgroundColor: palette.accent }]}
            >
              <Ionicons name="chatbubble" size={16} color={palette.accentText} />
              <Text style={[styles.actionBtnText, { color: palette.accentText }]}>Message</Text>
            </Pressable>
          )}
          {!isFriend && onAddFriend && (
            <Pressable
              onPress={onAddFriend}
              style={[styles.actionBtn, { backgroundColor: '#2ECC71' }]}
            >
              <Ionicons name="person-add" size={16} color="#FFFFFF" />
              <Text style={styles.actionBtnText}>Add Friend</Text>
            </Pressable>
          )}
          {isFriend && onRemoveFriend && (
            <Pressable
              onPress={onRemoveFriend}
              style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons name="person-remove" size={16} color={themeColors.textMuted} />
              <Text style={[styles.actionBtnText, { color: themeColors.textMuted }]}>
                Remove Friend
              </Text>
            </Pressable>
          )}
        </View>
      </ScrollView>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  container: {
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
    maxHeight: 600,
  },
  banner: {
    height: BANNER_HEIGHT,
    width: '100%',
  },
  closeBtn: {
    position: 'absolute',
    top: spacing.sm,
    right: spacing.sm,
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 14,
    width: 28,
    height: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarSection: {
    marginTop: -40,
    paddingHorizontal: spacing.md,
  },
  avatarBorder: {
    borderWidth: 4,
    borderRadius: 44,
    alignSelf: 'flex-start',
  },
  statusDot: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 3,
  },
  content: {
    flex: 1,
  },
  contentInner: {
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.lg,
  },
  displayName: {
    fontSize: 22,
    fontFamily: 'gg-sans-bold',
    marginTop: spacing.sm,
  },
  username: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
    marginTop: 2,
  },
  customStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  statusEmoji: {
    fontSize: 16,
  },
  statusText: {
    fontSize: 13,
  },
  badgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    borderRadius: borderRadius.sm,
  },
  badgeName: {
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  divider: {
    height: 1,
    marginVertical: spacing.md,
  },
  section: {
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: spacing.xs,
  },
  sectionValue: {
    fontSize: 13,
  },
  bioText: {
    fontSize: 14,
    lineHeight: 20,
  },
  mutualRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  mutualItem: {
    alignItems: 'center',
    width: 56,
  },
  mutualIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  mutualIconFallback: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  mutualIconText: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
  mutualName: {
    fontSize: 10,
    marginTop: 4,
    textAlign: 'center',
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  actionBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.sm + 2,
    borderRadius: borderRadius.md,
  },
  actionBtnText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
});
