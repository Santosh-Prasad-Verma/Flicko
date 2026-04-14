/**
 * MessageSearch Component
 *
 * Full-text search through channel messages with debounced input,
 * highlighted results, and scroll-to-message on tap.
 *
 * Requirements: Feature 8 (Message Search)
 */
import React, { memo, useState, useCallback, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { supabase } from '@lib/supabase';
import { Avatar } from '../ui/Avatar';

// ── Types ─────────────────────────────────────────────────────────────────

interface SearchResult {
  id: string;
  content: string;
  author_id: string;
  created_at: string;
  channel_id: string;
  author?: {
    username: string;
    display_name: string | null;
    avatar: string | null;
  };
}

interface MessageSearchProps {
  channelId: string;
  onClose: () => void;
  onJumpToMessage?: (messageId: string) => void;
}

const DEBOUNCE_MS = 300;
const MIN_QUERY_LENGTH = 3;
const PAGE_SIZE = 25;

// ── Component ─────────────────────────────────────────────────────────────

export const MessageSearch = memo(function MessageSearch({
  channelId,
  onClose,
  onJumpToMessage,
}: MessageSearchProps) {
  const { themeColors } = useTheme();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [totalResults, setTotalResults] = useState(0);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inputRef = useRef<TextInput>(null);

  const search = useCallback(
    async (searchQuery: string, offset = 0) => {
      if (searchQuery.trim().length < MIN_QUERY_LENGTH) {
        setResults([]);
        setTotalResults(0);
        return;
      }

      if (offset === 0) setLoading(true);
      try {
        // Use Supabase full-text search (textSearch on content)
        const { data, error, count } = await supabase
          .from('messages')
          .select(
            `
            id,
            content,
            author_id,
            created_at,
            channel_id,
            author:profiles!messages_author_id_fkey(username, display_name, avatar)
          `,
            { count: 'exact' },
          )
          .eq('channel_id', channelId)
          .textSearch('content', searchQuery.trim(), {
            type: 'websearch',
            config: 'english',
          })
          .order('created_at', { ascending: false })
          .range(offset, offset + PAGE_SIZE - 1);

        if (error) {
          // Fallback to ilike search if textSearch fails
          const { data: fallbackData, error: fallbackErr, count: fallbackCount } = await supabase
            .from('messages')
            .select(
              `
              id,
              content,
              author_id,
              created_at,
              channel_id,
              author:profiles!messages_author_id_fkey(username, display_name, avatar)
            `,
              { count: 'exact' },
            )
            .eq('channel_id', channelId)
            .ilike('content', `%${searchQuery.trim()}%`)
            .order('created_at', { ascending: false })
            .range(offset, offset + PAGE_SIZE - 1);

          if (fallbackErr) throw fallbackErr;

          const mapped = (fallbackData ?? []).map((r: any) => ({
            ...r,
            author: Array.isArray(r.author) ? r.author[0] : r.author,
          }));

          if (offset === 0) {
            setResults(mapped);
          } else {
            setResults((prev) => [...prev, ...mapped]);
          }
          setTotalResults(fallbackCount ?? 0);
          setHasMore((fallbackData?.length ?? 0) === PAGE_SIZE);
          return;
        }

        const mapped = (data ?? []).map((r: any) => ({
          ...r,
          author: Array.isArray(r.author) ? r.author[0] : r.author,
        }));

        if (offset === 0) {
          setResults(mapped);
        } else {
          setResults((prev) => [...prev, ...mapped]);
        }
        setTotalResults(count ?? 0);
        setHasMore((data?.length ?? 0) === PAGE_SIZE);
      } catch (err) {
        console.error('[MessageSearch] search error:', err);
      } finally {
        setLoading(false);
      }
    },
    [channelId],
  );

  // Debounced search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      search(query);
    }, DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query, search]);

  const handleLoadMore = useCallback(() => {
    if (!loading && hasMore) {
      search(query, results.length);
    }
  }, [loading, hasMore, query, results.length, search]);

  const highlightText = useCallback(
    (text: string): React.ReactNode => {
      if (!query.trim()) return text;
      const escapedQuery = query.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const parts = text.split(new RegExp(`(${escapedQuery})`, 'gi'));
      return parts.map((part, i) =>
        part.toLowerCase() === query.trim().toLowerCase() ? (
          <Text key={i} style={{ backgroundColor: themeColors.accentPrimary + '40', fontFamily: 'gg-sans-semibold' }}>
            {part}
          </Text>
        ) : (
          <Text key={i}>{part}</Text>
        ),
      );
    },
    [query, themeColors],
  );

  const formatDate = (dateStr: string): string => {
    const d = new Date(dateStr);
    return d.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: d.getFullYear() !== new Date().getFullYear() ? 'numeric' : undefined,
    });
  };

  const renderResult = useCallback(
    ({ item }: { item: SearchResult }) => {
      const authorName =
        item.author?.display_name || item.author?.username || 'Unknown';

      return (
        <Pressable
          onPress={() => onJumpToMessage?.(item.id)}
          style={({ pressed }) => [
            styles.resultItem,
            pressed && { backgroundColor: themeColors.bgTertiary },
          ]}
        >
          <Avatar
            name={authorName}
            imageUrl={item.author?.avatar}
            size={32}
          />
          <View style={styles.resultContent}>
            <View style={styles.resultHeader}>
              <Text style={[styles.resultAuthor, { color: themeColors.textPrimary }]}>
                {authorName}
              </Text>
              <Text style={[styles.resultDate, { color: themeColors.textMuted }]}>
                {formatDate(item.created_at)}
              </Text>
            </View>
            <Text
              style={[styles.resultText, { color: themeColors.textSecondary }]}
              numberOfLines={3}
            >
              {highlightText(item.content)}
            </Text>
          </View>
        </Pressable>
      );
    },
    [themeColors, highlightText, onJumpToMessage],
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={onClose} hitSlop={12}>
          <Ionicons name="arrow-back" size={22} color={themeColors.textPrimary} />
        </Pressable>
        <View style={[styles.searchBar, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="search" size={18} color={themeColors.textMuted} />
          <TextInput
            ref={inputRef}
            value={query}
            onChangeText={setQuery}
            placeholder="Search messages..."
            placeholderTextColor={themeColors.textMuted}
            style={[styles.searchInput, { color: themeColors.textPrimary }]}
            autoFocus
            autoCorrect={false}
            returnKeyType="search"
          />
          {query.length > 0 && (
            <Pressable onPress={() => setQuery('')} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </View>
      </View>

      {/* Results count */}
      {query.trim().length >= MIN_QUERY_LENGTH && !loading && (
        <Text style={[styles.resultCount, { color: themeColors.textMuted }]}>
          {totalResults} {totalResults === 1 ? 'result' : 'results'}
        </Text>
      )}

      {/* Minimum chars hint */}
      {query.trim().length > 0 && query.trim().length < MIN_QUERY_LENGTH && (
        <View style={styles.hintContainer}>
          <Text style={[styles.hintText, { color: themeColors.textMuted }]}>
            Type at least {MIN_QUERY_LENGTH} characters to search
          </Text>
        </View>
      )}

      {/* Results list */}
      {loading && results.length === 0 ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
        </View>
      ) : (
        <FlatList
          data={results}
          renderItem={renderResult}
          keyExtractor={(item) => item.id}
          onEndReached={handleLoadMore}
          onEndReachedThreshold={0.3}
          keyboardDismissMode="on-drag"
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            query.trim().length >= MIN_QUERY_LENGTH && !loading ? (
              <View style={styles.emptyContainer}>
                <Ionicons name="search-outline" size={48} color={themeColors.textMuted} />
                <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                  No messages found
                </Text>
              </View>
            ) : null
          }
        />
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  searchBar: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.lg,
    gap: spacing.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
  },
  resultCount: {
    fontSize: 12,
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.sm,
  },
  hintContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  hintText: {
    fontSize: 14,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  listContent: {
    paddingBottom: spacing.xl,
  },
  resultItem: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    gap: spacing.sm,
  },
  resultContent: {
    flex: 1,
  },
  resultHeader: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: spacing.sm,
    marginBottom: 2,
  },
  resultAuthor: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  resultDate: {
    fontSize: 11,
  },
  resultText: {
    fontSize: 14,
    lineHeight: 20,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: spacing.xl * 3,
    gap: spacing.sm,
  },
  emptyText: {
    fontSize: 14,
  },
});
