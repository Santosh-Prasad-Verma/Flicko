/**
 * User Status Picker Screen
 *
 * Set presence status (online/idle/dnd/invisible) and custom status.
 * Requirements: Feature 19 (User Status System)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useQueryClient } from '@tanstack/react-query';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import {
  PresenceStatus,
  CustomStatus,
  STATUS_OPTIONS,
  CUSTOM_STATUS_PRESETS,
  getPresence,
  setPresenceStatus,
  setCustomStatus,
} from '@services/userStatusService';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { useSettingsStore } from '@stores/settingsStore';

const EXPIRY_OPTIONS = [
  { label: "Don't clear", value: null },
  { label: '30 minutes', value: 30 * 60 * 1000 },
  { label: '1 hour', value: 60 * 60 * 1000 },
  { label: '4 hours', value: 4 * 60 * 60 * 1000 },
  { label: 'Today', value: null as number | null }, // computed at save time
];

export default function StatusScreen() {
  const userId = useAuthStore((s: AuthStore) => s.user?.id);
  const { themeColors: c } = useTheme();
  const queryClient = useQueryClient();

  const [loading, setLoading] = useState(true);
  const [currentStatus, setCurrentStatus] = useState<PresenceStatus>('online');
  const [customText, setCustomText] = useState('');
  const [customEmoji, setCustomEmoji] = useState('');
  const [expiryIndex, setExpiryIndex] = useState(0);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!userId) return;
    (async () => {
      try {
        const p = await getPresence(userId);
        if (p) {
          setCurrentStatus(p.status);
          if (p.custom_status) {
            setCustomText(p.custom_status.text || '');
            setCustomEmoji(p.custom_status.emoji || '');
          }
        }
      } catch {}
      setLoading(false);
    })();
  }, [userId]);

  const handleStatusChange = useCallback(async (status: PresenceStatus) => {
    if (!userId) return;
    setCurrentStatus(status);
    try {
      await setPresenceStatus(userId, status);
      queryClient.invalidateQueries({ queryKey: ['profile', userId] });
      router.back();
    } catch {}
  }, [userId, queryClient, router]);

  const handleSaveCustom = useCallback(async () => {
    if (!userId) return;
    setSaving(true);
    try {
      if (!customText && !customEmoji) {
        await setCustomStatus(userId, null);
      } else {
        let expiresAt: string | null = null;
        const opt = EXPIRY_OPTIONS[expiryIndex];
        if (opt.value) {
          expiresAt = new Date(Date.now() + opt.value).toISOString();
        }
        await setCustomStatus(userId, {
          text: customText || null,
          emoji: customEmoji || null,
          expires_at: expiresAt,
        });
      }
      queryClient.invalidateQueries({ queryKey: ['profile', userId] });
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e?.message || 'Failed to update status');
    }
    setSaving(false);
  }, [userId, customText, customEmoji, expiryIndex]);

  const handleClearCustom = useCallback(async () => {
    if (!userId) return;
    setCustomText('');
    setCustomEmoji('');
    try {
      await setCustomStatus(userId, null);
    } catch {}
  }, [userId]);

  if (loading) {
    return (
      <View style={[styles.center, { backgroundColor: c.bgPrimary }]}>
        <Stack.Screen options={{ title: 'Status' }} />
        <ActivityIndicator color={c.accentPrimary} />
      </View>
    );
  }

  return (
    <ScrollView style={[styles.container, { backgroundColor: c.bgPrimary }]} keyboardShouldPersistTaps="handled">
      <Stack.Screen
        options={{
          title: 'Set Status',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
          headerRight: () => (
            <Pressable onPress={handleSaveCustom} disabled={saving}>
              {saving ? (
                <ActivityIndicator color={c.accentPrimary} size="small" />
              ) : (
                <Text style={[styles.saveBtn, { color: c.accentPrimary }]}>Save</Text>
              )}
            </Pressable>
          ),
        }}
      />

      {/* Presence Status */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>STATUS</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        {STATUS_OPTIONS.map((opt) => {
          const selected = currentStatus === opt.value;
          return (
            <Pressable
              key={opt.value}
              style={[styles.statusRow, selected && { backgroundColor: c.bgTertiary }]}
              onPress={() => handleStatusChange(opt.value)}
            >
              <Ionicons name={opt.icon as any} size={18} color={opt.color} />
              <Text style={[styles.statusLabel, { color: c.textPrimary }]}>{opt.label}</Text>
              {selected && <Ionicons name="checkmark" size={20} color={c.accentPrimary} />}
            </Pressable>
          );
        })}
      </View>

      {/* Custom Status */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>CUSTOM STATUS</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        <View style={styles.customInputRow}>
          <Pressable
            style={[styles.emojiBtn, { backgroundColor: c.bgTertiary }]}
            onPress={() => {
              // Cycle through preset emojis as simple picker
              const emojis = CUSTOM_STATUS_PRESETS.map((p) => p.emoji);
              const idx = emojis.indexOf(customEmoji);
              setCustomEmoji(emojis[(idx + 1) % emojis.length]);
            }}
          >
            <Text style={styles.emojiText}>{customEmoji || '😀'}</Text>
          </Pressable>
          <TextInput
            style={[styles.customInput, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
            value={customText}
            onChangeText={setCustomText}
            placeholder="What are you up to?"
            placeholderTextColor={c.textMuted}
            maxLength={128}
          />
        </View>

        {(customText || customEmoji) && (
          <Pressable style={styles.clearBtn} onPress={handleClearCustom}>
            <Ionicons name="close-circle" size={16} color={c.danger} />
            <Text style={[styles.clearText, { color: c.danger }]}>Clear custom status</Text>
          </Pressable>
        )}
      </View>

      {/* Presets */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>QUICK SET</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        {CUSTOM_STATUS_PRESETS.map((preset, i) => (
          <Pressable
            key={i}
            style={({ pressed }) => [styles.presetRow, pressed && { backgroundColor: c.bgTertiary }]}
            onPress={() => {
              setCustomEmoji(preset.emoji);
              setCustomText(preset.text);
            }}
          >
            <Text style={styles.presetEmoji}>{preset.emoji}</Text>
            <Text style={[styles.presetText, { color: c.textPrimary }]}>{preset.text}</Text>
          </Pressable>
        ))}
      </View>

      {/* Expiry */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>CLEAR AFTER</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        {EXPIRY_OPTIONS.map((opt, i) => {
          const selected = expiryIndex === i;
          return (
            <Pressable
              key={i}
              style={[styles.expiryRow, selected && { backgroundColor: c.bgTertiary }]}
              onPress={() => setExpiryIndex(i)}
            >
              <Text style={[styles.expiryLabel, { color: c.textPrimary }]}>{opt.label}</Text>
              {selected && <Ionicons name="checkmark" size={18} color={c.accentPrimary} />}
            </Pressable>
          );
        })}
      </View>

      {/* Status Scheduling (Feature 18) */}
      <StatusScheduleSection />

      {/* Save Button */}
      <View style={styles.saveContainer}>
        <Pressable
          style={[styles.saveButton, { backgroundColor: c.accentPrimary, opacity: saving ? 0.6 : 1 }]}
          onPress={handleSaveCustom}
          disabled={saving}
        >
          {saving ? (
            <ActivityIndicator color="#fff" size="small" />
          ) : (
            <Text style={styles.saveButtonText}>Save</Text>
          )}
        </Pressable>
      </View>

      <View style={{ height: spacing.xxxxl }} />
    </ScrollView>
  );
}

const IDLE_TIMEOUT_OPTIONS = [1, 2, 5, 10, 15, 30];

function StatusScheduleSection() {
  const { themeColors: c } = useTheme();
  const { statusSchedule, updateStatusSchedule } = useSettingsStore();

  return (
    <>
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>AUTO STATUS</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        {/* Auto DND */}
        <View style={styles.scheduleRow}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.statusLabel, { color: c.textPrimary }]}>
              Scheduled Do Not Disturb
            </Text>
            <Text style={[styles.scheduleHint, { color: c.textMuted }]}>
              {statusSchedule.autoDndEnabled
                ? `${statusSchedule.autoDndStart} — ${statusSchedule.autoDndEnd}`
                : 'Automatically enable DND during set hours'}
            </Text>
          </View>
          <Pressable
            style={[
              styles.toggleTrack,
              {
                backgroundColor: statusSchedule.autoDndEnabled
                  ? c.accentPrimary
                  : c.bgTertiary,
              },
            ]}
            onPress={() =>
              updateStatusSchedule({ autoDndEnabled: !statusSchedule.autoDndEnabled })
            }
          >
            <View
              style={[
                styles.toggleThumb,
                statusSchedule.autoDndEnabled && styles.toggleThumbActive,
              ]}
            />
          </Pressable>
        </View>

        {statusSchedule.autoDndEnabled && (
          <View style={styles.timeRow}>
            <Pressable
              style={[styles.timeBtn, { backgroundColor: c.bgTertiary }]}
              onPress={() => {
                const [h, m] = statusSchedule.autoDndStart.split(':').map(Number);
                const newH = (h + 1) % 24;
                updateStatusSchedule({
                  autoDndStart: `${String(newH).padStart(2, '0')}:${String(m).padStart(2, '0')}`,
                });
              }}
            >
              <Text style={[styles.timeText, { color: c.textPrimary }]}>
                Start: {statusSchedule.autoDndStart}
              </Text>
            </Pressable>
            <Pressable
              style={[styles.timeBtn, { backgroundColor: c.bgTertiary }]}
              onPress={() => {
                const [h, m] = statusSchedule.autoDndEnd.split(':').map(Number);
                const newH = (h + 1) % 24;
                updateStatusSchedule({
                  autoDndEnd: `${String(newH).padStart(2, '0')}:${String(m).padStart(2, '0')}`,
                });
              }}
            >
              <Text style={[styles.timeText, { color: c.textPrimary }]}>
                End: {statusSchedule.autoDndEnd}
              </Text>
            </Pressable>
          </View>
        )}

        {/* Idle Timeout */}
        <View style={styles.scheduleRow}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.statusLabel, { color: c.textPrimary }]}>
              Idle Timeout
            </Text>
            <Text style={[styles.scheduleHint, { color: c.textMuted }]}>
              Set to idle after {statusSchedule.idleTimeoutMinutes} min of inactivity
            </Text>
          </View>
        </View>
        <View style={styles.idleChipRow}>
          {IDLE_TIMEOUT_OPTIONS.map((val) => (
            <Pressable
              key={val}
              style={[
                styles.idleChip,
                {
                  backgroundColor:
                    statusSchedule.idleTimeoutMinutes === val
                      ? c.accentPrimary
                      : c.bgTertiary,
                },
              ]}
              onPress={() => updateStatusSchedule({ idleTimeoutMinutes: val })}
            >
              <Text
                style={[
                  styles.idleChipText,
                  {
                    color:
                      statusSchedule.idleTimeoutMinutes === val
                        ? '#fff'
                        : c.textPrimary,
                  },
                ]}
              >
                {val}m
              </Text>
            </Pressable>
          ))}
        </View>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  sectionTitle: {
    ...typography.overline,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    paddingBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
    gap: spacing.md,
  },
  statusLabel: { ...typography.bodySmall, fontFamily: 'gg-sans-medium', flex: 1 },
  customInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    gap: spacing.sm,
  },
  emojiBtn: {
    width: 40,
    height: 40,
    borderRadius: borderRadius.sm,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emojiText: { fontSize: 22 },
  customInput: {
    flex: 1,
    height: 40,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    ...typography.bodySmall,
  },
  clearBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
  },
  clearText: { ...typography.caption },
  presetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
    gap: spacing.md,
  },
  presetEmoji: { fontSize: 20 },
  presetText: { ...typography.bodySmall },
  expiryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  expiryLabel: { ...typography.bodySmall },
  saveBtn: { ...typography.bodyBold },
  saveContainer: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.xl,
  },
  saveButton: {
    height: 48,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
  },
  scheduleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    gap: spacing.md,
  },
  scheduleHint: {
    ...typography.caption,
    marginTop: 2,
  },
  toggleTrack: {
    width: 48,
    height: 28,
    borderRadius: 14,
    padding: 2,
    justifyContent: 'center',
  },
  toggleThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#fff',
  },
  toggleThumbActive: {
    alignSelf: 'flex-end',
  },
  timeRow: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
    gap: spacing.sm,
  },
  timeBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  timeText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  idleChipRow: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
    gap: 8,
    flexWrap: 'wrap',
  },
  idleChip: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 16,
  },
  idleChipText: {
    fontSize: 13,
    fontFamily: 'gg-sans-medium',
  },
});
