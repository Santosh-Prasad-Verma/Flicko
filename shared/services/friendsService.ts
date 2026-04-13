import { supabase } from '../lib/supabase';
import type { Friend, FriendRequest, UserProfile, FriendshipStatus } from '@shared/types/models';

/**
 * Friends Service
 * 
 * Handles all friend-related API operations including fetching friends,
 * managing friend requests, and friendship operations.
 * 
 * Requirements: 4.1, 4.2, 4.3, 6.1, 6.2, 6.3, 6.4, 6.5, 16.2
 */

/**
 * Fetch all accepted friends for a user with status-based sorting
 * 
 * Queries the friends table for accepted friendships and joins with profiles
 * to get friend details. Results are sorted by online status (online, idle, dnd, offline).
 * 
 * @param userId - The ID of the user whose friends to fetch
 * @returns Array of Friend objects sorted by online status
 * @throws Error if query fails
 * 
 * Requirements: 4.1, 4.2, 4.3
 */
export async function fetchFriends(userId: string): Promise<Friend[]> {
  const { data, error } = await supabase
    .from('friends')
    .select(`
      id,
      user_id,
      friend_id,
      status,
      created_at,
      friend:profiles!friends_friend_id_fkey (
        id,
        username,
        avatar,
        status,
        custom_status,
        last_seen
      )
    `)
    .eq('user_id', userId)
    .eq('status', 'accepted');

  if (error) {
    throw new Error(`Failed to fetch friends: ${error.message}`);
  }

  if (!data) {
    return [];
  }

  // Transform the data to match the Friend interface
  const friends: Friend[] = data.map((friendship: any) => ({
    id: friendship.id,
    user_id: friendship.user_id,
    friend_user_id: friendship.friend_id,
    status: friendship.status as FriendshipStatus,
    created_at: new Date(friendship.created_at),
    user: {
      id: friendship.friend.id,
      username: friendship.friend.username,
      avatar: friendship.friend.avatar,
      status: friendship.friend.status,
      custom_status: friendship.friend.custom_status,
      last_seen: new Date(friendship.friend.last_seen),
    } as UserProfile,
  }));

  // Sort by online status: online, idle, dnd, offline
  const statusOrder: Record<string, number> = {
    online: 0,
    idle: 1,
    dnd: 2,
    offline: 3,
  };

  friends.sort((a, b) => {
    const statusA = statusOrder[a.user.status] ?? 4;
    const statusB = statusOrder[b.user.status] ?? 4;
    return statusA - statusB;
  });

  return friends;
}

/**
 * Fetch pending friend requests for a user
 * 
 * Queries the friends table for pending requests where the user is the recipient.
 * Joins with profiles to get requester details.
 * 
 * @param userId - The ID of the user whose friend requests to fetch
 * @returns Array of FriendRequest objects
 * @throws Error if query fails
 * 
 * Requirements: 6.1, 6.2
 */
export async function fetchFriendRequests(userId: string): Promise<FriendRequest[]> {
  const { data, error } = await supabase
    .from('friends')
    .select(`
      id,
      user_id,
      friend_id,
      status,
      created_at,
      requester:profiles!friends_user_id_fkey (
        id,
        username,
        avatar,
        status,
        custom_status,
        last_seen
      )
    `)
    .eq('friend_id', userId)
    .eq('status', 'pending');

  if (error) {
    throw new Error(`Failed to fetch friend requests: ${error.message}`);
  }

  if (!data) {
    return [];
  }

  // Transform the data to match the FriendRequest interface
  const requests: FriendRequest[] = data.map((request: any) => ({
    id: request.id,
    from_user_id: request.user_id,
    to_user_id: request.friend_id,
    status: request.status as FriendshipStatus,
    created_at: new Date(request.created_at),
    user: {
      id: request.id,
      user_id: request.user_id,
      friend_user_id: request.friend_id,
      status: request.status as FriendshipStatus,
      created_at: new Date(request.created_at),
      user: {
        id: request.requester.id,
        username: request.requester.username,
        avatar: request.requester.avatar,
        status: request.requester.status,
        custom_status: request.requester.custom_status,
        last_seen: new Date(request.requester.last_seen),
      } as UserProfile,
    } as Friend,
  }));

  return requests;
}

/**
 * Accept a friend request
 * 
 * Verifies the request exists and the user is the recipient, updates the friendship
 * status to 'accepted', and creates a reciprocal friendship from recipient to requester.
 * 
 * @param requestId - The ID of the friend request to accept
 * @param userId - The ID of the user accepting the request (must be recipient)
 * @returns void
 * @throws Error if request not found, user is not recipient, or operation fails
 * 
 * Requirements: 6.3, 6.5
 */
export async function acceptFriendRequest(requestId: string, userId: string): Promise<void> {
  // Verify request exists and user is recipient
  const { data: request, error: fetchError } = await supabase
    .from('friends')
    .select('*')
    .eq('id', requestId)
    .eq('friend_id', userId)
    .eq('status', 'pending')
    .single();

  if (fetchError || !request) {
    throw new Error('Friend request not found or already processed');
  }

  // Update request status to accepted
  const { error: updateError } = await supabase
    .from('friends')
    .update({ status: 'accepted' })
    .eq('id', requestId);

  if (updateError) {
    throw new Error(`Failed to accept friend request: ${updateError.message}`);
  }

  // Create reciprocal friendship (from recipient to requester)
  const { error: insertError } = await supabase
    .from('friends')
    .insert({
      user_id: request.friend_id,
      friend_id: request.user_id,
      status: 'accepted',
    });

  if (insertError) {
    // If reciprocal friendship creation fails, we should ideally rollback
    // but for now we'll just throw an error
    throw new Error(`Failed to create reciprocal friendship: ${insertError.message}`);
  }
}

/**
 * Reject a friend request
 * 
 * Verifies the request exists and the user is the recipient, then deletes the friend request.
 * 
 * @param requestId - The ID of the friend request to reject
 * @param userId - The ID of the user rejecting the request (must be recipient)
 * @returns void
 * @throws Error if request not found, user is not recipient, or operation fails
 * 
 * Requirements: 6.4
 */
export async function rejectFriendRequest(requestId: string, userId: string): Promise<void> {
  // Verify request exists and user is recipient
  const { data: request, error: fetchError } = await supabase
    .from('friends')
    .select('*')
    .eq('id', requestId)
    .eq('friend_id', userId)
    .eq('status', 'pending')
    .single();

  if (fetchError || !request) {
    throw new Error('Friend request not found or already processed');
  }

  // Delete the friend request
  const { error: deleteError } = await supabase
    .from('friends')
    .delete()
    .eq('id', requestId);

  if (deleteError) {
    throw new Error(`Failed to reject friend request: ${deleteError.message}`);
  }
}
