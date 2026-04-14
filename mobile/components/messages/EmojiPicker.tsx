/**
 * EmojiPicker Component
 *
 * Mobile emoji picker with Unicode emoji categories + custom emojis.
 * Custom emojis split into Animated (GIF) and Static sections.
 */
import React, { useState, useMemo, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Modal as RNModal,
  TextInput,
  ActivityIndicator,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { spacing } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';
import { ANIMATED_EMOJIS, STATIC_EMOJIS, type CustomEmoji } from '../../constants/customEmojis';
import { supabase } from '../../services/supabase';
import { GifPicker } from './GifPicker';

interface ServerEmoji {
  id: string;
  server_id: string;
  name: string;
  url: string;
  animated: boolean;
}

export interface EmojiPickerProps {
  visible: boolean;
  onSelect: (emoji: string) => void;
  onClose: () => void;
  serverId?: string;
  onGifSelect?: (gif: { url: string; title: string; width: number; height: number }) => void;
}

const EMOJI_CATEGORIES: Record<string, string[]> = {
  'Smileys': [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
    '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
    '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
    '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
    '🤧', '🥵', '🥶', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐',
    '👍', '👎', '👏', '🙌', '👋', '🤝', '🙏', '💪', '🤘', '✌️',
  ],
  'Animals': [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
    '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🦆',
    '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋',
    '🌸', '🌺', '🌻', '🌷', '🌹', '🥀', '🌼', '🌵', '🌲', '🌳',
    '🌴', '🌱', '🌿', '☘️', '🍀', '🍁', '🍂', '🍃', '🌾', '🌈',
  ],
  'Food': [
    '🍎', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒', '🍑',
    '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬', '🥒',
    '🌶️', '🌽', '🥕', '🧄', '🧅', '🥔', '🍠', '🥐', '🥯', '🍞',
    '🥖', '🥨', '🧀', '🥚', '🍳', '🧈', '🥞', '🧇', '🥓', '🥩',
    '🍗', '🍖', '🌭', '🍔', '🍟', '🍕', '🥪', '🧆', '🌮',
  ],
  'Activities': [
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
    '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🥅', '⛳', '🏹', '🎣',
    '🥊', '🥋', '🎽', '🛹', '🛼', '🛷', '⛸️', '🥌', '🎿', '⛷️',
    '🎮', '🕹️', '🎯', '🎲', '🎰', '🎳', '🎨', '🎭', '🎪', '🎬',
  ],
  'Travel': [
    '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
    '🚚', '🚛', '🚜', '🛵', '🚲', '🏍️', '🛺', '🚨', '🚔',
    '✈️', '🛫', '🛬', '🚀', '🛸', '🚁', '🛶', '⛵', '🚤', '🛳️',
    '⛴️', '🚢', '⚓', '🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏭', '🏢',
  ],
  'Objects': [
    '⌚', '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️', '💾',
    '💿', '📀', '📹', '📷', '📸', '📼', '🎥', '📞', '☎️', '📟',
    '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '🕰️', '⏱️', '⏲️', '⏳',
    '💡', '🔦', '🕯️', '🧯', '🛢️', '💰', '💵', '💴', '💶', '💷',
  ],
  'Symbols': [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
    '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '🎁', '✨', '⭐',
    '🌟', '💫', '☑️', '✅', '❌', '❎', '➕', '➖', '✖️', '➗',
    '🔥', '💯', '🎉', '🎊', '🎈', '🎀', '🏆', '🥇', '🥈', '🥉',
  ],
};

type TabType = 'animated' | 'server' | 'static' | string;

const UNICODE_CATEGORIES = Object.keys(EMOJI_CATEGORIES);

export function EmojiPicker({ visible, onSelect, onClose, serverId, onGifSelect }: EmojiPickerProps) {
  const { themeColors } = useTheme();
  const [activeTab, setActiveTab] = useState<TabType>('animated');
  const [searchQuery, setSearchQuery] = useState('');
  const [serverEmojis, setServerEmojis] = useState<ServerEmoji[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const fetchServerEmojis = async () => {
      if (!serverId) return;
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from('server_emojis')
          .select('*')
          .eq('server_id', serverId);

        if (error) throw error;
        if (data) {
          setServerEmojis((data as ServerEmoji[]).map((e: ServerEmoji) => ({
            ...e,
            animated: e.url.endsWith('.gif') || e.animated
          })));
        }
      } catch (error: any) {
        console.error('Error fetching server emojis:', error);
      } finally {
        setLoading(false);
      }
    };

    if (visible && serverId) {
      fetchServerEmojis();
    }
  }, [visible, serverId]);

  const filteredServer = useMemo(() => {
    if (!searchQuery.trim()) return serverEmojis;
    const q = searchQuery.toLowerCase();
    return serverEmojis.filter((e) => e.name.toLowerCase().includes(q));
  }, [searchQuery, serverEmojis]);

  const filteredAnimated = useMemo(() => {
    if (!searchQuery.trim()) return ANIMATED_EMOJIS;
    const q = searchQuery.toLowerCase();
    return ANIMATED_EMOJIS.filter((e) => e.name.toLowerCase().includes(q));
  }, [searchQuery]);

  const filteredStatic = useMemo(() => {
    if (!searchQuery.trim()) return STATIC_EMOJIS;
    const q = searchQuery.toLowerCase();
    return STATIC_EMOJIS.filter((e) => e.name.toLowerCase().includes(q));
  }, [searchQuery]);

  const handleEmojiPress = (emoji: string) => {
    onSelect(emoji);
    onClose();
  };

  const handleCustomEmojiPress = (emoji: CustomEmoji | ServerEmoji) => {
    onSelect(`:${emoji.name}:`);
    onClose();
  };

  const isUnicodeTab = UNICODE_CATEGORIES.includes(activeTab);

  const renderServerEmojis = () => {
    if (loading) {
      return (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="small" color="#5B4CFF" />
        </View>
      );
    }

    if (filteredServer.length === 0) {
      return (
        <View style={styles.centerContainer}>
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            {searchQuery ? 'No emojis matching search' : 'No server emojis available'}
          </Text>
        </View>
      );
    }

    return (
      <View style={styles.emojiGrid}>
        {filteredServer.map((emoji: ServerEmoji) => (
          <Pressable
            key={emoji.id}
            style={({ pressed }: { pressed: boolean }) => [
              styles.customEmojiBtn,
              pressed && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => handleCustomEmojiPress(emoji)}
          >
            <Image
              source={{ uri: emoji.url }}
              style={styles.customEmojiImg}
              contentFit="contain"
              autoplay={true}
            />
          </Pressable>
        ))}
      </View>
    );
  };

  return (
    <RNModal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose}>
        <Pressable style={[styles.picker, { backgroundColor: themeColors.bgSecondary }]}>
          {/* Search bar */}
          <View style={[styles.searchRow, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="search" size={16} color={themeColors.textMuted} />
            <TextInput
              value={searchQuery}
              onChangeText={setSearchQuery}
              placeholder="Search emojis..."
              placeholderTextColor={themeColors.textMuted}
              style={[styles.searchInput, { color: themeColors.textPrimary }]}
              autoCapitalize="none"
              autoCorrect={false}
            />
            {searchQuery.length > 0 && (
              <Pressable onPress={() => setSearchQuery('')} hitSlop={8}>
                <Ionicons name="close-circle" size={16} color={themeColors.textMuted} />
              </Pressable>
            )}
          </View>

          {/* Tab bar */}
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabBar} contentContainerStyle={styles.tabBarContent}>
            <Pressable
              style={[styles.tabBtn, activeTab === 'animated' && { backgroundColor: themeColors.bgTertiary, borderRadius: 6 }]}
              onPress={() => setActiveTab('animated')}
            >
              <Text style={[styles.tabLabel, { color: activeTab === 'animated' ? themeColors.accentPrimary : themeColors.textMuted }]}>Emoji</Text>
            </Pressable>

            <Pressable
              style={[styles.tabBtn, activeTab === 'giphy' && { backgroundColor: themeColors.bgTertiary, borderRadius: 6 }]}
              onPress={() => setActiveTab('giphy')}
            >
              <Text style={[styles.tabLabel, { color: activeTab === 'giphy' ? themeColors.accentPrimary : themeColors.textMuted }]}>GIFs</Text>
            </Pressable>

            {serverEmojis.length > 0 && (
              <Pressable
                style={[styles.tabBtn, activeTab === 'server' && { backgroundColor: themeColors.bgTertiary, borderRadius: 6 }]}
                onPress={() => setActiveTab('server')}
              >
                <Ionicons name="server-outline" size={18} color={activeTab === 'server' ? themeColors.accentPrimary : themeColors.textMuted} />
              </Pressable>
            )}

            <Pressable
              style={[styles.tabBtn, activeTab === 'static' && { backgroundColor: themeColors.bgTertiary, borderRadius: 6 }]}
              onPress={() => setActiveTab('static')}
            >
              <Ionicons name="images-outline" size={18} color={activeTab === 'static' ? themeColors.accentPrimary : themeColors.textMuted} />
            </Pressable>

            <View style={[styles.tabDivider, { backgroundColor: themeColors.border }]} />

            {UNICODE_CATEGORIES.map((cat) => (
              <Pressable
                key={cat}
                style={[styles.tabBtn, activeTab === cat && { backgroundColor: themeColors.bgTertiary, borderRadius: 6 }]}
                onPress={() => setActiveTab(cat)}
              >
                <Text style={styles.tabIcon}>
                  {cat === 'Smileys' ? '😀' : cat === 'Animals' ? '🐶' : cat === 'Food' ? '🍎' :
                   cat === 'Activities' ? '⚽' : cat === 'Travel' ? '🚗' : cat === 'Objects' ? '💻' : '❤️'}
                </Text>
              </Pressable>
            ))}
          </ScrollView>

          {/* Category label */}
          <Text style={[styles.categoryLabel, { color: themeColors.textMuted }]}>
            {activeTab === 'animated' ? 'Animated' : activeTab === 'static' ? 'Custom Stickers' : activeTab === 'giphy' ? 'GIPHY' : activeTab}
          </Text>

          {/* Content */}
          <ScrollView style={styles.emojiScroll} contentContainerStyle={activeTab === 'giphy' ? { flex: 1 } : styles.emojiGrid}>
            {activeTab === 'giphy' && (
              <GifPicker
                embedded
                apiKey={process.env.EXPO_PUBLIC_GIPHY_API_KEY}
                onClose={onClose}
                onSelect={(gif) => {
                  onGifSelect?.(gif);
                  onClose();
                }}
              />
            )}
            {activeTab === 'animated' && (
              filteredAnimated.length > 0 ? (
                filteredAnimated.map((emoji: CustomEmoji) => (
                  <Pressable
                    key={emoji.name}
                    style={({ pressed }: { pressed: boolean }) => [styles.customEmojiBtn, pressed && { backgroundColor: themeColors.bgTertiary }]}
                    onPress={() => handleCustomEmojiPress(emoji)}
                  >
                    <Image source={emoji.source} style={styles.customEmojiImg} contentFit="contain" autoplay={true} />
                  </Pressable>
                ))
              ) : (
                <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>No animated emojis found</Text>
              )
            )}

            {activeTab === 'server' && renderServerEmojis()}

            {activeTab === 'static' && (
              filteredStatic.length > 0 ? (
                filteredStatic.map((emoji: CustomEmoji) => (
                  <Pressable
                    key={emoji.name}
                    style={({ pressed }: { pressed: boolean }) => [styles.customEmojiBtn, pressed && { backgroundColor: themeColors.bgTertiary }]}
                    onPress={() => handleCustomEmojiPress(emoji)}
                  >
                    <Image source={emoji.source} style={styles.customEmojiImg} contentFit="contain" />
                  </Pressable>
                ))
              ) : (
                <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>No static emojis found</Text>
              )
            )}

            {isUnicodeTab && EMOJI_CATEGORIES[activeTab]?.map((emoji: string) => (
              <Pressable
                key={emoji}
                style={({ pressed }: { pressed: boolean }) => [styles.emojiBtn, pressed && { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => handleEmojiPress(emoji)}
              >
                <Text style={styles.emoji}>{emoji}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </Pressable>
      </Pressable>
    </RNModal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  picker: {
    height: 380,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingTop: spacing.sm,
  },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.md,
    borderRadius: 8,
    paddingHorizontal: spacing.sm,
    paddingVertical: 6,
    marginBottom: spacing.xs,
    gap: spacing.xs,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    paddingVertical: 0,
  },
  tabBar: {
    maxHeight: 36,
  },
  tabBarContent: {
    paddingHorizontal: spacing.sm,
    gap: 2,
    alignItems: 'center',
  },
  tabBtn: {
    paddingHorizontal: 8,
    paddingVertical: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabLabel: {
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  tabIcon: {
    fontSize: 18,
  },
  tabDivider: {
    width: 1,
    height: 20,
    marginHorizontal: 4,
  },
  categoryLabel: {
    fontSize: 12,
    fontWeight: 'bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  emojiScroll: {
    flex: 1,
  },
  emojiGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: spacing.xs,
    paddingBottom: spacing.xl,
  },
  emojiBtn: {
    width: '12.5%',
    aspectRatio: 1,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 6,
  },
  emoji: {
    fontSize: 24,
  },
  customEmojiBtn: {
    width: '14.28%',
    aspectRatio: 1,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 6,
    padding: 4,
  },
  customEmojiImg: {
    width: 32,
    height: 32,
  },
  emptyText: {
    fontSize: 14,
    textAlign: 'center',
    paddingTop: spacing.xl,
    width: '100%',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: spacing.xl,
    width: '100%',
  },
});
