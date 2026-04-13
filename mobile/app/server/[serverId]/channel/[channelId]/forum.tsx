/**
 * Forum Channel Screen
 *
 * Displays a forum channel as a list of posts (threads) with tag filters,
 * sorting, and a "New Post" flow.
 *
 * Route: /server/[serverId]/channel/[channelId]/forum
 * Requirements: Feature 7 (Forum Channels)
 */
import React, { useCallback, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  Modal,
  TextInput,
  ActivityIndicator,
  ScrollView,
  Alert,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../../services/supabase';
import { useForumPosts, useForumTags, useCreateForumPost } from '@hooks/useForum';
import { useAuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET, type ThemeColors } from '../../../../../constants/Colors';
import { useTheme } from '../../../../../hooks/useTheme';

type SortMode = 'latest_activity' | 'creation_date';

interface ForumTag {
  id: string;
  name: string;
  emoji?: string | null;
  moderated?: boolean;
}

interface ForumPostItem {
  id: string;
  name: string;
  creator_id: string;
  message_count: number;
  last_message_at: string | null;
  created_at: string;
  creator?: { username: string; display_name?: string; avatar_url?: string };
  tags?: ForumTag[];
  first_message?: string;
}

// ─── Main Screen ───────────────────────────────────────────────────────────────

export default function ForumChannelScreen() {
  const { serverId, channelId } = useLocalSearchParams<{
    serverId: string;
    channelId: string;
  }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);

  // State
  const [sort, setSort] = useState<SortMode>('latest_activity');
  const [filterTagId, setFilterTagId] = useState<string | undefined>();
  const [createVisible, setCreateVisible] = useState(false);

  // Channel info
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channels')
        .select('*')
        .eq('id', channelId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!channelId,
  });

  // Tags
  const { data: tags = [] } = useForumTags(channelId!);

  // Posts
  const {
    data: postsData,
    isLoading,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    refetch,
  } = useForumPosts(channelId!, { sort, tagId: filterTagId });

  const posts: ForumPostItem[] = useMemo(() => {
    if (!postsData?.pages) return [];
    return postsData.pages.flat() as ForumPostItem[];
  }, [postsData]);

  const handlePostPress = useCallback(
    (post: ForumPostItem) => {
      // Navigate to the thread (forum post = thread)
      router.push(
        `/server/${serverId}/channel/${channelId}/thread/${post.id}` as any,
      );
    },
    [serverId, channelId],
  );

  const handleLoadMore = useCallback(() => {
    if (hasNextPage && !isFetchingNextPage) fetchNextPage();
  }, [hasNextPage, isFetchingNextPage, fetchNextPage]);

  // ── Render ──

  const renderPost = useCallback(
    ({ item }: { item: ForumPostItem }) => (
      <ForumPostCard
        post={item}
        tags={tags}
        themeColors={themeColors}
        onPress={() => handlePostPress(item)}
      />
    ),
    [tags, themeColors, handlePostPress],
  );

  const renderHeader = () => (
    <View>
      {/* Topic / description */}
      {channel?.topic ? (
        <Text style={[styles.topicText, { color: themeColors.textSecondary }]}>
          {channel.topic}
        </Text>
      ) : null}

      {/* Tag filters */}
      {tags.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.tagRow}
          contentContainerStyle={styles.tagRowContent}
        >
          <Pressable
            style={[
              styles.tagChip,
              {
                backgroundColor: !filterTagId ? themeColors.accentPrimary : themeColors.bgTertiary,
              },
            ]}
            onPress={() => setFilterTagId(undefined)}
          >
            <Text
              style={[
                styles.tagChipText,
                { color: !filterTagId ? '#fff' : themeColors.textSecondary },
              ]}
            >
              All
            </Text>
          </Pressable>
          {tags.map((tag: ForumTag) => {
            const active = filterTagId === tag.id;
            return (
              <Pressable
                key={tag.id}
                style={[
                  styles.tagChip,
                  {
                    backgroundColor: active
                      ? themeColors.accentPrimary
                      : themeColors.bgTertiary,
                  },
                ]}
                onPress={() => setFilterTagId(active ? undefined : tag.id)}
              >
                <Text
                  style={[
                    styles.tagChipText,
                    { color: active ? '#fff' : themeColors.textSecondary },
                  ]}
                >
                  {tag.emoji ? `${tag.emoji} ` : ''}
                  {tag.name}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>
      )}

      {/* Sort bar */}
      <View style={[styles.sortBar, { borderBottomColor: themeColors.border }]}>
        <SortButton
          label="Latest Activity"
          active={sort === 'latest_activity'}
          themeColors={themeColors}
          onPress={() => setSort('latest_activity')}
        />
        <SortButton
          label="Creation Date"
          active={sort === 'creation_date'}
          themeColors={themeColors}
          onPress={() => setSort('creation_date')}
        />
      </View>
    </View>
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + spacing.sm,
              backgroundColor: themeColors.bgSecondary,
              borderBottomColor: themeColors.border,
            },
          ]}
        >
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={styles.backButton}
            accessibilityRole="button"
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <View style={styles.channelNameRow}>
              <Ionicons name="newspaper-outline" size={16} color={themeColors.textMuted} />
              <Text style={[styles.channelName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {channel?.name || 'Forum'}
              </Text>
            </View>
          </View>
          <Pressable
            onPress={() => setCreateVisible(true)}
            hitSlop={8}
            style={styles.headerAction}
            accessibilityLabel="New post"
          >
            <Ionicons name="add-circle-outline" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        {/* Post list */}
        <FlatList
          data={posts}
          renderItem={renderPost}
          keyExtractor={(item) => item.id}
          ListHeaderComponent={renderHeader}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <View style={styles.emptyContainer}>
                <Ionicons name="chatbox-outline" size={48} color={themeColors.textMuted} />
                <Text style={[styles.emptyText, { color: themeColors.textSecondary }]}>
                  No posts yet — be the first!
                </Text>
              </View>
            )
          }
          ListFooterComponent={
            isFetchingNextPage ? (
              <ActivityIndicator style={styles.footerLoader} color={themeColors.accentPrimary} />
            ) : null
          }
          onEndReached={handleLoadMore}
          onEndReachedThreshold={0.3}
          onRefresh={() => refetch()}
          refreshing={false}
          contentContainerStyle={styles.listContent}
        />

        {/* Create post modal */}
        <CreateForumPostModal
          visible={createVisible}
          onClose={() => setCreateVisible(false)}
          channelId={channelId!}
          serverId={serverId!}
          tags={tags}
          themeColors={themeColors}
        />
      </View>
    </>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

function SortButton({
  label,
  active,
  themeColors,
  onPress,
}: {
  label: string;
  active: boolean;
  themeColors: ThemeColors;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.sortButton,
        active && { borderBottomColor: themeColors.accentPrimary, borderBottomWidth: 2 },
      ]}
    >
      <Text
        style={[
          styles.sortButtonText,
          { color: active ? themeColors.accentPrimary : themeColors.textMuted },
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

function ForumPostCard({
  post,
  tags,
  themeColors,
  onPress,
}: {
  post: ForumPostItem;
  tags: ForumTag[];
  themeColors: ThemeColors;
  onPress: () => void;
}) {
  const postTags = post.tags ?? [];
  const creatorName = post.creator?.display_name || post.creator?.username || 'Unknown';

  const timeAgo = useMemo(() => {
    const ts = post.last_message_at || post.created_at;
    if (!ts) return '';
    const diff = Date.now() - new Date(ts).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }, [post.last_message_at, post.created_at]);

  return (
    <Pressable
      style={[styles.postCard, { backgroundColor: themeColors.cardBg }]}
      onPress={onPress}
      accessibilityRole="button"
    >
      <Text style={[styles.postTitle, { color: themeColors.textPrimary }]} numberOfLines={2}>
        {post.name}
      </Text>

      {post.first_message ? (
        <Text style={[styles.postPreview, { color: themeColors.textSecondary }]} numberOfLines={2}>
          {post.first_message}
        </Text>
      ) : null}

      {/* Tags */}
      {postTags.length > 0 && (
        <View style={styles.postTagRow}>
          {postTags.map((t) => (
            <View key={t.id} style={[styles.postTag, { backgroundColor: themeColors.bgTertiary }]}>
              <Text style={[styles.postTagText, { color: themeColors.textSecondary }]}>
                {t.emoji ? `${t.emoji} ` : ''}
                {t.name}
              </Text>
            </View>
          ))}
        </View>
      )}

      {/* Meta row */}
      <View style={styles.postMeta}>
        <Text style={[styles.postMetaText, { color: themeColors.textMuted }]}>
          {creatorName}
        </Text>
        <View style={styles.postMetaRight}>
          <Ionicons name="chatbubble-outline" size={12} color={themeColors.textMuted} />
          <Text style={[styles.postMetaText, { color: themeColors.textMuted }]}>
            {post.message_count ?? 0}
          </Text>
          <Text style={[styles.postMetaText, { color: themeColors.textMuted }]}>·</Text>
          <Text style={[styles.postMetaText, { color: themeColors.textMuted }]}>{timeAgo}</Text>
        </View>
      </View>
    </Pressable>
  );
}

// ─── Create Post Modal ─────────────────────────────────────────────────────────

function CreateForumPostModal({
  visible,
  onClose,
  channelId,
  serverId,
  tags,
  themeColors,
}: {
  visible: boolean;
  onClose: () => void;
  channelId: string;
  serverId: string;
  tags: ForumTag[];
  themeColors: ThemeColors;
}) {
  const user = useAuthStore((s: any) => s.user);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [selectedTags, setSelectedTags] = useState<string[]>([]);

  const createPost = useCreateForumPost();

  const handleSubmit = () => {
    if (!title.trim()) {
      Alert.alert('Title required', 'Please enter a title for your post.');
      return;
    }
    if (!content.trim()) {
      Alert.alert('Content required', 'Please write something in your post.');
      return;
    }
    createPost.mutate(
      {
        channelId,
        serverId,
        name: title.trim(),
        content: content.trim(),
        creatorId: user?.id!,
        tagIds: selectedTags.length > 0 ? selectedTags : undefined,
      },
      {
        onSuccess: (thread) => {
          setTitle('');
          setContent('');
          setSelectedTags([]);
          onClose();
          // Navigate to the new thread
          router.push(
            `/server/${serverId}/channel/${channelId}/thread/${thread.id}` as any,
          );
        },
        onError: (err) => {
          Alert.alert('Failed to create post', err.message);
        },
      },
    );
  };

  const toggleTag = (tagId: string) => {
    setSelectedTags((prev) =>
      prev.includes(tagId) ? prev.filter((id) => id !== tagId) : [...prev, tagId],
    );
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: themeColors.overlay }]}>
        <View
          style={[
            styles.modalContent,
            { backgroundColor: themeColors.bgSecondary },
          ]}
        >
          {/* Modal Header */}
          <View style={[styles.modalHeader, { borderBottomColor: themeColors.border }]}>
            <Pressable onPress={onClose} hitSlop={12}>
              <Ionicons name="close" size={24} color={themeColors.textSecondary} />
            </Pressable>
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>
              New Post
            </Text>
            <Pressable
              onPress={handleSubmit}
              disabled={createPost.isPending || !title.trim() || !content.trim()}
              style={[
                styles.submitBtn,
                {
                  backgroundColor:
                    !title.trim() || !content.trim()
                      ? themeColors.bgTertiary
                      : themeColors.accentPrimary,
                },
              ]}
            >
              {createPost.isPending ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.submitBtnText}>Post</Text>
              )}
            </Pressable>
          </View>

          <ScrollView style={styles.modalBody} keyboardShouldPersistTaps="handled">
            {/* Title */}
            <TextInput
              style={[
                styles.titleInput,
                {
                  color: themeColors.textPrimary,
                  backgroundColor: themeColors.inputBg,
                  borderColor: themeColors.border,
                },
              ]}
              placeholder="Post title"
              placeholderTextColor={themeColors.textMuted}
              value={title}
              onChangeText={setTitle}
              maxLength={100}
              autoFocus
            />

            {/* Content */}
            <TextInput
              style={[
                styles.contentInput,
                {
                  color: themeColors.textPrimary,
                  backgroundColor: themeColors.inputBg,
                  borderColor: themeColors.border,
                },
              ]}
              placeholder="Write your post content..."
              placeholderTextColor={themeColors.textMuted}
              value={content}
              onChangeText={setContent}
              multiline
              textAlignVertical="top"
            />

            {/* Tags */}
            {tags.length > 0 && (
              <>
                <Text style={[styles.tagLabel, { color: themeColors.textSecondary }]}>
                  Tags
                </Text>
                <View style={styles.tagSelector}>
                  {tags.map((tag: ForumTag) => {
                    const selected = selectedTags.includes(tag.id);
                    return (
                      <Pressable
                        key={tag.id}
                        style={[
                          styles.tagChip,
                          {
                            backgroundColor: selected
                              ? themeColors.accentPrimary
                              : themeColors.bgTertiary,
                          },
                        ]}
                        onPress={() => toggleTag(tag.id)}
                      >
                        <Text
                          style={[
                            styles.tagChipText,
                            { color: selected ? '#fff' : themeColors.textSecondary },
                          ]}
                        >
                          {tag.emoji ? `${tag.emoji} ` : ''}
                          {tag.name}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

// ─── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  backButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerInfo: { flex: 1, marginLeft: spacing.sm },
  channelNameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  channelName: { ...typography.headingS },
  headerAction: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  topicText: { ...typography.bodySmall, paddingHorizontal: spacing.md, paddingTop: spacing.md },
  tagRow: { marginTop: spacing.md },
  tagRowContent: { paddingHorizontal: spacing.md, gap: spacing.sm },
  tagChip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs + 2,
    borderRadius: borderRadius.full,
  },
  tagChipText: { ...typography.caption },
  sortBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    marginTop: spacing.md,
    paddingHorizontal: spacing.md,
  },
  sortButton: {
    paddingVertical: spacing.sm,
    marginRight: spacing.lg,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  sortButtonText: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  listContent: { paddingBottom: spacing.xxxl },
  loader: { marginTop: spacing.xxxxl },
  footerLoader: { paddingVertical: spacing.lg },
  emptyContainer: { alignItems: 'center', paddingTop: spacing.xxxxl * 2, gap: spacing.md },
  emptyText: { ...typography.body },

  // Post card
  postCard: {
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    padding: spacing.lg,
    borderRadius: borderRadius.md,
  },
  postTitle: { ...typography.headingS, marginBottom: spacing.xs },
  postPreview: { ...typography.bodySmall, marginBottom: spacing.sm },
  postTagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs, marginBottom: spacing.sm },
  postTag: { paddingHorizontal: spacing.sm, paddingVertical: 2, borderRadius: borderRadius.sm },
  postTagText: { ...typography.micro },
  postMeta: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  postMetaRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  postMetaText: { ...typography.caption },

  // Modal
  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl, maxHeight: '90%' },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: spacing.lg,
    borderBottomWidth: 1,
  },
  modalTitle: { ...typography.headingM },
  modalBody: { padding: spacing.lg },
  submitBtn: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: borderRadius.sm },
  submitBtnText: { color: '#fff', ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  titleInput: {
    ...typography.headingS,
    padding: spacing.md,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    marginBottom: spacing.md,
  },
  contentInput: {
    ...typography.body,
    padding: spacing.md,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    minHeight: 120,
    marginBottom: spacing.md,
  },
  tagLabel: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold', marginBottom: spacing.sm },
  tagSelector: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
});
