/**
 * GoLiveModal — "Go Live" configuration sheet
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Modal as RNModal,
} from 'react-native';
import { useTheme } from '@/hooks/useTheme';
import { Ionicons } from '@expo/vector-icons';
import { SCREEN_SHARE_PRESETS } from '@services/mediaService';

interface GoLiveModalProps {
  visible: boolean;
  onClose: () => void;
  onGoLive: (config: {
    title: string;
    streamType: 'screen' | 'application' | 'game' | 'camera';
    quality: string;
  }) => Promise<void>;
  loading: boolean;
}

const STREAM_TYPES = [
  { key: 'screen' as const, icon: 'desktop-outline', label: 'Screen' },
  { key: 'game' as const, icon: 'game-controller-outline', label: 'Game' },
  { key: 'application' as const, icon: 'apps-outline', label: 'Application' },
  { key: 'camera' as const, icon: 'videocam-outline', label: 'Camera' },
];

export function GoLiveModal({ visible, onClose, onGoLive, loading }: GoLiveModalProps) {
  const { themeColors } = useTheme();
  const [title, setTitle] = useState('');
  const [streamType, setStreamType] = useState<'screen' | 'application' | 'game' | 'camera'>('screen');
  const [quality, setQuality] = useState('720p30');

  const handleGoLive = useCallback(async () => {
    await onGoLive({ title: title || 'Live Stream', streamType, quality });
    // Don't auto-close - let parent handle it
  }, [title, streamType, quality, onGoLive]);

  return (
    <RNModal visible={visible} onRequestClose={onClose} animationType="slide" transparent>
      <View style={styles.backdrop}>
        <View style={[styles.sheet, { backgroundColor: themeColors.bgPrimary }]}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Go Live</Text>
            <Pressable onPress={onClose} hitSlop={8}>
              <Ionicons name="close" size={24} color={themeColors.textSecondary} />
            </Pressable>
          </View>

          <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
            {/* Title */}
            <View style={styles.section}>
              <Text style={[styles.label, { color: themeColors.textSecondary }]}>STREAM TITLE</Text>
              <TextInput
                value={title}
                onChangeText={setTitle}
                placeholder="What are you streaming?"
                placeholderTextColor={themeColors.textMuted}
                style={[
                  styles.input,
                  {
                    backgroundColor: themeColors.inputBg,
                    color: themeColors.textPrimary,
                    borderColor: themeColors.border,
                  },
                ]}
                maxLength={100}
              />
            </View>

            {/* Stream Type */}
            <View style={styles.section}>
              <Text style={[styles.label, { color: themeColors.textSecondary }]}>STREAM TYPE</Text>
              <View style={styles.typeGrid}>
                {STREAM_TYPES.map((type) => (
                  <Pressable
                    key={type.key}
                    onPress={() => setStreamType(type.key)}
                    style={[
                      styles.typeOption,
                      {
                        backgroundColor:
                          streamType === type.key ? 'rgba(88,101,242,0.2)' : themeColors.bgTertiary,
                        borderColor: streamType === type.key ? '#5865f2' : themeColors.border,
                      },
                    ]}
                  >
                    <Ionicons
                      name={type.icon as any}
                      size={24}
                      color={streamType === type.key ? '#5865f2' : themeColors.textSecondary}
                    />
                    <Text
                      style={[
                        styles.typeLabel,
                        { color: streamType === type.key ? '#5865f2' : themeColors.textPrimary },
                      ]}
                    >
                      {type.label}
                    </Text>
                  </Pressable>
                ))}
              </View>
            </View>

            {/* Quality */}
            <View style={styles.section}>
              <Text style={[styles.label, { color: themeColors.textSecondary }]}>STREAM QUALITY</Text>
              {Object.entries(SCREEN_SHARE_PRESETS).map(([key, preset]) => {
                const isSelected = quality === key;
                const isNitro = key === '1080p30' || key === '1080p60';

                return (
                  <Pressable
                    key={key}
                    onPress={() => setQuality(key)}
                    style={[
                      styles.qualityOption,
                      {
                        backgroundColor: isSelected ? 'rgba(88,101,242,0.1)' : themeColors.bgTertiary,
                        borderColor: isSelected ? '#5865f2' : 'transparent',
                      },
                    ]}
                  >
                    <View style={styles.qualityInfo}>
                      <Text style={[styles.qualityName, { color: themeColors.textPrimary }]}>
                        {preset.name}
                      </Text>
                      <Text style={[styles.qualityDetail, { color: themeColors.textSecondary }]}>
                        {preset.width}x{preset.height} @ {preset.fps}fps
                      </Text>
                    </View>

                    <View style={styles.qualityRight}>
                      {isNitro && (
                        <View style={[styles.nitroBadge, { backgroundColor: '#f47fff' }]}>
                          <Text style={styles.nitroText}>NITRO</Text>
                        </View>
                      )}
                      {isSelected && <Ionicons name="checkmark-circle" size={22} color="#5865f2" />}
                    </View>
                  </Pressable>
                );
              })}
            </View>

            {/* Go Live Button */}
            <Pressable
              onPress={handleGoLive}
              disabled={loading}
              style={[styles.goLiveButton, loading && { opacity: 0.6 }]}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <View style={styles.goLiveContent}>
                  <Ionicons name="radio" size={18} color="#fff" />
                  <Text style={styles.goLiveText}>Go Live</Text>
                </View>
              )}
            </Pressable>
          </ScrollView>
        </View>
      </View>
    </RNModal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  sheet: {
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    maxHeight: '80%',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerTitle: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  content: {
    padding: 16,
  },
  section: {
    marginBottom: 20,
  },
  label: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  input: {
    height: 44,
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 12,
    fontSize: 15,
  },
  typeGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  typeOption: {
    flex: 1,
    minWidth: '45%',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 16,
    borderRadius: 10,
    borderWidth: 2,
  },
  typeLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  qualityOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1.5,
    marginBottom: 6,
  },
  qualityInfo: { gap: 2 },
  qualityName: { fontSize: 14, fontFamily: 'gg-sans-semibold' },
  qualityDetail: { fontSize: 12 },
  qualityRight: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  nitroBadge: { paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 },
  nitroText: { color: '#fff', fontSize: 9, fontFamily: 'gg-sans-bold' },
  goLiveButton: {
    backgroundColor: '#5865f2',
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 32,
  },
  goLiveContent: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  goLiveText: { color: '#fff', fontSize: 16, fontFamily: 'gg-sans-bold' },
});
