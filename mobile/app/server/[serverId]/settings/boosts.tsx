/**
 * Server Boosts Screen
 *
 * View boost tier progress, perks, boosters list, and boost action.
 * Requirements: Feature 26 (Server Boosts)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  FlatList,
  Pressable,
  Alert,
  ActivityIndicator,
  Image,
} from 'react-native';
import { useLocalSearchParams, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  BoostStatus,
  BOOST_TIERS,
  getBoostStatus,
  boostServer,
  getNextTier,
} from '@services/boostService';
import { useAuthStore } from '@stores/authStore';

export default function BoostsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const userId = useAuthStore((s: any) => s.user?.id);
  const { themeColors: c } = useTheme();

  const [status, setStatus] = useState<BoostStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [boosting, setBoosting] = useState(false);

  const fetch = useCallback(async () => {
    if (!serverId) return;
    try { setStatus(await getBoostStatus(serverId)); } catch {}
    setLoading(false);
  }, [serverId]);

  useEffect(() => { fetch(); }, [fetch]);

  const handleBoost = async () => {
    if (!serverId || !userId) return;
    setBoosting(true);
    try {
      await boostServer(serverId, userId);
      await fetch();
    } catch (e: any) {
      Alert.alert('Error', e?.message || 'Failed to boost');
    }
    setBoosting(false);
  };

  if (loading || !status) {
    return (
      <View style={[styles.center, { backgroundColor: c.bgPrimary }]}>
        <Stack.Screen options={{ title: 'Server Boost' }} />
        <ActivityIndicator color={c.accentPrimary} />
      </View>
    );
  }

  const nextTier = getNextTier(status.tier);
  const progress = nextTier
    ? ((status.boost_count - status.tier.requiredBoosts) / (nextTier.requiredBoosts - status.tier.requiredBoosts)) * 100
    : 100;

  return (
    <ScrollView style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'Server Boost',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
        }}
      />

      {/* Tier card */}
      <View style={[styles.tierCard, { backgroundColor: c.bgSecondary }]}>
        <Ionicons name="flash" size={36} color="#FF73FA" />
        <Text style={[styles.tierName, { color: c.textPrimary }]}>{status.tier.name}</Text>
        <Text style={[styles.boostCount, { color: c.textSecondary }]}>
          {status.boost_count} Boost{status.boost_count !== 1 ? 's' : ''}
        </Text>

        {nextTier && (
          <View style={styles.progressSection}>
            <View style={[styles.progressBar, { backgroundColor: c.border }]}>
              <View style={[styles.progressFill, { backgroundColor: '#FF73FA', width: `${Math.min(progress, 100)}%` }]} />
            </View>
            <Text style={[styles.progressLabel, { color: c.textMuted }]}>
              {nextTier.requiredBoosts - status.boost_count} more boost{nextTier.requiredBoosts - status.boost_count !== 1 ? 's' : ''} to reach {nextTier.name}
            </Text>
          </View>
        )}

        <Pressable
          style={[styles.boostBtn, { opacity: boosting ? 0.5 : 1 }]}
          onPress={handleBoost}
          disabled={boosting}
        >
          {boosting ? (
            <ActivityIndicator color="#FFF" size="small" />
          ) : (
            <>
              <Ionicons name="flash" size={18} color="#FFF" />
              <Text style={styles.boostBtnText}>Boost This Server</Text>
            </>
          )}
        </Pressable>
      </View>

      {/* Perks */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>CURRENT PERKS</Text>
      {BOOST_TIERS.filter((t) => t.level <= status.tier.level && t.perks.length > 0).map((t) => (
        <View key={t.level} style={[styles.perksCard, { backgroundColor: c.bgSecondary }]}>
          <Text style={[styles.perksTitle, { color: c.textPrimary }]}>{t.name}</Text>
          {t.perks.map((perk, i) => (
            <View key={i} style={styles.perkRow}>
              <Ionicons name="checkmark" size={16} color={c.success} />
              <Text style={[styles.perkText, { color: c.textSecondary }]}>{perk}</Text>
            </View>
          ))}
        </View>
      ))}

      {/* Boosters */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>
        BOOSTERS ({status.boosters.length})
      </Text>
      <View style={[styles.boostersList, { backgroundColor: c.bgSecondary }]}>
        {status.boosters.length === 0 ? (
          <Text style={[styles.emptyText, { color: c.textMuted }]}>No boosters yet — be the first!</Text>
        ) : (
          status.boosters.map((b) => (
            <View key={b.id} style={styles.boosterRow}>
              <View style={[styles.boosterAvatar, { backgroundColor: c.bgTertiary }]}>
                {b.user?.avatar_url ? (
                  <Image source={{ uri: b.user.avatar_url }} style={styles.boosterAvatarImg} />
                ) : (
                  <Ionicons name="person" size={16} color={c.textMuted} />
                )}
              </View>
              <Text style={[styles.boosterName, { color: c.textPrimary }]}>
                {b.user?.username || 'Unknown'}
              </Text>
              <Text style={[styles.boosterDate, { color: c.textMuted }]}>
                since {new Date(b.started_at).toLocaleDateString()}
              </Text>
            </View>
          ))
        )}
      </View>

      <View style={{ height: spacing.xxxxl }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  tierCard: {
    margin: spacing.md,
    borderRadius: borderRadius.lg,
    padding: spacing.xl,
    alignItems: 'center',
    gap: spacing.sm,
  },
  tierName: { ...typography.headingL },
  boostCount: { ...typography.body },
  progressSection: { width: '100%', marginTop: spacing.sm, gap: spacing.xs },
  progressBar: { height: 6, borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: 6, borderRadius: 3 },
  progressLabel: { ...typography.caption, textAlign: 'center' },
  boostBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: '#FF73FA',
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    marginTop: spacing.md,
  },
  boostBtnText: { ...typography.bodyBold, color: '#FFF' },
  sectionTitle: { ...typography.overline, paddingHorizontal: spacing.lg, paddingTop: spacing.xl, paddingBottom: spacing.sm },
  perksCard: { marginHorizontal: spacing.md, borderRadius: borderRadius.md, padding: spacing.lg, marginBottom: spacing.sm },
  perksTitle: { ...typography.headingS, marginBottom: spacing.sm },
  perkRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.xs },
  perkText: { ...typography.bodySmall },
  boostersList: { marginHorizontal: spacing.md, borderRadius: borderRadius.md, padding: spacing.lg },
  boosterRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm },
  boosterAvatar: { width: 32, height: 32, borderRadius: 16, justifyContent: 'center', alignItems: 'center', overflow: 'hidden' },
  boosterAvatarImg: { width: 32, height: 32, borderRadius: 16 },
  boosterName: { ...typography.bodySmall, fontFamily: 'gg-sans-medium', flex: 1 },
  boosterDate: { ...typography.caption },
  emptyText: { ...typography.bodySmall, textAlign: 'center', paddingVertical: spacing.md },
});
