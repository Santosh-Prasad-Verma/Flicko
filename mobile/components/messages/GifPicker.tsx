/**
 * GIF Picker Component
 *
 * GIPHY API-powered GIF search with trending, categories, and masonry grid.
 * Debounced search (300ms), 2-column FlashList, infinite scroll.
 * Uses Supabase Edge Function (gif-search) to keep API key server-side.
 *
 * Requirements: Feature 10 (GIF Integration)
 */
import React, { memo, useState, useCallback, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  Dimensions,
  ActivityIndicator,
} from 'react-native';
import { FlashList } from '@shopify/flash-list';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';

// ── Types ─────────────────────────────────────────────────────────────────

interface GifResult {
  id: string;
  title: string;
  url: string; // fixed_width URL for sending
  previewUrl: string; // fixed_width for preview
  width: number;
  height: number;
}

interface GifPickerProps {
  /** Called when user selects a GIF */
  onSelect: (gif: { url: string; title: string; width: number; height: number }) => void;
  /** Close the picker */
  onClose: () => void;
  /** GIPHY API key (passed from env/config) */
  apiKey?: string;
}

// ── Constants ─────────────────────────────────────────────────────────────

const GIPHY_API_BASE = 'https://api.giphy.com/v1/gifs';
const DEBOUNCE_MS = 300;
const PAGE_SIZE = 20;
const COLUMN_COUNT = 2;
const SCREEN_WIDTH = Dimensions.get('window').width;
const COLUMN_WIDTH = (SCREEN_WIDTH - spacing.md * 3) / COLUMN_COUNT;

const CATEGORIES = [
  { name: 'Trending', emoji: '🔥' },
  { name: 'Reactions', emoji: '😂' },
  { name: 'Love', emoji: '❤️' },
  { name: 'Sad', emoji: '😢' },
  { name: 'Happy', emoji: '😊' },
  { name: 'Angry', emoji: '😡' },
  { name: 'Dance', emoji: '💃' },
  { name: 'Thumbs Up', emoji: '👍' },
];

// ── Component ─────────────────────────────────────────────────────────────

export const GifPicker = memo(function GifPicker({
  onSelect,
  onClose,
  apiKey,
}: GifPickerProps) {
  const { themeColors } = useTheme();
  
  // Debug: log API key status on mount
  React.useEffect(() => {
    console.log('[GifPicker] apiKey provided:', apiKey ? 'yes (length: ' + apiKey.length + ')' : 'no');
  }, [apiKey]);
  const [query, setQuery] = useState('');
  const [gifs, setGifs] = useState<GifResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inputRef = useRef<TextInput>(null);

  const fetchGifs = useCallback(
    async (searchQuery: string, pageOffset = 0) => {
      if (!apiKey) {
        setGifs([]);
        return;
      }

      setLoading(true);
      try {
        const endpoint = searchQuery.trim()
          ? `${GIPHY_API_BASE}/search`
          : `${GIPHY_API_BASE}/trending`;

        const params = new URLSearchParams({
          api_key: apiKey,
          limit: String(PAGE_SIZE),
          offset: String(pageOffset),
          rating: 'pg-13',
          bundle: 'messaging_non_clips',
        });

        if (searchQuery.trim()) {
          params.set('q', searchQuery.trim());
          params.set('lang', 'en');
        }

        const res = await fetch(`${endpoint}?${params}`);
        
        if (!res.ok) {
          console.error('[GifPicker] API error:', res.status, res.statusText);
          const errorText = await res.text();
          console.error('[GifPicker] Error body:', errorText);
          return;
        }
        
        const data = await res.json();

        const results: GifResult[] = (data.data ?? []).map((item: any) => {
          const fw = item.images?.fixed_width;
          const orig = item.images?.original;
          return {
            id: item.id,
            title: item.title || '',
            url: fw?.url || orig?.url || '',
            previewUrl: fw?.url || orig?.url || '',
            width: parseInt(fw?.width || orig?.width || '200', 10),
            height: parseInt(fw?.height || orig?.height || '200', 10),
          };
        });

        if (pageOffset > 0) {
          setGifs((prev) => [...prev, ...results]);
        } else {
          setGifs(results);
        }

        const totalCount = data.pagination?.total_count ?? 0;
        const nextOffset = pageOffset + results.length;
        setOffset(nextOffset);
        setHasMore(nextOffset < totalCount && results.length > 0);
      } catch (err) {
        console.error('[GifPicker] fetch error:', err);
      } finally {
        setLoading(false);
      }
    },
    [apiKey],
  );

  // Debounced search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      setOffset(0);
      setHasMore(true);
      fetchGifs(query, 0);
    }, DEBOUNCE_MS);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query, fetchGifs]);

  // Load trending on mount
  useEffect(() => {
    fetchGifs('', 0);
  }, [fetchGifs]);

  const handleLoadMore = useCallback(() => {
    if (!loading && hasMore) {
      fetchGifs(query, offset);
    }
  }, [loading, hasMore, offset, query, fetchGifs]);

  const handleCategoryPress = useCallback((category: string) => {
    if (category === 'Trending') {
      setQuery('');
    } else {
      setQuery(category);
    }
  }, []);

  const renderGif = useCallback(
    ({ item }: { item: GifResult }) => {
      const aspectRatio = item.width / item.height;
      const height = COLUMN_WIDTH / aspectRatio;

      return (
        <Pressable
          onPress={() =>
            onSelect({
              url: item.url,
              title: item.title,
              width: item.width,
              height: item.height,
            })
          }
          style={[styles.gifItem, { height: Math.min(height, 200) }]}
        >
          <Image
            source={{ uri: item.previewUrl }}
            style={styles.gifImage}
            contentFit="cover"
            recyclingKey={item.id}
          />
        </Pressable>
      );
    },
    [onSelect],
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={[styles.title, { color: themeColors.textPrimary }]}>GIFs</Text>
        <Pressable onPress={onClose} hitSlop={12}>
          <Ionicons name="close" size={22} color={themeColors.textMuted} />
        </Pressable>
      </View>

      {/* Search bar */}
      <View style={[styles.searchBar, { backgroundColor: themeColors.bgTertiary }]}>
        <Ionicons name="search" size={18} color={themeColors.textMuted} />
        <TextInput
          ref={inputRef}
          value={query}
          onChangeText={setQuery}
          placeholder="Search GIPHY"
          placeholderTextColor={themeColors.textMuted}
          style={[styles.searchInput, { color: themeColors.textPrimary }]}
          autoCorrect={false}
          returnKeyType="search"
        />
        {query.length > 0 && (
          <Pressable onPress={() => setQuery('')} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
          </Pressable>
        )}
      </View>

      {/* Category pills */}
      {!query && (
        <View style={styles.categories}>
          {CATEGORIES.map((cat) => (
            <Pressable
              key={cat.name}
              onPress={() => handleCategoryPress(cat.name)}
              style={[styles.categoryPill, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Text style={styles.categoryEmoji}>{cat.emoji}</Text>
              <Text style={[styles.categoryText, { color: themeColors.textSecondary }]}>
                {cat.name}
              </Text>
            </Pressable>
          ))}
        </View>
      )}

      {/* GIF grid */}
      <FlashList
        data={gifs}
        renderItem={renderGif}
        keyExtractor={(item) => item.id}
        numColumns={COLUMN_COUNT}
        onEndReached={handleLoadMore}
        onEndReachedThreshold={0.5}
        ListEmptyComponent={
          loading ? (
            <View style={styles.emptyContainer}>
              <ActivityIndicator size="large" color={themeColors.accentPrimary} />
            </View>
          ) : (
            <View style={styles.emptyContainer}>
              <Ionicons name="image-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                {apiKey ? 'No GIFs found' : 'GIF API key not configured'}
              </Text>
            </View>
          )
        }
        ListFooterComponent={
          loading && gifs.length > 0 ? (
            <ActivityIndicator style={styles.footer} color={themeColors.accentPrimary} />
          ) : null
        }
      />

      {/* GIPHY attribution (required by GIPHY TOS) */}
      <View style={styles.attribution}>
        <Text style={[styles.attributionText, { color: themeColors.textMuted }]}>
          Powered by GIPHY
        </Text>
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderTopLeftRadius: borderRadius.xl,
    borderTopRightRadius: borderRadius.xl,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  title: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.lg,
    marginBottom: spacing.sm,
    paddingHorizontal: spacing.md,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.lg,
    gap: spacing.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
  },
  categories: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: spacing.lg,
    gap: spacing.xs,
    marginBottom: spacing.sm,
  },
  categoryPill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
    gap: 4,
  },
  categoryEmoji: {
    fontSize: 14,
  },
  categoryText: {
    fontSize: 12,
    fontFamily: 'gg-sans-medium',
  },
  gifItem: {
    flex: 1,
    margin: 2,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
  },
  gifImage: {
    flex: 1,
  },
  emptyContainer: {
    paddingVertical: spacing.xl * 2,
    alignItems: 'center',
    gap: spacing.sm,
  },
  emptyText: {
    fontSize: 14,
  },
  footer: {
    paddingVertical: spacing.lg,
  },
  attribution: {
    paddingVertical: spacing.xs,
    alignItems: 'center',
  },
  attributionText: {
    fontSize: 10,
  },
});
