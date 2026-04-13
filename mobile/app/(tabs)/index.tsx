/**
 * Servers Tab — Discord Mobile Style
 *
 * Shows a vertical list of server icons (left rail) with the main content
 * area showing the selected server's channels or the home/DMs view.
 * This matches Discord's mobile Servers tab exactly.
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
} from 'react-native';
import { Image } from 'expo-image';
import Animated, {
  FadeIn,
} from 'react-native-reanimated';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { LoadingSpinner } from '../../components/shared/LoadingSpinner';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import type { Server } from '@shared/types';

type SidebarView = 'home' | 'dms' | string; // string = serverId

const SERVER_ICON_SIZE = 48;
const ACTIVE_INDICATOR_HEIGHT = 36;

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  // Unified selection: 'home' | 'dms' | serverId
  const [activeView, setActiveView] = useState<SidebarView>('home');

  const selectedServerId = activeView !== 'home' && activeView !== 'dms' ? activeView : null;

  const { data: servers = [], isLoading, refetch } = useQuery<Server[]>({
    queryKey: ['servers'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('server_members')
        .select('server:servers(*)')
        .eq('user_id', user?.id ?? '');
      if (error) throw error;

      return (data ?? [])
        .map((row) => {
          const membership = row as unknown as { server: Server | Server[] | null };
          return Array.isArray(membership.server)
            ? membership.server[0]
            : membership.server;
        })
        .filter((server): server is Server => Boolean(server));
    },
    enabled: !!user?.id,
  });

  const { data: channels = [] } = useQuery({
    queryKey: ['channels', selectedServerId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channels')
        .select('*')
        .eq('server_id', selectedServerId!)
        .order('position', { ascending: true });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!selectedServerId,
  });

  const selectedServer = servers.find((s) => s.id === selectedServerId);
  const isOwner = !!(selectedServer && user && selectedServer.owner_id === user.id);

  // Navigate to server options: settings page for owners, member-options page for members.
  const handleServerOptions = useCallback(() => {
    if (!selectedServerId) return;
    if (isOwner) {
      router.push(`/server/${selectedServerId}/settings` as any);
    } else {
      router.push(`/server/${selectedServerId}/server-options` as any);
    }
  }, [selectedServerId, isOwner]);

  const renderServerIcon = useCallback(
    (server: Server) => {
      const isActive = activeView === server.id;
      return (
        <Pressable
          key={server.id}
          onPress={() => setActiveView(server.id)}
          onLongPress={() => router.push(`/server/${server.id}`)}
          accessibilityLabel={`Server: ${server.name}`}
          accessibilityRole="button"
          style={styles.serverIconWrapper}
        >
          {/* Active pill indicator */}
          <View
            style={[
              styles.activePill,
              {
                backgroundColor: '#FFFFFF',
                height: isActive ? ACTIVE_INDICATOR_HEIGHT : 0,
                opacity: isActive ? 1 : 0,
              },
            ]}
          />
          <View
            style={[
              styles.serverIcon,
              {
                backgroundColor: isActive
                  ? themeColors.accentPrimary
                  : themeColors.bgSecondary,
                borderRadius: isActive ? 16 : SERVER_ICON_SIZE / 2,
              },
            ]}
          >
            {server.icon ? (
              <Image
                source={{ uri: server.icon }}
                style={[
                  styles.serverImage,
                  { borderRadius: isActive ? 16 : SERVER_ICON_SIZE / 2 },
                ]}
                contentFit="cover"
                transition={200}
                cachePolicy="disk"
                autoplay={true}
              />
            ) : (
              <Text
                style={[
                  styles.serverInitial,
                  { color: isActive ? '#FFFFFF' : themeColors.textPrimary },
                ]}
              >
                {server.name
                  .split(/\s+/)
                  .map((w) => w[0])
                  .join('')
                  .slice(0, 2)
                  .toUpperCase()}
              </Text>
            )}
          </View>
        </Pressable>
      );
    },
    [activeView, themeColors],
  );

  const handleChannelPress = useCallback(
    (channelId: string, channelType: string) => {
      if (channelType === 'voice' || channelType === 'stage') {
        router.push(`/server/${selectedServerId}/channel/${channelId}/voice` as any);
      } else {
        router.push(`/server/${selectedServerId}/channel/${channelId}` as any);
      }
    },
    [selectedServerId],
  );

  if (isLoading) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgTertiary }]}>
        <LoadingSpinner fullScreen message="Loading servers..." />
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgTertiary }]}>
      {/* Left Server Rail */}
      <View style={[styles.serverRail, { paddingTop: insets.top + 8 }]}>
        {/* Home button */}
        <Pressable
          onPress={() => setActiveView('home')}
          style={styles.serverIconWrapper}
          accessibilityLabel="Home"
          accessibilityRole="button"
        >
          <View
            style={[
              styles.activePill,
              {
                backgroundColor: '#FFFFFF',
                height: activeView === 'home' ? ACTIVE_INDICATOR_HEIGHT : 0,
                opacity: activeView === 'home' ? 1 : 0,
              },
            ]}
          />
          <View
            style={[
              styles.serverIcon,
              {
                backgroundColor:
                  activeView === 'home'
                    ? themeColors.accentPrimary
                    : themeColors.bgSecondary,
                borderRadius: activeView === 'home' ? 16 : SERVER_ICON_SIZE / 2,
              },
            ]}
          >
            <Ionicons
              name="home"
              size={24}
              color={activeView === 'home' ? '#FFFFFF' : themeColors.textPrimary}
            />
          </View>
        </Pressable>

        {/* Messages / DMs button — navigates directly to DMs tab */}
        <Pressable
          onPress={() => router.push('/(tabs)/dms')}
          style={styles.serverIconWrapper}
          accessibilityLabel="Messages"
          accessibilityRole="button"
        >
          <View style={[styles.activePill, { opacity: 0 }]} />
          <View
            style={[
              styles.serverIcon,
              {
                backgroundColor: themeColors.bgSecondary,
                borderRadius: SERVER_ICON_SIZE / 2,
              },
            ]}
          >
            <Ionicons
              name="chatbubble-ellipses"
              size={22}
              color={themeColors.textPrimary}
            />
          </View>
        </Pressable>

        {/* Divider */}
        <View style={[styles.railDivider, { backgroundColor: themeColors.border }]} />

        {/* Server icons */}
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 80 }}
        >
          {servers.map(renderServerIcon)}

          {/* Add server button */}
          <Pressable
            onPress={() => router.push('/server/create')}
            style={styles.serverIconWrapper}
            accessibilityLabel="Add a Server"
            accessibilityRole="button"
          >
            <View style={[styles.activePill, { opacity: 0 }]} />
            <View
              style={[
                styles.serverIcon,
                {
                  backgroundColor: themeColors.bgSecondary,
                  borderRadius: SERVER_ICON_SIZE / 2,
                },
              ]}
            >
              <Ionicons name="add" size={24} color={themeColors.success} />
            </View>
          </Pressable>

          {/* Discover button */}
          <Pressable
            onPress={() => router.push('/server/discover')}
            style={styles.serverIconWrapper}
            accessibilityLabel="Explore Servers"
            accessibilityRole="button"
          >
            <View style={[styles.activePill, { opacity: 0 }]} />
            <View
              style={[
                styles.serverIcon,
                {
                  backgroundColor: themeColors.bgSecondary,
                  borderRadius: SERVER_ICON_SIZE / 2,
                },
              ]}
            >
              <Ionicons name="compass" size={24} color={themeColors.success} />
            </View>
          </Pressable>
        </ScrollView>
      </View>

      <View style={[styles.mainContent, { backgroundColor: themeColors.bgSecondary }]}>
        {selectedServerId === null ? (
          /* Home View — quick access grid */
          <>
            <View
              style={[
                styles.header,
                { paddingTop: insets.top + 8, backgroundColor: themeColors.bgSecondary },
              ]}
            >
              <Pressable
                onPress={() => router.push('/search')}
                hitSlop={8}
                style={[styles.headerBtn, { marginRight: 'auto' }]}
              >
                <Ionicons name="search" size={22} color={themeColors.textSecondary} />
              </Pressable>
              
              <View style={styles.headerActions}>
                {/* Empty right actions */}
              </View>
            </View>

            <ScrollView
              contentContainerStyle={{
                paddingHorizontal: spacing.md,
                paddingBottom: insets.bottom + 80,
                paddingTop: spacing.sm,
              }}
            >
              {/* Quick action cards */}
              <Pressable
                style={({ pressed }) => [
                  styles.quickRow,
                  {
                    backgroundColor: pressed
                      ? themeColors.bgTertiary
                      : themeColors.bgPrimary,
                  },
                ]}
                onPress={() => router.push('/(tabs)/dms')}
              >
                <View style={[styles.quickIcon, { backgroundColor: themeColors.accentPrimary }]}>
                  <Ionicons name="chatbubble" size={20} color="#fff" />
                </View>
                <Text style={[styles.quickLabel, { color: themeColors.textPrimary }]}>
                  Direct Messages
                </Text>
                <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
              </Pressable>

              <Pressable
                style={({ pressed }) => [
                  styles.quickRow,
                  {
                    backgroundColor: pressed
                      ? themeColors.bgTertiary
                      : themeColors.bgPrimary,
                  },
                ]}
                onPress={() => router.push('/(tabs)/friends')}
              >
                <View style={[styles.quickIcon, { backgroundColor: themeColors.success }]}>
                  <Ionicons name="people" size={20} color="#fff" />
                </View>
                <Text style={[styles.quickLabel, { color: themeColors.textPrimary }]}>
                  Friends
                </Text>
                <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
              </Pressable>

              <Pressable
                style={({ pressed }) => [
                  styles.quickRow,
                  {
                    backgroundColor: pressed
                      ? themeColors.bgTertiary
                      : themeColors.bgPrimary,
                  },
                ]}
                onPress={() => router.push('/notifications')}
              >
                <View style={[styles.quickIcon, { backgroundColor: themeColors.warning }]}>
                  <Ionicons name="notifications" size={20} color="#fff" />
                </View>
                <Text style={[styles.quickLabel, { color: themeColors.textPrimary }]}>
                  Notifications
                </Text>
                <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
              </Pressable>

              {/* Your Servers heading */}
              {servers.length > 0 && (
                <>
                  <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
                    YOUR SERVERS
                  </Text>
                  {servers.map((server) => (
                    <Pressable
                      key={server.id}
                      style={({ pressed }) => [
                        styles.serverRow,
                        {
                          backgroundColor: pressed
                            ? themeColors.bgTertiary
                            : themeColors.bgPrimary,
                        },
                      ]}
                      onPress={() => router.push(`/server/${server.id}`)}
                    >
                      {server.icon ? (
                        <Image
                          source={{ uri: server.icon }}
                          style={styles.serverRowImage}
                          contentFit="cover"
                          transition={200}
                          cachePolicy="disk"
                          autoplay={true}
                        />
                      ) : (
                        <View
                          style={[
                            styles.serverRowPlaceholder,
                            { backgroundColor: themeColors.accentPrimary },
                          ]}
                        >
                          <Text style={styles.serverRowInitial}>
                            {server.name.charAt(0).toUpperCase()}
                          </Text>
                        </View>
                      )}
                      <View style={styles.serverRowInfo}>
                        <Text
                          style={[styles.serverRowName, { color: themeColors.textPrimary }]}
                          numberOfLines={1}
                        >
                          {server.name}
                        </Text>
                        {server.description ? (
                          <Text
                            style={[styles.serverRowDesc, { color: themeColors.textMuted }]}
                            numberOfLines={1}
                          >
                            {server.description}
                          </Text>
                        ) : null}
                      </View>
                      <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
                    </Pressable>
                  ))}
                </>
              )}
            </ScrollView>
          </>
        ) : (
          /* Server Channel List View */
          <>
            <View
              style={[
                styles.header,
                { paddingTop: insets.top + 8, backgroundColor: themeColors.bgSecondary },
              ]}
            >
              <View style={styles.headerInfo}>
                <Text
                  style={[styles.headerTitle, { color: themeColors.textPrimary }]}
                  numberOfLines={1}
                >
                  {selectedServer?.name || 'Server'}
                </Text>
              </View>
              <View style={styles.headerActions}>
                <Pressable
                  onPress={() => router.push(`/server/${selectedServerId}/members` as any)}
                  hitSlop={8}
                  style={styles.headerBtn}
                  accessibilityLabel="View members"
                >
                  <Ionicons name="people" size={22} color={themeColors.textSecondary} />
                </Pressable>
                <Pressable
                  onPress={handleServerOptions}
                  hitSlop={8}
                  style={styles.headerBtn}
                  accessibilityLabel="Server options"
                >
                  <Ionicons
                    name="ellipsis-vertical"
                    size={20}
                    color={themeColors.textSecondary}
                  />
                </Pressable>
              </View>
            </View>

            <ScrollView contentContainerStyle={{ paddingBottom: insets.bottom + 80 }}>
              {/* Server Banner */}
              {selectedServer?.banner && (
                <Animated.View entering={FadeIn.duration(400)}>
                  <Image
                    source={{ uri: selectedServer.banner }}
                    style={styles.serverBanner}
                    contentFit="cover"
                    transition={300}
                    autoplay={true}
                    cachePolicy="disk"
                  />
                </Animated.View>
              )}
              {channels.map((channel: any) => {
                if (channel.type === 'category') {
                  return (
                    <View key={channel.id} style={styles.categoryHeader}>
                      <Ionicons name="chevron-down" size={10} color={themeColors.textMuted} />
                      <Text style={[styles.categoryName, { color: themeColors.textMuted }]}>
                        {channel.name.toUpperCase()}
                      </Text>
                    </View>
                  );
                }
                return (
                  <Pressable
                    key={channel.id}
                    onPress={() => handleChannelPress(channel.id, channel.type)}
                    style={({ pressed }) => [
                      styles.channelRow,
                      pressed && { backgroundColor: themeColors.bgTertiary },
                    ]}
                  >
                    <Ionicons
                      name={
                        channel.type === 'voice'
                          ? 'volume-medium'
                          : channel.type === 'announcement'
                            ? 'megaphone-outline'
                            : channel.type === 'forum'
                              ? 'newspaper-outline'
                              : 'chatbubble-outline'
                      }
                      size={18}
                      color={themeColors.textMuted}
                      style={{ width: 22 }}
                    />
                    <Text
                      style={[styles.channelName, { color: themeColors.textSecondary }]}
                      numberOfLines={1}
                    >
                      {channel.name}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          </>
        )}

      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'row',
  },
  /* Server Rail — left sidebar */
  serverRail: {
    width: 72,
    alignItems: 'center',
  },
  serverIconWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    width: 72,
  },
  activePill: {
    width: 4,
    borderTopRightRadius: 4,
    borderBottomRightRadius: 4,
    marginRight: 8,
  },
  serverIcon: {
    width: SERVER_ICON_SIZE,
    height: SERVER_ICON_SIZE,
    alignItems: 'center',
    justifyContent: 'center',
    // NOTE: No overflow:hidden here — it blocks GIF / animated-WebP frame
    // rendering on Android. Border-radius is applied to the Image directly.
  },
  serverImage: {
    width: SERVER_ICON_SIZE,
    height: SERVER_ICON_SIZE,
  },
  serverInitial: {
    fontSize: 18,
    fontFamily: 'gg-sans-semibold',
  },
  railDivider: {
    width: 32,
    height: 2,
    borderRadius: 1,
    marginVertical: 4,
    alignSelf: 'center',
  },
  /* Main content */
  mainContent: {
    flex: 1,
    borderTopLeftRadius: 12,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
  },
  headerInfo: {
    flex: 1,
  },
  headerTitle: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
  },
  headerActions: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  headerBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  /* Quick action rows — Discord home style */
  quickRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: 18,
    marginBottom: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  quickIcon: {
    width: 36,
    height: 36,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  quickLabel: {
    flex: 1,
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
  },
  /* Section titles */
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.24,
    textTransform: 'uppercase',
    marginTop: spacing.xl,
    marginBottom: spacing.sm,
    marginLeft: spacing.xs,
  },
  /* Server rows */
  serverRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: 18,
    marginBottom: spacing.xs,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  serverRowImage: {
    width: 40,
    height: 40,
    borderRadius: 12,
  },
  serverRowPlaceholder: {
    width: 40,
    height: 40,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  serverRowInitial: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
    color: '#FFFFFF',
  },
  serverRowInfo: {
    flex: 1,
    marginLeft: spacing.md,
    minWidth: 0,
  },
  serverRowName: {
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
  },
  serverRowDesc: {
    fontSize: 13,
    marginTop: 2,
  },
  /* Channel list inside server view */
  categoryHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: 4,
    gap: 4,
  },
  categoryName: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.24,
  },
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 6,
    marginHorizontal: spacing.sm,
    borderRadius: 4,
    minHeight: 34,
  },
  channelName: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
    marginLeft: spacing.sm,
    flex: 1,
  },
  serverBanner: {
    width: '100%',
    height: 120,
    borderRadius: 0,
  },
});
