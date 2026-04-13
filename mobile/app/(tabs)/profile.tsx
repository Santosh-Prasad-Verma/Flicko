/**
 * You Tab — Discord Mobile Style Profile
 * Shows current user's profile with Discord-style card layout
 */
import React, { useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../../components/ui/Avatar';
import { spacing, borderRadius } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import { supabase } from '../../services/supabase';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const flickoIcon = require('../../assets/splash_icon.png');

// Badge type
interface Badge {
  id: string;
  name: string;
  icon: keyof typeof Ionicons.glyphMap;
  color: string;
}

// Role type
interface Role {
  id: string;
  name: string;
  color: string;
}

// Spotify activity
interface SpotifyActivity {
  track: string;
  artist: string;
  album: string;
  albumArt?: string;
  progress: number;
  duration: number;
}

const STATUS_COLORS: Record<string, string> = {
  online: '#23A559',
  idle: '#F0B232',
  dnd: '#ED4245',
  offline: '#80848E',
};

export default function ProfileScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const setUser = useAuthStore((s: any) => s.setUser);

  // Fetch full profile
  const { data: profile, refetch } = useQuery({
    queryKey: ['profile', user?.id],
    queryFn: async () => {
      const { data, error} = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user!.id)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!user?.id,
    staleTime: 30000,
    gcTime: 300000,
    refetchOnMount: true,
  });

  // Sync profile back into auth store
  useEffect(() => {
    if (profile && user) {
      const updatedUser = {
        ...user,
        display_name: profile.display_name ?? user.display_name,
        avatar: profile.avatar ?? user.avatar,
        banner: profile.banner ?? user.banner,
        bio: profile.bio ?? user.bio,
        pronouns: profile.pronouns ?? user.pronouns,
      };
      
      // Only update if something actually changed
      if (JSON.stringify(updatedUser) !== JSON.stringify(user)) {
        setUser(updatedUser);
      }
    }
  }, [profile, user?.id]); // Only depend on profile and user.id, not full user object

  const username = user?.username || 'User';
  const displayName = profile?.display_name || user?.display_name || username;
  const discriminator = profile?.discriminator || user?.discriminator || null;
  const avatarUrl = profile?.avatar || user?.avatar;
  const bannerUrl = profile?.banner || user?.banner;
  const bio = profile?.bio || user?.bio;
  const createdAt = profile?.created_at || user?.created_at;

  const memberSince = createdAt
    ? new Date(createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
    : null;

  const rawStatus = profile?.online_status as string | undefined;
  const onlineStatus =
    rawStatus === 'online' || rawStatus === 'idle' || rawStatus === 'dnd' || rawStatus === 'offline'
      ? rawStatus
      : 'offline';

  // Mock data for UI display (replace with real data later)
  const badges: Badge[] = useMemo(() => [
    { id: '1', name: 'HypeSquad', icon: 'shield', color: '#9B84EE' },
    { id: '2', name: 'Nitro', icon: 'flash', color: '#F47FFF' },
    { id: '3', name: 'Active Developer', icon: 'code-slash', color: '#23A559' },
    { id: '4', name: 'Server Booster', icon: 'rocket', color: '#FF73FA' },
    { id: '5', name: 'Early Supporter', icon: 'heart', color: '#FF73FA' },
  ], []);

  const roles: Role[] = useMemo(() => [
    { id: '1', name: 'Role', color: '#99AAB5' },
    { id: '2', name: 'Role', color: '#99AAB5' },
    { id: '3', name: 'Role', color: '#99AAB5' },
    { id: '4', name: 'Role', color: '#99AAB5' },
  ], []);

  const spotifyActivity: SpotifyActivity | null = useMemo(() => ({
    track: 'Song',
    artist: 'Artist',
    album: 'Album',
    albumArt: undefined,
    progress: 42,
    duration: 260,
  }), []);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // If no user is logged in, show message
  if (!user) {
    return (
      <View style={[styles.container, { backgroundColor: '#36393F', justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={{ color: '#FFFFFF', fontSize: 16 }}>Please log in to view your profile</Text>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: '#36393F' }]}>
      {/* Header */}
      <View style={[styles.topBar, { paddingTop: insets.top + 4, backgroundColor: '#36393F' }]}>
        <Pressable
          onPress={() => router.push('/search' as any)}
          hitSlop={12}
          style={[{ marginRight: 'auto', padding: spacing.xs, marginLeft: spacing.sm }]}
        >
          <Ionicons name="search" size={24} color="#FFFFFF" />
        </Pressable>
        <View style={styles.topBarRight}>
          <Pressable onPress={() => router.push('/flicko-plus' as any)} hitSlop={12} style={styles.plusBtn}>
            <LinearGradient
              colors={['#5865F2', '#EB459E']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.plusBtnGradient}
            >
              <Ionicons name="diamond" size={16} color="#fff" />
            </LinearGradient>
          </Pressable>
          <Pressable onPress={() => { refetch(); router.push('/settings'); }} hitSlop={12} style={styles.gearBtn}>
            <Ionicons name="settings-sharp" size={22} color="#B5BAC1" />
          </Pressable>
        </View>
      </View>

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xl, padding: spacing.md }}
        showsVerticalScrollIndicator={false}
      >
        {/* Single unified profile card */}
        <View style={styles.profileCard}>
          {/* Banner */}
          <View style={styles.bannerContainer}>
            {bannerUrl ? (
              <Image
                source={{ uri: bannerUrl }}
                style={styles.bannerImage}
                contentFit="cover"
                autoplay={true}
              />
            ) : (
              <View style={[styles.bannerImage, { backgroundColor: '#000000' }]} />
            )}
          </View>

          {/* Avatar and badges row */}
          <View style={styles.avatarBadgeRow}>
            {/* Avatar with status */}
            <View style={styles.avatarContainer}>
              <View style={[styles.avatarWrapper, { borderColor: '#2B2D31' }]}>
                <Avatar
                  name={displayName}
                  imageUrl={avatarUrl ?? undefined}
                  size={80}
                />
                <View style={[styles.statusIndicator, { backgroundColor: STATUS_COLORS[onlineStatus] }]} />
              </View>
            </View>

            {/* Badges aligned to right */}
            <View style={styles.badgesRow}>
              {badges.slice(0, 5).map((badge) => (
                <Pressable key={badge.id} style={styles.badgeIcon}>
                  <Ionicons
                    name={badge.icon}
                    size={20}
                    color={badge.color}
                  />
                </Pressable>
              ))}
            </View>
          </View>

          {/* Content area */}
          <View style={styles.contentArea}>
            {/* Username with discriminator */}
            <View style={styles.nameRow}>
              <Text style={styles.displayName}>{displayName}</Text>
              {discriminator && (
                <Text style={styles.discriminator}>#{discriminator}</Text>
              )}
            </View>

            {/* Member Since */}
            {memberSince && (
              <View style={styles.memberSinceRow}>
                <Image source={flickoIcon} style={styles.memberSinceIcon} contentFit="contain" />
                <Text style={[styles.memberSince, { color: '#B5BAC1' }]}>
                  Member since {memberSince}
                </Text>
              </View>
            )}
            <Pressable
              onPress={() => router.push('/settings/status' as any)}
              style={styles.setStatusRow}
              hitSlop={8}
            >
              <Ionicons name="ellipse" size={10} color={STATUS_COLORS[onlineStatus] || '#80848E'} />
              <Text style={styles.setStatusText}>Set status</Text>
              <Ionicons name="chevron-forward" size={14} color="#6D6F78" />
            </Pressable>

            {/* Divider */}
            <View style={[styles.divider, { backgroundColor: '#1E1F22' }]} />

            {/* About Me Section */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>ABOUT ME</Text>
              <Text style={styles.sectionContent}>
                {bio || 'graphic/ui designer'}
              </Text>
              {profile?.website && (
                <Text style={styles.linkText}>{profile.website}</Text>
              )}
            </View>

            {/* Spotify Activity Section - Placeholder */}
            {/*
            <View style={styles.section}>
              <View style={styles.spotifyHeader}>
                <Text style={styles.sectionTitle}>LISTENING TO SPOTIFY</Text>
                <View style={styles.spotifyIconCircle}>
                  <Ionicons name="musical-notes" size={18} color="#1DB954" />
                </View>
              </View>

              <View style={styles.spotifyContent}>
                <View style={[styles.albumArt, { backgroundColor: '#4E5058' }]}>
                  {spotifyActivity.albumArt ? (
                    <Image
                      source={{ uri: spotifyActivity.albumArt }}
                      style={styles.albumArtImage}
                      contentFit="cover"
                    />
                  ) : (
                    <Ionicons name="musical-notes" size={24} color="#B5BAC1" />
                  )}
                </View>

                <View style={styles.trackInfo}>
                  <Text style={styles.trackName}>{spotifyActivity.track}</Text>
                  <Text style={styles.artistName}>{spotifyActivity.artist}</Text>
                  <Text style={styles.albumName}>{spotifyActivity.album}</Text>
                </View>
              </View>

              <View style={styles.progressContainer}>
                <View style={[styles.progressBar, { backgroundColor: '#4E5058' }]}>
                  <View
                    style={[
                      styles.progressFill,
                      {
                        backgroundColor: '#B5BAC1',
                        width: `${(spotifyActivity.progress / spotifyActivity.duration) * 100}%`,
                      },
                    ]}
                  />
                </View>
                <View style={styles.progressTimes}>
                  <Text style={styles.timeText}>{formatTime(spotifyActivity.progress)}</Text>
                  <Text style={styles.timeText}>{formatTime(spotifyActivity.duration)}</Text>
                </View>
              </View>

              <View style={styles.spotifyActions}>
                <Pressable style={[styles.spotifyButton, { backgroundColor: '#4E5058' }]}>
                  <Ionicons name="musical-notes" size={14} color="#FFFFFF" />
                  <Text style={styles.spotifyButtonText}>Play on Spotify</Text>
                </Pressable>
                <Pressable style={[styles.spotifyIconButton, { backgroundColor: '#4E5058' }]}>
                  <Ionicons name="people" size={16} color="#B5BAC1" />
                </Pressable>
              </View>
            </View>
            */}

            {/* Roles Section - Placeholder */}
            {/*
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>ROLES</Text>
              <View style={styles.rolesContainer}>
                {roles.map((role) => (
                  <View key={role.id} style={[styles.roleChip, { backgroundColor: '#1E1F22' }]}>
                    <View style={[styles.roleDot, { backgroundColor: role.color }]} />
                    <Text style={styles.roleText}>{role.name}</Text>
                  </View>
                ))}
                <Pressable style={[styles.addRoleButton, { backgroundColor: '#1E1F22' }]}>
                  <Ionicons name="add" size={14} color="#B5BAC1" />
                </Pressable>
              </View>
            </View>
            */}
          </View>
        </View>

        {/* Action Buttons below card */}
        <View style={styles.actionButtons}>
          <Pressable
            style={[styles.actionBtn, { backgroundColor: '#2B2D31' }]}
            onPress={() => router.push('/settings/edit-profile')}
          >
            <Ionicons name="pencil" size={18} color="#FFFFFF" />
            <Text style={[styles.actionBtnText, { color: '#FFFFFF' }]}>Edit Profile</Text>
          </Pressable>

          <Pressable
            style={[styles.actionBtn, { backgroundColor: '#2B2D31' }]}
            onPress={() => router.push('/(tabs)/friends' as any)}
          >
            <Ionicons name="people" size={18} color="#FFFFFF" />
            <Text style={[styles.actionBtnText, { color: '#FFFFFF' }]}>Friends</Text>
          </Pressable>
        </View>

        <Text style={[styles.version, { color: '#80848E' }]}>Flicko v1.0.0</Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.sm,
  },
  topBarTitle: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
  },
  topBarRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  plusBtn: {
    borderRadius: 16,
    overflow: 'hidden',
  },
  plusBtnGradient: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  gearBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Single unified profile card
  profileCard: {
    backgroundColor: '#2B2D31',
    borderRadius: 16,
    overflow: 'hidden',
    maxWidth: 480,
    alignSelf: 'center',
    width: '100%',
  },

  // Banner
  bannerContainer: {
    height: 100,
    overflow: 'hidden',
  },
  bannerImage: {
    width: '100%',
    height: '100%',
  },

  // Avatar and badges row
  avatarBadgeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    paddingHorizontal: spacing.md,
    marginTop: -50,
    marginBottom: spacing.xs,
  },
  avatarContainer: {
    position: 'relative',
  },
  avatarWrapper: {
    borderWidth: 6,
    borderRadius: 46,
    backgroundColor: '#2B2D31',
  },
  statusIndicator: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 4,
    borderColor: '#2B2D31',
  },

  // Badges
  badgesRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 56,
  },
  badgeIcon: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Content area
  contentArea: {
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
  },

  // Name
  nameRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: spacing.sm,
  },
  displayName: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
    color: '#FFFFFF',
  },
  discriminator: {
    fontSize: 20,
    fontFamily: 'gg-sans',
    color: '#B5BAC1',
  },
  memberSinceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: spacing.xs,
  },
  memberSinceIcon: {
    width: 18,
    height: 18,
  },
  memberSince: {
    fontSize: 13,
    fontFamily: 'gg-sans',
    color: '#B5BAC1',
  },
  setStatusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: spacing.xs,
    marginBottom: spacing.sm,
    paddingVertical: 6,
  },
  setStatusText: {
    flex: 1,
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    color: '#DBDEE1',
  },

  // Divider
  divider: {
    height: 1,
    marginVertical: spacing.md,
  },

  // Sections
  section: {
    marginTop: spacing.md,
  },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    color: '#B5BAC1',
    letterSpacing: 0.5,
    marginBottom: spacing.xs,
    textTransform: 'uppercase',
  },
  sectionContent: {
    fontSize: 14,
    fontFamily: 'gg-sans',
    color: '#DBDEE1',
    lineHeight: 18,
  },
  linkText: {
    fontSize: 14,
    fontFamily: 'gg-sans',
    color: '#00A8FC',
    marginTop: 4,
  },

  // Spotify
  spotifyHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  spotifyIconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#1DB954',
    alignItems: 'center',
    justifyContent: 'center',
  },
  spotifyContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.sm,
  },
  albumArt: {
    width: 60,
    height: 60,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  albumArtImage: {
    width: '100%',
    height: '100%',
  },
  trackInfo: {
    flex: 1,
  },
  trackName: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    color: '#FFFFFF',
    marginBottom: 2,
  },
  artistName: {
    fontSize: 13,
    fontFamily: 'gg-sans',
    color: '#DBDEE1',
    marginBottom: 2,
  },
  albumName: {
    fontSize: 13,
    fontFamily: 'gg-sans',
    color: '#B5BAC1',
  },
  progressContainer: {
    marginBottom: spacing.sm,
  },
  progressBar: {
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  progressTimes: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  timeText: {
    fontSize: 11,
    fontFamily: 'gg-sans',
    color: '#B5BAC1',
  },
  spotifyActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  spotifyButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: 10,
    borderRadius: 4,
  },
  spotifyButtonText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    color: '#FFFFFF',
  },
  spotifyIconButton: {
    width: 32,
    height: 32,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Roles
  rolesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  roleChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 4,
  },
  roleDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  roleText: {
    fontSize: 13,
    fontFamily: 'gg-sans',
    color: '#DBDEE1',
  },
  addRoleButton: {
    width: 24,
    height: 24,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Action buttons
  actionButtons: {
    marginTop: spacing.md,
    gap: spacing.sm,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 14,
    paddingHorizontal: spacing.lg,
    borderRadius: 12,
  },
  actionBtnText: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },

  // Version
  version: {
    fontSize: 12,
    textAlign: 'center',
    marginTop: spacing.xxl,
  },
});
