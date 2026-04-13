// ============================================
// Rich Presence Card — Shows user activity on profile
// "Playing X", "Listening to Spotify", "Streaming on Twitch", custom status
// ============================================
import React, { useEffect, useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  TouchableOpacity,
  Linking,
} from 'react-native';
import Animated, { FadeIn, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';

// ---- Types ----

export type ActivityType = 0 | 1 | 2 | 3 | 4 | 5;
// 0=Playing, 1=Streaming, 2=Listening, 3=Watching, 4=Custom, 5=Competing

export interface RichActivity {
  name: string;
  type: ActivityType;
  url?: string;
  details?: string;
  state?: string;
  emoji?: { name: string; id?: string; animated?: boolean };
  timestamps?: { start?: number; end?: number };
  assets?: {
    large_image?: string;
    large_text?: string;
    small_image?: string;
    small_text?: string;
  };
  party?: { id?: string; size?: [number, number] };
  buttons?: { label: string; url: string }[];
  application_id?: string;
}

export interface ConnectedAccount {
  id: string;
  name: string;
  type: string;
  verified: boolean;
  visibility: number;
  show_activity: boolean;
}

interface RichPresenceCardProps {
  activity?: RichActivity | null;
  themeColors?: any;
}

interface ConnectedAccountCardProps {
  account: ConnectedAccount;
  themeColors?: any;
}

interface UserProfilePresenceProps {
  activities: RichActivity[];
  connections: ConnectedAccount[];
}

// ---- Activity Label Helpers ----

const ACTIVITY_LABELS: Record<number, string> = {
  0: 'Playing',
  1: 'Streaming',
  2: 'Listening to',
  3: 'Watching',
  4: '',
  5: 'Competing in',
};

const ACTIVITY_ICONS: Record<number, { name: string; color: string }> = {
  0: { name: 'game-controller', color: '#3BA55D' },
  1: { name: 'videocam', color: '#9146FF' },
  2: { name: 'musical-note', color: '#1DB954' },
  3: { name: 'eye', color: '#ED4245' },
  4: { name: 'happy', color: '#5865F2' },
  5: { name: 'trophy', color: '#FAA61A' },
};

const CONNECTION_META: Record<string, { icon: string; color: string; displayName: string }> = {
  spotify: { icon: 'musical-notes', color: '#1DB954', displayName: 'Spotify' },
  twitch: { icon: 'logo-twitch', color: '#9146FF', displayName: 'Twitch' },
  youtube: { icon: 'logo-youtube', color: '#FF0000', displayName: 'YouTube' },
  twitter: { icon: 'logo-twitter', color: '#1DA1F2', displayName: 'Twitter/X' },
  github: { icon: 'logo-github', color: '#FFFFFF', displayName: 'GitHub' },
  steam: { icon: 'game-controller', color: '#1B2838', displayName: 'Steam' },
  playstation: { icon: 'game-controller-outline', color: '#003087', displayName: 'PlayStation' },
  xbox: { icon: 'game-controller-outline', color: '#107C10', displayName: 'Xbox' },
  reddit: { icon: 'logo-reddit', color: '#FF4500', displayName: 'Reddit' },
  discord: { icon: 'chatbubbles', color: '#5865F2', displayName: 'Discord' },
  google: { icon: 'logo-google', color: '#DB4437', displayName: 'Google' },
};

// ---- Rich Presence Card ----

export function RichPresenceCard({ activity, themeColors: propThemeColors }: RichPresenceCardProps) {
  const defaultThemeColors = useTheme();
  const themeColors = propThemeColors ?? defaultThemeColors;

  if (!activity) return null;

  const label = ACTIVITY_LABELS[activity.type] ?? '';
  const iconMeta = ACTIVITY_ICONS[activity.type] ?? ACTIVITY_ICONS[0];
  const isSpotify = activity.type === 2 && activity.name?.toLowerCase().includes('spotify');

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      style={[styles.card, { backgroundColor: themeColors.surface ?? themeColors.bgSecondary }]}
    >
      {/* Header */}
      <View style={styles.cardHeader}>
        <Ionicons name={iconMeta.name as any} size={14} color={iconMeta.color} />
        <Text style={[styles.cardLabel, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
          {label.toUpperCase()} {activity.type !== 4 ? activity.name.toUpperCase() : ''}
        </Text>
      </View>

      {/* Content */}
      <View style={styles.cardBody}>
        {/* Large image */}
        {activity.assets?.large_image && (
          <View style={styles.assetContainer}>
            <Image
              source={{ uri: activity.assets.large_image }}
              style={styles.largeImage}
              resizeMode="cover"
            />
            {activity.assets.small_image && (
              <Image
                source={{ uri: activity.assets.small_image }}
                style={styles.smallImage}
                resizeMode="cover"
              />
            )}
          </View>
        )}

        <View style={styles.cardDetails}>
          {/* Custom status with emoji */}
          {activity.type === 4 ? (
            <View style={styles.customStatus}>
              {activity.emoji && <Text style={styles.statusEmoji}>{activity.emoji.name}</Text>}
              <Text style={[styles.statusText, { color: themeColors.text ?? themeColors.textPrimary }]}>
                {activity.state ?? activity.name}
              </Text>
            </View>
          ) : (
            <>
              <Text style={[styles.detailTitle, { color: themeColors.text ?? themeColors.textPrimary }]} numberOfLines={1}>
                {activity.details ?? activity.name}
              </Text>
              {activity.state && (
                <Text style={[styles.detailSub, { color: themeColors.textSecondary ?? themeColors.textMuted }]} numberOfLines={1}>
                  {activity.state}
                </Text>
              )}
            </>
          )}

          {/* Timestamps / elapsed */}
          {activity.timestamps?.start && (
            <ElapsedTime startMs={activity.timestamps.start} themeColors={themeColors} />
          )}

          {/* Spotify progress bar */}
          {isSpotify && activity.timestamps?.start && activity.timestamps?.end && (
            <SpotifyProgressBar
              startMs={activity.timestamps.start}
              endMs={activity.timestamps.end}
              themeColors={themeColors}
            />
          )}

          {/* Party size */}
          {activity.party?.size && (
            <Text style={[styles.partyText, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
              {activity.party.size[0]} of {activity.party.size[1]}
            </Text>
          )}
        </View>
      </View>

      {/* Action Buttons */}
      {activity.buttons && activity.buttons.length > 0 && (
        <View style={styles.buttonRow}>
          {activity.buttons.map((btn, i) => (
            <TouchableOpacity
              key={i}
              style={[styles.actionButton, { borderColor: themeColors.border }]}
              onPress={() => { try { Linking.openURL(btn.url); } catch {} }}
            >
              <Text style={[styles.actionButtonText, { color: themeColors.text ?? themeColors.textPrimary }]}>
                {btn.label}
              </Text>
            </TouchableOpacity>
          ))}
          {isSpotify && (
            <TouchableOpacity
              style={[styles.listenAlongButton, { backgroundColor: '#1DB954' }]}
              onPress={() => { /* Listen Along */ }}
            >
              <Ionicons name="headset" size={14} color="#fff" />
              <Text style={styles.listenAlongText}>Listen Along</Text>
            </TouchableOpacity>
          )}
        </View>
      )}

      {/* Listen Along for Spotify without explicit buttons */}
      {isSpotify && (!activity.buttons || activity.buttons.length === 0) && (
        <View style={styles.buttonRow}>
          <TouchableOpacity
            style={[styles.listenAlongButton, { backgroundColor: '#1DB954' }]}
            onPress={() => { /* Listen Along — would open Spotify deep link */ }}
          >
            <Ionicons name="headset" size={14} color="#fff" />
            <Text style={styles.listenAlongText}>Listen Along</Text>
          </TouchableOpacity>
        </View>
      )}
    </Animated.View>
  );
}

// ---- Elapsed Time ----

function ElapsedTime({ startMs, themeColors }: { startMs: number; themeColors: any }) {
  const [elapsed, setElapsed] = useState('');

  useEffect(() => {
    const update = () => {
      const diff = Date.now() - startMs;
      const hrs = Math.floor(diff / 3600000);
      const mins = Math.floor((diff % 3600000) / 60000);
      const secs = Math.floor((diff % 60000) / 1000);
      setElapsed(
        hrs > 0
          ? `${hrs}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')} elapsed`
          : `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')} elapsed`
      );
    };
    update();
    const timer = setInterval(update, 1000);
    return () => clearInterval(timer);
  }, [startMs]);

  return (
    <Text style={[styles.elapsedText, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
      {elapsed}
    </Text>
  );
}

// ---- Spotify Progress Bar ----

function SpotifyProgressBar({
  startMs,
  endMs,
  themeColors,
}: {
  startMs: number;
  endMs: number;
  themeColors: any;
}) {
  const [progress, setProgress] = useState(0);
  const [currentStr, setCurrentStr] = useState('0:00');
  const totalMs = endMs - startMs;
  const totalStr = useMemo(() => {
    const mins = Math.floor(totalMs / 60000);
    const secs = Math.floor((totalMs % 60000) / 1000);
    return `${mins}:${String(secs).padStart(2, '0')}`;
  }, [totalMs]);

  useEffect(() => {
    const update = () => {
      const elapsed = Date.now() - startMs;
      const pct = Math.min(elapsed / totalMs, 1);
      setProgress(pct);
      const curMins = Math.floor(elapsed / 60000);
      const curSecs = Math.floor((elapsed % 60000) / 1000);
      setCurrentStr(`${curMins}:${String(curSecs).padStart(2, '0')}`);
    };
    update();
    const timer = setInterval(update, 1000);
    return () => clearInterval(timer);
  }, [startMs, totalMs]);

  return (
    <View style={styles.progressContainer}>
      <View style={[styles.progressBg, { backgroundColor: themeColors.border }]}>
        <View style={[styles.progressFill, { width: `${progress * 100}%`, backgroundColor: '#1DB954' }]} />
      </View>
      <View style={styles.progressTimes}>
        <Text style={[styles.progressTime, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
          {currentStr}
        </Text>
        <Text style={[styles.progressTime, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
          {totalStr}
        </Text>
      </View>
    </View>
  );
}

// ---- Connected Account Card ----

export function ConnectedAccountCard({ account, themeColors: propThemeColors }: ConnectedAccountCardProps) {
  const defaultThemeColors = useTheme();
  const themeColors = propThemeColors ?? defaultThemeColors;
  const meta = CONNECTION_META[account.type] ?? { icon: 'link', color: '#888', displayName: account.type };

  return (
    <View style={[styles.connectionRow, { borderBottomColor: themeColors.border }]}>
      <View style={[styles.connectionIconWrap, { backgroundColor: meta.color + '20' }]}>
        <Ionicons name={meta.icon as any} size={16} color={meta.color} />
      </View>
      <View style={styles.connectionInfo}>
        <Text style={[styles.connectionName, { color: themeColors.textSecondary ?? themeColors.textMuted }]}>
          {meta.displayName}
        </Text>
        <Text style={[styles.connectionUsername, { color: themeColors.text ?? themeColors.textPrimary }]}>
          {account.name}
        </Text>
      </View>
      {account.verified && (
        <Ionicons name="checkmark-circle" size={16} color="#3BA55D" />
      )}
    </View>
  );
}

// ---- User Profile Presence Section ----

export function UserProfilePresence({ activities, connections }: UserProfilePresenceProps) {
  const { themeColors } = useTheme();

  return (
    <View>
      {/* Activities */}
      {activities.map((activity, i) => (
        <RichPresenceCard key={`activity-${i}`} activity={activity} themeColors={themeColors} />
      ))}

      {/* Connections */}
      {connections.length > 0 && (
        <View style={styles.connectionsSection}>
          <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
            CONNECTIONS
          </Text>
          {connections.map((conn) => (
            <ConnectedAccountCard key={`${conn.type}-${conn.id}`} account={conn} themeColors={themeColors} />
          ))}
        </View>
      )}
    </View>
  );
}

// ---- Styles ----

const styles = StyleSheet.create({
  card: {
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    marginVertical: spacing.xs,
    overflow: 'hidden',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginBottom: spacing.xs,
  },
  cardLabel: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
  },
  cardBody: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  assetContainer: {
    width: 60,
    height: 60,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
  },
  largeImage: {
    width: 60,
    height: 60,
    borderRadius: borderRadius.sm,
  },
  smallImage: {
    position: 'absolute',
    bottom: -4,
    right: -4,
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#2B2D31',
  },
  cardDetails: {
    flex: 1,
    justifyContent: 'center',
  },
  customStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  statusEmoji: {
    fontSize: 18,
  },
  statusText: {
    fontSize: 14,
  },
  detailTitle: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  detailSub: {
    fontSize: 12,
    marginTop: 2,
  },
  elapsedText: {
    fontSize: 12,
    marginTop: 4,
  },
  partyText: {
    fontSize: 12,
    marginTop: 2,
  },
  // Spotify progress
  progressContainer: {
    marginTop: spacing.xs,
  },
  progressBg: {
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
    marginTop: 2,
  },
  progressTime: {
    fontSize: 10,
  },
  // Action buttons
  buttonRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  actionButton: {
    flex: 1,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    alignItems: 'center',
  },
  actionButtonText: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  listenAlongButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.sm,
  },
  listenAlongText: {
    color: '#fff',
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  // Connections
  connectionsSection: {
    marginTop: spacing.sm,
  },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: spacing.xs,
    paddingHorizontal: spacing.sm,
  },
  connectionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.sm,
  },
  connectionIconWrap: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  connectionInfo: {
    flex: 1,
  },
  connectionName: {
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  connectionUsername: {
    fontSize: 14,
  },
});
