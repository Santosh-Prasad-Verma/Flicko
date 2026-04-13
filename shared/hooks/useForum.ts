/**
 * Forum + Announcement + Slowmode Hooks
 */
import { useQuery, useMutation, useInfiniteQuery, useQueryClient } from '@tanstack/react-query';
import * as forumService from '../services/forumService';

// ─── Forum Tags ────────────────────────────────────────────────────────────────

export function useForumTags(channelId: string) {
  return useQuery({
    queryKey: ['forum-tags', channelId],
    queryFn: () => forumService.getForumTags(channelId),
    enabled: !!channelId,
  });
}

export function useCreateForumTag() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ channelId, name, emoji, moderated }: {
      channelId: string; name: string; emoji?: string; moderated?: boolean;
    }) => forumService.createForumTag(channelId, name, emoji, moderated),
    onSuccess: (_, { channelId }) => qc.invalidateQueries({ queryKey: ['forum-tags', channelId] }),
  });
}

export function useDeleteForumTag() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: forumService.deleteForumTag,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['forum-tags'] }),
  });
}

// ─── Forum Posts ───────────────────────────────────────────────────────────────

export function useForumPosts(channelId: string, options?: {
  sort?: 'latest_activity' | 'creation_date';
  tagId?: string;
}) {
  return useInfiniteQuery({
    queryKey: ['forum-posts', channelId, options?.sort, options?.tagId],
    queryFn: ({ pageParam }) =>
      forumService.getForumPosts(channelId, {
        sort: options?.sort,
        tagId: options?.tagId,
        before: pageParam,
      }),
    enabled: !!channelId,
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) =>
      lastPage.length >= 25 ? lastPage[lastPage.length - 1]?.created_at : undefined,
  });
}

export function useCreateForumPost() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: forumService.createForumPost,
    onSuccess: (_, vars) => qc.invalidateQueries({ queryKey: ['forum-posts', vars.channelId] }),
  });
}

// ─── Announcements ─────────────────────────────────────────────────────────────

export function usePublishMessage() {
  return useMutation({ mutationFn: forumService.publishMessage });
}

export function useFollowChannel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ sourceChannelId, targetChannelId }: { sourceChannelId: string; targetChannelId: string }) =>
      forumService.followChannel(sourceChannelId, targetChannelId),
    onSuccess: (_, { sourceChannelId }) =>
      qc.invalidateQueries({ queryKey: ['channel-followers', sourceChannelId] }),
  });
}

export function useChannelFollowers(channelId: string) {
  return useQuery({
    queryKey: ['channel-followers', channelId],
    queryFn: () => forumService.getChannelFollowers(channelId),
    enabled: !!channelId,
  });
}

// ─── Slowmode ──────────────────────────────────────────────────────────────────

export function useSlowmodeCooldown(channelId: string, userId: string, slowmodeSeconds: number) {
  return useQuery({
    queryKey: ['slowmode', channelId, userId],
    queryFn: () => forumService.getSlowmodeCooldown(channelId, userId, slowmodeSeconds),
    enabled: !!channelId && !!userId && slowmodeSeconds > 0,
    refetchInterval: 1000, // refresh every second for countdown
  });
}
