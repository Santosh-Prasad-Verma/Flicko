import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  getDMConversations,
  getDMMessages,
  sendDM,
} from '../dmService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

// Mock markdown sanitization
vi.mock('@/lib/markdown', () => ({
  sanitizeHtml: vi.fn((content: string) => content),
}));

describe('dmService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockOtherUser = {
    id: 'user-456',
    username: 'otheruser',
    email: 'other@example.com',
    discriminator: '0001',
    avatar: null,
    banner: null,
    bio: null,
    status: 'online' as const,
    custom_status: null,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  };

  const mockDirectMessage = {
    id: 'dm-123',
    sender_id: 'user-123',
    recipient_id: 'user-456',
    content: 'Hello!',
    created_at: '2024-01-01T12:00:00Z',
    updated_at: null,
    sender: mockUser,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getDMConversations', () => {
    it('should fetch all DM conversations for authenticated user', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const dmQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [
            {
              ...mockDirectMessage,
              sender: mockUser,
              recipient: mockOtherUser,
            },
          ],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(dmQuery as any);

      const result = await getDMConversations();

      expect(result).toHaveLength(1);
      expect(result[0].userId).toBe('user-456');
      expect(result[0].user).toEqual(mockOtherUser);
      expect(result[0].lastMessage).toBeDefined();
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getDMConversations()).rejects.toThrow('User not authenticated');
    });

    it('should return empty array if user has no DM conversations', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const dmQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(dmQuery as any);

      const result = await getDMConversations();

      expect(result).toEqual([]);
    });

    it('should group messages by conversation partner', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const dmQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [
            {
              id: 'dm-1',
              sender_id: 'user-456',
              recipient_id: 'user-123',
              content: 'Message 1',
              created_at: '2024-01-01T12:00:00Z',
              sender: mockOtherUser,
              recipient: mockUser,
            },
            {
              id: 'dm-2',
              sender_id: 'user-123',
              recipient_id: 'user-456',
              content: 'Message 2',
              created_at: '2024-01-01T12:01:00Z',
              sender: mockUser,
              recipient: mockOtherUser,
            },
          ],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(dmQuery as any);

      const result = await getDMConversations();

      expect(result).toHaveLength(1);
      expect(result[0].userId).toBe('user-456');
      expect(result[0].lastMessage?.id).toBe('dm-1'); // Most recent message
    });

    it('should sort conversations by most recent activity', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const user2 = { ...mockOtherUser, id: 'user-789' };

      const dmQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({
          data: [
            {
              id: 'dm-2',
              sender_id: 'user-789',
              recipient_id: 'user-123',
              content: 'Recent message',
              created_at: '2024-01-02T12:00:00Z',
              sender: user2,
              recipient: mockUser,
            },
            {
              id: 'dm-1',
              sender_id: 'user-456',
              recipient_id: 'user-123',
              content: 'Old message',
              created_at: '2024-01-01T12:00:00Z',
              sender: mockOtherUser,
              recipient: mockUser,
            },
          ],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(dmQuery as any);

      const result = await getDMConversations();

      expect(result).toHaveLength(2);
      expect(result[0].userId).toBe('user-789'); // Most recent first
      expect(result[1].userId).toBe('user-456');
    });
  });

  describe('getDMMessages', () => {
    it('should fetch DM messages between two users', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock user existence check
      const userQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      // Mock messages query
      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [mockDirectMessage],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(userQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      const result = await getDMMessages({ otherUserId: 'user-456' });

      expect(result).toEqual([mockDirectMessage]);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(
        getDMMessages({ otherUserId: 'user-456' })
      ).rejects.toThrow('User not authenticated');
    });

    it('should throw error if other user does not exist', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const userQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'User not found' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(userQuery as any);

      await expect(
        getDMMessages({ otherUserId: 'invalid-user' })
      ).rejects.toThrow('User not found');
    });

    it('should return messages in chronological order', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const userQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      // Messages returned in reverse chronological order from DB
      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [
            { ...mockDirectMessage, id: 'dm-2', created_at: '2024-01-01T12:01:00Z' },
            { ...mockDirectMessage, id: 'dm-1', created_at: '2024-01-01T12:00:00Z' },
          ],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(userQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      const result = await getDMMessages({ otherUserId: 'user-456' });

      // Should be reversed to chronological order
      expect(result[0].id).toBe('dm-1');
      expect(result[1].id).toBe('dm-2');
    });

    it('should support pagination with before cursor', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const userQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      // Mock getting the before message timestamp
      const beforeQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { created_at: '2024-01-01T12:00:00Z' },
          error: null,
        }),
      };

      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        lt: vi.fn().mockResolvedValue({
          data: [mockDirectMessage],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(userQuery as any)
        .mockReturnValueOnce(beforeQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      const result = await getDMMessages({
        otherUserId: 'user-456',
        before: 'dm-123',
      });

      expect(result).toBeDefined();
    });

    it('should respect custom limit parameter', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const userQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      const limitSpy = vi.fn().mockResolvedValue({
        data: [],
        error: null,
      });

      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        or: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: limitSpy,
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(userQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      await getDMMessages({ otherUserId: 'user-456', limit: 25 });

      expect(limitSpy).toHaveBeenCalledWith(25);
    });
  });

  describe('sendDM', () => {
    it('should send a direct message', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock recipient check
      const recipientQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      // Mock message creation
      const messageQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockDirectMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(recipientQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      const result = await sendDM({
        recipientId: 'user-456',
        content: 'Hello!',
      });

      expect(result).toEqual(mockDirectMessage);
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(
        sendDM({ recipientId: 'user-456', content: 'Hello!' })
      ).rejects.toThrow('User not authenticated');
    });

    it('should validate message content is not empty', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(
        sendDM({ recipientId: 'user-456', content: '' })
      ).rejects.toThrow('Message content cannot be empty');

      await expect(
        sendDM({ recipientId: 'user-456', content: '   ' })
      ).rejects.toThrow('Message content cannot be empty');
    });

    it('should validate message content length', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const longContent = 'a'.repeat(2001);

      await expect(
        sendDM({ recipientId: 'user-456', content: longContent })
      ).rejects.toThrow('Message content must be 2000 characters or less');
    });

    it('should throw error if recipient does not exist', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const recipientQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'User not found' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(recipientQuery as any);

      await expect(
        sendDM({ recipientId: 'invalid-user', content: 'Hello!' })
      ).rejects.toThrow('Recipient not found');
    });

    it('should prevent sending DM to self', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const recipientQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-123' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(recipientQuery as any);

      await expect(
        sendDM({ recipientId: 'user-123', content: 'Hello!' })
      ).rejects.toThrow('Cannot send direct message to yourself');
    });

    it('should sanitize message content', async () => {
      const { sanitizeHtml } = await import('@/lib/markdown');
      
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const recipientQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      const messageQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockDirectMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(recipientQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      await sendDM({
        recipientId: 'user-456',
        content: '<script>alert("xss")</script>Hello!',
      });

      expect(sanitizeHtml).toHaveBeenCalled();
    });

    it('should trim whitespace from message content', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const recipientQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'user-456' },
          error: null,
        }),
      };

      const insertSpy = vi.fn().mockReturnThis();
      const messageQuery = {
        insert: insertSpy,
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockDirectMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(recipientQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      await sendDM({
        recipientId: 'user-456',
        content: '  Hello!  ',
      });

      // Verify insert was called with trimmed content
      expect(insertSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          content: 'Hello!',
        })
      );
    });
  });
});
