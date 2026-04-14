/**
 * ChannelList Component — Discord-Accurate Animated
 *
 * Displays channels grouped by category with collapsible sections.
 * Categories are channels with type='category'. Child channels have parent_id.
 * Uncategorized channels appear at top. Voice channels show user counts.
 *
 * Animations:
 * - Channel rows: press scale-down (0.98), animated bg highlight
 * - Category headers: chevron rotation on collapse/expand
 * - List items: FadeIn entering animation
 * - Unread/mention badges: spring pop-in
 *
 * Requirements: 4.2, 4.3, 4.7, 4.8, 6.1, 6.2, 6.3, 16.2
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  SectionList,
  StyleSheet,
  Pressable,
  RefreshControl,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  FadeIn,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { router, usePathname } from 'expo-router';
import { spacing, typography, MINIMUM_TOUCH_TARGET, borderRadius } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';
import { EmptyState } from '../shared/EmptyState';
import {
  SPRING_SNAPPY,
  TIMING_FAST,
  PRESS_SCALE_CARD,
  ENTER_POP,
} from '../../constants/Animations';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export interface ChannelItem {
  id: string;
  name: string;
  type: 'text' | 'voice' | 'category' | 'announcement' | 'forum' | 'stage';
  topic?: string | null;
  parent_id?: string | null;
  position?: number;
  unread_count?: number;
  mention_count?: number;
  muted?: boolean;
  voice_user_count?: number;
  nsfw?: boolean;
}

interface ChannelListProps {
  channels: ChannelItem[];
  serverId: string;
  refreshing?: boolean;
  onRefresh?: () => void;
  onCreateChannel?: (categoryId?: string) => void;
  canManageChannels?: boolean;
}

// Icon per channel type
const CHANNEL_ICON: Record<string, { ionicon?: keyof typeof Ionicons.glyphMap; text?: string }> = {
  text:         { ionicon: undefined,                   text: '#' },
  voice:        { ionicon: 'volume-medium-outline'                },
  announcement: { ionicon: 'megaphone-outline'                    },
  forum:        { ionicon: 'newspaper-outline'                    },
  stage:        { ionicon: 'radio-outline'                        },
};

// ─── Channel Row ───────────────────────────────────────────────────────────────

const ChannelRow = memo(function ChannelRow({
  channel,
  serverId,
}: {
  channel: ChannelItem;
  serverId: string;
}) {
  const { themeColors } = useTheme();
  const pathname = usePathname();

  const isActive = pathname.includes(`/channel/${channel.id}`);
  const hasUnread = (channel.unread_count ?? 0) > 0;
  const hasMentions = (channel.mention_count ?? 0) > 0;
  const isMuted = channel.muted ?? false;

  const iconInfo = CHANNEL_ICON[channel.type] ?? { ionicon: 'chatbubble-outline' as keyof typeof Ionicons.glyphMap };

  // Animated press
  const pressed = useSharedValue(0);
  const rowAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: interpolate(pressed.value, [0, 1], [1, 0.97], Extrapolation.CLAMP) }],
  }));

  const handlePress = () => {
    if (channel.type === 'voice' || channel.type === 'stage') {
      router.push(`/server/${serverId}/channel/${channel.id}/voice` as any);
    } else if (channel.type === 'forum') {
      router.push(`/server/${serverId}/channel/${channel.id}/forum` as any);
    } else {
      router.push(`/server/${serverId}/channel/${channel.id}` as any);
    }
  };

  // Determine text color based on states
  const nameColor = isActive
    ? themeColors.textPrimary
    : hasUnread && !isMuted
      ? themeColors.textPrimary
      : isMuted
        ? themeColors.textMuted
        : themeColors.textSecondary;

  const iconColor = isActive
    ? themeColors.accentPrimary
    : hasUnread && !isMuted
      ? themeColors.textSecondary
      : themeColors.textMuted;

  return (
    <Animated.View
      entering={FadeIn.duration(150)}
      style={rowAnimStyle}
    >
      <Pressable
        onPress={handlePress}
        onPressIn={() => { pressed.value = withSpring(1, SPRING_SNAPPY); }}
        onPressOut={() => { pressed.value = withSpring(0, SPRING_SNAPPY); }}
        style={[
          styles.channelRow,
          isActive && { backgroundColor: themeColors.bgTertiary },
        ]}
        accessibilityRole="button"
        accessibilityLabel={`${channel.type} channel ${channel.name}`}
      >
        {/* Active left accent bar */}
        {isActive && (
          <View style={[styles.activeBar, { backgroundColor: themeColors.accentPrimary }]} />
        )}

        {/* Channel icon / hash symbol */}
        <View style={styles.channelIconWrap}>
          {iconInfo.text ? (
            <Text style={[styles.hashSymbol, { color: iconColor }]}>{iconInfo.text}</Text>
          ) : (
            <Ionicons
              name={iconInfo.ionicon!}
              size={16}
              color={iconColor}
            />
          )}
        </View>

        <View style={styles.channelInfo}>
          <Text
            style={[
              styles.channelName,
              {
                color: nameColor,
                fontFamily: isActive || (hasUnread && !isMuted) ? 'gg-sans-semibold' : 'gg-sans',
              },
            ]}
            numberOfLines={1}
          >
            {channel.name}
          </Text>
          {channel.topic ? (
            <Text style={[styles.channelTopic, { color: themeColors.textMuted }]} numberOfLines={1}>
              {channel.topic}
            </Text>
          ) : null}
        </View>

        {/* Voice user count */}
        {(channel.type === 'voice' || channel.type === 'stage') && (channel.voice_user_count ?? 0) > 0 && (
          <View style={[styles.voiceCount, { backgroundColor: themeColors.success + '22' }]}>
            <Ionicons name="people" size={11} color={themeColors.success} />
            <Text style={[styles.voiceCountText, { color: themeColors.success }]}>
              {channel.voice_user_count}
            </Text>
          </View>
        )}

        {/* NSFW indicator */}
        {channel.nsfw && (
          <View style={[styles.nsfwPill, { backgroundColor: themeColors.danger + '22' }]}>
            <Text style={[styles.nsfwText, { color: themeColors.danger }]}>18+</Text>
          </View>
        )}

        {/* Unread dot (no mentions) */}
        {hasUnread && !hasMentions && !isMuted && !isActive && (
          <View style={[styles.unreadDot, { backgroundColor: themeColors.textPrimary }]} />
        )}

        {/* Mention badge */}
        {hasMentions && !isMuted && (
          <Animated.View entering={ENTER_POP} style={[styles.badge, { backgroundColor: themeColors.danger }]}>
            <Text style={styles.badgeText}>
              {channel.mention_count! > 99 ? '99+' : channel.mention_count}
            </Text>
          </Animated.View>
        )}

        {/* Muted icon */}
        {isMuted && (
          <Ionicons name="volume-mute" size={13} color={themeColors.textMuted} />
        )}
      </Pressable>
    </Animated.View>
  );
});

// ─── Category Section ──────────────────────────────────────────────────────────

interface CategorySection {
  categoryId: string | null;
  title: string;
  data: ChannelItem[];
}

/* ── Animated Category Header ── */
const AnimatedIonicons = Animated.createAnimatedComponent(Ionicons);

const CategoryHeader = memo(function CategoryHeader({
  section,
  isCollapsed,
  themeColors,
  toggleCategory,
  canManageChannels,
  onCreateChannel,
}: {
  section: CategorySection;
  isCollapsed: boolean;
  themeColors: any;
  toggleCategory: (id: string) => void;
  canManageChannels: boolean;
  onCreateChannel?: (categoryId?: string) => void;
}) {
  const rotation = useSharedValue(isCollapsed ? 0 : 90);

  React.useEffect(() => {
    rotation.value = withSpring(isCollapsed ? 0 : 90, SPRING_SNAPPY);
  }, [isCollapsed]);

  const chevronStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${rotation.value}deg` }],
  }));

  const pressScale = useSharedValue(1);
  const headerAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pressScale.value }],
  }));

  return (
    <AnimatedPressable
      onPressIn={() => { pressScale.value = withSpring(0.97, SPRING_SNAPPY); }}
      onPressOut={() => { pressScale.value = withSpring(1, SPRING_SNAPPY); }}
      onPress={() => toggleCategory(section.categoryId!)}
      onLongPress={() => onCreateChannel?.(section.categoryId ?? undefined)}
      style={[styles.categoryHeader, { backgroundColor: themeColors.bgPrimary }, headerAnimStyle]}
      accessibilityRole="button"
      accessibilityLabel={`${section.title} category, ${isCollapsed ? 'collapsed' : 'expanded'}`}
    >
      <Animated.View style={[styles.chevronWrap, chevronStyle]}>
        <Ionicons
          name="chevron-forward"
          size={11}
          color={themeColors.textMuted}
        />
      </Animated.View>
      <Text style={[styles.categoryTitle, { color: themeColors.textMuted }]} numberOfLines={1}>
        {section.title.toUpperCase()}
      </Text>
      {canManageChannels && (
        <Pressable
          onPress={() => onCreateChannel?.(section.categoryId ?? undefined)}
          hitSlop={8}
          style={styles.addChannelButton}
        >
          <Ionicons name="add" size={15} color={themeColors.textMuted} />
        </Pressable>
      )}
    </AnimatedPressable>
  );
});

export const ChannelList = memo(function ChannelList({
  channels,
  serverId,
  refreshing = false,
  onRefresh,
  onCreateChannel,
  canManageChannels = false,
}: ChannelListProps) {
  const { themeColors } = useTheme();
  const [collapsedCategories, setCollapsedCategories] = useState<Set<string>>(new Set());

  // Build sections: group channels by category
  const sections: CategorySection[] = React.useMemo(() => {
    const categories = channels
      .filter((c) => c.type === 'category')
      .sort((a, b) => (a.position ?? 0) - (b.position ?? 0));

    const childChannels = channels.filter((c) => c.type !== 'category');

    // Uncategorized channels (no parent_id)
    const uncategorized = childChannels
      .filter((c) => !c.parent_id)
      .sort((a, b) => (a.position ?? 0) - (b.position ?? 0));

    const result: CategorySection[] = [];

    if (uncategorized.length > 0) {
      result.push({ categoryId: null, title: '', data: uncategorized });
    }

    for (const cat of categories) {
      const children = childChannels
        .filter((c) => c.parent_id === cat.id)
        .sort((a, b) => (a.position ?? 0) - (b.position ?? 0));

      // Include category even if empty (so user knows it exists)
      result.push({ categoryId: cat.id, title: cat.name, data: children });
    }

    return result;
  }, [channels]);

  const toggleCategory = useCallback((categoryId: string) => {
    setCollapsedCategories((prev) => {
      const next = new Set(prev);
      if (next.has(categoryId)) next.delete(categoryId);
      else next.add(categoryId);
      return next;
    });
  }, []);

  const renderItem = useCallback(
    ({ item, section }: { item: ChannelItem; section: CategorySection }) => {
      if (section.categoryId && collapsedCategories.has(section.categoryId)) {
        // Don't render children of collapsed categories
        // (unless they have unread/mentions)
        const hasUnread = (item.unread_count ?? 0) > 0 || (item.mention_count ?? 0) > 0;
        if (!hasUnread) return null;
      }
      return <ChannelRow channel={item} serverId={serverId} />;
    },
    [serverId, collapsedCategories],
  );

  const renderSectionHeader = useCallback(
    ({ section }: { section: CategorySection }) => {
      // No header for uncategorized
      if (!section.categoryId) return null;

      return (
        <CategoryHeader
          section={section}
          isCollapsed={collapsedCategories.has(section.categoryId!)}
          themeColors={themeColors}
          toggleCategory={toggleCategory}
          canManageChannels={canManageChannels}
          onCreateChannel={onCreateChannel}
        />
      );
    },
    [themeColors, collapsedCategories, toggleCategory, canManageChannels, onCreateChannel],
  );

  if (channels.length === 0) {
    return (
      <EmptyState
        icon="list-outline"
        title="No channels"
        message="This server doesn't have any channels yet"
      />
    );
  }

  return (
    <SectionList
      sections={sections}
      renderItem={renderItem}
      renderSectionHeader={renderSectionHeader}
      keyExtractor={(item) => item.id}
      stickySectionHeadersEnabled
      refreshControl={
        onRefresh ? (
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={themeColors.accentPrimary}
            colors={[themeColors.accentPrimary]}
          />
        ) : undefined
      }
      contentContainerStyle={styles.listContent}
    />
  );
});

const styles = StyleSheet.create({
  listContent: {
    paddingBottom: spacing.xl,
    paddingTop: spacing.sm,
  },
  // ─── Category header ────────────────────────────────────────────
  categoryHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: spacing.sm,
    paddingRight: spacing.md,
    paddingVertical: 7,
    gap: 3,
    marginTop: 16,     // breathing room above each category
  },
  chevronWrap: {
    width: 16,
    alignItems: 'center',
  },
  categoryTitle: {
    flex: 1,
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.8,
  },
  addChannelButton: {
    width: 22,
    height: 22,
    justifyContent: 'center',
    alignItems: 'center',
  },
  // ─── Channel row ────────────────────────────────────────────────
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: spacing.md,
    paddingRight: spacing.md,
    paddingVertical: 5,
    minHeight: 34,
    marginHorizontal: spacing.sm,
    borderRadius: 6,
    overflow: 'hidden',
    position: 'relative',
  },
  activeBar: {
    position: 'absolute',
    left: 0,
    top: 6,
    bottom: 6,
    width: 3,
    borderRadius: 2,
  },
  channelIconWrap: {
    width: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hashSymbol: {
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
    lineHeight: 20,
  },
  channelInfo: {
    flex: 1,
    marginLeft: 7,
  },
  channelName: {
    fontSize: 15,
    lineHeight: 20,
  },
  channelTopic: {
    fontSize: 11,
    lineHeight: 14,
    marginTop: 1,
  },
  // ─── Badges and indicators ───────────────────────────────────────
  voiceCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: 5,
    paddingVertical: 2,
    borderRadius: 10,
    marginLeft: 4,
  },
  voiceCountText: {
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  nsfwPill: {
    paddingHorizontal: 5,
    paddingVertical: 2,
    borderRadius: 4,
    marginLeft: 4,
  },
  nsfwText: {
    fontSize: 10,
    fontFamily: 'gg-sans-bold',
  },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginLeft: 4,
  },
  badge: {
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 5,
    marginLeft: 4,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
  },
});
