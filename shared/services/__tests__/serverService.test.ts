import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  getServers,
  getServer,
  createServer,
  updateServer,
  deleteServer,
} from '../serverService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

describe('serverService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockServer = {
    id: 'server-123',
    name: 'Test Server',
    description: 'A test server',
    icon: null,
    owner_id: 'user-123',
    member_count: 1,
    created_at: '2024-01-01T00:00:00Z',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getServers', () => {
    it('should fetch all servers for authenticated user', async () => {
      // Mock authenticated user
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock server_members query
      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: [{ server_id: 'server-123' }],
          error: null,
        }),
      };

      // Mock servers query
      const serversQuery = {
        select: vi.fn().mockReturnThis(),
        in: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [mockServer],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(serversQuery as any);

      const result = await getServers();

      expect(result).toEqual([mockServer]);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getServers()).rejects.toThrow('User not authenticated');
    });

    it('should return empty array if user has no servers', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(membershipQuery as any);

      const result = await getServers();

      expect(result).toEqual([]);
    });
  });

  describe('getServer', () => {
    it('should fetch a single server by ID', async () => {
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

      // Mock server query
      const serverQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockServer,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(serverQuery as any);

      const result = await getServer('server-123');

      expect(result).toEqual(mockServer);
    });

    it('should throw error if user is not a member', async () => {
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

      await expect(getServer('server-123')).rejects.toThrow(
        'Access denied: User is not a member of this server'
      );
    });
  });

  describe('createServer', () => {
    it('should create a new server with default channel', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock server creation
      const serverQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockServer,
          error: null,
        }),
      };

      // Mock member creation
      const memberQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      // Mock channel creation
      const channelQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(serverQuery as any)
        .mockReturnValueOnce(memberQuery as any)
        .mockReturnValueOnce(channelQuery as any);

      const result = await createServer({
        name: 'Test Server',
        description: 'A test server',
      });

      expect(result).toEqual(mockServer);
    });

    it('should validate server name', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(createServer({ name: '' })).rejects.toThrow(
        'Server name is required'
      );

      await expect(
        createServer({ name: 'a'.repeat(101) })
      ).rejects.toThrow('Server name must be 100 characters or less');
    });
  });

  describe('updateServer', () => {
    it('should update server details', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock ownership check
      const ownerQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { owner_id: 'user-123' },
          error: null,
        }),
      };

      // Mock update
      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockServer, name: 'Updated Server' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(ownerQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      const result = await updateServer('server-123', {
        name: 'Updated Server',
      });

      expect(result.name).toBe('Updated Server');
    });

    it('should throw error if user is not the owner', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const ownerQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { owner_id: 'other-user' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(ownerQuery as any);

      await expect(
        updateServer('server-123', { name: 'Updated' })
      ).rejects.toThrow('Access denied: Only the server owner can update the server');
    });
  });

  describe('deleteServer', () => {
    it('should delete a server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock ownership check
      const ownerQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { owner_id: 'user-123' },
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
        .mockReturnValueOnce(ownerQuery as any)
        .mockReturnValueOnce(deleteQuery as any);

      await expect(deleteServer('server-123')).resolves.not.toThrow();
    });

    it('should throw error if user is not the owner', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const ownerQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { owner_id: 'other-user' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(ownerQuery as any);

      await expect(deleteServer('server-123')).rejects.toThrow(
        'Access denied: Only the server owner can delete the server'
      );
    });
  });
});
