import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  createThread,
  getChannelThreads,
  getThread,
  getThreadMessages,
  getThreadMembers,
  sendThreadMessage,
  joinThread,
  leaveThread,
  toggleThreadArchive,
  type CreateThreadInput,
  type Thread,
} from '../services/threadService';

/**
 * Hook for listing threads in a channel
 */
export function useChannelThreads(channelId: string | null, includeArchived = false) {
  return useQuery({
    queryKey: ['threads', channelId, includeArchived],
    queryFn: () => getChannelThreads(channelId!, includeArchived),
    enabled: !!channelId,
    staleTime: 30_000,
  });
}

/**
 * Hook for fetching a single thread
 */
export function useThread(threadId: string | null) {
  return useQuery({
    queryKey: ['thread', threadId],
    queryFn: () => getThread(threadId!),
    enabled: !!threadId,
    staleTime: 30_000,
  });
}

/**
 * Hook for fetching thread messages with infinite scroll
 */
export function useThreadMessages(threadId: string | null) {
  return useInfiniteQuery({
    queryKey: ['thread-messages', threadId],
    queryFn: ({ pageParam }) =>
      getThreadMessages(threadId!, 50, pageParam as string | undefined),
    enabled: !!threadId,
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => {
      if (lastPage.length < 50) return undefined;
      return lastPage[0]?.id;
    },
    staleTime: 15_000,
  });
}

/**
 * Hook for thread members
 */
export function useThreadMembers(threadId: string | null) {
  return useQuery({
    queryKey: ['thread-members', threadId],
    queryFn: () => getThreadMembers(threadId!),
    enabled: !!threadId,
  });
}

/**
 * Hook for creating a thread
 */
export function useCreateThread() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateThreadInput) => createThread(input),
    onSuccess: (thread: Thread) => {
      queryClient.invalidateQueries({ queryKey: ['threads', thread.parent_channel_id] });
    },
  });
}

/**
 * Hook for sending a thread message
 */
export function useSendThreadMessage() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ threadId, channelId, content, options }: { threadId: string; channelId: string; content: string; options?: { isSilent?: boolean } }) =>
      sendThreadMessage(threadId, channelId, content, options),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['thread-messages', variables.threadId] });
      queryClient.invalidateQueries({ queryKey: ['thread', variables.threadId] });
    },
  });
}

/**
 * Hook for joining a thread
 */
export function useJoinThread() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (threadId: string) => joinThread(threadId),
    onSuccess: (_data, threadId) => {
      queryClient.invalidateQueries({ queryKey: ['thread-members', threadId] });
    },
  });
}

/**
 * Hook for leaving a thread
 */
export function useLeaveThread() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (threadId: string) => leaveThread(threadId),
    onSuccess: (_data, threadId) => {
      queryClient.invalidateQueries({ queryKey: ['thread-members', threadId] });
    },
  });
}

/**
 * Hook for archiving/unarchiving a thread
 */
export function useToggleThreadArchive() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ threadId, archived }: { threadId: string; archived: boolean }) =>
      toggleThreadArchive(threadId, archived),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['threads'] });
    },
  });
}
