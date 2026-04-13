/**
 * Activity Picker
 *
 * Discord-style activity picker modal for voice channels.
 * Shows available activities grouped by category (Games, Watch Together, Premium)
 * with search and launch functionality.
 *
 * Requirements: Activity Picker Feature
 */
import React, { memo, useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  TextInput,
  Image,
  ActivityIndicator,
  Alert,
} from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  FadeInDown,
  ZoomIn,
  Layout,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { Modal } from '../ui/Modal';
import { useTheme } from '../../hooks/useTheme';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import {
  useActivityStore,
  type Activity,
  type ActivityCategory,
} from '@stores/activityStore';
import {
  getActivities,
  createActivitySession,
} from '@services/activityService';

interface ActivityPickerProps {
  channelId: string;
  serverId: string;
}

// ── Category Tab ──────────────────────────────────────────────────────────

const CATEGORIES: { key: ActivityCategory; label: string; icon: string }[] = [
  { key: 'games', label: 'Games', icon: 'game-controller' },
  { key: 'watch_together', label: 'Watch', icon: 'tv' },
  { key: 'premium', label: 'Premium', icon: 'diamond' },
];

const CategoryTabs = memo(function CategoryTabs({
  selected,
  onSelect,
}: {
  selected: ActivityCategory;
  onSelect: (cat: ActivityCategory) => void;
}) {
  const { themeColors } = useTheme();

  return (
    <View style={styles.categoryRow}>
      {CATEGORIES.map((cat) => {
        const isActive = selected === cat.key;
        return (
          <Pressable
            key={cat.key}
            onPress={() => onSelect(cat.key)}
            style={[
              styles.categoryTab,
              isActive && {
                backgroundColor: themeColors.accentPrimary + '20',
                borderColor: themeColors.accentPrimary,
              },
              !isActive && { borderColor: themeColors.border },
            ]}
            accessibilityRole="tab"
            accessibilityState={{ selected: isActive }}
          >
            <Ionicons
              name={cat.icon as any}
              size={18}
              color={
                isActive ? themeColors.accentPrimary : themeColors.textMuted
              }
            />
            <Text
              style={[
                styles.categoryLabel,
                {
                  color: isActive
                    ? themeColors.accentPrimary
                    : themeColors.textMuted,
                },
              ]}
            >
              {cat.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
});

// ── Activity Card ─────────────────────────────────────────────────────────

const ActivityCard = memo(function ActivityCard({
  activity,
  onLaunch,
}: {
  activity: Activity;
  onLaunch: (activity: Activity) => void;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View
      entering={FadeInDown.duration(200)}
      layout={Layout.springify()}
    >
      <Pressable
        onPress={() => onLaunch(activity)}
        style={({ pressed }) => [
          styles.activityCard,
          {
            backgroundColor: pressed
              ? themeColors.bgTertiary
              : themeColors.bgSecondary,
            borderColor: themeColors.border,
          },
        ]}
      >
        {/* Icon / Thumbnail */}
        <View
          style={[
            styles.activityIcon,
            { backgroundColor: themeColors.bgTertiary },
          ]}
        >
          {activity.iconUrl ? (
            <Image
              source={{ uri: activity.iconUrl }}
              style={styles.activityImage}
              resizeMode="cover"
            />
          ) : (
            <Ionicons
              name="game-controller"
              size={28}
              color={themeColors.accentPrimary}
            />
          )}
          {activity.isPremium && (
            <View style={[styles.premiumBadge, { backgroundColor: '#FFD700' }]}>
              <Ionicons name="diamond" size={8} color="#000" />
            </View>
          )}
        </View>

        {/* Info */}
        <View style={styles.activityInfo}>
          <Text
            style={[styles.activityName, { color: themeColors.textPrimary }]}
            numberOfLines={1}
          >
            {activity.name}
          </Text>
          <Text
            style={[
              styles.activityDescription,
              { color: themeColors.textMuted },
            ]}
            numberOfLines={2}
          >
            {activity.description}
          </Text>
          <View style={styles.activityMeta}>
            <View style={styles.metaItem}>
              <Ionicons
                name="people"
                size={12}
                color={themeColors.textMuted}
              />
              <Text
                style={[styles.metaText, { color: themeColors.textMuted }]}
              >
                Up to {activity.maxParticipants}
              </Text>
            </View>
            <View style={styles.metaItem}>
              <Ionicons
                name="time"
                size={12}
                color={themeColors.textMuted}
              />
              <Text
                style={[styles.metaText, { color: themeColors.textMuted }]}
              >
                {activity.avgDuration}
              </Text>
            </View>
          </View>
        </View>

        {/* Launch arrow */}
        <Ionicons
          name="chevron-forward"
          size={20}
          color={themeColors.textMuted}
        />
      </Pressable>
    </Animated.View>
  );
});

// ── Activity Detail Sheet ─────────────────────────────────────────────────

const ActivityDetail = memo(function ActivityDetail({
  activity,
  onLaunch,
  onBack,
  launching,
}: {
  activity: Activity;
  onLaunch: () => void;
  onBack: () => void;
  launching: boolean;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View entering={FadeIn.duration(200)} exiting={FadeOut.duration(150)}>
      {/* Back button */}
      <Pressable onPress={onBack} style={styles.backRow}>
        <Ionicons name="arrow-back" size={20} color={themeColors.textPrimary} />
        <Text style={[styles.backText, { color: themeColors.textPrimary }]}>
          Activities
        </Text>
      </Pressable>

      {/* Hero */}
      <View style={styles.detailHero}>
        <View
          style={[
            styles.detailIconLarge,
            { backgroundColor: themeColors.bgTertiary },
          ]}
        >
          {activity.iconUrl ? (
            <Image
              source={{ uri: activity.iconUrl }}
              style={styles.detailImage}
              resizeMode="cover"
            />
          ) : (
            <Ionicons
              name="game-controller"
              size={48}
              color={themeColors.accentPrimary}
            />
          )}
        </View>
        <Text
          style={[styles.detailName, { color: themeColors.textPrimary }]}
        >
          {activity.name}
        </Text>
        <Text
          style={[styles.detailDeveloper, { color: themeColors.textMuted }]}
        >
          by {activity.developer}
        </Text>
      </View>

      {/* Description */}
      <Text
        style={[styles.detailDescription, { color: themeColors.textSecondary }]}
      >
        {activity.description}
      </Text>

      {/* Stats */}
      <View style={styles.detailStats}>
        <View style={[styles.statBox, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="people" size={18} color={themeColors.accentPrimary} />
          <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>
            {activity.maxParticipants}
          </Text>
          <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>
            Max Players
          </Text>
        </View>
        <View style={[styles.statBox, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="time" size={18} color={themeColors.accentPrimary} />
          <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>
            {activity.avgDuration}
          </Text>
          <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>
            Avg Duration
          </Text>
        </View>
        <View style={[styles.statBox, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="layers" size={18} color={themeColors.accentPrimary} />
          <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>
            {activity.category === 'games'
              ? 'Game'
              : activity.category === 'watch_together'
                ? 'Watch'
                : 'Premium'}
          </Text>
          <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>
            Category
          </Text>
        </View>
      </View>

      {/* Premium notice */}
      {activity.isPremium && (
        <View
          style={[
            styles.premiumNotice,
            { backgroundColor: '#FFD700' + '15', borderColor: '#FFD700' + '30' },
          ]}
        >
          <Ionicons name="diamond" size={16} color="#FFD700" />
          <Text style={[styles.premiumText, { color: '#FFD700' }]}>
            This activity requires Flicko Premium
          </Text>
        </View>
      )}

      {/* Launch button */}
      <Pressable
        onPress={onLaunch}
        disabled={launching}
        style={[
          styles.launchBtn,
          {
            backgroundColor: launching
              ? themeColors.bgTertiary
              : themeColors.accentPrimary,
          },
        ]}
      >
        {launching ? (
          <ActivityIndicator size="small" color="#FFFFFF" />
        ) : (
          <>
            <Ionicons name="rocket" size={20} color="#FFFFFF" />
            <Text style={styles.launchText}>Start Activity</Text>
          </>
        )}
      </Pressable>
    </Animated.View>
  );
});

// ── Main Component ────────────────────────────────────────────────────────

export const ActivityPicker = memo(function ActivityPicker({
  channelId,
  serverId,
}: ActivityPickerProps) {
  const { themeColors } = useTheme();
  const store = useActivityStore();
  const [loading, setLoading] = useState(false);
  const [searchText, setSearchText] = useState('');
  const [selectedActivity, setSelectedActivity] = useState<Activity | null>(null);
  const [launching, setLaunching] = useState(false);

  // Fetch activities
  useEffect(() => {
    if (!store.pickerVisible) return;
    let cancelled = false;

    const fetchActivities = async () => {
      setLoading(true);
      try {
        const activities = await getActivities();
        if (!cancelled) store.setActivities(activities);
      } catch (err) {
        console.error('[ActivityPicker] fetch error:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    fetchActivities();
    return () => { cancelled = true; };
  }, [store.pickerVisible]);

  // Filter activities
  const filteredActivities = useMemo(() => {
    let items = store.activities.filter(
      (a) => a.category === store.selectedCategory,
    );

    if (searchText.trim()) {
      const q = searchText.toLowerCase();
      items = items.filter(
        (a) =>
          a.name.toLowerCase().includes(q) ||
          a.description.toLowerCase().includes(q),
      );
    }

    return items;
  }, [store.activities, store.selectedCategory, searchText]);

  const handleLaunch = useCallback(
    async (activity: Activity) => {
      if (activity.isPremium) {
        Alert.alert(
          'Premium Required',
          'This activity requires Flicko Premium. Upgrade to access all activities!',
          [{ text: 'OK' }],
        );
        return;
      }
      setSelectedActivity(activity);
    },
    [],
  );

  const handleConfirmLaunch = useCallback(async () => {
    if (!selectedActivity) return;

    setLaunching(true);
    try {
      const session = await createActivitySession({
        activityId: selectedActivity.id,
        channelId,
        serverId,
      });
      store.launchActivity(session);
    } catch (err: any) {
      Alert.alert('Launch Failed', err.message || 'Could not start activity');
    } finally {
      setLaunching(false);
    }
  }, [selectedActivity, channelId, serverId, store]);

  const renderActivity = useCallback(
    ({ item }: { item: Activity }) => (
      <ActivityCard activity={item} onLaunch={handleLaunch} />
    ),
    [handleLaunch],
  );

  return (
    <Modal
      visible={store.pickerVisible}
      onClose={() => {
        setSelectedActivity(null);
        store.closePicker();
      }}
      title={selectedActivity ? selectedActivity.name : 'Activities'}
    >
      <View style={styles.pickerBody}>
      {selectedActivity ? (
        <ActivityDetail
          activity={selectedActivity}
          onLaunch={handleConfirmLaunch}
          onBack={() => setSelectedActivity(null)}
          launching={launching}
        />
      ) : (
        <>
          {/* Search */}
          <View
            style={[styles.searchBox, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Ionicons name="search" size={16} color={themeColors.textMuted} />
            <TextInput
              style={[styles.searchInput, { color: themeColors.textPrimary }]}
              placeholder="Search activities..."
              placeholderTextColor={themeColors.textMuted}
              value={searchText}
              onChangeText={setSearchText}
              returnKeyType="search"
            />
            {searchText.length > 0 && (
              <Pressable onPress={() => setSearchText('')} hitSlop={8}>
                <Ionicons
                  name="close-circle"
                  size={16}
                  color={themeColors.textMuted}
                />
              </Pressable>
            )}
          </View>

          {/* Category tabs */}
          <CategoryTabs
            selected={store.selectedCategory}
            onSelect={store.setCategory}
          />

          {/* Activity list */}
          {loading ? (
            <View style={styles.center}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : filteredActivities.length === 0 ? (
            <View style={styles.center}>
              <Ionicons
                name="game-controller-outline"
                size={40}
                color={themeColors.textMuted}
              />
              <Text
                style={[styles.emptyText, { color: themeColors.textMuted }]}
              >
                {searchText.trim()
                  ? 'No activities match your search'
                  : 'No activities in this category. Apply Supabase migration 098_seed_builtin_activities.sql to add defaults.'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={filteredActivities}
              renderItem={renderActivity}
              keyExtractor={(item) => item.id}
              contentContainerStyle={styles.activityList}
              showsVerticalScrollIndicator
              style={styles.listContainer}
            />
          )}
        </>
      )}
      </View>
    </Modal>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  pickerBody: {
    flex: 1,
    minHeight: 280,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    borderRadius: borderRadius.md,
    height: 36,
    gap: spacing.xs,
    marginBottom: spacing.md,
  },
  searchInput: {
    flex: 1,
    ...typography.bodySmall,
    paddingVertical: 0,
  },
  categoryRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  categoryTab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    borderWidth: 1,
  },
  categoryLabel: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  listContainer: {
    flex: 1,
    minHeight: 200,
  },
  activityList: {
    gap: spacing.sm,
    paddingBottom: spacing.md,
  },
  activityCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    gap: spacing.md,
  },
  activityIcon: {
    width: 56,
    height: 56,
    borderRadius: borderRadius.lg,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
  activityImage: {
    width: '100%',
    height: '100%',
  },
  premiumBadge: {
    position: 'absolute',
    top: 2,
    right: 2,
    width: 14,
    height: 14,
    borderRadius: 7,
    alignItems: 'center',
    justifyContent: 'center',
  },
  activityInfo: {
    flex: 1,
  },
  activityName: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
    marginBottom: 2,
  },
  activityDescription: {
    ...typography.caption,
    marginBottom: spacing.xs,
  },
  activityMeta: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  metaText: {
    ...typography.micro,
  },
  center: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.xxxl,
    gap: spacing.sm,
  },
  emptyText: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  // Detail view
  backRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.lg,
  },
  backText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  detailHero: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  detailIconLarge: {
    width: 96,
    height: 96,
    borderRadius: borderRadius.xl,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    marginBottom: spacing.md,
  },
  detailImage: {
    width: '100%',
    height: '100%',
  },
  detailName: {
    ...typography.headingL,
    textAlign: 'center',
  },
  detailDeveloper: {
    ...typography.caption,
    textAlign: 'center',
    marginTop: spacing.xs,
  },
  detailDescription: {
    ...typography.bodySmall,
    textAlign: 'center',
    marginBottom: spacing.xl,
  },
  detailStats: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.xl,
  },
  statBox: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    gap: spacing.xs,
  },
  statValue: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-bold',
  },
  statLabel: {
    ...typography.micro,
  },
  premiumNotice: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    marginBottom: spacing.lg,
  },
  premiumText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
    flex: 1,
  },
  launchBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.lg,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  launchText: {
    color: '#FFFFFF',
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
});
