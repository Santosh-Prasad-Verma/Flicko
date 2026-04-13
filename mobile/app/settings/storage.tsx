/**
 * Data & Storage Settings
 * Route: /settings/storage
 */
import React, { useCallback } from 'react';
import { View, Text, StyleSheet, Switch, ScrollView, Pressable, Alert } from 'react-native';
import { Stack, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

export default function StorageSettingsScreen() {
  const { themeColors } = useTheme();
  const dataStorage = useSettingsStore((s) => s.dataStorage);
  const updateDataStorage = useSettingsStore((s) => s.updateDataStorage);

  const handleClearCache = useCallback(() => {
    Alert.alert(
      'Clear Cache',
      'This will clear cached images and files managed by the app cache directory.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear',
          style: 'destructive',
          onPress: async () => {
            try {
              await Image.clearDiskCache();
              await Image.clearMemoryCache();
              Alert.alert('Done', 'Image cache cleared.');
            } catch (e: any) {
              Alert.alert('Error', e?.message || 'Could not clear cache');
            }
          },
        },
      ],
    );
  }, []);

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Data & Storage',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>AUTO-DOWNLOAD</Text>

          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
            <View style={[styles.row, { borderBottomColor: themeColors.border }]}>
              <View style={styles.rowInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Images</Text>
                <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>Auto-download images</Text>
              </View>
              <Switch
                value={dataStorage.autoDownloadImages}
                onValueChange={(v) => updateDataStorage({ autoDownloadImages: v })}
                trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
                thumbColor="#fff"
              />
            </View>

            <View style={[styles.row, { borderBottomColor: themeColors.border }]}>
              <View style={styles.rowInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Videos</Text>
                <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>Auto-download videos on Wi-Fi</Text>
              </View>
              <Switch
                value={dataStorage.autoDownloadVideos}
                onValueChange={(v) => updateDataStorage({ autoDownloadVideos: v })}
                trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
                thumbColor="#fff"
              />
            </View>

            <View style={styles.row}>
              <View style={styles.rowInfo}>
                <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Files</Text>
                <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>Auto-download files</Text>
              </View>
              <Switch
                value={dataStorage.autoDownloadFiles}
                onValueChange={(v) => updateDataStorage({ autoDownloadFiles: v })}
                trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
                thumbColor="#fff"
              />
            </View>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>STORAGE</Text>

          <Pressable
            style={[styles.card, styles.clearCard, { backgroundColor: themeColors.bgSecondary }]}
            onPress={handleClearCache}
          >
            <View style={styles.rowInfo}>
              <Text style={[styles.rowLabel, { color: themeColors.danger }]}>Clear Cache</Text>
              <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>
                Free up space by clearing cached data
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
          </Pressable>
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  section: { marginTop: spacing.md },
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginHorizontal: spacing.md,
    marginBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: 12,
    overflow: 'hidden',
  },
  clearCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  rowInfo: { flex: 1, paddingRight: spacing.sm },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowDesc: { ...typography.caption, marginTop: 2 },
});
