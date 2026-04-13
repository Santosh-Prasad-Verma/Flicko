/**
 * User Profile View Screen - Discord Enhanced
 *
 * Full Discord-style profile with badges, roles, mutual friends,
 * mutual servers, rich presence activity, Spotify player,
 * connection indicators, and proper micro-interactions.
 *
 * Route: /profile/[userId]
 * Requirements: 10.1, 10.2
 */
import React, { useMemo, useCallback, useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  ActivityIndicator,
  Alert,
  ActionSheetIOS,
  Platform,
  Dimensions,
  TextInput,
  Animated,
  FlatList,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { Image } from 'expo-image';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons, MaterialCommunityIcons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import { supabase } from '../../services/supabase';
import { Avatar } from '../../components/ui/Avatar';
import { ProfileMusicPlayer, ProfileMusicTrack } from '../../components/music';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const NOTES_PREFIX = '@flicko:user_note:';
const BANNER_HEIGHT = 150;
const AVATAR_SIZE = 84;
const AVATAR_BORDER = 6;

// ─── Types ────────────────────────────────────────────────────────────────────

type OnlineStatus = 'online' | 'idle' | 'dnd' | 'offline';

interface Badge {
  id: string;
  icon: string; // Ionicons or MaterialCommunityIcons name
  label: string;
  color: string;
  iconSet?: 'ionicons' | 'mci';
}

interface Role {
  id: string;
  name: string;
  color: string;
}

interface MutualFriend {
  id: string;
  username: string;
  display_name: string | null;
  avatar: string | null;
  online_status: OnlineStatus;
}

interface MutualServer {
  id: string;
  name: string;
  icon: string | null;
}

interface RichPresence {
  type: 'playing' | 'watching' | 'listening' | 'streaming' | 'competing';
  name: string;
  details?: string;
  state?: string;
  largeImage?: string;
  smallImage?: string;
  startTimestamp?: number;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const STATUS_OPTIONS: { key: OnlineStatus; label: string; color: string }[] = [
  { key: 'online',  label: 'Online',         color: '#23A559' },
  { key: 'idle',    label: 'Idle',           color: '#F0B232' },
  { key: 'dnd',     label: 'Do Not Disturb', color: '#ED4245' },
  { key: 'offline', label: 'Invisible',      color: '#80848E' },
];

const STATUS_COLORS: Record<string, string> = {
  online:  '#23A559',
  idle:    '#F0B232',
  dnd:     '#ED4245',
  offline: '#80848E',
};

const STATUS_LABELS: Record<string, string> = {
  online:  'Online',
  idle:    'Idle',
  dnd:     'Do Not Disturb',
  offline: 'Invisible',
};

/** Map profile flags / conditions → badge definitions */
const buildBadges = (profile: any): Badge[] => {
  const badges: Badge[] = [];
  if (profile?.is_staff)
    badges.push({ id: 'staff',      icon: 'shield',          label: 'Flicko Staff',           color: '#ED4245', iconSet: 'ionicons' });
  if (profile?.is_partner)
    badges.push({ id: 'partner',    icon: 'diamond',         label: 'Partnered Server Owner', color: '#5865F2', iconSet: 'ionicons' });
  if (profile?.hypesquad === 'bravery')
    badges.push({ id: 'bravery',    icon: 'shield-half',     label: 'HypeSquad Bravery',      color: '#9B59B6', iconSet: 'ionicons' });
  if (profile?.hypesquad === 'brilliance')
    badges.push({ id: 'brilliance', icon: 'diamond',         label: 'HypeSquad Brilliance',   color: '#E74C3C', iconSet: 'ionicons' });
  if (profile?.hypesquad === 'balance')
    badges.push({ id: 'balance',    icon: 'scale',           label: 'HypeSquad Balance',      color: '#2ECC71', iconSet: 'ionicons' });
  if (profile?.is_nitro || profile?.has_nitro)
    badges.push({ id: 'nitro',      icon: 'sparkles',        label: 'Nitro Subscriber',       color: '#5865F2', iconSet: 'ionicons' });
  if (profile?.is_early_supporter)
    badges.push({ id: 'early',      icon: 'heart',           label: 'Early Supporter',        color: '#E91E8C', iconSet: 'ionicons' });
  if (profile?.is_verified_dev)
    badges.push({ id: 'dev',        icon: 'code-slash',      label: 'Verified Bot Developer', color: '#5865F2', iconSet: 'ionicons' });
  if (profile?.bug_hunter_level === 1)
    badges.push({ id: 'bug1',       icon: 'bug',             label: 'Bug Hunter',             color: '#23A559', iconSet: 'ionicons' });
  if (profile?.bug_hunter_level === 2)
    badges.push({ id: 'bug2',       icon: 'bug',             label: 'Bug Hunter Gold',        color: '#F0B232', iconSet: 'ionicons' });
  return badges;
};

// ─── Sub-components ───────────────────────────────────────────────────────────

/** Animated status dot with idle pulse */
const StatusDot = ({
  status,
  size = 18,
  borderWidth = 3,
  borderColor = '#2B2D31',
  onPress,
}: {
  status: OnlineStatus;
  size?: number;
  borderWidth?: number;
  borderColor?: string;
  onPress?: () => void;
}) => {
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (status === 'idle') {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 0.5, duration: 900, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1,   duration: 900, useNativeDriver: true }),
        ])
      ).start();
    } else {
      pulseAnim.setValue(1);
    }
  }, [status]);

  const dot = (
    <Animated.View
      style={{
        width:        size,
        height:       size,
        borderRadius: size / 2,
        backgroundColor: STATUS_COLORS[status],
        borderWidth,
        borderColor,
        opacity: status === 'idle' ? pulseAnim : 1,
      }}
    />
  );

  if (onPress) return <Pressable onPress={onPress} hitSlop={8}>{dot}</Pressable>;
  return dot;
};

/** Single badge icon with tooltip on long-press */
const BadgeIcon = ({ badge }: { badge: Badge }) => {
  const [showTip, setShowTip] = useState(false);
  return (
    <Pressable
      onLongPress={() => { setShowTip(true); setTimeout(() => setShowTip(false), 1800); }}
      style={styles.badgeWrapper}
    >
      <View style={[styles.badgeCircle, { backgroundColor: badge.color + '22' }]}>
        <Ionicons name={badge.icon as any} size={16} color={badge.color} />
      </View>
      {showTip && (
        <View style={styles.badgeTooltip}>
          <Text style={styles.badgeTooltipText}>{badge.label}</Text>
        </View>
      )}
    </Pressable>
  );
};

/** Rich presence activity card */
const ActivityCard = ({ activity }: { activity: RichPresence }) => {
  const [elapsed, setElapsed] = useState('');

  useEffect(() => {
    if (!activity.startTimestamp) return;
    const update = () => {
      const diff = Math.floor((Date.now() - activity.startTimestamp!) / 1000);
      const h = Math.floor(diff / 3600);
      const m = Math.floor((diff % 3600) / 60);
      const s = diff % 60;
      setElapsed(h > 0
        ? `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`
        : `${m}:${String(s).padStart(2,'0')}`
      );
    };
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  }, [activity.startTimestamp]);

  const typeLabel: Record<RichPresence['type'], string> = {
    playing:   'Playing',
    watching:  'Watching',
    listening: 'Listening to',
    streaming: 'Live on',
    competing: 'Competing in',
  };

  return (
    <View style={styles.activityCard}>
      <View style={styles.activityHeader}>
        <View style={styles.activityTypeRow}>
          <View style={styles.activityTypeDot} />
          <Text style={styles.activityTypeLabel}>{typeLabel[activity.type]}</Text>
        </View>
      </View>
      <View style={styles.activityBody}>
        {activity.largeImage && (
          <View style={styles.activityImageStack}>
            <Image source={{ uri: activity.largeImage }} style={styles.activityLargeImage} />
            {activity.smallImage && (
              <Image source={{ uri: activity.smallImage }} style={styles.activitySmallImage} />
            )}
          </View>
        )}
        <View style={styles.activityInfo}>
          <Text style={styles.activityName} numberOfLines={1}>{activity.name}</Text>
          {activity.details && (
            <Text style={styles.activityDetails} numberOfLines={1}>{activity.details}</Text>
          )}
          {activity.state && (
            <Text style={styles.activityState} numberOfLines={1}>{activity.state}</Text>
          )}
          {activity.startTimestamp && (
            <Text style={styles.activityElapsed}>{elapsed} elapsed</Text>
          )}
        </View>
      </View>
    </View>
  );
};

/** Mutual friend avatar chip */
const MutualFriendChip = ({ friend }: { friend: MutualFriend }) => (
  <Pressable
    style={styles.mutualFriendChip}
    onPress={() => router.push(`/profile/${friend.id}`)}
  >
    <View style={styles.mutualAvatarContainer}>
      <Avatar
        name={friend.display_name || friend.username}
        imageUrl={friend.avatar || undefined}
        size={36}
      />
      <StatusDot
        status={friend.online_status}
        size={12}
        borderWidth={2}
        borderColor='#2B2D31'
      />
    </View>
    <Text style={styles.mutualFriendName} numberOfLines={1}>
      {friend.display_name || friend.username}
    </Text>
  </Pressable>
);

/** Role pill */
const RolePill = ({ role }: { role: Role }) => (
  <View style={[styles.rolePill, { borderColor: role.color + '66' }]}>
    <View style={[styles.roleDot, { backgroundColor: role.color }]} />
    <Text style={[styles.roleText, { color: role.color }]}>{role.name}</Text>
  </View>
);

/** Section header — matches Discord's uppercase grey label */
const SectionHeader = ({ title }: { title: string }) => (
  <Text style={styles.sectionTitle}>{title}</Text>
);

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function UserProfileScreen() {
  const { userId }     = useLocalSearchParams<{ userId: string }>();
  const insets         = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const currentUser    = useAuthStore((s: any) => s.user);
  const queryClient    = useQueryClient();
  const isOwnProfile   = currentUser?.id === userId;

  const [note, setNote]               = useState('');
  const [isEditingNote, setIsEditingNote] = useState(false);
  const [showStatusPicker, setShowStatusPicker] = useState(false);
  const [profileMusic, setProfileMusic] = useState<ProfileMusicTrack | null>(null);

  const scrollY       = useRef(new Animated.Value(0)).current;
  const MUSIC_KEY     = `@flicko:profile_music:${userId}`;

  // ── Queries ────────────────────────────────────────────────────────────────

  const { data: profile, isLoading } = useQuery({
    queryKey: ['profile', userId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!userId,
  });

  const { data: friendStatus } = useQuery({
    queryKey: ['friend-status', currentUser?.id, userId],
    queryFn: async () => {
      if (!currentUser?.id || !userId || currentUser.id === userId) return 'self';
      const { data: friendship } = await supabase
        .from('friends').select('id')
        .eq('user_id', currentUser.id).eq('friend_id', userId).maybeSingle();
      if (friendship) return 'friends';
      const { data: sent } = await supabase
        .from('friend_requests').select('id')
        .eq('sender_id', currentUser.id).eq('receiver_id', userId)
        .eq('status', 'pending').maybeSingle();
      if (sent) return 'pending_sent';
      const { data: recv } = await supabase
        .from('friend_requests').select('id')
        .eq('sender_id', userId).eq('receiver_id', currentUser.id)
        .eq('status', 'pending').maybeSingle();
      if (recv) return 'pending_received';
      return 'none';
    },
    enabled: !!currentUser?.id && !!userId,
  });

  const { data: mutualFriends = [] } = useQuery<MutualFriend[]>({
    queryKey: ['mutual-friends', currentUser?.id, userId],
    queryFn: async () => {
      if (!currentUser?.id || !userId || currentUser.id === userId) return [];
      const { data: myFriends } = await supabase
        .from('friends').select('friend_id').eq('user_id', currentUser.id);
      const { data: theirFriends } = await supabase
        .from('friends').select('friend_id').eq('user_id', userId);
      if (!myFriends || !theirFriends) return [];
      const mySet   = new Set(myFriends.map((f: any) => f.friend_id));
      const mutual  = theirFriends
        .map((f: any) => f.friend_id)
        .filter((id: string) => mySet.has(id));
      if (mutual.length === 0) return [];
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, username, display_name, avatar, online_status')
        .in('id', mutual.slice(0, 10));
      return (profiles as MutualFriend[]) || [];
    },
    enabled: !!currentUser?.id && !!userId && !isOwnProfile,
  });

  const { data: userRoles = [] } = useQuery<Role[]>({
    queryKey: ['user-roles', userId],
    queryFn: async () => {
      const { data } = await supabase
        .from('user_roles')
        .select('roles(id, name, color)')
        .eq('user_id', userId);
      if (!data) return [];
      return data.map((r: any) => r.roles).filter(Boolean) as Role[];
    },
    enabled: !!userId,
  });

  // Stubbed rich presence — replace with real-time subscription
  const { data: richPresence } = useQuery<RichPresence | null>({
    queryKey: ['presence', userId],
    queryFn: async () => {
      const { data } = await supabase
        .from('user_presence')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();
      if (!data) return null;
      return data as RichPresence;
    },
    enabled: !!userId,
    refetchInterval: 15_000,
  });

  // ── Effects ────────────────────────────────────────────────────────────────

  useEffect(() => {
    if (userId)
      AsyncStorage.getItem(`${NOTES_PREFIX}${userId}`).then(v => v && setNote(v));
  }, [userId]);

  useEffect(() => {
    if (userId && isOwnProfile)
      AsyncStorage.getItem(MUSIC_KEY).then(v => {
        if (v) try { setProfileMusic(JSON.parse(v)); } catch {}
      });
  }, [userId, isOwnProfile, MUSIC_KEY]);

  // ── Mutations ──────────────────────────────────────────────────────────────

  const sendFriendRequest = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from('friend_requests').insert({
        sender_id:   currentUser!.id,
        receiver_id: userId,
        status:      'pending',
      });
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['friend-status', currentUser?.id, userId] }),
    onError:   (e: any) => Alert.alert('Error', e.message),
  });

  const acceptFriendRequest = useMutation({
    mutationFn: async () => {
      await supabase
        .from('friend_requests').update({ status: 'accepted' })
        .eq('sender_id', userId).eq('receiver_id', currentUser!.id);
      await supabase.from('friends').insert([
        { user_id: currentUser!.id, friend_id: userId },
        { user_id: userId,          friend_id: currentUser!.id },
      ]);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['friend-status', currentUser?.id, userId] });
      queryClient.invalidateQueries({ queryKey: ['friends'] });
    },
  });

  const removeFriend = useMutation({
    mutationFn: async () => {
      await supabase.from('friends')
        .delete()
        .or(`user_id.eq.${currentUser!.id},user_id.eq.${userId}`)
        .or(`friend_id.eq.${currentUser!.id},friend_id.eq.${userId}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['friend-status', currentUser?.id, userId] });
      queryClient.invalidateQueries({ queryKey: ['friends'] });
    },
  });

  // ── Handlers ───────────────────────────────────────────────────────────────

  const handleMusicChange = useCallback(async (track: ProfileMusicTrack | null) => {
    setProfileMusic(track);
    if (track) await AsyncStorage.setItem(MUSIC_KEY, JSON.stringify(track));
    else        await AsyncStorage.removeItem(MUSIC_KEY);
  }, [MUSIC_KEY]);

  const saveNote = useCallback(async () => {
    if (!userId) return;
    try {
      if (note.trim()) await AsyncStorage.setItem(`${NOTES_PREFIX}${userId}`, note.trim());
      else              await AsyncStorage.removeItem(`${NOTES_PREFIX}${userId}`);
    } catch (e) { console.error(e); }
    setIsEditingNote(false);
  }, [userId, note]);

  const handleFriendAction = useCallback(() => {
    if (friendStatus === 'none')             sendFriendRequest.mutate();
    else if (friendStatus === 'pending_received') acceptFriendRequest.mutate();
    else if (friendStatus === 'friends') {
      Alert.alert('Remove Friend', `Remove ${profile?.display_name || profile?.username} as a friend?`, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Remove', style: 'destructive', onPress: () => removeFriend.mutate() },
      ]);
    }
  }, [friendStatus, profile, sendFriendRequest, acceptFriendRequest, removeFriend]);

  const handleMoreOptions = useCallback(() => {
    const ownOpts = [
      { label: 'Edit Profile', action: () => router.push('/settings/edit-profile') },
      { label: 'Copy User ID', action: () => userId && Clipboard.setStringAsync(userId) },
    ];
    const otherOpts = [
      { label: 'Copy User ID', action: () => userId && Clipboard.setStringAsync(userId) },
      { label: 'Block User', action: () =>
          Alert.alert('Block User', `Block ${profile?.display_name || profile?.username}?`, [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Block', style: 'destructive', onPress: async () => {
                if (!currentUser?.id || !userId) return;
                await supabase.from('blocked_users').upsert({ user_id: currentUser.id, blocked_id: userId });
                router.back();
              },
            },
          ])
      },
      { label: 'Report', action: () => Alert.alert('Report User', 'Coming soon.') },
    ];
    const opts = isOwnProfile ? ownOpts : otherOpts;
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { options: [...opts.map(o => o.label), 'Cancel'], cancelButtonIndex: opts.length,
          destructiveButtonIndex: !isOwnProfile ? 1 : undefined },
        idx => { if (idx < opts.length) opts[idx].action(); },
      );
    } else {
      Alert.alert('Options', undefined, [
        ...opts.map(o => ({ text: o.label, onPress: o.action,
          style: o.label === 'Block User' ? 'destructive' as const : 'default' as const })),
        { text: 'Cancel', style: 'cancel' },
      ]);
    }
  }, [userId, profile, currentUser?.id, isOwnProfile]);

  const handleStatusChange = useCallback(async (s: OnlineStatus) => {
    setShowStatusPicker(false);
    if (!currentUser?.id) return;
    await supabase.from('profiles').update({ online_status: s }).eq('id', currentUser.id);
    queryClient.invalidateQueries({ queryKey: ['profile', userId] });
  }, [currentUser?.id, queryClient, userId]);

  // ── Derived ────────────────────────────────────────────────────────────────

  const badges      = useMemo(() => buildBadges(profile), [profile]);
  const accentColor = profile?.accent_color || '#5865F2';
  const onlineStatus: OnlineStatus = profile?.online_status || 'online';
  const displayName = profile?.display_name || profile?.username || 'Unknown';

  const bannerHeaderOpacity = scrollY.interpolate({
    inputRange:  [0, BANNER_HEIGHT - 60],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  const formatJoinDate = (d?: string) =>
    d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Unknown';

  // ── Render guards ──────────────────────────────────────────────────────────

  if (isLoading) return (
    <View style={[styles.container, styles.center, { backgroundColor: '#1E1F22' }]}>
      <ActivityIndicator color={accentColor} size="large" />
    </View>
  );

  if (!profile) return (
    <View style={[styles.container, styles.center, { backgroundColor: '#1E1F22' }]}>
      <Text style={styles.errorText}>User not found</Text>
    </View>
  );

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={styles.container}>

        {/* ── Floating header (fades in on scroll) ── */}
        <Animated.View
          style={[
            styles.floatingHeader,
            { opacity: bannerHeaderOpacity, paddingTop: insets.top },
          ]}
          pointerEvents="none"
        >
          <BlurView intensity={60} tint="dark" style={StyleSheet.absoluteFill} />
          <Text style={styles.floatingHeaderName}>{displayName}</Text>
        </Animated.View>

        <Animated.ScrollView
          style={styles.scrollView}
          contentContainerStyle={{ paddingBottom: insets.bottom + 40 }}
          showsVerticalScrollIndicator={false}
          scrollEventThrottle={16}
          onScroll={Animated.event(
            [{ nativeEvent: { contentOffset: { y: scrollY } } }],
            { useNativeDriver: true },
          )}
        >
          {/* ── Banner ── */}
          <View style={styles.bannerContainer}>
            {profile.banner ? (
              <Image
                source={{ uri: profile.banner }}
                style={StyleSheet.absoluteFill}
                contentFit="cover"
              />
            ) : (
              <LinearGradient
                colors={[accentColor, accentColor + 'AA', '#1E1F22']}
                style={StyleSheet.absoluteFill}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
              />
            )}
            {/* Bottom fade into card */}
            <LinearGradient
              colors={['transparent', '#2B2D31']}
              style={styles.bannerFade}
            />
          </View>

          {/* ── Profile card ── */}
          <View style={styles.profileCard}>

            {/* Avatar + actions row */}
            <View style={styles.avatarRow}>
              <View>
                <View style={[styles.avatarRing, { borderColor: '#2B2D31' }]}>
                  <Avatar
                    name={displayName}
                    imageUrl={profile.avatar || undefined}
                    size={AVATAR_SIZE}
                  />
                </View>
                <View style={styles.statusDotWrapper}>
                  <StatusDot
                    status={onlineStatus}
                    size={20}
                    borderWidth={4}
                    borderColor="#2B2D31"
                    onPress={isOwnProfile ? () => setShowStatusPicker(true) : undefined}
                  />
                </View>
              </View>

              {/* Right-side action buttons */}
              <View style={styles.actionRow}>
                {!isOwnProfile && (
                  <>
                    {/* Friend button */}
                    {friendStatus === 'none' && (
                      <ActionButton
                        icon="person-add"
                        label="Add Friend"
                        color={accentColor}
                        onPress={handleFriendAction}
                        loading={sendFriendRequest.isPending}
                      />
                    )}
                    {friendStatus === 'pending_sent' && (
                      <ActionButton icon="time" label="Pending" color="#4E5058" disabled />
                    )}
                    {friendStatus === 'pending_received' && (
                      <ActionButton
                        icon="checkmark-circle"
                        label="Accept"
                        color="#23A559"
                        onPress={handleFriendAction}
                        loading={acceptFriendRequest.isPending}
                      />
                    )}
                    {friendStatus === 'friends' && (
                      <ActionButton
                        icon="people"
                        label="Friends"
                        color="#4E5058"
                        onPress={handleFriendAction}
                      />
                    )}
                    {/* Message button — always shown for non-self */}
                    <ActionButton
                      icon="chatbubble-ellipses"
                      label="Message"
                      color="#4E5058"
                      onPress={() => router.push(`/dm/${userId}`)}
                    />
                  </>
                )}
                {isOwnProfile && (
                  <ActionButton
                    icon="create-outline"
                    label="Edit Profile"
                    color="#4E5058"
                    onPress={() => router.push('/settings/edit-profile')}
                  />
                )}
              </View>
            </View>

            {/* ── Identity ── */}
            <View style={styles.identityBlock}>
              <View style={styles.nameRow}>
                <Text style={styles.displayName}>{displayName}</Text>
                {isOwnProfile && (
                  <Pressable onPress={() => setShowStatusPicker(true)}>
                    <View style={[styles.statusBadge, { backgroundColor: STATUS_COLORS[onlineStatus] + '22' }]}>
                      <View style={[styles.statusBadgeDot, { backgroundColor: STATUS_COLORS[onlineStatus] }]} />
                      <Text style={[styles.statusBadgeText, { color: STATUS_COLORS[onlineStatus] }]}>
                        {STATUS_LABELS[onlineStatus]}
                      </Text>
                    </View>
                  </Pressable>
                )}
              </View>
              <Text style={styles.usernameHandle}>@{profile.username}</Text>
            </View>

            {/* ── Badges ── */}
            {badges.length > 0 && (
              <View style={styles.badgesRow}>
                {badges.map(b => <BadgeIcon key={b.id} badge={b} />)}
              </View>
            )}

            {/* ── Card divider ── */}
            <View style={styles.cardDivider} />

            {/* ── Activity / Rich Presence ── */}
            {richPresence && (
              <View style={styles.section}>
                <SectionHeader title="CURRENT ACTIVITY" />
                <ActivityCard activity={richPresence} />
              </View>
            )}

            {/* ── Spotify / Music Player ── */}
            <ProfileMusicPlayer
              currentTrack={profileMusic}
              onTrackChange={isOwnProfile ? handleMusicChange : undefined}
              isOwnProfile={isOwnProfile}
            />

            {/* ── About Me ── */}
            {(profile.bio || isOwnProfile) && (
              <View style={styles.section}>
                <SectionHeader title="ABOUT ME" />
                <Text style={styles.bioText}>
                  {profile.bio || (isOwnProfile ? 'You haven\'t written anything yet.' : '')}
                </Text>
              </View>
            )}

            {/* ── Member Since ── */}
            <View style={styles.section}>
              <SectionHeader title="FLICKO MEMBER SINCE" />
              <View style={styles.memberRow}>
                <View style={[styles.memberIconCircle, { backgroundColor: accentColor + '22' }]}>
                  <Ionicons name="calendar" size={16} color={accentColor} />
                </View>
                <Text style={styles.memberDate}>{formatJoinDate(profile.created_at)}</Text>
              </View>
            </View>

            {/* ── Roles ── */}
            {userRoles.length > 0 && (
              <View style={styles.section}>
                <SectionHeader title={`ROLES — ${userRoles.length}`} />
                <View style={styles.rolesWrap}>
                  {userRoles.map(r => <RolePill key={r.id} role={r} />)}
                </View>
              </View>
            )}

            {/* ── Mutual Friends ── */}
            {!isOwnProfile && mutualFriends.length > 0 && (
              <View style={styles.section}>
                <SectionHeader title={`MUTUAL FRIENDS — ${mutualFriends.length}`} />
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.mutualFriendsScroll}
                >
                  {mutualFriends.map(f => <MutualFriendChip key={f.id} friend={f} />)}
                </ScrollView>
              </View>
            )}

            {/* ── Note (other users only) ── */}
            {!isOwnProfile && (
              <View style={styles.section}>
                <View style={styles.noteLabelRow}>
                  <SectionHeader title="NOTE" />
                  {note && !isEditingNote && (
                    <Pressable onPress={() => setIsEditingNote(true)}>
                      <Text style={styles.noteEditLink}>Edit</Text>
                    </Pressable>
                  )}
                </View>
                {isEditingNote ? (
                  <View style={styles.noteInputContainer}>
                    <TextInput
                      value={note}
                      onChangeText={setNote}
                      placeholder="Click to add a note about this user"
                      placeholderTextColor="#4E5058"
                      style={styles.noteInput}
                      multiline
                      maxLength={256}
                      autoFocus
                    />
                    <View style={styles.noteActions}>
                      <Text style={styles.noteCharCount}>{note.length}/256</Text>
                      <Pressable style={styles.noteSaveBtn} onPress={saveNote}>
                        <Text style={styles.noteSaveBtnText}>Save</Text>
                      </Pressable>
                    </View>
                  </View>
                ) : (
                  <Pressable style={styles.noteTouchable} onPress={() => setIsEditingNote(true)}>
                    <Ionicons name="create-outline" size={14} color="#4E5058" style={styles.noteIcon} />
                    <Text style={[styles.noteDisplayText, !note && styles.notePlaceholderText]}>
                      {note || 'Click to add a note — only you can see this'}
                    </Text>
                  </Pressable>
                )}
              </View>
            )}

          </View>
        </Animated.ScrollView>

        {/* ── Status picker modal ── */}
        {showStatusPicker && (
          <Pressable style={styles.statusOverlay} onPress={() => setShowStatusPicker(false)}>
            <Pressable style={styles.statusSheet} onPress={e => e.stopPropagation()}>
              <View style={styles.statusSheetHandle} />
              <Text style={styles.statusSheetTitle}>Set Status</Text>
              {STATUS_OPTIONS.map(opt => (
                <Pressable
                  key={opt.key}
                  style={[styles.statusRow, onlineStatus === opt.key && styles.statusRowActive]}
                  onPress={() => handleStatusChange(opt.key)}
                >
                  <StatusDot status={opt.key} size={16} borderWidth={0} borderColor="transparent" />
                  <Text style={styles.statusRowLabel}>{opt.label}</Text>
                  {onlineStatus === opt.key && (
                    <Ionicons name="checkmark" size={18} color={accentColor} />
                  )}
                </Pressable>
              ))}
            </Pressable>
          </Pressable>
        )}

        {/* ── Nav buttons ── */}
        <View style={[styles.navButtons, { top: insets.top + 8 }]}>
          <Pressable style={styles.navBtn} onPress={() => router.back()} hitSlop={12}>
            <Ionicons name="arrow-back" size={20} color="#FFF" />
          </Pressable>
          <Pressable style={styles.navBtn} onPress={handleMoreOptions} hitSlop={12}>
            <Ionicons name="ellipsis-horizontal" size={20} color="#FFF" />
          </Pressable>
        </View>

      </View>
    </>
  );
}

// ─── ActionButton helper ──────────────────────────────────────────────────────

interface ActionButtonProps {
  icon:     string;
  label:    string;
  color:    string;
  onPress?: () => void;
  loading?: boolean;
  disabled?: boolean;
}

const ActionButton = ({ icon, label, color, onPress, loading, disabled }: ActionButtonProps) => (
  <Pressable
    style={[styles.actionBtn, { backgroundColor: color }, disabled && styles.actionBtnDisabled]}
    onPress={onPress}
    disabled={disabled || loading}
  >
    {loading
      ? <ActivityIndicator size="small" color="#FFF" />
      : <Ionicons name={icon as any} size={15} color="#FFF" />
    }
    <Text style={styles.actionBtnLabel}>{label}</Text>
  </Pressable>
);

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#1E1F22' },
  scrollView: { flex: 1 },
  center:     { justifyContent: 'center', alignItems: 'center' },
  errorText:  { color: '#80848E', fontSize: 16, fontFamily: 'gg-sans' },

  // Floating header
  floatingHeader: {
    position:       'absolute',
    top:            0,
    left:           0,
    right:          0,
    zIndex:         10,
    paddingBottom:  12,
    paddingHorizontal: 16,
    alignItems:     'center',
    justifyContent: 'flex-end',
    height:         80,
  },
  floatingHeaderName: {
    fontSize:   17,
    fontFamily: 'gg-sans-bold',
    color:      '#FFF',
  },

  // Banner
  bannerContainer: {
    height:   BANNER_HEIGHT,
    overflow: 'hidden',
  },
  bannerFade: {
    position: 'absolute',
    bottom:   0,
    left:     0,
    right:    0,
    height:   60,
  },

  // Profile card
  profileCard: {
    backgroundColor:  '#2B2D31',
    marginTop:        -20,
    borderTopLeftRadius:  16,
    borderTopRightRadius: 16,
    paddingBottom:    24,
    minHeight:        '100%',
  },

  // Avatar row
  avatarRow: {
    flexDirection:  'row',
    justifyContent: 'space-between',
    alignItems:     'flex-end',
    paddingHorizontal: 16,
    marginTop:      -(AVATAR_SIZE / 2 + AVATAR_BORDER),
  },
  avatarRing: {
    borderWidth:   AVATAR_BORDER,
    borderRadius:  (AVATAR_SIZE / 2) + AVATAR_BORDER,
    borderColor:   '#2B2D31',
    width:         AVATAR_SIZE + AVATAR_BORDER * 2,
    height:        AVATAR_SIZE + AVATAR_BORDER * 2,
    alignItems:    'center',
    justifyContent:'center',
    backgroundColor: '#2B2D31',
  },
  statusDotWrapper: {
    position: 'absolute',
    bottom:   2,
    right:    2,
  },
  actionRow: {
    flexDirection: 'row',
    gap:           8,
    paddingBottom: 4,
  },
  actionBtn: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            6,
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius:   6,
  },
  actionBtnDisabled: { opacity: 0.5 },
  actionBtnLabel: {
    fontSize:   13,
    fontFamily: 'gg-sans-semibold',
    color:      '#FFF',
  },

  // Identity
  identityBlock: {
    paddingHorizontal: 16,
    paddingTop:        14,
    gap:               4,
  },
  nameRow: {
    flexDirection: 'row',
    alignItems:    'center',
    gap:           10,
    flexWrap:      'wrap',
  },
  displayName: {
    fontSize:   22,
    fontFamily: 'gg-sans-bold',
    color:      '#FFF',
  },
  statusBadge: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            5,
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius:   20,
  },
  statusBadgeDot: {
    width:        7,
    height:       7,
    borderRadius: 4,
  },
  statusBadgeText: {
    fontSize:   11,
    fontFamily: 'gg-sans-semibold',
  },
  usernameHandle: {
    fontSize:   14,
    fontFamily: 'gg-sans',
    color:      '#80848E',
  },

  // Badges
  badgesRow: {
    flexDirection:    'row',
    flexWrap:         'wrap',
    gap:              8,
    paddingHorizontal: 16,
    paddingTop:       12,
  },
  badgeWrapper: { position: 'relative' },
  badgeCircle: {
    width:        30,
    height:       30,
    borderRadius: 15,
    alignItems:   'center',
    justifyContent: 'center',
  },
  badgeTooltip: {
    position:        'absolute',
    bottom:          36,
    left:            '50%',
    transform:       [{ translateX: -60 }],
    width:           120,
    backgroundColor: '#111214',
    borderRadius:    4,
    paddingVertical: 4,
    paddingHorizontal: 8,
    zIndex:          99,
  },
  badgeTooltipText: {
    color:      '#DBDEE1',
    fontSize:   11,
    fontFamily: 'gg-sans',
    textAlign:  'center',
  },

  // Card divider
  cardDivider: {
    height:            1,
    backgroundColor:   '#1E1F22',
    marginHorizontal:  16,
    marginTop:         16,
    marginBottom:      4,
  },

  // Sections
  section: {
    paddingHorizontal: 16,
    paddingTop:        16,
  },
  sectionTitle: {
    fontSize:      11,
    fontFamily:    'gg-sans-bold',
    color:         '#80848E',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom:  8,
  },

  // Activity card
  activityCard: {
    backgroundColor: '#1E1F22',
    borderRadius:    8,
    padding:         12,
  },
  activityHeader: { marginBottom: 10 },
  activityTypeRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  activityTypeDot: {
    width:        8,
    height:       8,
    borderRadius: 4,
    backgroundColor: '#23A559',
  },
  activityTypeLabel: {
    fontSize:   11,
    fontFamily: 'gg-sans-semibold',
    color:      '#B5BAC1',
    textTransform: 'uppercase',
    letterSpacing: 0.4,
  },
  activityBody:  { flexDirection: 'row', gap: 12 },
  activityImageStack: { position: 'relative', width: 60, height: 60 },
  activityLargeImage: {
    width:        60,
    height:       60,
    borderRadius: 8,
  },
  activitySmallImage: {
    position:     'absolute',
    bottom:       -4,
    right:        -4,
    width:        22,
    height:       22,
    borderRadius: 11,
    borderWidth:  2,
    borderColor:  '#1E1F22',
  },
  activityInfo:    { flex: 1, justifyContent: 'center', gap: 2 },
  activityName:    { fontSize: 14, fontFamily: 'gg-sans-bold', color: '#DBDEE1' },
  activityDetails: { fontSize: 13, fontFamily: 'gg-sans',      color: '#B5BAC1' },
  activityState:   { fontSize: 13, fontFamily: 'gg-sans',      color: '#B5BAC1' },
  activityElapsed: { fontSize: 12, fontFamily: 'gg-sans',      color: '#80848E', marginTop: 4 },

  // About me
  bioText: {
    fontSize:   14,
    fontFamily: 'gg-sans',
    color:      '#DBDEE1',
    lineHeight: 20,
  },

  // Member since
  memberRow: {
    flexDirection: 'row',
    alignItems:    'center',
    gap:           10,
  },
  memberIconCircle: {
    width:         30,
    height:        30,
    borderRadius:  15,
    alignItems:    'center',
    justifyContent:'center',
  },
  memberDate: {
    fontSize:   14,
    fontFamily: 'gg-sans',
    color:      '#DBDEE1',
  },

  // Roles
  rolesWrap: {
    flexDirection: 'row',
    flexWrap:      'wrap',
    gap:           8,
  },
  rolePill: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            6,
    borderWidth:    1,
    borderRadius:   4,
    paddingVertical: 4,
    paddingHorizontal: 8,
    backgroundColor: 'transparent',
  },
  roleDot: {
    width:        10,
    height:       10,
    borderRadius: 5,
  },
  roleText: {
    fontSize:   13,
    fontFamily: 'gg-sans-semibold',
  },

  // Mutual friends
  mutualFriendsScroll: {
    gap:         12,
    paddingBottom: 4,
  },
  mutualFriendChip: {
    alignItems: 'center',
    gap:        6,
    width:      56,
  },
  mutualAvatarContainer: {
    position:     'relative',
    width:        40,
    height:       40,
  },
  mutualFriendName: {
    fontSize:   10,
    fontFamily: 'gg-sans',
    color:      '#B5BAC1',
    textAlign:  'center',
  },

  // Note
  noteLabelRow: {
    flexDirection:  'row',
    alignItems:     'center',
    justifyContent: 'space-between',
    marginBottom:   8,
  },
  noteEditLink: {
    fontSize:   12,
    fontFamily: 'gg-sans-semibold',
    color:      '#5865F2',
  },
  noteInputContainer: {
    backgroundColor: '#1E1F22',
    borderRadius:    6,
    padding:         10,
  },
  noteInput: {
    fontSize:        14,
    fontFamily:      'gg-sans',
    color:           '#DBDEE1',
    minHeight:       60,
    textAlignVertical: 'top',
  },
  noteActions: {
    flexDirection:  'row',
    alignItems:     'center',
    justifyContent: 'space-between',
    marginTop:      8,
  },
  noteCharCount: {
    fontSize:   11,
    fontFamily: 'gg-sans',
    color:      '#4E5058',
  },
  noteSaveBtn: {
    backgroundColor: '#5865F2',
    borderRadius:    4,
    paddingVertical: 5,
    paddingHorizontal: 14,
  },
  noteSaveBtnText: {
    fontSize:   13,
    fontFamily: 'gg-sans-semibold',
    color:      '#FFF',
  },
  noteTouchable: {
    flexDirection:   'row',
    alignItems:      'flex-start',
    gap:             8,
    backgroundColor: '#1E1F22',
    borderRadius:    6,
    padding:         10,
    minHeight:       44,
  },
  noteIcon: { marginTop: 2 },
  noteDisplayText: {
    flex:       1,
    fontSize:   14,
    fontFamily: 'gg-sans',
    color:      '#DBDEE1',
    lineHeight: 20,
  },
  notePlaceholderText: { color: '#4E5058' },

  // Status picker
  statusOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent:  'flex-end',
  },
  statusSheet: {
    backgroundColor: '#2B2D31',
    borderTopLeftRadius:  16,
    borderTopRightRadius: 16,
    paddingHorizontal:    16,
    paddingBottom:        32,
    paddingTop:           12,
  },
  statusSheetHandle: {
    width:         40,
    height:        4,
    borderRadius:  2,
    backgroundColor: '#4E5058',
    alignSelf:     'center',
    marginBottom:  16,
  },
  statusSheetTitle: {
    fontSize:      16,
    fontFamily:    'gg-sans-bold',
    color:         '#FFF',
    marginBottom:  12,
    textAlign:     'center',
  },
  statusRow: {
    flexDirection:    'row',
    alignItems:       'center',
    gap:              14,
    paddingVertical:  12,
    paddingHorizontal: 10,
    borderRadius:     6,
  },
  statusRowActive:  { backgroundColor: '#36393F' },
  statusRowLabel: {
    flex:       1,
    fontSize:   15,
    fontFamily: 'gg-sans',
    color:      '#DBDEE1',
  },

  // Nav buttons
  navButtons: {
    position:       'absolute',
    left:           0,
    right:          0,
    flexDirection:  'row',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
  },
  navBtn: {
    width:          36,
    height:         36,
    borderRadius:   18,
    backgroundColor: 'rgba(0,0,0,0.45)',
    alignItems:     'center',
    justifyContent: 'center',
  },
});