import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  getChannels,
  getChannel,
  createChannel,
  updateChannel,
  deleteChannel,
} from '../../../shared/services/channelService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

describe('channelService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockChannel = {
    id: 'channel-123',
    server_id: 'server-123',
    name: 'general',
    type: 'text' as const,
    topic: 'General discussion',
    position: 0,
    nsfw: false,
    last_message_id: null,
    created_at: '2024-01-01T00:00:00Z',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getChannels', () => {
    it('should fetch all channels for a server ordered by position', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock membership check
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // Mock channels query
      const channelsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [mockChannel, { ...mockChannel, id: 'channel-456', position: 1 }],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(channelsQuery as any);

      const result = await getChannels('server-123');

      expect(result).toHaveLength(2);
      expect(result[0].position).toBe(0);
      expect(result[1].position).toBe(1);
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getChannels('server-123')).rejects.toThrow('User not authenticated');
    });

    it('should throw error if user is not a member of the server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(membershipQuery as any);

      await expect(getChannels('server-123')).rejects.toThrow(
        'Access denied: User is not a member of this server'
      );
    });

    it('should return empty array if server has no channels', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const channelsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(channelsQuery as any);

      const result = await getChannels('server-123');

      expect(result).toEqual([]);
    });
  });

  describe('getChannel', () => {
    it('should fetch a single channel by ID', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock channel query
      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockChannel,
          error: null,
        }),
      };

      // Mock membership check
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      const result = await getChannel('channel-123');

      expect(result).toEqual(mockChannel);
    });

    it('should throw error if channel not found', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Not found' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(channelQuery as any);

      await expect(getChannel('channel-123')).rejects.toThrow('Failed to fetch channel');
    });

    it('should throw error if user is not a member of the server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockChannel,
          error: null,
        }),
      };

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      await expect(getChannel('channel-123')).rejects.toThrow(
        'Access denied: User is not a member of this server'
      );
    });
  });

  describe('createChannel', () => {
    it('should create a new channel with auto-assigned position', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock membership check
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // Mock existing channels query (for position calculation)
      const existingChannelsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [{ position: 2 }],
          error: null,
        }),
      };

      // Mock channel creation
      const createQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockChannel, position: 3 },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(existingChannelsQuery as any)
        .mockReturnValueOnce(createQuery as any);

      const result = await createChannel({
        serverId: 'server-123',
        name: 'general',
        type: 'text',
        topic: 'General discussion',
      });

      expect(result.position).toBe(3);
      expect(result.name).toBe('general');
    });

    it('should assign position 0 for first channel in server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // No existing channels
      const existingChannelsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      const createQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockChannel,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(existingChannelsQuery as any)
        .mockReturnValueOnce(createQuery as any);

      const result = await createChannel({
        serverId: 'server-123',
        name: 'general',
      });

      expect(result.position).toBe(0);
    });

    it('should validate channel name', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(
        createChannel({ serverId: 'server-123', name: '' })
      ).rejects.toThrow('Channel name is required');

      await expect(
        createChannel({ serverId: 'server-123', name: '   ' })
      ).rejects.toThrow('Channel name is required');

      await expect(
        createChannel({ serverId: 'server-123', name: 'a'.repeat(101) })
      ).rejects.toThrow('Channel name must be 100 characters or less');
    });

    it('should throw error if user is not a member of the server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(membershipQuery as any);

      await expect(
        createChannel({ serverId: 'server-123', name: 'test' })
      ).rejects.toThrow('Access denied: User is not a member of this server');
    });

    it('should use default values for optional fields', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const existingChannelsQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      const createQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockChannel, type: 'text', nsfw: false },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(existingChannelsQuery as any)
        .mockReturnValueOnce(createQuery as any);

      const result = await createChannel({
        serverId: 'server-123',
        name: 'test-channel',
      });

      expect(result.type).toBe('text');
      expect(result.nsfw).toBe(false);
    });
  });

  describe('updateChannel', () => {
    it('should update channel details', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock channel fetch
      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      // Mock membership check
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // Mock update
      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockChannel, name: 'updated-channel', topic: 'New topic' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      const result = await updateChannel('channel-123', {
        name: 'updated-channel',
        topic: 'New topic',
      });

      expect(result.name).toBe('updated-channel');
      expect(result.topic).toBe('New topic');
    });

    it('should validate channel name when updating', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      await expect(
        updateChannel('channel-123', { name: '' })
      ).rejects.toThrow('Channel name cannot be empty');

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      await expect(
        updateChannel('channel-123', { name: 'a'.repeat(101) })
      ).rejects.toThrow('Channel name must be 100 characters or less');
    });

    it('should throw error if channel not found', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(channelQuery as any);

      await expect(
        updateChannel('channel-123', { name: 'updated' })
      ).rejects.toThrow('Channel not found');
    });

    it('should throw error if user is not a member of the server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      await expect(
        updateChannel('channel-123', { name: 'updated' })
      ).rejects.toThrow('Access denied: User is not a member of this server');
    });

    it('should allow updating position', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockChannel, position: 5 },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      const result = await updateChannel('channel-123', { position: 5 });

      expect(result.position).toBe(5);
    });
  });

  describe('deleteChannel', () => {
    it('should delete a channel', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock channel fetch
      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      // Mock membership check
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // Mock delete
      const deleteQuery = {
        delete: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(deleteQuery as any);

      await expect(deleteChannel('channel-123')).resolves.not.toThrow();
    });

    it('should throw error if channel not found', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(channelQuery as any);

      await expect(deleteChannel('channel-123')).rejects.toThrow('Channel not found');
    });

    it('should throw error if user is not a member of the server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const channelQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { server_id: 'server-123' },
          error: null,
        }),
      };

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any);

      await expect(deleteChannel('channel-123')).rejects.toThrow(
        'Access denied: User is not a member of this server'
      );
    });
  });
});
