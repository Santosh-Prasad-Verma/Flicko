/**
 * Voice & Video Settings
 * Features: 21 (Noise Suppression), 22 (Push to Talk)
 * Route: /settings/voice
 */
import React from 'react';
import { View, Text, StyleSheet, Switch, ScrollView, Pressable } from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

export default function VoiceSettingsScreen() {
  const { themeColors } = useTheme();
  const voice = useSettingsStore((s) => s.voice);
  const updateVoice = useSettingsStore((s) => s.updateVoice);

  const noiseOptions: { label: string; value: 'off' | 'low' | 'high' }[] = [
    { label: 'Off', value: 'off' },
    { label: 'Low', value: 'low' },
    { label: 'High (Krisp-like)', value: 'high' },
  ];

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Voice & Video',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Input Mode */}
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>INPUT MODE</Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {(['voice_activity', 'push_to_talk'] as const).map((mode, i) => (
            <Pressable
              key={mode}
              style={[
                styles.radioRow,
                i === 0 && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border },
              ]}
              onPress={() => updateVoice({ inputMode: mode })}
            >
              <View style={styles.radioInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>
                  {mode === 'voice_activity' ? 'Voice Activity' : 'Push to Talk'}
                </Text>
                <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>
                  {mode === 'voice_activity' ? 'Automatically transmit when you speak' : 'Hold a button to transmit audio'}
                </Text>
              </View>
              <View style={[styles.radio, { borderColor: voice.inputMode === mode ? themeColors.accentPrimary : themeColors.textMuted }]}>
                {voice.inputMode === mode && <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />}
              </View>
            </Pressable>
          ))}
        </View>

        {/* Noise Suppression */}
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>NOISE SUPPRESSION</Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {noiseOptions.map((opt, i) => (
            <Pressable
              key={opt.value}
              style={[
                styles.radioRow,
                i < noiseOptions.length - 1 && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border },
              ]}
              onPress={() => updateVoice({ noiseSuppression: opt.value })}
            >
              <Text style={[styles.rowLabel, { color: themeColors.textPrimary, flex: 1 }]}>{opt.label}</Text>
              <View style={[styles.radio, { borderColor: voice.noiseSuppression === opt.value ? themeColors.accentPrimary : themeColors.textMuted }]}>
                {voice.noiseSuppression === opt.value && <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />}
              </View>
            </Pressable>
          ))}
        </View>

        {/* Voice Processing */}
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>VOICE PROCESSING</Text>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={[styles.toggleRow, { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border }]}>
            <View style={styles.radioInfo}>
              <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Echo Cancellation</Text>
              <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>Auto-cancel echoes during calls</Text>
            </View>
            <Switch value={voice.echoCancellation} onValueChange={(v) => updateVoice({ echoCancellation: v })} trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }} thumbColor="#fff" />
          </View>
          <View style={styles.toggleRow}>
            <View style={styles.radioInfo}>
              <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Automatic Gain Control</Text>
              <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>Automatically adjust mic volume</Text>
            </View>
            <Switch value={voice.autoGainControl} onValueChange={(v) => updateVoice({ autoGainControl: v })} trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }} thumbColor="#fff" />
          </View>
        </View>

        {/* Sensitivity (only for voice activity) */}
        {voice.inputMode === 'voice_activity' && (
          <>
            <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>VOICE SENSITIVITY</Text>
            <View style={[styles.card, { backgroundColor: themeColors.bgSecondary, padding: spacing.md }]}>
              <View style={styles.sliderRow}>
                <Ionicons name="volume-low" size={18} color={themeColors.textMuted} />
                <View style={styles.sliderTrack}>
                  {[0, 25, 50, 75, 100].map((val) => (
                    <Pressable
                      key={val}
                      onPress={() => updateVoice({ voiceActivityThreshold: val })}
                      style={[
                        styles.sliderDot,
                        {
                          backgroundColor: voice.voiceActivityThreshold >= val ? themeColors.accentPrimary : themeColors.bgTertiary,
                        },
                      ]}
                    />
                  ))}
                </View>
                <Ionicons name="volume-high" size={18} color={themeColors.textMuted} />
              </View>
              <Text style={[styles.sliderLabel, { color: themeColors.textMuted }]}>
                Threshold: {voice.voiceActivityThreshold}%
              </Text>
            </View>
          </>
        )}
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  sectionTitle: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', paddingHorizontal: spacing.md + spacing.sm, marginTop: spacing.lg, marginBottom: spacing.sm },
  card: { marginHorizontal: spacing.md, borderRadius: 12, overflow: 'hidden' },
  radioRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, minHeight: MINIMUM_TOUCH_TARGET },
  toggleRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, minHeight: MINIMUM_TOUCH_TARGET },
  radioInfo: { flex: 1, marginRight: spacing.md },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowDesc: { ...typography.caption, marginTop: 2 },
  radio: { width: 22, height: 22, borderRadius: 11, borderWidth: 2, justifyContent: 'center', alignItems: 'center' },
  radioInner: { width: 12, height: 12, borderRadius: 6 },
  sliderRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  sliderTrack: { flex: 1, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  sliderDot: { width: 20, height: 20, borderRadius: 10 },
  sliderLabel: { ...typography.caption, textAlign: 'center', marginTop: spacing.sm },
});
