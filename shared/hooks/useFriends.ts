import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fetchFriends, acceptFriendRequest, rejectFriendRequest } from '@shared/services/friendsService';
import { useAuthStore } from '@/stores/authStore';
import { useToast } from '@/components/atoms/Toast';

/**
 * React Query hook for fetching friends list
 * 
 * Fetches all accepted friends for the authenticated user with status-based sorting.
 * Implements caching strategy with 5 minute stale time.
 * 
 * Requirements: 4.1, 6.1, 9.1, 9.3
 * 
 * Preconditions:
 * - User is authenticated
 * - User object contains valid id
 * 
 * Postconditions:
 * - Returns React Query result with friends data
 * - Data is cached for 5 minutes
 * - Query is disabled if user is not authenticated
 * - Friends are sorted by online status (online, idle, dnd, offline)
 * 
 * @returns React Query result containing friends data, loading state, and error state
 */
export function useFriends() {
  const user = useAuthStore((s) => s.user);
  
  return useQuery({
    queryKey: ['friends', user?.id],
    queryFn: () => fetchFriends(user!.id),
    enabled: !!user,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

/**
 * React Query mutation hook for accepting friend requests
 * 
 * Accepts a friend request and updates the friends list with optimistic updates.
 * Implements cache invalidation for both friends and friend requests queries.
 * Shows success/error toast notifications.
 * 
 * Requirements: 6.3, 6.4, 6.6, 12.3, 15.3
 * 
 * Preconditions:
 * - User is authenticated
 * - requestId is valid and exists
 * - User is the recipient of the request
 * 
 * Postconditions:
 * - Friend request is accepted
 * - Friends list is updated with optimistic update
 * - Friend requests list is updated
 * - Cache is invalidated for both queries
 * - Success toast notification is shown
 * - Error toast notification is shown on failure
 * 
 * @returns React Query mutation result with mutate function and loading state
 */
export function useAcceptFriendRequest() {
  const queryClient = useQueryClient();
  const user = useAuthStore((s) => s.user);
  const { showToast } = useToast();
  
  return useMutation({
    mutationFn: (requestId: string) => acceptFriendRequest(requestId, user!.id),
    onMutate: async (requestId) => {
      // Cancel any outgoing refetches to avoid overwriting optimistic update
      await queryClient.cancelQueries({ queryKey: ['friends', user?.id] });
      await queryClient.cancelQueries({ queryKey: ['friend-requests', user?.id] });
      
      // Snapshot the previous values
      const previousFriends = queryClient.getQueryData(['friends', user?.id]);
      const previousRequests = queryClient.getQueryData(['friend-requests', user?.id]);
      
      // Optimistically remove the request from the friend requests list
      queryClient.setQueryData(['friend-requests', user?.id], (old: any) => {
        if (!old) return old;
        return old.filter((request: any) => request.id !== requestId);
      });
      
      // Return context with previous values for rollback
      return { previousFriends, previousRequests };
    },
    onSuccess: () => {
      // Invalidate queries to refetch fresh data
      queryClient.invalidateQueries({ queryKey: ['friends', user?.id] });
      queryClient.invalidateQueries({ queryKey: ['friend-requests', user?.id] });
      
      // Show success toast
      showToast('success', 'Friend Request Accepted', 'You are now friends!');
    },
    onError: (error, _requestId, context) => {
      // Rollback optimistic updates on error
      if (context?.previousFriends) {
        queryClient.setQueryData(['friends', user?.id], context.previousFriends);
      }
      if (context?.previousRequests) {
        queryClient.setQueryData(['friend-requests', user?.id], context.previousRequests);
      }
      
      // Show error toast
      showToast('error', 'Failed to Accept Request', error instanceof Error ? error.message : 'Please try again.');
    },
  });
}

/**
 * React Query mutation hook for rejecting friend requests
 * 
 * Rejects a friend request and updates the friend requests list with cache invalidation.
 * Shows success/error toast notifications.
 * 
 * Requirements: 6.3, 6.4, 6.6, 12.3, 15.3
 * 
 * Preconditions:
 * - User is authenticated
 * - requestId is valid and exists
 * - User is the recipient of the request
 * 
 * Postconditions:
 * - Friend request is rejected
 * - Friend requests list is updated
 * - Cache is invalidated for friend requests query
 * - Success toast notification is shown
 * - Error toast notification is shown on failure
 * 
 * @returns React Query mutation result with mutate function and loading state
 */
export function useRejectFriendRequest() {
  const queryClient = useQueryClient();
  const user = useAuthStore((s) => s.user);
  const { showToast } = useToast();
  
  return useMutation({
    mutationFn: (requestId: string) => rejectFriendRequest(requestId, user!.id),
    onMutate: async (requestId) => {
      await queryClient.cancelQueries({ queryKey: ['friend-requests', user?.id] });
      const previousRequests = queryClient.getQueryData(['friend-requests', user?.id]);
      queryClient.setQueryData(['friend-requests', user?.id], (old: unknown[] | undefined) => {
        if (!old) return old;
        return old.filter((request: Record<string, unknown>) => request.id !== requestId);
      });
      return { previousRequests };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['friend-requests', user?.id] });
      showToast('success', 'Friend Request Rejected', 'The friend request has been declined.');
    },
    onError: (error, _requestId, context) => {
      if (context?.previousRequests) {
        queryClient.setQueryData(['friend-requests', user?.id], context.previousRequests);
      }
      showToast('error', 'Failed to Reject Request', error instanceof Error ? error.message : 'Please try again.');
    },
  });
}
