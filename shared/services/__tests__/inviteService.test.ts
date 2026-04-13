import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  createInvite,
  getInvites,
  getInviteByCode,
  joinViaInvite,
  deleteInvite,
} from '../../../shared/services/inviteService';
import type { Invite, Server } from '@shared/types/models';

// Mock Supabase
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

describe('inviteService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockServer: Server = {
    id: 'server-123',
    name: 'Test Server',
    description: 'A test server',
    icon: null,
    owner_id: 'user-123',
    member_count: 1,
    created_at: '2024-01-01T00:00:00Z',
  };

  const mockInvite: Invite = {
    id: 'invite-123',
    server_id: 'server-123',
    code: 'ABC12345',
    created_by: 'user-123',
    expires_at: null,
    max_uses: null,
    uses: 0,
    created_at: '2024-01-01T00:00:00Z',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('createInvite', () => {
    it('should create an invite successfully', async () => {
      // Mock authenticated user
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock membership check
      const membershipSelect = vi.fn().mockReturnThis();
      const membershipEq = vi.fn().mockReturnThis();
      const membershipSingle = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      // Mock code uniqueness check
      const codeSelect = vi.fn().mockReturnThis();
      const codeEq = vi.fn().mockReturnThis();
      const codeSingle = vi.fn().mockResolvedValue({
        data: null,
        error: null,
      });

      // Mock invite creation
      const insertSelect = vi.fn().mockReturnThis();
      const insertSingle = vi.fn().mockResolvedValue({
        data: mockInvite,
        error: null,
      });
      const insert = vi.fn().mockReturnValue({
        select: insertSelect,
      });

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: membershipSelect,
          } as any;
        }
        if (table === 'invites') {
          // First call is for code check, second is for insert
          const callCount = vi.mocked(supabase.from).mock.calls.filter(
            (call) => call[0] === 'invites'
          ).length;
          
          if (callCount === 1) {
            return {
              select: codeSelect,
            } as any;
          }
          
          return {
            insert,
          } as any;
        }
        return {} as any;
      });

      membershipSelect.mockReturnValue({ eq: membershipEq });
      membershipEq.mockReturnValue({ eq: membershipEq });
      membershipEq.mockReturnValue({ single: membershipSingle });

      codeSelect.mockReturnValue({ eq: codeEq });
      codeEq.mockReturnValue({ single: codeSingle });

      insertSelect.mockReturnValue({ single: insertSingle });

      const result = await createInvite({
        serverId: 'server-123',
        expiresAt: null,
        maxUses: null,
      });

      expect(result).toEqual(mockInvite);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(
        createInvite({ serverId: 'server-123' })
      ).rejects.toThrow('User not authenticated');
    });

    it('should throw error if user is not a member', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(
        createInvite({ serverId: 'server-123' })
      ).rejects.toThrow('Access denied: User is not a member of this server');
    });

    it('should throw error if max uses is less than 1', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(
        createInvite({ serverId: 'server-123', maxUses: 0 })
      ).rejects.toThrow('Max uses must be at least 1');
    });

    it('should throw error if expiration time is in the past', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      const pastDate = new Date('2020-01-01').toISOString();

      await expect(
        createInvite({ serverId: 'server-123', expiresAt: pastDate })
      ).rejects.toThrow('Expiration time must be in the future');
    });
  });

  describe('getInvites', () => {
    it('should fetch invites for a server', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const membershipSelect = vi.fn().mockReturnThis();
      const membershipEq = vi.fn().mockReturnThis();
      const membershipSingle = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      const invitesSelect = vi.fn().mockReturnThis();
      const invitesEq = vi.fn().mockReturnThis();
      const invitesOrder = vi.fn().mockResolvedValue({
        data: [mockInvite],
        error: null,
      });

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'server_members') {
          return {
            select: membershipSelect,
          } as any;
        }
        if (table === 'invites') {
          return {
            select: invitesSelect,
          } as any;
        }
        return {} as any;
      });

      membershipSelect.mockReturnValue({ eq: membershipEq });
      membershipEq.mockReturnValue({ eq: membershipEq });
      membershipEq.mockReturnValue({ single: membershipSingle });

      invitesSelect.mockReturnValue({ eq: invitesEq });
      invitesEq.mockReturnValue({ order: invitesOrder });

      const result = await getInvites('server-123');

      expect(result).toEqual([mockInvite]);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getInvites('server-123')).rejects.toThrow(
        'User not authenticated'
      );
    });

    it('should throw error if user is not a member', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(getInvites('server-123')).rejects.toThrow(
        'Access denied: User is not a member of this server'
      );
    });
  });

  describe('getInviteByCode', () => {
    it('should fetch an invite by code', async () => {
      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: { ...mockInvite, server: mockServer },
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      const result = await getInviteByCode('ABC12345');

      expect(result).toEqual({ ...mockInvite, server: mockServer });
    });

    it('should throw error if invite not found', async () => {
      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'Not found' },
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(getInviteByCode('INVALID')).rejects.toThrow(
        'Failed to fetch invite'
      );
    });

    it('should throw error if invite is expired by max uses', async () => {
      const expiredInvite = {
        ...mockInvite,
        max_uses: 5,
        uses: 5,
        server: mockServer,
      };

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: expiredInvite,
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(getInviteByCode('ABC12345')).rejects.toThrow(
        'This invite has expired'
      );
    });

    it('should throw error if invite is expired by time', async () => {
      const expiredInvite = {
        ...mockInvite,
        expires_at: '2020-01-01T00:00:00Z',
        server: mockServer,
      };

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: expiredInvite,
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(getInviteByCode('ABC12345')).rejects.toThrow(
        'This invite has expired'
      );
    });
  });

  describe('joinViaInvite', () => {
    it('should join a server via invite', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const inviteSelect = vi.fn().mockReturnThis();
      const inviteEq = vi.fn().mockReturnThis();
      const inviteSingle = vi.fn().mockResolvedValue({
        data: { ...mockInvite, server: mockServer },
        error: null,
      });

      const memberSelect = vi.fn().mockReturnThis();
      const memberEq = vi.fn().mockReturnThis();
      const memberSingle = vi.fn().mockResolvedValue({
        data: null,
        error: null,
      });

      const insert = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      const update = vi.fn().mockReturnThis();
      const updateEq = vi.fn().mockResolvedValue({
        data: mockInvite,
        error: null,
      });

      let callCount = 0;
      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'invites') {
          callCount++;
          if (callCount === 1) {
            return {
              select: inviteSelect,
            } as any;
          }
          return {
            update,
          } as any;
        }
        if (table === 'server_members') {
          const memberCallCount = vi.mocked(supabase.from).mock.calls.filter(
            (call) => call[0] === 'server_members'
          ).length;
          
          if (memberCallCount === 1) {
            return {
              select: memberSelect,
            } as any;
          }
          return {
            insert,
          } as any;
        }
        return {} as any;
      });

      inviteSelect.mockReturnValue({ eq: inviteEq });
      inviteEq.mockReturnValue({ single: inviteSingle });

      memberSelect.mockReturnValue({ eq: memberEq });
      memberEq.mockReturnValue({ eq: memberEq });
      memberEq.mockReturnValue({ single: memberSingle });

      update.mockReturnValue({ eq: updateEq });

      const result = await joinViaInvite('ABC12345');

      expect(result).toEqual(mockServer);
      expect(insert).toHaveBeenCalled();
    });

    it('should return server if user is already a member', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const inviteSelect = vi.fn().mockReturnThis();
      const inviteEq = vi.fn().mockReturnThis();
      const inviteSingle = vi.fn().mockResolvedValue({
        data: { ...mockInvite, server: mockServer },
        error: null,
      });

      const memberSelect = vi.fn().mockReturnThis();
      const memberEq = vi.fn().mockReturnThis();
      const memberSingle = vi.fn().mockResolvedValue({
        data: { id: 'member-123' },
        error: null,
      });

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'invites') {
          return {
            select: inviteSelect,
          } as any;
        }
        if (table === 'server_members') {
          return {
            select: memberSelect,
          } as any;
        }
        return {} as any;
      });

      inviteSelect.mockReturnValue({ eq: inviteEq });
      inviteEq.mockReturnValue({ single: inviteSingle });

      memberSelect.mockReturnValue({ eq: memberEq });
      memberEq.mockReturnValue({ eq: memberEq });
      memberEq.mockReturnValue({ single: memberSingle });

      const result = await joinViaInvite('ABC12345');

      expect(result).toEqual(mockServer);
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(joinViaInvite('ABC12345')).rejects.toThrow(
        'User not authenticated'
      );
    });

    it('should throw error if invite is expired', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const expiredInvite = {
        ...mockInvite,
        max_uses: 5,
        uses: 5,
        server: mockServer,
      };

      const select = vi.fn().mockReturnThis();
      const eq = vi.fn().mockReturnThis();
      const single = vi.fn().mockResolvedValue({
        data: expiredInvite,
        error: null,
      });

      vi.mocked(supabase.from).mockReturnValue({
        select,
      } as any);

      select.mockReturnValue({ eq });
      eq.mockReturnValue({ single });

      await expect(joinViaInvite('ABC12345')).rejects.toThrow(
        'This invite has expired'
      );
    });
  });

  describe('deleteInvite', () => {
    it('should delete an invite', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const inviteSelect = vi.fn().mockReturnThis();
      const inviteEq = vi.fn().mockReturnThis();
      const inviteSingle = vi.fn().mockResolvedValue({
        data: { server_id: 'server-123' },
        error: null,
      });

      const serverSelect = vi.fn().mockReturnThis();
      const serverEq = vi.fn().mockReturnThis();
      const serverSingle = vi.fn().mockResolvedValue({
        data: { owner_id: 'user-123' },
        error: null,
      });

      const deleteEq = vi.fn().mockResolvedValue({
        data: null,
        error: null,
      });
      const deleteFn = vi.fn().mockReturnValue({
        eq: deleteEq,
      });

      let callCount = 0;
      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'invites') {
          callCount++;
          if (callCount === 1) {
            return {
              select: inviteSelect,
            } as any;
          }
          return {
            delete: deleteFn,
          } as any;
        }
        if (table === 'servers') {
          return {
            select: serverSelect,
          } as any;
        }
        return {} as any;
      });

      inviteSelect.mockReturnValue({ eq: inviteEq });
      inviteEq.mockReturnValue({ single: inviteSingle });

      serverSelect.mockReturnValue({ eq: serverEq });
      serverEq.mockReturnValue({ single: serverSingle });

      await deleteInvite('invite-123');

      expect(deleteFn).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(deleteInvite('invite-123')).rejects.toThrow(
        'User not authenticated'
      );
    });

    it('should throw error if user is not the server owner', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const inviteSelect = vi.fn().mockReturnThis();
      const inviteEq = vi.fn().mockReturnThis();
      const inviteSingle = vi.fn().mockResolvedValue({
        data: { server_id: 'server-123' },
        error: null,
      });

      const serverSelect = vi.fn().mockReturnThis();
      const serverEq = vi.fn().mockReturnThis();
      const serverSingle = vi.fn().mockResolvedValue({
        data: { owner_id: 'other-user' },
        error: null,
      });

      vi.mocked(supabase.from).mockImplementation((table: string) => {
        if (table === 'invites') {
          return {
            select: inviteSelect,
          } as any;
        }
        if (table === 'servers') {
          return {
            select: serverSelect,
          } as any;
        }
        return {} as any;
      });

      inviteSelect.mockReturnValue({ eq: inviteEq });
      inviteEq.mockReturnValue({ single: inviteSingle });

      serverSelect.mockReturnValue({ eq: serverEq });
      serverEq.mockReturnValue({ single: serverSingle });

      await expect(deleteInvite('invite-123')).rejects.toThrow(
        'Access denied: Only the server owner can delete invites'
      );
    });
  });
});
