/**
 * ServerList Component — Discord-style with animated rows
 *
 * Scrollable list of user's servers with pull-to-refresh.
 * Rows enter with staggered fade-up animation and have press feedback.
 * Requirements: 4.1, 4.6, 4.7, 4.9
 */
import React, { useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  RefreshControl,
  Pressable,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  FadeInDown,
} from 'react-native-reanimated';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ServerIcon } from './ServerIcon';
import { EmptyState } from '../shared/EmptyState';
import { spacing, typography, borderRadius } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { SPRING_SNAPPY, PRESS_SCALE_CARD } from '../../constants/Animations';
import type { Server } from '@shared/types';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

interface ServerListProps {
  servers: Server[];
  isLoading?: boolean;
  onRefresh?: () => void;
}

/** Animated server row with press scale and staggered entrance */
const ServerRow = React.memo(function ServerRow({
  item,
  index,
  themeColors,
  onPress,
}: {
  item: Server;
  index: number;
  themeColors: any;
  onPress: (id: string) => void;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <View>
      <AnimatedPressable
        onPressIn={() => { scale.value = withSpring(PRESS_SCALE_CARD, SPRING_SNAPPY); }}
        onPressOut={() => { scale.value = withSpring(1, SPRING_SNAPPY); }}
        onPress={() => onPress(item.id)}
        style={[styles.serverRow, animStyle]}
      >
        <ServerIcon
          name={item.name}
          iconUrl={item.icon}
          onPress={() => onPress(item.id)}
        />
        <View style={styles.serverInfo}>
          <Text
            style={[styles.serverName, { color: themeColors.textPrimary }]}
            numberOfLines={1}
          >
            {item.name}
          </Text>
          {item.description ? (
            <Text
              style={[styles.serverDesc, { color: themeColors.textSecondary }]}
              numberOfLines={1}
            >
              {item.description}
            </Text>
          ) : null}
        </View>
      </AnimatedPressable>
    </View>
  );
});

export const ServerList = React.memo<ServerListProps>(function ServerList({
  servers,
  isLoading = false,
  onRefresh,
}) {
  const { themeColors } = useTheme();

  const handleServerPress = useCallback((serverId: string) => {
    router.push(`/server/${serverId}`);
  }, []);

  const renderItem = useCallback(
    ({ item, index }: { item: Server; index: number }) => (
      <ServerRow
        item={item}
        index={index}
        themeColors={themeColors}
        onPress={handleServerPress}
      />
    ),
    [themeColors, handleServerPress],
  );

  const keyExtractor = useCallback((item: Server) => item.id, []);

  if (servers.length === 0 && !isLoading) {
    return (
      <View style={{ flex: 1 }}>
        <EmptyState
          icon="layers-outline"
          title="No servers yet"
          message="Join or create a server to start chatting with others."
          actionLabel="Create Server"
          onAction={() => {/* TODO: create server flow */}}
        />
        <DiscoveryButton themeColors={themeColors} />
      </View>
    );
  }

  return (
    <FlatList
      data={servers}
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      contentContainerStyle={styles.list}
      ListFooterComponent={<DiscoveryButton themeColors={themeColors} />}
      refreshControl={
        onRefresh ? (
          <RefreshControl
            refreshing={isLoading}
            onRefresh={onRefresh}
            tintColor={themeColors.accentPrimary}
            colors={[themeColors.accentPrimary]}
          />
        ) : undefined
      }
      showsVerticalScrollIndicator={false}
    />
  );
});

/** Compact discovery button often seen at the bottom of the server list */
const DiscoveryButton = ({ themeColors }: { themeColors: any }) => (
  <Pressable
    onPress={() => router.push('/server/discover')}
    style={({ pressed }) => [
      styles.discoveryBtn,
      { 
        backgroundColor: pressed ? themeColors.bgTertiary : themeColors.bgSecondary,
        borderColor: themeColors.border
      }
    ]}
  >
    <Ionicons name="compass-outline" size={24} color={themeColors.accentPrimary} />
    <Text style={[styles.discoveryText, { color: themeColors.textPrimary }]}>
      Discover Servers
    </Text>
  </Pressable>
);

const styles = StyleSheet.create({
  list: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  serverRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.sm,
    marginBottom: spacing.xs,
    borderRadius: borderRadius.md,
  },
  serverInfo: {
    flex: 1,
    marginLeft: spacing.md,
  },
  serverName: {
    ...typography.bodyBold,
  },
  serverDesc: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  discoveryBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: spacing.md,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    gap: spacing.sm,
  },
  discoveryText: {
    ...typography.bodyBold,
    fontSize: 15,
  },
});
