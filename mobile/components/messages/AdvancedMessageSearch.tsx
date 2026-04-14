/**
 * Advanced Message Search
 *
 * Discord-style message search with filter chips (from, mentions, has,
 * before, after, in, pinned) and paginated result display with
 * "Jump to message" functionality.
 *
 * Requirements: Search UI Feature
 */
import React, { memo, useCallback, useMemo, useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  FlatList,
  ActivityIndicator,
  ScrollView,
  Keyboard,
} from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  FadeInDown,
  SlideInDown,
  Layout,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { supabase } from '../../services/supabase';
import { Avatar } from '../ui/Avatar';
import { useTheme } from '@/hooks/useTheme';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';

import type { SearchSortOrder } from '@services/searchService';

// ── Types ─────────────────────────────────────────────────────────────────

export type SearchFilterType =
  | 'from'
  | 'mentions'
  | 'has'
  | 'before'
  | 'after'
  | 'in'
  | 'pinned';

export interface SearchFilter {
  type: SearchFilterType;
  value: string;
  displayLabel: string;
}

export interface SearchResultMessage {
  id: string;
  content: string;
  createdAt: string;
  channelId: string;
  channelName: string;
  serverId: string;
  serverName: string;
  author: {
    id: string;
    username: string;
    displayName: string;
    avatar: string | null;
  };
  /** Text surrounding the match for context */
  matchContext: string;
  isPinned: boolean;
  hasAttachment: boolean;
  hasEmbed: boolean;
}

interface AdvancedMessageSearchProps {
  /** Pre-select a server/channel context */
  serverId?: string;
  channelId?: string;
}

// ── Filter Chip ───────────────────────────────────────────────────────────

const FILTER_OPTIONS: { type: SearchFilterType; label: string; icon: string; placeholder: string }[] = [
  { type: 'from', label: 'from:', icon: 'person', placeholder: 'username' },
  { type: 'mentions', label: 'mentions:', icon: 'at', placeholder: 'username' },
  { type: 'has', label: 'has:', icon: 'attach', placeholder: 'link, image, file, video, embed' },
  { type: 'before', label: 'before:', icon: 'calendar-outline', placeholder: 'YYYY-MM-DD' },
  { type: 'after', label: 'after:', icon: 'calendar', placeholder: 'YYYY-MM-DD' },
  { type: 'in', label: 'in:', icon: 'chatbox', placeholder: '#channel' },
  { type: 'pinned', label: 'pinned:', icon: 'pin', placeholder: 'true' },
];

const FilterChip = memo(function FilterChip({
  filter,
  onRemove,
}: {
  filter: SearchFilter;
  onRemove: (filter: SearchFilter) => void;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View
      entering={FadeIn.duration(150)}
      exiting={FadeOut.duration(100)}
      layout={Layout.springify()}
    >
      <View
        style={[styles.filterChip, { backgroundColor: themeColors.accentPrimary + '30' }]}
      >
        <Text
          style={[styles.filterType, { color: themeColors.accentPrimary }]}
        >
          {filter.type}:
        </Text>
        <Text
          style={[styles.filterValue, { color: themeColors.textPrimary }]}
          numberOfLines={1}
        >
          {filter.value}
        </Text>
        <Pressable onPress={() => onRemove(filter)} hitSlop={4}>
          <Ionicons name="close" size={14} color={themeColors.textMuted} />
        </Pressable>
      </View>
    </Animated.View>
  );
});

// ── Filter Picker ─────────────────────────────────────────────────────────

const FilterPicker = memo(function FilterPicker({
  visible,
  onSelectFilter,
  onClose,
}: {
  visible: boolean;
  onSelectFilter: (type: SearchFilterType) => void;
  onClose: () => void;
}) {
  const { themeColors } = useTheme();

  if (!visible) return null;

  return (
    <Animated.View
      entering={SlideInDown.duration(200)}
      exiting={FadeOut.duration(100)}
      style={[styles.filterPicker, { backgroundColor: themeColors.bgSecondary, borderColor: themeColors.border }]}
    >
      <Text style={[styles.filterPickerTitle, { color: themeColors.textMuted }]}>
        ADD FILTER
      </Text>
      {FILTER_OPTIONS.map((opt) => (
        <Pressable
          key={opt.type}
          onPress={() => {
            onSelectFilter(opt.type);
            onClose();
          }}
          style={({ pressed }) => [
            styles.filterOption,
            pressed && { backgroundColor: themeColors.bgTertiary },
          ]}
        >
          <Ionicons
            name={opt.icon as any}
            size={18}
            color={themeColors.accentPrimary}
          />
          <View style={styles.filterOptionInfo}>
            <Text
              style={[styles.filterOptionLabel, { color: themeColors.textPrimary }]}
            >
              {opt.label}
            </Text>
            <Text
              style={[styles.filterOptionHint, { color: themeColors.textMuted }]}
            >
              {opt.placeholder}
            </Text>
          </View>
        </Pressable>
      ))}
    </Animated.View>
  );
});

// ── Search Result Card ────────────────────────────────────────────────────

const SearchResultCard = memo(function SearchResultCard({
  message,
  onJump,
  searchQuery,
}: {
  message: SearchResultMessage;
  onJump: (message: SearchResultMessage) => void;
  searchQuery: string;
}) {
  const { themeColors } = useTheme();

  const formatTime = (ts: string) => {
    const d = new Date(ts);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    if (diffMs < 86400000) {
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
    return d.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' });
  };

  // Highlight matching text — render **bold** markers from highlighted_content
  const highlightedContent = useMemo(() => {
    const raw = (message as any).highlighted_content || message.content;
    if (!raw) return null;

    // Parse **bold** markers into Text components
    const parts = raw.split(/\*\*(.+?)\*\*/g);
    if (parts.length <= 1) return raw;

    return parts.map((part: string, i: number) => {
      if (i % 2 === 1) {
        // Odd indices are inside ** markers — highlight
        return (
          <Text key={i} style={{ fontFamily: 'gg-sans-bold', backgroundColor: '#FAA61A40' }}>
            {part}
          </Text>
        );
      }
      return part;
    });
  }, [message.content, (message as any).highlighted_content, searchQuery]);

  return (
    <Animated.View entering={FadeInDown.duration(200)}>
      <Pressable
        onPress={() => onJump(message)}
        style={({ pressed }) => [
          styles.resultCard,
          {
            backgroundColor: pressed
              ? themeColors.bgTertiary
              : themeColors.bgSecondary,
            borderColor: themeColors.border,
          },
        ]}
      >
        {/* Header */}
        <View style={styles.resultHeader}>
          <Avatar
            name={message.author.displayName}
            imageUrl={message.author.avatar}
            size={32}
          />
          <View style={styles.resultMeta}>
            <Text
              style={[styles.resultAuthor, { color: themeColors.textPrimary }]}
              numberOfLines={1}
            >
              {message.author.displayName}
            </Text>
            <Text style={[styles.resultTime, { color: themeColors.textMuted }]}>
              {formatTime(message.createdAt)}
            </Text>
          </View>
          <View style={styles.resultBadges}>
            {message.isPinned && (
              <Ionicons name="pin" size={12} color={themeColors.warning} />
            )}
            {message.hasAttachment && (
              <Ionicons name="attach" size={12} color={themeColors.textMuted} />
            )}
          </View>
        </View>

        {/* Content */}
        <Text
          style={[styles.resultContent, { color: themeColors.textPrimary }]}
          numberOfLines={3}
        >
          {highlightedContent}
        </Text>

        {/* Footer */}
        <View style={styles.resultFooter}>
          <View style={styles.resultChannel}>
            <Ionicons name="chatbox" size={12} color={themeColors.textMuted} />
            <Text style={[styles.resultChannelName, { color: themeColors.textMuted }]}>
              #{message.channelName}
            </Text>
            <Text style={[styles.resultServerName, { color: themeColors.textMuted }]}>
              • {message.serverName}
            </Text>
          </View>
          <Pressable
            onPress={() => onJump(message)}
            style={[styles.jumpBtn, { backgroundColor: themeColors.accentPrimary + '20' }]}
          >
            <Text style={[styles.jumpText, { color: themeColors.accentPrimary }]}>
              Jump
            </Text>
          </Pressable>
        </View>
      </Pressable>
    </Animated.View>
  );
});

// ── Main Component ────────────────────────────────────────────────────────

export const AdvancedMessageSearch = memo(function AdvancedMessageSearch({
  serverId,
  channelId,
}: AdvancedMessageSearchProps) {
  const { themeColors } = useTheme();
  const inputRef = useRef<TextInput>(null);
  const [query, setQuery] = useState('');
  const [filters, setFilters] = useState<SearchFilter[]>([]);
  const [results, setResults] = useState<SearchResultMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [totalResults, setTotalResults] = useState(0);
  const [showFilterPicker, setShowFilterPicker] = useState(false);
  const [pendingFilterType, setPendingFilterType] = useState<SearchFilterType | null>(null);
  const [filterInput, setFilterInput] = useState('');
  const [sortOrder, setSortOrder] = useState<SearchSortOrder>('relevance');
  const searchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Debounced search
  useEffect(() => {
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current);
    }

    const trimmed = query.trim();
    if (!trimmed && filters.length === 0) {
      setResults([]);
      setTotalResults(0);
      return;
    }

    searchTimeoutRef.current = setTimeout(() => {
      performSearch(trimmed, filters);
    }, 400);

    return () => {
      if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
    };
  }, [query, filters, sortOrder]);

  const performSearch = useCallback(
    async (searchQuery: string, activeFilters: SearchFilter[], offset = 0) => {
      setLoading(true);
      try {
        let dbQuery = supabase
          .from('messages')
          .select(
            `id, content, created_at, channel_id, pinned,
           author:profiles!author_id(id, username, display_name, avatar),
           channel:channels!channel_id(name, server_id, servers!inner(name))`,
            { count: 'exact' },
          )
          .order('created_at', { ascending: false })
          .range(offset, offset + 24);

        // Text search
        if (searchQuery) {
          dbQuery = dbQuery.ilike('content', `%${searchQuery}%`);
        }

        // Apply filters
        for (const filter of activeFilters) {
          switch (filter.type) {
            case 'from':
              dbQuery = dbQuery.eq('author.username', filter.value);
              break;
            case 'in':
              dbQuery = dbQuery.eq('channel.name', filter.value.replace('#', ''));
              break;
            case 'before':
              dbQuery = dbQuery.lt('created_at', filter.value);
              break;
            case 'after':
              dbQuery = dbQuery.gt('created_at', filter.value);
              break;
            case 'pinned':
              dbQuery = dbQuery.eq('pinned', true);
              break;
            case 'has':
              if (filter.value === 'image' || filter.value === 'file' || filter.value === 'video') {
                dbQuery = dbQuery.not('attachments', 'is', null);
              } else if (filter.value === 'link') {
                dbQuery = dbQuery.ilike('content', '%http%');
              } else if (filter.value === 'embed') {
                dbQuery = dbQuery.not('embeds', 'is', null);
              }
              break;
          }
        }

        // Server/channel context
        if (channelId) {
          dbQuery = dbQuery.eq('channel_id', channelId);
        } else if (serverId) {
          dbQuery = dbQuery.eq('channel.server_id', serverId);
        }

        const { data, count, error } = await dbQuery;

        if (error) throw error;

        const mapped = (data ?? []).map((row: any): SearchResultMessage => {
          const author = Array.isArray(row.author) ? row.author[0] : row.author;
          const channel = Array.isArray(row.channel) ? row.channel[0] : row.channel;
          const server = channel?.servers;

          return {
            id: row.id,
            content: row.content || '',
            createdAt: row.created_at,
            channelId: row.channel_id,
            channelName: channel?.name || 'unknown',
            serverId: channel?.server_id || '',
            serverName: (Array.isArray(server) ? server[0]?.name : server?.name) || 'Unknown',
            author: {
              id: author?.id || '',
              username: author?.username || 'unknown',
              displayName: author?.display_name || author?.username || 'Unknown',
              avatar: author?.avatar || null,
            },
            matchContext: row.content || '',
            isPinned: row.pinned || false,
            hasAttachment: false,
            hasEmbed: false,
          };
        });

        if (offset === 0) {
          setResults(mapped);
        } else {
          setResults((prev) => [...prev, ...mapped]);
        }

        setTotalResults(count ?? mapped.length);
        setHasMore((count ?? 0) > offset + 25);
      } catch (err) {
        console.error('[Search] error:', err);
      } finally {
        setLoading(false);
      }
    },
    [serverId, channelId],
  );

  const handleAddFilter = useCallback((type: SearchFilterType) => {
    if (type === 'pinned') {
      // Boolean filter — add immediately
      setFilters((prev) => [
        ...prev.filter((f) => f.type !== 'pinned'),
        { type: 'pinned', value: 'true', displayLabel: 'pinned: true' },
      ]);
    } else {
      setPendingFilterType(type);
      setFilterInput('');
      inputRef.current?.focus();
    }
  }, []);

  const handleConfirmFilter = useCallback(() => {
    if (!pendingFilterType || !filterInput.trim()) return;

    const filter: SearchFilter = {
      type: pendingFilterType,
      value: filterInput.trim(),
      displayLabel: `${pendingFilterType}: ${filterInput.trim()}`,
    };

    setFilters((prev) => [...prev, filter]);
    setPendingFilterType(null);
    setFilterInput('');
  }, [pendingFilterType, filterInput]);

  const handleRemoveFilter = useCallback((filter: SearchFilter) => {
    setFilters((prev) => prev.filter((f) => f !== filter));
  }, []);

  const handleJump = useCallback((message: SearchResultMessage) => {
    if (message.serverId) {
      router.push(`/server/${message.serverId}/channel/${message.channelId}` as any);
    }
  }, []);

  const handleLoadMore = useCallback(() => {
    if (loading || !hasMore) return;
    performSearch(query.trim(), filters, results.length);
  }, [loading, hasMore, query, filters, results.length, performSearch]);

  const renderResult = useCallback(
    ({ item }: { item: SearchResultMessage }) => (
      <SearchResultCard
        message={item}
        onJump={handleJump}
        searchQuery={query}
      />
    ),
    [handleJump, query],
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      {/* Search input area */}
      <View style={styles.searchArea}>
        <View
          style={[styles.searchBox, { backgroundColor: themeColors.bgTertiary }]}
        >
          <Ionicons name="search" size={18} color={themeColors.textMuted} />

          {/* Active filters */}
          {filters.length > 0 && (
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              style={styles.filterScroll}
              contentContainerStyle={styles.filterScrollContent}
            >
              {filters.map((filter, i) => (
                <FilterChip
                  key={`${filter.type}-${filter.value}-${i}`}
                  filter={filter}
                  onRemove={handleRemoveFilter}
                />
              ))}
            </ScrollView>
          )}

          {/* Input */}
          <TextInput
            ref={inputRef}
            style={[styles.searchInput, { color: themeColors.textPrimary }]}
            placeholder={
              pendingFilterType
                ? `Enter ${pendingFilterType} value...`
                : 'Search messages...'
            }
            placeholderTextColor={themeColors.textMuted}
            value={pendingFilterType ? filterInput : query}
            onChangeText={pendingFilterType ? setFilterInput : setQuery}
            onSubmitEditing={pendingFilterType ? handleConfirmFilter : undefined}
            returnKeyType={pendingFilterType ? 'done' : 'search'}
            autoFocus
          />

          {/* Filter button */}
          <Pressable
            onPress={() => setShowFilterPicker((v) => !v)}
            hitSlop={8}
            style={styles.filterBtn}
          >
            <Ionicons
              name="options"
              size={20}
              color={
                showFilterPicker
                  ? themeColors.accentPrimary
                  : themeColors.textMuted
              }
            />
          </Pressable>

          {/* Clear */}
          {(query.length > 0 || filters.length > 0) && (
            <Pressable
              onPress={() => {
                setQuery('');
                setFilters([]);
                setResults([]);
              }}
              hitSlop={8}
            >
              <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </View>

        {/* Pending filter indicator */}
        {pendingFilterType && (
          <Animated.View
            entering={FadeIn.duration(100)}
            style={[styles.pendingBanner, { backgroundColor: themeColors.accentPrimary + '15' }]}
          >
            <Text style={[styles.pendingText, { color: themeColors.accentPrimary }]}>
              Type value for <Text style={{ fontFamily: 'gg-sans-bold' }}>{pendingFilterType}:</Text> filter
            </Text>
            <Pressable onPress={() => setPendingFilterType(null)}>
              <Text style={[styles.pendingCancel, { color: themeColors.textMuted }]}>
                Cancel
              </Text>
            </Pressable>
          </Animated.View>
        )}

        {/* Filter picker dropdown */}
        <FilterPicker
          visible={showFilterPicker}
          onSelectFilter={handleAddFilter}
          onClose={() => setShowFilterPicker(false)}
        />
      </View>

      {/* Results count + sort toggle */}
      {totalResults > 0 && (
        <Animated.View
          entering={FadeIn.duration(150)}
          style={styles.resultsCountRow}
        >
          <Text style={[styles.resultsCount, { color: themeColors.textMuted }]}>
            {totalResults} result{totalResults !== 1 ? 's' : ''}
          </Text>
          <View style={styles.sortToggle}>
            {(['relevance', 'newest', 'oldest'] as SearchSortOrder[]).map((order) => (
              <Pressable
                key={order}
                onPress={() => setSortOrder(order)}
                style={[
                  styles.sortOption,
                  sortOrder === order && { backgroundColor: themeColors.accentPrimary + '30' },
                ]}
              >
                <Text
                  style={[
                    styles.sortOptionText,
                    {
                      color: sortOrder === order ? themeColors.accentPrimary : themeColors.textMuted,
                      fontFamily: sortOrder === order ? 'gg-sans-bold' : 'gg-sans',
                    },
                  ]}
                >
                  {order.charAt(0).toUpperCase() + order.slice(1)}
                </Text>
              </Pressable>
            ))}
          </View>
        </Animated.View>
      )}

      {/* Results list */}
      {loading && results.length === 0 ? (
        <View style={styles.center}>
          <ActivityIndicator color={themeColors.accentPrimary} />
          <Text style={[styles.loadingText, { color: themeColors.textMuted }]}>
            Searching...
          </Text>
        </View>
      ) : results.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="search-outline" size={48} color={themeColors.textMuted} />
          <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>
            {query.trim() || filters.length > 0
              ? 'No results found'
              : 'Search messages'}
          </Text>
          <Text style={[styles.emptySubtitle, { color: themeColors.textMuted }]}>
            {query.trim() || filters.length > 0
              ? 'Try adjusting your search or filters'
              : 'Use filters to narrow your search'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={results}
          renderItem={renderResult}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.resultsList}
          onEndReached={handleLoadMore}
          onEndReachedThreshold={0.3}
          ListFooterComponent={
            loading ? (
              <ActivityIndicator
                color={themeColors.accentPrimary}
                style={{ paddingVertical: spacing.lg }}
              />
            ) : null
          }
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        />
      )}
    </View>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchArea: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    zIndex: 10,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    borderRadius: borderRadius.md,
    minHeight: 40,
    gap: spacing.xs,
  },
  filterScroll: {
    maxWidth: '40%',
  },
  filterScrollContent: {
    gap: spacing.xs,
    alignItems: 'center',
  },
  searchInput: {
    flex: 1,
    ...typography.bodySmall,
    paddingVertical: spacing.xs,
  },
  filterBtn: {
    padding: spacing.xs,
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  filterChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: borderRadius.sm,
  },
  filterType: {
    ...typography.micro,
    fontFamily: 'gg-sans-bold',
  },
  filterValue: {
    ...typography.micro,
    maxWidth: 80,
  },
  filterPicker: {
    marginTop: spacing.sm,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    padding: spacing.sm,
  },
  filterPickerTitle: {
    ...typography.overline,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  filterOption: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.sm,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  filterOptionInfo: {
    flex: 1,
  },
  filterOptionLabel: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  filterOptionHint: {
    ...typography.caption,
  },
  pendingBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    marginTop: spacing.sm,
  },
  pendingText: {
    ...typography.caption,
  },
  pendingCancel: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  resultsCountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  resultsCount: {
    ...typography.caption,
  },
  sortToggle: {
    flexDirection: 'row',
    gap: 2,
  },
  sortOption: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: borderRadius.sm,
  },
  sortOptionText: {
    fontSize: 11,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.md,
    paddingHorizontal: spacing.xl,
  },
  loadingText: {
    ...typography.bodySmall,
  },
  emptyTitle: {
    ...typography.headingM,
    textAlign: 'center',
  },
  emptySubtitle: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  resultsList: {
    padding: spacing.md,
    gap: spacing.sm,
  },
  resultCard: {
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  resultHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  resultMeta: {
    flex: 1,
  },
  resultAuthor: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  resultTime: {
    ...typography.micro,
  },
  resultBadges: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  resultContent: {
    ...typography.bodySmall,
    marginBottom: spacing.sm,
  },
  resultFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  resultChannel: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  resultChannelName: {
    ...typography.micro,
  },
  resultServerName: {
    ...typography.micro,
  },
  jumpBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.sm,
  },
  jumpText: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
});
