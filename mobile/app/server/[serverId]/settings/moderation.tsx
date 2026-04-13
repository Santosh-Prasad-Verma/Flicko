/**
 * Moderation / Safety Setup Screen
 *
 * Configure verification level, explicit content filter, and content moderation.
 * Route: /server/[serverId]/settings/moderation
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

type VerificationLevel = 'none' | 'low' | 'medium' | 'high' | 'very_high';
type ContentFilter = 'disabled' | 'members_without_roles' | 'all_members';

const VERIFICATION_LEVELS: { value: VerificationLevel; label: string; description: string; icon: keyof typeof Ionicons.glyphMap }[] = [
  { value: 'none', label: 'None', description: 'Unrestricted', icon: 'shield-outline' },
  { value: 'low', label: 'Low', description: 'Must have a verified email on their account', icon: 'mail-outline' },
  { value: 'medium', label: 'Medium', description: 'Must be registered on Flicko for longer than 5 minutes', icon: 'time-outline' },
  { value: 'high', label: 'High', description: 'Must be a member of this server for longer than 10 minutes', icon: 'hourglass-outline' },
  { value: 'very_high', label: 'Highest', description: 'Must have a verified phone number', icon: 'phone-portrait-outline' },
];

const CONTENT_FILTERS: { value: ContentFilter; label: string; description: string }[] = [
  { value: 'disabled', label: "Don't scan any media", description: 'No messages screened' },
  { value: 'members_without_roles', label: 'Scan media from members without a role', description: 'Recommended for most servers' },
  { value: 'all_members', label: 'Scan media from all members', description: 'Maximum protection' },
];

export default function ModerationScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: server, isLoading } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('servers')
        .select('*')
        .eq('id', serverId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId,
  });

  const [verificationLevel, setVerificationLevel] = useState<VerificationLevel>('none');
  const [contentFilter, setContentFilter] = useState<ContentFilter>('disabled');
  const [hasChanges, setHasChanges] = useState(false);

  useEffect(() => {
    if (server) {
      setVerificationLevel(server.verification_level || 'none');
      setContentFilter(server.explicit_content_filter || 'disabled');
    }
  }, [server]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase
        .from('servers')
        .update({
          verification_level: verificationLevel,
          explicit_content_filter: contentFilter,
        })
        .eq('id', serverId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server', serverId] });
      setHasChanges(false);
      Alert.alert('Saved', 'Moderation settings updated.');
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  if (isLoading) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary, justifyContent: 'center', alignItems: 'center' }]}>
        <ActivityIndicator size="large" color={themeColors.accentPrimary} />
      </View>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Safety Setup</Text>
          <Pressable
            onPress={() => saveMutation.mutate()}
            disabled={!hasChanges || saveMutation.isPending}
            style={[styles.saveBtn, { opacity: hasChanges ? 1 : 0.4 }]}
          >
            {saveMutation.isPending ? (
              <ActivityIndicator size="small" color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.saveText, { color: themeColors.accentPrimary }]}>Save</Text>
            )}
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={{ padding: spacing.lg, paddingBottom: insets.bottom + 40 }}>
          {/* Verification Level */}
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>VERIFICATION LEVEL</Text>
          <Text style={[styles.sectionDesc, { color: themeColors.textSecondary }]}>
            Members must meet these criteria before they can send messages in text channels
          </Text>

          {VERIFICATION_LEVELS.map((level) => (
            <Pressable
              key={level.value}
              onPress={() => { setVerificationLevel(level.value); setHasChanges(true); }}
              style={[
                styles.optionCard,
                {
                  backgroundColor: verificationLevel === level.value
                    ? themeColors.accentPrimary + '15'
                    : themeColors.bgSecondary,
                  borderColor: verificationLevel === level.value
                    ? themeColors.accentPrimary
                    : 'transparent',
                },
              ]}
            >
              <Ionicons
                name={level.icon}
                size={20}
                color={verificationLevel === level.value ? themeColors.accentPrimary : themeColors.textMuted}
              />
              <View style={styles.optionInfo}>
                <Text style={[styles.optionLabel, { color: themeColors.textPrimary }]}>
                  {level.label}
                </Text>
                <Text style={[styles.optionDesc, { color: themeColors.textMuted }]}>
                  {level.description}
                </Text>
              </View>
              <View style={[
                styles.radio,
                {
                  borderColor: verificationLevel === level.value ? themeColors.accentPrimary : themeColors.textMuted,
                },
              ]}>
                {verificationLevel === level.value && (
                  <View style={[styles.radioDot, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>
          ))}

          {/* Content Filter */}
          <Text style={[styles.sectionTitle, { color: themeColors.textMuted, marginTop: spacing.xl }]}>
            EXPLICIT MEDIA CONTENT FILTER
          </Text>
          <Text style={[styles.sectionDesc, { color: themeColors.textSecondary }]}>
            Automatically scan and delete messages that contain explicit content
          </Text>

          {CONTENT_FILTERS.map((filter) => (
            <Pressable
              key={filter.value}
              onPress={() => { setContentFilter(filter.value); setHasChanges(true); }}
              style={[
                styles.optionCard,
                {
                  backgroundColor: contentFilter === filter.value
                    ? themeColors.accentPrimary + '15'
                    : themeColors.bgSecondary,
                  borderColor: contentFilter === filter.value
                    ? themeColors.accentPrimary
                    : 'transparent',
                },
              ]}
            >
              <View style={styles.optionInfo}>
                <Text style={[styles.optionLabel, { color: themeColors.textPrimary }]}>
                  {filter.label}
                </Text>
                <Text style={[styles.optionDesc, { color: themeColors.textMuted }]}>
                  {filter.description}
                </Text>
              </View>
              <View style={[
                styles.radio,
                {
                  borderColor: contentFilter === filter.value ? themeColors.accentPrimary : themeColors.textMuted,
                },
              ]}>
                {contentFilter === filter.value && (
                  <View style={[styles.radioDot, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  saveBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveText: { fontSize: 16, fontFamily: 'gg-sans-semibold' },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
  },
  sectionDesc: {
    fontSize: 13,
    marginBottom: spacing.md,
    lineHeight: 18,
  },
  optionCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.sm,
    borderWidth: 1,
    gap: spacing.md,
  },
  optionInfo: { flex: 1 },
  optionLabel: { fontSize: 15, fontFamily: 'gg-sans-semibold' },
  optionDesc: { fontSize: 12, marginTop: 2 },
  radio: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
});
