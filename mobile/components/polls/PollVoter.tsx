/**
 * PollVoter Component
 *
 * Displays an active poll with animated progress bars, vote counts,
 * expiration timer, and handles voting/unvoting.
 *
 * Requirements: Feature 21 (Polls System)
 */
import React, { memo, useState, useCallback, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { supabase } from '@lib/supabase';

// ── Types ─────────────────────────────────────────────────────────────────

interface PollOption {
  id: string;
  text: string;
  position: number;
  vote_count: number;
}

interface PollData {
  id: string;
  question: string;
  allow_multiselect: boolean;
  expires_at: string;
  creator_id: string;
  options: PollOption[];
  total_votes: number;
  user_votes: string[]; // option IDs the current user voted for
}

interface PollVoterProps {
  poll: PollData;
  currentUserId: string;
  onVoteChange?: () => void;
}

// ── Helpers ───────────────────────────────────────────────────────────────

function formatTimeRemaining(expiresAt: string): string {
  const remaining = new Date(expiresAt).getTime() - Date.now();
  if (remaining <= 0) return 'Ended';

  const hours = Math.floor(remaining / (1000 * 60 * 60));
  const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));

  if (hours >= 24) {
    const days = Math.floor(hours / 24);
    return `${days}d ${hours % 24}h remaining`;
  }
  if (hours > 0) return `${hours}h ${minutes}m remaining`;
  return `${minutes}m remaining`;
}

// ── Animated progress bar ─────────────────────────────────────────────────

const AnimatedBar = memo(function AnimatedBar({
  percentage,
  isSelected,
  accentColor,
  bgColor,
}: {
  percentage: number;
  isSelected: boolean;
  accentColor: string;
  bgColor: string;
}) {
  const width = useSharedValue(0);

  useEffect(() => {
    width.value = withTiming(percentage, {
      duration: 500,
      easing: Easing.out(Easing.cubic),
    });
  }, [percentage, width]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${width.value}%`,
  }));

  return (
    <View style={[styles.barBg, { backgroundColor: bgColor }]}>
      <Animated.View
        style={[
          styles.barFill,
          {
            backgroundColor: isSelected
              ? accentColor
              : accentColor + '40',
          },
          animatedStyle,
        ]}
      />
    </View>
  );
});

// ── Component ─────────────────────────────────────────────────────────────

export const PollVoter = memo(function PollVoter({
  poll,
  currentUserId,
  onVoteChange,
}: PollVoterProps) {
  const { themeColors } = useTheme();
  const [voting, setVoting] = useState(false);
  const [userVotes, setUserVotes] = useState<Set<string>>(
    new Set(poll.user_votes),
  );
  const [options, setOptions] = useState(poll.options);
  const [totalVotes, setTotalVotes] = useState(poll.total_votes);

  const isExpired = useMemo(
    () => new Date(poll.expires_at).getTime() <= Date.now(),
    [poll.expires_at],
  );

  const hasVoted = userVotes.size > 0;

  // Update timer
  const [timeStr, setTimeStr] = useState(formatTimeRemaining(poll.expires_at));
  useEffect(() => {
    if (isExpired) return;
    const interval = setInterval(() => {
      setTimeStr(formatTimeRemaining(poll.expires_at));
    }, 60_000);
    return () => clearInterval(interval);
  }, [poll.expires_at, isExpired]);

  const handleVote = useCallback(
    async (optionId: string) => {
      if (isExpired || voting) return;

      const alreadyVoted = userVotes.has(optionId);
      setVoting(true);

      try {
        if (alreadyVoted) {
          // Remove vote
          const { error } = await supabase
            .from('poll_votes')
            .delete()
            .eq('poll_id', poll.id)
            .eq('option_id', optionId)
            .eq('user_id', currentUserId);

          if (error) throw error;

          setUserVotes((prev) => {
            const next = new Set(prev);
            next.delete(optionId);
            return next;
          });
          setOptions((prev) =>
            prev.map((o) =>
              o.id === optionId ? { ...o, vote_count: Math.max(0, o.vote_count - 1) } : o,
            ),
          );
          setTotalVotes((prev) => Math.max(0, prev - 1));
        } else {
          // Single-select: remove previous vote first
          if (!poll.allow_multiselect && userVotes.size > 0) {
            const prevOptionId = Array.from(userVotes)[0];
            await supabase
              .from('poll_votes')
              .delete()
              .eq('poll_id', poll.id)
              .eq('user_id', currentUserId);

            setOptions((prev) =>
              prev.map((o) =>
                o.id === prevOptionId
                  ? { ...o, vote_count: Math.max(0, o.vote_count - 1) }
                  : o,
              ),
            );
            setTotalVotes((prev) => Math.max(0, prev - 1));
          }

          // Add vote
          const { error } = await supabase
            .from('poll_votes')
            .insert({
              poll_id: poll.id,
              option_id: optionId,
              user_id: currentUserId,
            });

          if (error) throw error;

          setUserVotes((prev) => {
            const next = new Set(poll.allow_multiselect ? prev : []);
            next.add(optionId);
            return next;
          });
          setOptions((prev) =>
            prev.map((o) =>
              o.id === optionId ? { ...o, vote_count: o.vote_count + 1 } : o,
            ),
          );
          setTotalVotes((prev) => prev + 1);
        }

        onVoteChange?.();
      } catch (err) {
        console.error('[PollVoter] vote error:', err);
      } finally {
        setVoting(false);
      }
    },
    [poll, currentUserId, userVotes, isExpired, voting, onVoteChange],
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgTertiary }]}>
      {/* Question */}
      <View style={styles.questionRow}>
        <Ionicons name="bar-chart-outline" size={18} color={themeColors.accentPrimary} />
        <Text style={[styles.question, { color: themeColors.textPrimary }]}>
          {poll.question}
        </Text>
      </View>

      {/* Options */}
      {options
        .sort((a, b) => a.position - b.position)
        .map((opt) => {
          const percentage = totalVotes > 0 ? (opt.vote_count / totalVotes) * 100 : 0;
          const isSelected = userVotes.has(opt.id);

          return (
            <Pressable
              key={opt.id}
              onPress={() => handleVote(opt.id)}
              disabled={isExpired || voting}
              style={[
                styles.optionContainer,
                isSelected && {
                  borderColor: themeColors.accentPrimary,
                  borderWidth: 1,
                },
              ]}
            >
              <AnimatedBar
                percentage={percentage}
                isSelected={isSelected}
                accentColor={themeColors.accentPrimary}
                bgColor={themeColors.bgSecondary}
              />
              <View style={styles.optionContent}>
                <View style={styles.optionLeft}>
                  {isSelected && (
                    <Ionicons
                      name="checkmark-circle"
                      size={16}
                      color={themeColors.accentPrimary}
                    />
                  )}
                  <Text
                    style={[
                      styles.optionText,
                      { color: themeColors.textPrimary },
                      isSelected && { fontFamily: 'gg-sans-semibold' },
                    ]}
                  >
                    {opt.text}
                  </Text>
                </View>
                <Text style={[styles.voteCount, { color: themeColors.textMuted }]}>
                  {opt.vote_count} ({percentage.toFixed(0)}%)
                </Text>
              </View>
            </Pressable>
          );
        })}

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={[styles.footerText, { color: themeColors.textMuted }]}>
          {totalVotes} {totalVotes === 1 ? 'vote' : 'votes'}
          {poll.allow_multiselect ? ' · Multiple answers' : ''}
        </Text>
        <Text
          style={[
            styles.footerText,
            { color: isExpired ? themeColors.danger : themeColors.textMuted },
          ]}
        >
          {timeStr}
        </Text>
      </View>

      {voting && (
        <ActivityIndicator
          style={styles.loadingOverlay}
          color={themeColors.accentPrimary}
        />
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    marginVertical: spacing.xs,
  },
  questionRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  question: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
    flex: 1,
    lineHeight: 20,
  },
  optionContainer: {
    borderRadius: borderRadius.md,
    overflow: 'hidden',
    marginBottom: spacing.sm,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  barBg: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    borderRadius: borderRadius.md,
  },
  barFill: {
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    borderRadius: borderRadius.md,
  },
  optionContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minHeight: 42,
  },
  optionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    flex: 1,
  },
  optionText: {
    fontSize: 14,
    flex: 1,
  },
  voteCount: {
    fontSize: 12,
    fontFamily: 'gg-sans-medium',
    marginLeft: spacing.sm,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
  },
  footerText: {
    fontSize: 12,
  },
  loadingOverlay: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
  },
});
