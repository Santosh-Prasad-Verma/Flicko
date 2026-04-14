/**
 * QuickSwitcher Component (Feature 12)
 *
 * Universal search overlay to quickly jump to any channel, DM, or server.
 * Triggered by swipe down or search icon.
 */
import React, { memo, useState, useCallback, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  FlatList,
  Modal,
} from 'react-native';
import Animated, { FadeIn, FadeOut, SlideInUp } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';
import { supabase } from '@services/supabase';

interface QuickSwitcherProps {
  visible: boolean;
  onClose: () => void;
  userId?: string;
}

interface SwitcherItem {
  id: string;
  type: 'channel' | 'dm' | 'server';
  name: string;
  subtitle?: string;
  icon: keyof typeof Ionicons.glyphMap;
  serverId?: string;
}

export const QuickSwitcher = memo(function QuickSwitcher({
  visible,
  onClose,
  userId,
}: QuickSwitcherProps) {
  const { themeColors: c } = useTheme();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SwitcherItem[]>([]);
  const [recentItems, setRecentItems] = useState<SwitcherItem[]>([]);
  const inputRef = useRef<TextInput>(null);

  // Focus input when opened
  useEffect(() => {
    if (visible) {
      setTimeout(() => inputRef.current?.focus(), 200);
    } else {
      setQuery('');
      setResults([]);
    }
  }, [visible]);

  const search = useCallback(async (text: string) => {
    setQuery(text);
    if (!text.trim()) {
      setResults([]);
      return;
    }

    const items: SwitcherItem[] = [];
    const searchTerm = `%${text.toLowerCase()}%`;

    try {
      // Search channels
      const { data: channels } = await supabase
        .from('channels')
        .select('id, name, server_id, servers!inner(name)')
        .ilike('name', searchTerm)
        .limit(10);

      if (channels) {
        for (const ch of channels) {
          items.push({
            id: ch.id,
            type: 'channel',
            name: `#${ch.name}`,
            subtitle: (ch as any).servers?.name,
            icon: 'chatbubble-outline',
            serverId: ch.server_id,
          });
        }
      }

      // Search servers
      const { data: servers } = await supabase
        .from('servers')
        .select('id, name')
        .ilike('name', searchTerm)
        .limit(5);

      if (servers) {
        for (const s of servers) {
          items.push({
            id: s.id,
            type: 'server',
            name: s.name,
            icon: 'server-outline',
          });
        }
      }

      // Search DMs (users)
      const { data: users } = await supabase
        .from('profiles')
        .select('id, username, display_name')
        .or(`username.ilike.${searchTerm},display_name.ilike.${searchTerm}`)
        .limit(5);

      if (users) {
        for (const u of users) {
          items.push({
            id: u.id,
            type: 'dm',
            name: u.display_name || u.username,
            subtitle: `@${u.username}`,
            icon: 'person-outline',
          });
        }
      }
    } catch (err) {
      console.error('[QuickSwitcher] search error:', err);
    }

    setResults(items);
  }, []);

  const handleSelect = useCallback((item: SwitcherItem) => {
    onClose();
    switch (item.type) {
      case 'channel':
        if (item.serverId) {
          router.push(`/server/${item.serverId}/channel/${item.id}`);
        }
        break;
      case 'server':
        router.push(`/server/${item.id}`);
        break;
      case 'dm':
        router.push(`/dm/${item.id}`);
        break;
    }
  }, [onClose]);

  const displayItems = query.trim() ? results : recentItems;

  if (!visible) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose}>
        <Animated.View
          entering={SlideInUp.duration(200)}
          style={[styles.container, { backgroundColor: c.bgSecondary }]}
        >
          <Pressable onPress={(e) => e.stopPropagation()}>
            {/* Search input */}
            <View style={[styles.searchRow, { backgroundColor: c.bgTertiary }]}>
              <Ionicons name="search" size={18} color={c.textMuted} />
              <TextInput
                ref={inputRef}
                value={query}
                onChangeText={search}
                placeholder="Where would you like to go?"
                placeholderTextColor={c.textMuted}
                style={[styles.searchInput, { color: c.textPrimary }]}
                selectionColor={c.accentPrimary}
                autoCapitalize="none"
                autoCorrect={false}
              />
              {query.length > 0 && (
                <Pressable onPress={() => { setQuery(''); setResults([]); }} hitSlop={12}>
                  <Ionicons name="close-circle" size={18} color={c.textMuted} />
                </Pressable>
              )}
            </View>

            {/* Results */}
            <FlatList
              data={displayItems}
              keyExtractor={(item) => `${item.type}-${item.id}`}
              style={styles.resultsList}
              keyboardShouldPersistTaps="handled"
              ListEmptyComponent={
                <View style={styles.emptyState}>
                  <Text style={[styles.emptyText, { color: c.textMuted }]}>
                    {query.trim() ? 'No results found' : 'Start typing to search channels, servers, and DMs'}
                  </Text>
                </View>
              }
              renderItem={({ item }) => (
                <Pressable
                  onPress={() => handleSelect(item)}
                  style={[styles.resultItem, { borderBottomColor: c.border }]}
                >
                  <Ionicons name={item.icon} size={20} color={c.textSecondary} />
                  <View style={styles.resultTextCol}>
                    <Text style={[styles.resultName, { color: c.textPrimary }]}>{item.name}</Text>
                    {item.subtitle && (
                      <Text style={[styles.resultSubtitle, { color: c.textMuted }]}>{item.subtitle}</Text>
                    )}
                  </View>
                  <View style={[styles.badge, { backgroundColor: c.bgTertiary }]}>
                    <Text style={[styles.badgeText, { color: c.textMuted }]}>
                      {item.type === 'channel' ? 'Channel' : item.type === 'server' ? 'Server' : 'DM'}
                    </Text>
                  </View>
                </Pressable>
              )}
            />
          </Pressable>
        </Animated.View>
      </Pressable>
    </Modal>
  );
});

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-start',
    paddingTop: 80,
  },
  container: {
    marginHorizontal: spacing.lg,
    borderRadius: borderRadius.xl,
    maxHeight: 450,
    overflow: 'hidden',
  },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    margin: spacing.md,
    gap: spacing.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    fontFamily: 'gg-sans',
    paddingVertical: 4,
  },
  resultsList: {
    maxHeight: 350,
  },
  resultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.md,
  },
  resultTextCol: {
    flex: 1,
  },
  resultName: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  resultSubtitle: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    marginTop: 2,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
  },
  badgeText: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
  },
  emptyState: {
    padding: spacing.xl,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    fontFamily: 'gg-sans',
    textAlign: 'center',
  },
});
