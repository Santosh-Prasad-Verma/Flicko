/**
 * VideoSettings — Video settings screen (preferences)
 */
import React, { useEffect, useState, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, Switch, Pressable } from 'react-native';
import { useTheme } from '../../hooks/useTheme';
import { Ionicons } from '@expo/vector-icons';
import * as videoSettingsService from '@services/videoSettingsService';
import { QualitySelector } from './QualitySelector';

interface VideoSettingsProps {
  onClose?: () => void;
}

export function VideoSettings({ onClose }: VideoSettingsProps) {
  const { themeColors } = useTheme();
  const [settings, setSettings] = useState<videoSettingsService.VideoSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const data = await videoSettingsService.getVideoSettings();
      setSettings(data);
    } catch (error) {
      console.error('Failed to load video settings:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateSetting = useCallback(
    async (key: string, value: any) => {
      if (!settings) return;
      const updated = { ...settings, [key]: value };
      setSettings(updated);

      try {
        await videoSettingsService.updateVideoSettings({ [key]: value });
      } catch (error) {
        console.error('Failed to update setting:', error);
        setSettings(settings); // revert
      }
    },
    [settings],
  );

  if (loading || !settings) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <Text style={[styles.loadingText, { color: themeColors.textSecondary }]}>Loading...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Video Settings</Text>
        {onClose && (
          <Pressable onPress={onClose} hitSlop={8}>
            <Ionicons name="close" size={24} color={themeColors.textSecondary} />
          </Pressable>
        )}
      </View>

      {/* Camera section */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>CAMERA</Text>

        <SettingRow
          label="Default Camera"
          value={settings.default_camera === 'front' ? 'Front' : 'Back'}
          onPress={() =>
            updateSetting('default_camera', settings.default_camera === 'front' ? 'back' : 'front')
          }
          colors={themeColors}
        />

        <SwitchRow
          label="Always Preview Video"
          description="Show a preview before turning on your camera"
          value={settings.always_preview}
          onToggle={(v) => updateSetting('always_preview', v)}
          colors={themeColors}
        />

        <SwitchRow
          label="Mirror Self View"
          description="Mirror your own camera feed"
          value={settings.mirror_video}
          onToggle={(v) => updateSetting('mirror_video', v)}
          colors={themeColors}
        />
      </View>

      {/* Quality section */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>QUALITY</Text>

        <QualitySelector
          currentQuality={settings.default_quality}
          onSelectQuality={(q) => updateSetting('default_quality', q)}
        />

        <View style={styles.spacer} />

        <SwitchRow
          label="Hardware Acceleration"
          description="Use GPU for video encoding/decoding"
          value={settings.hardware_acceleration}
          onToggle={(v) => updateSetting('hardware_acceleration', v)}
          colors={themeColors}
        />

        <SwitchRow
          label="Data Saver Mode"
          description="Reduce video quality to save data"
          value={settings.data_saver_mode}
          onToggle={(v) => updateSetting('data_saver_mode', v)}
          colors={themeColors}
        />
      </View>

      {/* PiP section */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
          PICTURE-IN-PICTURE
        </Text>

        <SwitchRow
          label="Enable PiP"
          description="Show floating video when leaving the voice channel screen"
          value={settings.pip_enabled}
          onToggle={(v) => updateSetting('pip_enabled', v)}
          colors={themeColors}
        />
      </View>

      <View style={{ height: 40 }} />
    </ScrollView>
  );
}

// ── Reusable Setting Rows ──

function SettingRow({
  label,
  value,
  onPress,
  colors,
}: {
  label: string;
  value: string;
  onPress: () => void;
  colors: any;
}) {
  return (
    <Pressable onPress={onPress} style={[styles.row, { borderBottomColor: colors.border }]}>
      <Text style={[styles.rowLabel, { color: colors.textPrimary }]}>{label}</Text>
      <View style={styles.rowRight}>
        <Text style={[styles.rowValue, { color: colors.textSecondary }]}>{value}</Text>
        <Ionicons name="chevron-forward" size={16} color={colors.textMuted} />
      </View>
    </Pressable>
  );
}

function SwitchRow({
  label,
  description,
  value,
  onToggle,
  colors,
}: {
  label: string;
  description?: string;
  value: boolean;
  onToggle: (v: boolean) => void;
  colors: any;
}) {
  return (
    <View style={[styles.row, { borderBottomColor: colors.border }]}>
      <View style={styles.rowTextContent}>
        <Text style={[styles.rowLabel, { color: colors.textPrimary }]}>{label}</Text>
        {description && (
          <Text style={[styles.rowDescription, { color: colors.textMuted }]}>{description}</Text>
        )}
      </View>
      <Switch
        value={value}
        onValueChange={onToggle}
        trackColor={{ false: colors.bgTertiary, true: '#5865f2' }}
        thumbColor="#fff"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingText: { textAlign: 'center', marginTop: 40, fontSize: 14 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerTitle: { fontSize: 18, fontFamily: 'gg-sans-bold' },
  section: { paddingHorizontal: 16, marginBottom: 24 },
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: 12,
  },
  spacer: { height: 12 },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  rowTextContent: { flex: 1, marginRight: 12 },
  rowLabel: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  rowDescription: { fontSize: 12, marginTop: 2 },
  rowRight: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  rowValue: { fontSize: 14 },
});
