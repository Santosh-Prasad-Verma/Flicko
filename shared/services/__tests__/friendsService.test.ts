import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  fetchFriends,
  fetchFriendRequests,
  acceptFriendRequest,
  rejectFriendRequest,
} from '../../../shared/services/friendsService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(),
  },
}));

describe('friendsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('fetchFriends', () => {
    const mockFriendsData = [
      {
        id: 'friendship-1',
        user_id: 'user-123',
        friend_id: 'friend-1',
        status: 'accepted',
        created_at: '2024-01-01T00:00:00Z',
        friend: {
          id: 'friend-1',
          username: 'friend1',
          avatar: 'https://example.com/avatar1.png',
          status: 'online',
          custom_status: 'Playing games',
          last_seen: '2024-01-15T10:00:00Z',
        },
      },
      {
        id: 'friendship-2',
        user_id: 'user-123',
        friend_id: 'friend-2',
        status: 'accepted',
        created_at: '2024-01-02T00:00:00Z',
        friend: {
          id: 'friend-2',
          username: 'friend2',
          avatar: null,
          status: 'offline',
          custom_status: null,
          last_seen: '2024-01-14T10:00:00Z',
        },
      },
      {
        id: 'friendship-3',
        user_id: 'user-123',
        friend_id: 'friend-3',
        status: 'accepted',
        created_at: '2024-01-03T00:00:00Z',
        friend: {
          id: 'friend-3',
          username: 'friend3',
          avatar: 'https://example.com/avatar3.png',
          status: 'idle',
          custom_status: 'Away',
          last_seen: '2024-01-15T09:00:00Z',
        },
      },
    ];

    it('should fetch accepted friends for a user', async () => {
      const friendsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      // Chain the eq calls
      friendsQuery.eq
        .mockReturnValueOnce(friendsQuery) // First eq for user_id
        .mockResolvedValueOnce({ // Second eq for status
          data: mockFriendsData,
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(friendsQuery as any);

      const result = await fetchFriends('user-123');

      expect(result).toHaveLength(3);
      expect(supabase.from).toHaveBeenCalledWith('friends');
      expect(friendsQuery.eq).toHaveBeenCalledWith('user_id', 'user-123');
      expect(friendsQuery.eq).toHaveBeenCalledWith('status', 'accepted');
    });

    it('should sort friends by online status (online, idle, dnd, offline)', async () => {
      const friendsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      friendsQuery.eq
        .mockReturnValueOnce(friendsQuery)
        .mockResolvedValueOnce({
          data: mockFriendsData,
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(friendsQuery as any);

      const result = await fetchFriends('user-123');

      // Verify sorting: online, idle, offline
      expect(result[0].user.status).toBe('online');
      expect(result[1].user.status).toBe('idle');
      expect(result[2].user.status).toBe('offline');
    });

    it('should return empty array when no friends found', async () => {
      const friendsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      friendsQuery.eq
        .mockReturnValueOnce(friendsQuery)
        .mockResolvedValueOnce({
          data: [],
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(friendsQuery as any);

      const result = await fetchFriends('user-123');

      expect(result).toEqual([]);
    });

    it('should throw error on query failure', async () => {
      const friendsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      friendsQuery.eq
        .mockReturnValueOnce(friendsQuery)
        .mockResolvedValueOnce({
          data: null,
          error: { message: 'Database error' },
        });

      vi.mocked(supabase.from).mockReturnValueOnce(friendsQuery as any);

      await expect(fetchFriends('user-123')).rejects.toThrow(
        'Failed to fetch friends: Database error'
      );
    });

    it('should transform data to match Friend interface', async () => {
      const friendsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      friendsQuery.eq
        .mockReturnValueOnce(friendsQuery)
        .mockResolvedValueOnce({
          data: [mockFriendsData[0]],
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(friendsQuery as any);

      const result = await fetchFriends('user-123');

      expect(result[0]).toMatchObject({
        id: 'friendship-1',
        user_id: 'user-123',
        friend_user_id: 'friend-1',
        status: 'accepted',
        user: {
          id: 'friend-1',
          username: 'friend1',
          avatar: 'https://example.com/avatar1.png',
          status: 'online',
          custom_status: 'Playing games',
        },
      });
      expect(result[0].created_at).toBeInstanceOf(Date);
      expect(result[0].user.last_seen).toBeInstanceOf(Date);
    });
  });

  describe('fetchFriendRequests', () => {
    const mockRequestsData = [
      {
        id: 'request-1',
        user_id: 'requester-1',
        friend_id: 'user-123',
        status: 'pending',
        created_at: '2024-01-10T00:00:00Z',
        requester: {
          id: 'requester-1',
          username: 'requester1',
          avatar: 'https://example.com/avatar.png',
          status: 'online',
          custom_status: 'Hey!',
          last_seen: '2024-01-15T10:00:00Z',
        },
      },
      {
        id: 'request-2',
        user_id: 'requester-2',
        friend_id: 'user-123',
        status: 'pending',
        created_at: '2024-01-11T00:00:00Z',
        requester: {
          id: 'requester-2',
          username: 'requester2',
          avatar: null,
          status: 'offline',
          custom_status: null,
          last_seen: '2024-01-14T10:00:00Z',
        },
      },
    ];

    it('should fetch pending friend requests for a user', async () => {
      const requestsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      requestsQuery.eq
        .mockReturnValueOnce(requestsQuery)
        .mockResolvedValueOnce({
          data: mockRequestsData,
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(requestsQuery as any);

      const result = await fetchFriendRequests('user-123');

      expect(result).toHaveLength(2);
      expect(supabase.from).toHaveBeenCalledWith('friends');
      expect(requestsQuery.eq).toHaveBeenCalledWith('friend_id', 'user-123');
      expect(requestsQuery.eq).toHaveBeenCalledWith('status', 'pending');
    });

    it('should return empty array when no requests found', async () => {
      const requestsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      requestsQuery.eq
        .mockReturnValueOnce(requestsQuery)
        .mockResolvedValueOnce({
          data: [],
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(requestsQuery as any);

      const result = await fetchFriendRequests('user-123');

      expect(result).toEqual([]);
    });

    it('should throw error on query failure', async () => {
      const requestsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      requestsQuery.eq
        .mockReturnValueOnce(requestsQuery)
        .mockResolvedValueOnce({
          data: null,
          error: { message: 'Database error' },
        });

      vi.mocked(supabase.from).mockReturnValueOnce(requestsQuery as any);

      await expect(fetchFriendRequests('user-123')).rejects.toThrow(
        'Failed to fetch friend requests: Database error'
      );
    });

    it('should transform data to match FriendRequest interface', async () => {
      const requestsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
      };

      requestsQuery.eq
        .mockReturnValueOnce(requestsQuery)
        .mockResolvedValueOnce({
          data: [mockRequestsData[0]],
          error: null,
        });

      vi.mocked(supabase.from).mockReturnValueOnce(requestsQuery as any);

      const result = await fetchFriendRequests('user-123');

      expect(result[0]).toMatchObject({
        id: 'request-1',
        from_user_id: 'requester-1',
        to_user_id: 'user-123',
        status: 'pending',
      });
      expect(result[0].created_at).toBeInstanceOf(Date);
    });
  });

  describe('acceptFriendRequest', () => {
    const mockRequest = {
      id: 'request-1',
      user_id: 'requester-1',
      friend_id: 'user-123',
      status: 'pending',
      created_at: '2024-01-10T00:00:00Z',
    };

    it('should accept a friend request successfully', async () => {
      // Mock fetch request
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockRequest,
          error: null,
        }),
      };

      // Mock update request
      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      // Mock insert reciprocal friendship
      const insertQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(updateQuery as any)
        .mockReturnValueOnce(insertQuery as any);

      await acceptFriendRequest('request-1', 'user-123');

      expect(fetchQuery.eq).toHaveBeenCalledWith('id', 'request-1');
      expect(fetchQuery.eq).toHaveBeenCalledWith('friend_id', 'user-123');
      expect(fetchQuery.eq).toHaveBeenCalledWith('status', 'pending');
      expect(updateQuery.update).toHaveBeenCalledWith({ status: 'accepted' });
      expect(insertQuery.insert).toHaveBeenCalledWith({
        user_id: 'user-123',
        friend_id: 'requester-1',
        status: 'accepted',
      });
    });

    it('should throw error if request not found', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Not found' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(acceptFriendRequest('request-1', 'user-123')).rejects.toThrow(
        'Friend request not found or already processed'
      );
    });

    it('should throw error if user is not the recipient', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(acceptFriendRequest('request-1', 'wrong-user')).rejects.toThrow(
        'Friend request not found or already processed'
      );
    });

    it('should throw error if update fails', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockRequest,
          error: null,
        }),
      };

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Update failed' },
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      await expect(acceptFriendRequest('request-1', 'user-123')).rejects.toThrow(
        'Failed to accept friend request: Update failed'
      );
    });

    it('should throw error if reciprocal friendship creation fails', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockRequest,
          error: null,
        }),
      };

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      const insertQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Insert failed' },
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(updateQuery as any)
        .mockReturnValueOnce(insertQuery as any);

      await expect(acceptFriendRequest('request-1', 'user-123')).rejects.toThrow(
        'Failed to create reciprocal friendship: Insert failed'
      );
    });
  });

  describe('rejectFriendRequest', () => {
    const mockRequest = {
      id: 'request-1',
      user_id: 'requester-1',
      friend_id: 'user-123',
      status: 'pending',
      created_at: '2024-01-10T00:00:00Z',
    };

    it('should reject a friend request successfully', async () => {
      // Mock fetch request
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockRequest,
          error: null,
        }),
      };

      // Mock delete request
      const deleteQuery = {
        delete: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(deleteQuery as any);

      await rejectFriendRequest('request-1', 'user-123');

      expect(fetchQuery.eq).toHaveBeenCalledWith('id', 'request-1');
      expect(fetchQuery.eq).toHaveBeenCalledWith('friend_id', 'user-123');
      expect(fetchQuery.eq).toHaveBeenCalledWith('status', 'pending');
      expect(deleteQuery.eq).toHaveBeenCalledWith('id', 'request-1');
    });

    it('should throw error if request not found', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Not found' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(rejectFriendRequest('request-1', 'user-123')).rejects.toThrow(
        'Friend request not found or already processed'
      );
    });

    it('should throw error if user is not the recipient', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(rejectFriendRequest('request-1', 'wrong-user')).rejects.toThrow(
        'Friend request not found or already processed'
      );
    });

    it('should throw error if delete fails', async () => {
      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockRequest,
          error: null,
        }),
      };

      const deleteQuery = {
        delete: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Delete failed' },
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(deleteQuery as any);

      await expect(rejectFriendRequest('request-1', 'user-123')).rejects.toThrow(
        'Failed to reject friend request: Delete failed'
      );
    });
  });
});
