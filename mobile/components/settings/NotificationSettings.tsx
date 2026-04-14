/**
 * NotificationSettings
 *
 * Per-channel and per-server notification preference UI.
 * Supports: All messages, Mentions only, Nothing, Mute with duration.
 * Settings stored in Supabase `notification_settings` or locally via AsyncStorage.
 *
 * Requirements: Feature 21 (Notification Settings)
 */
import React, { memo, useState, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Switch,
  ScrollView,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeIn } from 'react-native-reanimated';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';

// ── Types ───────────────────────────────────────────────────────────────

export type NotificationLevel = 'all' | 'mentions' | 'nothing';

export interface NotificationPrefs {
  level: NotificationLevel;
  muted: boolean;
  muteUntil: string | null; // ISO timestamp
  suppressEveryone: boolean;
  suppressRoles: boolean;
  mobilePush: boolean;
}

const DEFAULT_PREFS: NotificationPrefs = {
  level: 'all',
  muted: false,
  muteUntil: null,
  suppressEveryone: false,
  suppressRoles: false,
  mobilePush: true,
};

const MUTE_DURATIONS = [
  { label: '15 minutes', seconds: 15 * 60 },
  { label: '1 hour', seconds: 60 * 60 },
  { label: '8 hours', seconds: 8 * 60 * 60 },
  { label: '24 hours', seconds: 24 * 60 * 60 },
  { label: 'Until I turn it back on', seconds: 0 },
] as const;

const PREFS_PREFIX = '@flicko:notif_prefs:';

interface NotificationSettingsProps {
  /** Channel or server ID */
  targetId: string;
  targetType: 'channel' | 'server';
  targetName: string;
  onClose?: () => void;
}

// ── Component ───────────────────────────────────────────────────────────

export const NotificationSettings = memo(function NotificationSettings({
  targetId,
  targetType,
  targetName,
  onClose,
}: NotificationSettingsProps) {
  const { themeColors } = useTheme();
  const [prefs, setPrefs] = useState<NotificationPrefs>(DEFAULT_PREFS);
  const [showMutePicker, setShowMutePicker] = useState(false);

  // Load saved prefs
  useEffect(() => {
    AsyncStorage.getItem(`${PREFS_PREFIX}${targetId}`).then((val) => {
      if (val) {
        try {
          const parsed = JSON.parse(val);
          // Check if mute expired
          if (parsed.muteUntil && new Date(parsed.muteUntil) < new Date()) {
            parsed.muted = false;
            parsed.muteUntil = null;
          }
          setPrefs({ ...DEFAULT_PREFS, ...parsed });
        } catch {}
      }
    });
  }, [targetId]);

  // Persist prefs
  const savePrefs = useCallback(
    async (updated: NotificationPrefs) => {
      setPrefs(updated);
      await AsyncStorage.setItem(`${PREFS_PREFIX}${targetId}`, JSON.stringify(updated));
    },
    [targetId],
  );

  const handleLevelChange = useCallback(
    (level: NotificationLevel) => {
      savePrefs({ ...prefs, level });
    },
    [prefs, savePrefs],
  );

  const handleMute = useCallback(
    (seconds: number) => {
      const muteUntil =
        seconds > 0 ? new Date(Date.now() + seconds * 1000).toISOString() : null;
      savePrefs({ ...prefs, muted: true, muteUntil });
      setShowMutePicker(false);
    },
    [prefs, savePrefs],
  );

  const handleUnmute = useCallback(() => {
    savePrefs({ ...prefs, muted: false, muteUntil: null });
  }, [prefs, savePrefs]);

  const RadioOption = ({
    label,
    description,
    selected,
    onPress,
  }: {
    label: string;
    description: string;
    selected: boolean;
    onPress: () => void;
  }) => (
    <Pressable onPress={onPress} style={[styles.radioRow, { borderColor: themeColors.border }]}>
      <View style={styles.radioTextCol}>
        <Text style={[styles.radioLabel, { color: themeColors.textPrimary }]}>{label}</Text>
        <Text style={[styles.radioDesc, { color: themeColors.textMuted }]}>{description}</Text>
      </View>
      <View
        style={[
          styles.radioCircle,
          { borderColor: selected ? themeColors.accentPrimary : themeColors.textMuted },
        ]}
      >
        {selected && (
          <View style={[styles.radioDot, { backgroundColor: themeColors.accentPrimary }]} />
        )}
      </View>
    </Pressable>
  );

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
    >
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: themeColors.border }]}>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
          Notification Settings
        </Text>
        <Text style={[styles.headerSubtitle, { color: themeColors.textMuted }]}>
          {targetType === 'channel' ? '#' : ''}{targetName}
        </Text>
        {onClose && (
          <Pressable onPress={onClose} style={styles.closeBtn} hitSlop={12}>
            <Ionicons name="close" size={22} color={themeColors.textMuted} />
          </Pressable>
        )}
      </View>

      <ScrollView contentContainerStyle={styles.body}>
        {/* Mute Toggle */}
        <View style={[styles.section, { borderBottomColor: themeColors.border }]}>
          <View style={styles.switchRow}>
            <View style={styles.switchText}>
              <Text style={[styles.sectionLabel, { color: themeColors.textPrimary }]}>
                Mute {targetType === 'channel' ? 'Channel' : 'Server'}
              </Text>
              {prefs.muted && prefs.muteUntil && (
                <Text style={[styles.muteUntilText, { color: themeColors.warning }]}>
                  Until {new Date(prefs.muteUntil).toLocaleString()}
                </Text>
              )}
              {prefs.muted && !prefs.muteUntil && (
                <Text style={[styles.muteUntilText, { color: themeColors.warning }]}>
                  Muted indefinitely
                </Text>
              )}
            </View>
            <Switch
              value={prefs.muted}
              onValueChange={(val) => {
                if (val) {
                  setShowMutePicker(true);
                } else {
                  handleUnmute();
                }
              }}
              trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              thumbColor="#FFFFFF"
            />
          </View>

          {/* Mute duration picker */}
          {showMutePicker && (
            <View style={styles.mutePicker}>
              {MUTE_DURATIONS.map((d) => (
                <Pressable
                  key={d.label}
                  onPress={() => handleMute(d.seconds)}
                  style={[styles.muteOption, { backgroundColor: themeColors.bgTertiary }]}
                >
                  <Text style={[styles.muteOptionText, { color: themeColors.textPrimary }]}>
                    {d.label}
                  </Text>
                </Pressable>
              ))}
            </View>
          )}
        </View>

        {/* Notification Level */}
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
            NOTIFICATION FREQUENCY
          </Text>
          <RadioOption
            label="All Messages"
            description="Get notified for every new message"
            selected={prefs.level === 'all'}
            onPress={() => handleLevelChange('all')}
          />
          <RadioOption
            label="Only @Mentions"
            description="Only when you're mentioned or @everyone"
            selected={prefs.level === 'mentions'}
            onPress={() => handleLevelChange('mentions')}
          />
          <RadioOption
            label="Nothing"
            description="You won't get any notifications"
            selected={prefs.level === 'nothing'}
            onPress={() => handleLevelChange('nothing')}
          />
        </View>

        {/* Suppress toggles */}
        <View style={[styles.section, { borderTopColor: themeColors.border, borderTopWidth: 1 }]}>
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
            OVERRIDES
          </Text>
          <View style={styles.switchRow}>
            <Text style={[styles.switchLabel, { color: themeColors.textPrimary }]}>
              Suppress @everyone and @here
            </Text>
            <Switch
              value={prefs.suppressEveryone}
              onValueChange={(val) => savePrefs({ ...prefs, suppressEveryone: val })}
              trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              thumbColor="#FFFFFF"
            />
          </View>
          <View style={styles.switchRow}>
            <Text style={[styles.switchLabel, { color: themeColors.textPrimary }]}>
              Suppress role @mentions
            </Text>
            <Switch
              value={prefs.suppressRoles}
              onValueChange={(val) => savePrefs({ ...prefs, suppressRoles: val })}
              trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              thumbColor="#FFFFFF"
            />
          </View>
          <View style={styles.switchRow}>
            <Text style={[styles.switchLabel, { color: themeColors.textPrimary }]}>
              Mobile Push Notifications
            </Text>
            <Switch
              value={prefs.mobilePush}
              onValueChange={(val) => savePrefs({ ...prefs, mobilePush: val })}
              trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              thumbColor="#FFFFFF"
            />
          </View>
        </View>
      </ScrollView>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
  },
  header: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  headerSubtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  closeBtn: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
  },
  body: {
    paddingBottom: spacing.xl,
  },
  section: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: spacing.sm,
  },
  sectionLabel: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
  },
  switchText: {
    flex: 1,
    marginRight: spacing.md,
  },
  switchLabel: {
    fontSize: 14,
    flex: 1,
    marginRight: spacing.md,
  },
  muteUntilText: {
    fontSize: 11,
    marginTop: 2,
  },
  mutePicker: {
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  muteOption: {
    paddingVertical: spacing.sm + 2,
    paddingHorizontal: spacing.md,
    borderRadius: borderRadius.md,
  },
  muteOptionText: {
    fontSize: 14,
  },
  radioRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  radioTextCol: {
    flex: 1,
    marginRight: spacing.md,
  },
  radioLabel: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  radioDesc: {
    fontSize: 12,
    marginTop: 2,
  },
  radioCircle: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  radioDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
});
