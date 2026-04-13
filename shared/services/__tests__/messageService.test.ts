import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import { sanitizeHtml } from '@/lib/markdown';
import {
  getMessages,
  sendMessage,
  editMessage,
  deleteMessage,
  addReaction,
  removeReaction,
  getReactions,
} from '../messageService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  },
}));

// Mock sanitization
vi.mock('@/lib/markdown', () => ({
  sanitizeHtml: vi.fn((html: string) => html),
}));

describe('messageService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
    username: 'testuser',
  };

  const mockChannel = {
    id: 'channel-123',
    server_id: 'server-123',
    name: 'general',
    type: 'text',
  };

  const mockMessage = {
    id: 'message-123',
    channel_id: 'channel-123',
    author_id: 'user-123',
    content: 'Test message',
    type: 'default',
    reply_to_id: null,
    attachments: [],
    embeds: [],
    reactions: [],
    mentions: [],
    mention_roles: [],
    mention_everyone: false,
    pinned: false,
    edited: false,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: null,
    author: mockUser,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getMessages', () => {
    it('should fetch messages for a channel with pagination', async () => {
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

      // Mock messages query
      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [mockMessage],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      const result = await getMessages({ channelId: 'channel-123' });

      expect(result).toEqual([mockMessage]);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(
        getMessages({ channelId: 'channel-123' })
      ).rejects.toThrow('User not authenticated');
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

      await expect(
        getMessages({ channelId: 'channel-123' })
      ).rejects.toThrow('Access denied: User is not a member of this server');
    });

    it('should support pagination with before cursor', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      // Mock before message query
      const beforeMessageQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { created_at: '2024-01-01T12:00:00Z' },
          error: null,
        }),
      };

      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        lt: vi.fn().mockResolvedValue({
          data: [mockMessage],
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(beforeMessageQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      const result = await getMessages({
        channelId: 'channel-123',
        before: 'message-456',
      });

      expect(result).toEqual([mockMessage]);
    });

    it('should use default page size of 50', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const limitSpy = vi.fn().mockResolvedValue({
        data: [],
        error: null,
      });

      const messagesQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: limitSpy,
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(messagesQuery as any);

      await getMessages({ channelId: 'channel-123' });

      expect(limitSpy).toHaveBeenCalledWith(50);
    });
  });

  describe('sendMessage', () => {
    it('should send a message successfully', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const messageQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      const result = await sendMessage({
        channelId: 'channel-123',
        content: 'Test message',
      });

      expect(result).toEqual(mockMessage);
      expect(sanitizeHtml).toHaveBeenCalledWith('Test message');
    });

    it('should validate empty message content', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(
        sendMessage({ channelId: 'channel-123', content: '' })
      ).rejects.toThrow('Message content cannot be empty');

      await expect(
        sendMessage({ channelId: 'channel-123', content: '   ' })
      ).rejects.toThrow('Message content cannot be empty');
    });

    it('should validate message length', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const longMessage = 'a'.repeat(2001);

      await expect(
        sendMessage({ channelId: 'channel-123', content: longMessage })
      ).rejects.toThrow('Message content must be 2000 characters or less');
    });

    it('should sanitize message content', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const messageQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      await sendMessage({
        channelId: 'channel-123',
        content: '<script>alert("xss")</script>Hello',
      });

      expect(sanitizeHtml).toHaveBeenCalled();
    });

    it('should support reply messages', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const replyToQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { channel_id: 'channel-123' },
          error: null,
        }),
      };

      const messageQuery = {
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockMessage, type: 'reply', reply_to_id: 'message-456' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(replyToQuery as any)
        .mockReturnValueOnce(messageQuery as any);

      const result = await sendMessage({
        channelId: 'channel-123',
        content: 'Reply message',
        replyToId: 'message-456',
      });

      expect(result.type).toBe('reply');
      expect(result.reply_to_id).toBe('message-456');
    });

    it('should validate reply-to message exists in same channel', async () => {
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
          data: { id: 'member-123' },
          error: null,
        }),
      };

      const replyToQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { channel_id: 'different-channel' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(replyToQuery as any);

      await expect(
        sendMessage({
          channelId: 'channel-123',
          content: 'Reply',
          replyToId: 'message-456',
        })
      ).rejects.toThrow('Invalid reply: Referenced message not found in this channel');
    });
  });

  describe('editMessage', () => {
    it('should edit a message successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { author_id: 'user-123', channel_id: 'channel-123' },
          error: null,
        }),
      };

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockMessage, content: 'Updated message', edited: true },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      const result = await editMessage('message-123', {
        content: 'Updated message',
      });

      expect(result.content).toBe('Updated message');
      expect(result.edited).toBe(true);
      expect(sanitizeHtml).toHaveBeenCalledWith('Updated message');
    });

    it('should throw error if user is not the author', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { author_id: 'other-user', channel_id: 'channel-123' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(
        editMessage('message-123', { content: 'Updated' })
      ).rejects.toThrow('Access denied: Only the message author can edit the message');
    });

    it('should validate edited message content', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(
        editMessage('message-123', { content: '' })
      ).rejects.toThrow('Message content cannot be empty');

      await expect(
        editMessage('message-123', { content: 'a'.repeat(2001) })
      ).rejects.toThrow('Message content must be 2000 characters or less');
    });

    it('should sanitize edited message content', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { author_id: 'user-123', channel_id: 'channel-123' },
          error: null,
        }),
      };

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockMessage,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(fetchQuery as any)
        .mockReturnValueOnce(updateQuery as any);

      await editMessage('message-123', {
        content: '<script>alert("xss")</script>Updated',
      });

      expect(sanitizeHtml).toHaveBeenCalled();
    });
  });

  describe('deleteMessage', () => {
    it('should delete a message successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { author_id: 'user-123' },
          error: null,
        }),
      };

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

      await expect(deleteMessage('message-123')).resolves.not.toThrow();
    });

    it('should throw error if user is not the author', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { author_id: 'other-user' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(deleteMessage('message-123')).rejects.toThrow(
        'Access denied: Only the message author can delete the message'
      );
    });

    it('should throw error if message not found', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const fetchQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(fetchQuery as any);

      await expect(deleteMessage('message-123')).rejects.toThrow('Message not found');
    });
  });

  describe('addReaction', () => {
    it('should add a reaction to a message successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const messageQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'message-123', channel_id: 'channel-123' },
          error: null,
        }),
      };

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

      const reactionQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(messageQuery as any)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(reactionQuery as any);

      await expect(addReaction('message-123', '👍')).resolves.not.toThrow();
    });

    it('should throw error if emoji is empty', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(addReaction('message-123', '')).rejects.toThrow('Emoji cannot be empty');
      await expect(addReaction('message-123', '   ')).rejects.toThrow('Emoji cannot be empty');
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(addReaction('message-123', '👍')).rejects.toThrow('User not authenticated');
    });

    it('should throw error if message not found', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const messageQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(messageQuery as any);

      await expect(addReaction('message-123', '👍')).rejects.toThrow('Message not found');
    });

    it('should ignore duplicate reaction errors', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const messageQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'message-123', channel_id: 'channel-123' },
          error: null,
        }),
      };

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

      const reactionQuery = {
        insert: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'duplicate key value violates unique constraint' },
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(messageQuery as any)
        .mockReturnValueOnce(channelQuery as any)
        .mockReturnValueOnce(membershipQuery as any)
        .mockReturnValueOnce(reactionQuery as any);

      await expect(addReaction('message-123', '👍')).resolves.not.toThrow();
    });
  });

  describe('removeReaction', () => {
    it('should remove a reaction from a message successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const reactionQuery = {
        delete: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(reactionQuery as any);

      await expect(removeReaction('message-123', '👍')).resolves.not.toThrow();
    });

    it('should throw error if emoji is empty', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(removeReaction('message-123', '')).rejects.toThrow('Emoji cannot be empty');
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(removeReaction('message-123', '👍')).rejects.toThrow('User not authenticated');
    });
  });

  describe('getReactions', () => {
    it('should get and aggregate reactions for a message', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const reactionQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: [
            { emoji: '👍', user_id: 'user-123' },
            { emoji: '👍', user_id: 'user-456' },
            { emoji: '❤️', user_id: 'user-789' },
          ],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(reactionQuery as any);

      const result = await getReactions('message-123');

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({
        emoji: '👍',
        count: 2,
        users: ['user-123', 'user-456'],
        me: true,
      });
      expect(result[1]).toEqual({
        emoji: '❤️',
        count: 1,
        users: ['user-789'],
        me: false,
      });
    });

    it('should return empty array if no reactions', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const reactionQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: [],
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(reactionQuery as any);

      const result = await getReactions('message-123');

      expect(result).toEqual([]);
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getReactions('message-123')).rejects.toThrow('User not authenticated');
    });
  });
});
