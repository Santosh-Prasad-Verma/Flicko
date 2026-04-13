import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { searchMessages, createDebouncedSearch } from '../../../shared/services/searchService';
import { supabase } from '@/lib/supabase';

// Mock the supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

describe('searchService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockMemberships = [
    { server_id: 'server-1' },
    { server_id: 'server-2' },
  ];

  const mockChannels = [
    { id: 'channel-1' },
    { id: 'channel-2' },
    { id: 'channel-3' },
  ];

  const mockMessages = [
    {
      id: 'msg-1',
      channel_id: 'channel-1',
      author_id: 'user-123',
      content: 'Hello world',
      created_at: '2024-01-01T10:00:00Z',
      author: { id: 'user-123', username: 'testuser' },
    },
    {
      id: 'msg-2',
      channel_id: 'channel-2',
      author_id: 'user-456',
      content: 'world peace',
      created_at: '2024-01-01T11:00:00Z',
      author: { id: 'user-456', username: 'otheruser' },
    },
    {
      id: 'msg-3',
      channel_id: 'channel-1',
      author_id: 'user-123',
      content: 'The world is beautiful',
      created_at: '2024-01-01T12:00:00Z',
      author: { id: 'user-123', username: 'testuser' },
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('searchMessages', () => {
    it('should return empty results for empty query', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const result = await searchMessages({ query: '' });

      expect(result.messages).toEqual([]);
      expect(result.hasMore).toBe(false);
    });

    it('should return empty results for whitespace-only query', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const result = await searchMessages({ query: '   ' });

      expect(result.messages).toEqual([]);
      expect(result.hasMore).toBe(false);
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(searchMessages({ query: 'test' })).rejects.toThrow(
        'User not authenticated'
      );
    });

    it('should search messages in accessible channels only', async () => {
      const mockSelect = vi.fn().mockReturnThis();

      const mockIn = vi.fn().mockReturnThis();
      const mockIlike = vi.fn().mockReturnThis();
      const mockOrder = vi.fn().mockReturnThis();
      const mockLimit = vi.fn().mockResolvedValue({ data: mockMessages, error: null });

      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: mockMemberships,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'channels') {
          return {
            select: vi.fn().mockReturnValue({
              in: vi.fn().mockResolvedValue({
                data: mockChannels,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'messages') {
          return {
            select: mockSelect,
          } as any;
        }
        return {} as any;
      });

      mockSelect.mockReturnValue({
        in: mockIn,
      });
      mockIn.mockReturnValue({
        ilike: mockIlike,
      });
      mockIlike.mockReturnValue({
        order: mockOrder,
      });
      mockOrder.mockReturnValue({
        limit: mockLimit,
      });

      const result = await searchMessages({ query: 'world' });

      expect(result.messages).toHaveLength(3);
      expect(mockIn).toHaveBeenCalledWith('channel_id', ['channel-1', 'channel-2', 'channel-3']);
      expect(mockIlike).toHaveBeenCalledWith('content', '%world%');
    });

    it('should return empty results if user has no accessible channels', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: [],
                error: null,
              }),
            }),
          } as any;
        }
        return {} as any;
      });

      const result = await searchMessages({ query: 'test' });

      expect(result.messages).toEqual([]);
      expect(result.hasMore).toBe(false);
    });

    it('should sort results by relevance (exact match first)', async () => {
      const messagesWithExact = [
        {
          id: 'msg-1',
          content: 'hello world test',
          created_at: '2024-01-01T10:00:00Z',
        },
        {
          id: 'msg-2',
          content: 'test',
          created_at: '2024-01-01T09:00:00Z',
        },
        {
          id: 'msg-3',
          content: 'test something',
          created_at: '2024-01-01T11:00:00Z',
        },
      ];

      const mockSelect = vi.fn().mockReturnThis();
      const mockIn = vi.fn().mockReturnThis();
      const mockIlike = vi.fn().mockReturnThis();
      const mockOrder = vi.fn().mockReturnThis();
      const mockLimit = vi.fn().mockResolvedValue({ data: messagesWithExact, error: null });

      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: mockMemberships,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'channels') {
          return {
            select: vi.fn().mockReturnValue({
              in: vi.fn().mockResolvedValue({
                data: mockChannels,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'messages') {
          return {
            select: mockSelect,
          } as any;
        }
        return {} as any;
      });

      mockSelect.mockReturnValue({ in: mockIn });
      mockIn.mockReturnValue({ ilike: mockIlike });
      mockIlike.mockReturnValue({ order: mockOrder });
      mockOrder.mockReturnValue({ limit: mockLimit });

      const result = await searchMessages({ query: 'test' });

      // Exact match should be first
      expect(result.messages[0].id).toBe('msg-2');
      // Starts with should be second
      expect(result.messages[1].id).toBe('msg-3');
      // Contains should be last
      expect(result.messages[2].id).toBe('msg-1');
    });

    it('should detect hasMore when results exceed limit', async () => {
      const manyMessages = Array.from({ length: 51 }, (_, i) => ({
        id: `msg-${i}`,
        content: `test message ${i}`,
        created_at: `2024-01-01T${String(i).padStart(2, '0')}:00:00Z`,
      }));

      const mockSelect = vi.fn().mockReturnThis();
      const mockIn = vi.fn().mockReturnThis();
      const mockIlike = vi.fn().mockReturnThis();
      const mockOrder = vi.fn().mockReturnThis();
      const mockLimit = vi.fn().mockResolvedValue({ data: manyMessages, error: null });

      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: mockMemberships,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'channels') {
          return {
            select: vi.fn().mockReturnValue({
              in: vi.fn().mockResolvedValue({
                data: mockChannels,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'messages') {
          return {
            select: mockSelect,
          } as any;
        }
        return {} as any;
      });

      mockSelect.mockReturnValue({ in: mockIn });
      mockIn.mockReturnValue({ ilike: mockIlike });
      mockIlike.mockReturnValue({ order: mockOrder });
      mockOrder.mockReturnValue({ limit: mockLimit });

      const result = await searchMessages({ query: 'test', limit: 50 });

      expect(result.messages).toHaveLength(50);
      expect(result.hasMore).toBe(true);
    });

    it('should handle search errors gracefully', async () => {
      const mockSelect = vi.fn().mockReturnThis();
      const mockIn = vi.fn().mockReturnThis();
      const mockIlike = vi.fn().mockReturnThis();
      const mockOrder = vi.fn().mockReturnThis();
      const mockLimit = vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'Database error' },
      });

      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: mockMemberships,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'channels') {
          return {
            select: vi.fn().mockReturnValue({
              in: vi.fn().mockResolvedValue({
                data: mockChannels,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'messages') {
          return {
            select: mockSelect,
          } as any;
        }
        return {} as any;
      });

      mockSelect.mockReturnValue({ in: mockIn });
      mockIn.mockReturnValue({ ilike: mockIlike });
      mockIlike.mockReturnValue({ order: mockOrder });
      mockOrder.mockReturnValue({ limit: mockLimit });

      await expect(searchMessages({ query: 'test' })).rejects.toThrow(
        'Failed to search messages: Database error'
      );
    });
  });

  describe('createDebouncedSearch', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('should debounce search calls', async () => {
      const callback = vi.fn();
      const debouncedSearch = createDebouncedSearch(callback);

      // Call multiple times rapidly
      debouncedSearch('test1');
      debouncedSearch('test2');
      debouncedSearch('test3');

      // Should not have called yet
      expect(callback).not.toHaveBeenCalled();

      // Fast-forward time by 300ms
      vi.advanceTimersByTime(300);

      // Wait for async operations
      await vi.runAllTimersAsync();

      // Should have called only once with the last query
      expect(callback).toHaveBeenCalledTimes(1);
    });

    it('should call callback with search results', async () => {


      const mockSelect = vi.fn().mockReturnThis();
      const mockIn = vi.fn().mockReturnThis();
      const mockIlike = vi.fn().mockReturnThis();
      const mockOrder = vi.fn().mockReturnThis();
      const mockLimit = vi.fn().mockResolvedValue({ data: mockMessages, error: null });

      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: vi.fn().mockReturnValue({
              eq: vi.fn().mockResolvedValue({
                data: mockMemberships,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'channels') {
          return {
            select: vi.fn().mockReturnValue({
              in: vi.fn().mockResolvedValue({
                data: mockChannels,
                error: null,
              }),
            }),
          } as any;
        }
        if (table === 'messages') {
          return {
            select: mockSelect,
          } as any;
        }
        return {} as any;
      });

      mockSelect.mockReturnValue({ in: mockIn });
      mockIn.mockReturnValue({ ilike: mockIlike });
      mockIlike.mockReturnValue({ order: mockOrder });
      mockOrder.mockReturnValue({ limit: mockLimit });

      const callback = vi.fn();
      const debouncedSearch = createDebouncedSearch(callback);

      debouncedSearch('world');

      vi.advanceTimersByTime(300);
      await vi.runAllTimersAsync();

      expect(callback).toHaveBeenCalledWith(
        expect.objectContaining({
          messages: expect.any(Array),
          hasMore: false,
        })
      );
    });

    it('should call callback with error on failure', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      const callback = vi.fn();
      const debouncedSearch = createDebouncedSearch(callback);

      debouncedSearch('test');

      vi.advanceTimersByTime(300);
      await vi.runAllTimersAsync();

      expect(callback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'User not authenticated',
        })
      );
    });
  });
});
