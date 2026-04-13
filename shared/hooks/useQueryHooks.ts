/**
 * Query Hooks
 *
 * TanStack Query hooks for new features:
 * - Polls
 * - Message Search
 * - Voice Participants
 * - User Profiles
 *
 * Cache strategy:
 * - Messages: 60s staleTime (default)
 * - User profiles: 5min staleTime (change infrequently)
 * - Polls: 30s staleTime (votes change frequently)
 * - Search: no caching (always fresh)
 */
import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';

// ── Query Keys ──────────────────────────────────────────────────────

export const queryKeys = {
  messages: (channelId: string) => ['messages', channelId] as const,
  messageSearch: (channelId: string, query: string) => ['message-search', channelId, query] as const,
  poll: (pollId: string) => ['poll', pollId] as const,
  pollVotes: (pollId: string) => ['poll-votes', pollId] as const,
  voiceParticipants: (channelId: string) => ['voice-participants', channelId] as const,
  userProfile: (userId: string) => ['user-profile', userId] as const,
  mutualServers: (userId: string) => ['mutual-servers', userId] as const,
  readStates: (userId: string) => ['read-states', userId] as const,
};

// ── Poll Hooks ──────────────────────────────────────────────────────

export function usePoll(pollId: string) {
  return useQuery({
    queryKey: queryKeys.poll(pollId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('polls')
        .select(`
          *,
          poll_options (
            id, text, emoji, position,
            poll_votes ( count )
          )
        `)
        .eq('id', pollId)
        .single();

      if (error) throw error;
      return data;
    },
    staleTime: 30_000, // 30s - polls change with votes
    enabled: !!pollId,
  });
}

export function useVotePoll() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ pollId, optionId, userId }: { pollId: string; optionId: string; userId: string }) => {
      const { error } = await supabase
        .from('poll_votes')
        .insert({ poll_id: pollId, option_id: optionId, user_id: userId });
      if (error) throw error;
    },
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.poll(variables.pollId) });
    },
  });
}

export function useUnvotePoll() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ pollId, userId }: { pollId: string; userId: string }) => {
      const { error } = await supabase
        .from('poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('user_id', userId);
      if (error) throw error;
    },
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.poll(variables.pollId) });
    },
  });
}

// ── User Profile Hooks ───────────────────────────────────────────────

export function useUserProfile(userId: string) {
  return useQuery({
    queryKey: queryKeys.userProfile(userId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) throw error;
      return data;
    },
    staleTime: 5 * 60_000, // 5min - profiles change infrequently
    enabled: !!userId,
  });
}

export function useMutualServers(userId: string) {
  return useQuery({
    queryKey: queryKeys.mutualServers(userId),
    queryFn: async () => {
      // Fetch servers that both the current user and target user are members of
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data, error } = await supabase
        .rpc('get_mutual_servers', { user_a: user.id, user_b: userId });

      if (error) throw error;
      return data ?? [];
    },
    staleTime: 5 * 60_000,
    enabled: !!userId,
  });
}

// ── Message Search Hook ──────────────────────────────────────────────

export function useMessageSearch(channelId: string, query: string) {
  return useInfiniteQuery({
    queryKey: queryKeys.messageSearch(channelId, query),
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('messages')
        .select('*, author:profiles!author_id(id, username, display_name, avatar_url)')
        .eq('channel_id', channelId)
        .ilike('content', `%${query}%`)
        .order('created_at', { ascending: false })
        .limit(25);

      if (pageParam) {
        q = q.lt('created_at', pageParam);
      }

      const { data, error } = await q;
      if (error) throw error;
      return data ?? [];
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => {
      if (lastPage.length < 25) return undefined;
      return lastPage[lastPage.length - 1]?.created_at ?? undefined;
    },
    staleTime: 0, // Always fresh search results
    enabled: !!channelId && query.length >= 3,
  });
}

// ── Read State Hooks ─────────────────────────────────────────────────

export function useReadStates(userId: string) {
  return useQuery({
    queryKey: queryKeys.readStates(userId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channel_read_states')
        .select('*')
        .eq('user_id', userId);

      if (error) throw error;
      return data ?? [];
    },
    staleTime: 30_000,
    enabled: !!userId,
  });
}
