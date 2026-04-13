/**
 * AI Channel Summarization (Feature 44)
 *
 * Summarize missed messages in a channel using AI.
 * Shows a "Catch up" button that fetches recent messages,
 * sends them to an AI endpoint, and displays a concise summary.
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '@services/supabase';

interface AISummaryProps {
  channelId: string;
  lastReadAt?: string;
  onDismiss?: () => void;
}

interface SummaryResult {
  summary: string;
  messageCount: number;
  topTopics: string[];
  mentionsYou: boolean;
}

/**
 * Summarize messages in a channel since lastReadAt.
 * Falls back to last 100 messages if no read marker.
 */
async function fetchAndSummarize(
  channelId: string,
  lastReadAt?: string
): Promise<SummaryResult> {
  // 1. Fetch recent messages
  let query = supabase
    .from('messages')
    .select('content, profiles:user_id(display_name, username), created_at')
    .eq('channel_id', channelId)
    .order('created_at', { ascending: false })
    .limit(100);

  if (lastReadAt) {
    query = query.gt('created_at', lastReadAt);
  }

  const { data: messages } = await query;
  if (!messages?.length) {
    return {
      summary: 'No new messages to summarize.',
      messageCount: 0,
      topTopics: [],
      mentionsYou: false,
    };
  }

  // 2. Build conversation transcript
  const transcript = messages
    .reverse()
    .map((m: any) => {
      const name = m.profiles?.display_name || m.profiles?.username || 'Unknown';
      return `${name}: ${m.content}`;
    })
    .join('\n');

  // 3. Call AI summarization endpoint (Edge Function or external API)
  try {
    const { data, error } = await supabase.functions.invoke('summarize-channel', {
      body: { transcript, messageCount: messages.length },
    });

    if (error || !data) throw new Error('AI summarization failed');

    return {
      summary: data.summary || 'Could not generate summary.',
      messageCount: messages.length,
      topTopics: data.topics || [],
      mentionsYou: data.mentionsYou || false,
    };
  } catch {
    // Fallback: simple extractive summary
    const uniqueAuthors = new Set(
      messages.map((m: any) => m.profiles?.display_name || m.profiles?.username)
    );
    const preview = messages
      .slice(0, 5)
      .map((m: any) => m.content)
      .join(' ')
      .slice(0, 300);

    return {
      summary: `${messages.length} messages from ${uniqueAuthors.size} people. Recent highlights: "${preview}…"`,
      messageCount: messages.length,
      topTopics: [],
      mentionsYou: false,
    };
  }
}

/**
 * "Catch Up" banner that appears when user has unread messages.
 */
export const AISummaryCatchUp = memo(function AISummaryCatchUp({
  channelId,
  lastReadAt,
  onDismiss,
}: AISummaryProps) {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<SummaryResult | null>(null);
  const [dismissed, setDismissed] = useState(false);

  const handleSummarize = useCallback(async () => {
    setLoading(true);
    try {
      const summary = await fetchAndSummarize(channelId, lastReadAt);
      setResult(summary);
    } catch {
      setResult({
        summary: 'Failed to generate summary. Please try again.',
        messageCount: 0,
        topTopics: [],
        mentionsYou: false,
      });
    } finally {
      setLoading(false);
    }
  }, [channelId, lastReadAt]);

  const handleDismiss = useCallback(() => {
    setDismissed(true);
    onDismiss?.();
  }, [onDismiss]);

  if (dismissed) return null;

  if (result) {
    return (
      <Animated.View
        entering={FadeIn.duration(200)}
        exiting={FadeOut.duration(200)}
        style={styles.resultCard}
      >
        <View style={styles.resultHeader}>
          <Ionicons name="sparkles" size={18} color="#FFD93D" />
          <Text style={styles.resultTitle}>AI Summary</Text>
          <TouchableOpacity onPress={handleDismiss} style={styles.dismissBtn}>
            <Ionicons name="close" size={18} color="#72767D" />
          </TouchableOpacity>
        </View>

        {result.mentionsYou && (
          <View style={styles.mentionBadge}>
            <Ionicons name="at" size={14} color="#ED4245" />
            <Text style={styles.mentionText}>You were mentioned</Text>
          </View>
        )}

        <ScrollView style={styles.summaryScroll} nestedScrollEnabled>
          <Text style={styles.summaryText}>{result.summary}</Text>
        </ScrollView>

        {result.topTopics.length > 0 && (
          <View style={styles.topicsRow}>
            {result.topTopics.map((topic, i) => (
              <View key={i} style={styles.topicChip}>
                <Text style={styles.topicText}>{topic}</Text>
              </View>
            ))}
          </View>
        )}

        <Text style={styles.messageCount}>
          Based on {result.messageCount} messages
        </Text>
      </Animated.View>
    );
  }

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      style={styles.catchUpBanner}
    >
      <Ionicons name="sparkles" size={16} color="#FFD93D" />
      <Text style={styles.catchUpText}>Missed messages?</Text>
      <TouchableOpacity
        onPress={handleSummarize}
        disabled={loading}
        style={styles.catchUpBtn}
      >
        {loading ? (
          <ActivityIndicator size="small" color="#FFF" />
        ) : (
          <Text style={styles.catchUpBtnText}>Catch Up</Text>
        )}
      </TouchableOpacity>
      <TouchableOpacity onPress={handleDismiss} style={styles.dismissBtn}>
        <Ionicons name="close" size={16} color="#72767D" />
      </TouchableOpacity>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  catchUpBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2F3136',
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginHorizontal: 12,
    marginVertical: 6,
    borderRadius: 8,
    gap: 8,
    borderWidth: 1,
    borderColor: '#5865F2',
  },
  catchUpText: {
    flex: 1,
    color: '#DCDDDE',
    fontSize: 13,
    fontFamily: 'GGSans-Medium',
  },
  catchUpBtn: {
    backgroundColor: '#5865F2',
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 4,
    minWidth: 70,
    alignItems: 'center',
  },
  catchUpBtnText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'GGSans-Bold',
  },
  dismissBtn: {
    padding: 4,
  },
  resultCard: {
    backgroundColor: '#2F3136',
    marginHorizontal: 12,
    marginVertical: 6,
    borderRadius: 8,
    padding: 14,
    borderWidth: 1,
    borderColor: '#5865F2',
  },
  resultHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 10,
  },
  resultTitle: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 15,
    fontFamily: 'GGSans-Bold',
  },
  mentionBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(237,66,69,0.15)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    alignSelf: 'flex-start',
    marginBottom: 8,
  },
  mentionText: {
    color: '#ED4245',
    fontSize: 12,
    fontFamily: 'GGSans-Medium',
  },
  summaryScroll: {
    maxHeight: 150,
  },
  summaryText: {
    color: '#DCDDDE',
    fontSize: 13,
    fontFamily: 'GGSans-Regular',
    lineHeight: 20,
  },
  topicsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: 10,
  },
  topicChip: {
    backgroundColor: '#40444B',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
  },
  topicText: {
    color: '#B9BBBE',
    fontSize: 11,
    fontFamily: 'GGSans-Medium',
  },
  messageCount: {
    color: '#72767D',
    fontSize: 11,
    fontFamily: 'GGSans-Regular',
    marginTop: 8,
  },
});
