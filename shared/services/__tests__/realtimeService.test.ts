import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  subscribeToChannel,
  unsubscribeFromChannel,
  trackPresence,
  sendTypingIndicator,
  stopTypingIndicator,
  subscribeToTyping,
  getActiveChannels,
  unsubscribeAll,
  getConnectionStatus,
} from '../../../shared/services/realtimeService';
import { supabase } from '@/lib/supabase';
import type { Message } from '@shared/types/models';

// Mock Supabase
vi.mock('@/lib/supabase', () => ({
  supabase: {
    channel: vi.fn(),
    removeChannel: vi.fn(),
    from: vi.fn(),
    realtime: {
      connection: {
        connectionState: 'connected',
      },
    },
  },
}));

describe('realtimeService', () => {
  let mockChannel: any;
  let mockSubscribe: any;
  let mockOn: any;
  let mockTrack: any;
  let mockUntrack: any;
  let mockSend: any;

  beforeEach(() => {
    vi.clearAllMocks();

    // Setup mock channel methods
    mockSubscribe = vi.fn((callback) => {
      // Simulate successful subscription
      setTimeout(() => callback('SUBSCRIBED'), 0);
      return mockChannel;
    });

    mockOn = vi.fn(() => mockChannel);
    mockTrack = vi.fn();
    mockUntrack = vi.fn();
    mockSend = vi.fn();

    mockChannel = {
      on: mockOn,
      subscribe: mockSubscribe,
      track: mockTrack,
      untrack: mockUntrack,
      send: mockSend,
      presenceState: vi.fn(() => ({})),
    };

    (supabase.channel as any).mockReturnValue(mockChannel);
    (supabase.from as any).mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({
        data: {
          id: 'user-1',
          username: 'testuser',
          status: 'online',
        },
      }),
    });
  });

  afterEach(() => {
    // Clean up all subscriptions
    unsubscribeAll();
  });

  describe('subscribeToChannel', () => {
    it('creates a subscription for message events', () => {
      const channelId = 'channel-1';
      const handlers = {
        onInsert: vi.fn(),
        onUpdate: vi.fn(),
        onDelete: vi.fn(),
      };

      subscribeToChannel(channelId, handlers);

      expect(supabase.channel).toHaveBeenCalledWith(`messages:${channelId}`);
      expect(mockOn).toHaveBeenCalledTimes(3); // INSERT, UPDATE, DELETE
      expect(mockSubscribe).toHaveBeenCalled();
    });

    it('registers INSERT event handler', () => {
      const channelId = 'channel-1';
      const onInsert = vi.fn();

      subscribeToChannel(channelId, { onInsert });

      expect(mockOn).toHaveBeenCalledWith(
        'postgres_changes',
        expect.objectContaining({
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        }),
        expect.any(Function)
      );
    });

    it('registers UPDATE event handler', () => {
      const channelId = 'channel-1';
      const onUpdate = vi.fn();

      subscribeToChannel(channelId, { onUpdate });

      expect(mockOn).toHaveBeenCalledWith(
        'postgres_changes',
        expect.objectContaining({
          event: 'UPDATE',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        }),
        expect.any(Function)
      );
    });

    it('registers DELETE event handler', () => {
      const channelId = 'channel-1';
      const onDelete = vi.fn();

      subscribeToChannel(channelId, { onDelete });

      expect(mockOn).toHaveBeenCalledWith(
        'postgres_changes',
        expect.objectContaining({
          event: 'DELETE',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        }),
        expect.any(Function)
      );
    });

    it('returns an unsubscribe function', () => {
      const channelId = 'channel-1';
      const unsubscribe = subscribeToChannel(channelId, {});

      expect(typeof unsubscribe).toBe('function');
    });

    it('warns when subscribing to already subscribed channel', () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => { });
      const channelId = 'channel-1';

      subscribeToChannel(channelId, {});
      subscribeToChannel(channelId, {});

      expect(consoleSpy).toHaveBeenCalledWith(
        `Already subscribed to channel ${channelId}`
      );

      consoleSpy.mockRestore();
    });

    it('adds channel to active channels', () => {
      const channelId = 'channel-1';
      subscribeToChannel(channelId, {});

      const activeChannels = getActiveChannels();
      expect(activeChannels).toContain(channelId);
    });

    it('calls onInsert handler when INSERT event received', async () => {
      const channelId = 'channel-1';
      const onInsert = vi.fn();
      let insertHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'INSERT') {
          insertHandler = handler;
        }
        return mockChannel;
      });

      subscribeToChannel(channelId, { onInsert });

      // Simulate INSERT event
      const newMessage: Message = {
        id: 'msg-1',
        channel_id: channelId,
        author_id: 'user-1',
        content: 'Hello',
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
        created_at: new Date().toISOString(),
        updated_at: null,
      };

      await insertHandler({ new: newMessage });

      // Wait for async author fetch
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(onInsert).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'msg-1',
          content: 'Hello',
          author: expect.objectContaining({
            id: 'user-1',
            username: 'testuser',
          }),
        })
      );
    });
  });

  describe('unsubscribeFromChannel', () => {
    it('removes channel subscription', () => {
      const channelId = 'channel-1';
      subscribeToChannel(channelId, {});

      unsubscribeFromChannel(channelId);

      expect(supabase.removeChannel).toHaveBeenCalledWith(mockChannel);
    });

    it('removes channel from active channels', () => {
      const channelId = 'channel-1';
      subscribeToChannel(channelId, {});

      unsubscribeFromChannel(channelId);

      const activeChannels = getActiveChannels();
      expect(activeChannels).not.toContain(channelId);
    });

    it('warns when unsubscribing from non-existent channel', () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => { });
      const channelId = 'non-existent';

      unsubscribeFromChannel(channelId);

      expect(consoleSpy).toHaveBeenCalledWith(
        `No active subscription for channel ${channelId}`
      );

      consoleSpy.mockRestore();
    });
  });

  describe('trackPresence', () => {
    it('creates a presence channel', () => {
      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';
      const status = 'online';

      trackPresence(channelId, userId, username, status, {});

      expect(supabase.channel).toHaveBeenCalledWith(`presence:${channelId}`);
    });

    it('subscribes to presence events', () => {
      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';
      const status = 'online';

      trackPresence(channelId, userId, username, status, {});

      expect(mockOn).toHaveBeenCalledWith(
        'presence',
        { event: 'sync' },
        expect.any(Function)
      );
      expect(mockOn).toHaveBeenCalledWith(
        'presence',
        { event: 'join' },
        expect.any(Function)
      );
      expect(mockOn).toHaveBeenCalledWith(
        'presence',
        { event: 'leave' },
        expect.any(Function)
      );
    });

    it('tracks user presence after subscription', async () => {
      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';
      const status = 'online';

      trackPresence(channelId, userId, username, status, {});

      // Wait for subscription callback
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(mockTrack).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: userId,
          username,
          status,
        })
      );
    });

    it('returns an unsubscribe function', () => {
      const channelId = 'channel-1';
      const unsubscribe = trackPresence(channelId, 'user-1', 'test', 'online', {});

      expect(typeof unsubscribe).toBe('function');
    });

    it('calls onJoin handler when user joins', () => {
      const channelId = 'channel-1';
      const onJoin = vi.fn();
      let joinHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'join') {
          joinHandler = handler;
        }
        return mockChannel;
      });

      trackPresence(channelId, 'user-1', 'test', 'online', { onJoin });

      // Simulate join event
      joinHandler({
        key: 'user-2',
        newPresences: [
          {
            user_id: 'user-2',
            username: 'newuser',
            status: 'online',
            online_at: new Date().toISOString(),
          },
        ],
      });

      expect(onJoin).toHaveBeenCalledWith(
        'user-2',
        expect.objectContaining({
          user_id: 'user-2',
          username: 'newuser',
          status: 'online',
        })
      );
    });
  });

  describe('sendTypingIndicator', () => {
    it('sends typing event', () => {
      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';

      sendTypingIndicator(channelId, userId, username);

      expect(supabase.channel).toHaveBeenCalledWith(`typing:${channelId}`);
      expect(mockSend).toHaveBeenCalledWith({
        type: 'broadcast',
        event: 'typing',
        payload: expect.objectContaining({
          user_id: userId,
          username,
        }),
      });
    });

    it('throttles typing events to max 1 per second', () => {
      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';

      sendTypingIndicator(channelId, userId, username);
      sendTypingIndicator(channelId, userId, username);
      sendTypingIndicator(channelId, userId, username);

      // Should only send once due to throttling
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    it('allows typing event after 1 second', async () => {
      vi.useFakeTimers();

      const channelId = 'channel-1';
      const userId = 'user-1';
      const username = 'testuser';

      sendTypingIndicator(channelId, userId, username);
      expect(mockSend).toHaveBeenCalledTimes(1);

      // Advance time by 1 second
      vi.advanceTimersByTime(1000);

      sendTypingIndicator(channelId, userId, username);
      expect(mockSend).toHaveBeenCalledTimes(2);

      vi.useRealTimers();
    });
  });

  describe('stopTypingIndicator', () => {
    it('sends stop typing event', () => {
      const channelId = 'channel-1';
      const userId = 'user-1';

      stopTypingIndicator(channelId, userId);

      expect(supabase.channel).toHaveBeenCalledWith(`typing:${channelId}`);
      expect(mockSend).toHaveBeenCalledWith({
        type: 'broadcast',
        event: 'stop_typing',
        payload: { user_id: userId },
      });
    });
  });

  describe('subscribeToTyping', () => {
    it('creates a typing channel subscription', () => {
      const channelId = 'channel-1';
      const currentUserId = 'user-1';

      subscribeToTyping(channelId, currentUserId, {});

      expect(supabase.channel).toHaveBeenCalledWith(`typing:${channelId}`);
      expect(mockOn).toHaveBeenCalledWith(
        'broadcast',
        { event: 'typing' },
        expect.any(Function)
      );
      expect(mockOn).toHaveBeenCalledWith(
        'broadcast',
        { event: 'stop_typing' },
        expect.any(Function)
      );
    });

    it('calls onTypingStart when typing event received', () => {
      const channelId = 'channel-1';
      const currentUserId = 'user-1';
      const onTypingStart = vi.fn();
      let typingHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'typing') {
          typingHandler = handler;
        }
        return mockChannel;
      });

      subscribeToTyping(channelId, currentUserId, { onTypingStart });

      // Simulate typing event from another user
      typingHandler({
        payload: {
          user_id: 'user-2',
          username: 'otheruser',
          typing_at: Date.now(),
        },
      });

      expect(onTypingStart).toHaveBeenCalledWith('user-2', 'otheruser');
    });

    it('ignores own typing events', () => {
      const channelId = 'channel-1';
      const currentUserId = 'user-1';
      const onTypingStart = vi.fn();
      let typingHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'typing') {
          typingHandler = handler;
        }
        return mockChannel;
      });

      subscribeToTyping(channelId, currentUserId, { onTypingStart });

      // Simulate typing event from self
      typingHandler({
        payload: {
          user_id: currentUserId,
          username: 'testuser',
          typing_at: Date.now(),
        },
      });

      expect(onTypingStart).not.toHaveBeenCalled();
    });

    it('automatically removes typing indicator after 5 seconds', async () => {
      vi.useFakeTimers();

      const channelId = 'channel-1';
      const currentUserId = 'user-1';
      const onTypingStart = vi.fn();
      const onTypingStop = vi.fn();
      let typingHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'typing') {
          typingHandler = handler;
        }
        return mockChannel;
      });

      subscribeToTyping(channelId, currentUserId, {
        onTypingStart,
        onTypingStop,
      });

      // Simulate typing event
      typingHandler({
        payload: {
          user_id: 'user-2',
          username: 'otheruser',
          typing_at: Date.now(),
        },
      });

      expect(onTypingStart).toHaveBeenCalledWith('user-2', 'otheruser');

      // Advance time by 5 seconds
      vi.advanceTimersByTime(5000);

      expect(onTypingStop).toHaveBeenCalledWith('user-2');

      vi.useRealTimers();
    });
  });

  describe('getActiveChannels', () => {
    it('returns empty array when no channels subscribed', () => {
      const activeChannels = getActiveChannels();
      expect(activeChannels).toEqual([]);
    });

    it('returns array of active channel IDs', () => {
      subscribeToChannel('channel-1', {});
      subscribeToChannel('channel-2', {});

      const activeChannels = getActiveChannels();
      expect(activeChannels).toContain('channel-1');
      expect(activeChannels).toContain('channel-2');
      expect(activeChannels).toHaveLength(2);
    });
  });

  describe('unsubscribeAll', () => {
    it('unsubscribes from all active channels', () => {
      subscribeToChannel('channel-1', {});
      subscribeToChannel('channel-2', {});

      unsubscribeAll();

      expect(supabase.removeChannel).toHaveBeenCalledTimes(2);
      expect(getActiveChannels()).toEqual([]);
    });

    it('clears all typing timers', () => {
      vi.useFakeTimers();

      const channelId = 'channel-1';
      const currentUserId = 'user-1';
      const onTypingStop = vi.fn();
      let typingHandler: any;

      mockOn.mockImplementation((_type: string, config: any, handler: any) => {
        if (config.event === 'typing') {
          typingHandler = handler;
        }
        return mockChannel;
      });

      subscribeToTyping(channelId, currentUserId, { onTypingStop });

      // Simulate typing event
      typingHandler({
        payload: {
          user_id: 'user-2',
          username: 'otheruser',
          typing_at: Date.now(),
        },
      });

      // Unsubscribe all before timer fires
      unsubscribeAll();

      // Advance time
      vi.advanceTimersByTime(5000);

      // Handler should not be called since timer was cleared
      expect(onTypingStop).not.toHaveBeenCalled();

      vi.useRealTimers();
    });
  });

  describe('getConnectionStatus', () => {
    it('returns connection status', () => {
      const status = getConnectionStatus();
      expect(status).toBe('connected');
    });

    it('returns unknown when connection state unavailable', () => {
      (supabase as any).realtime = null;
      const status = getConnectionStatus();
      expect(status).toBe('unknown');
    });
  });
});
