import { supabase } from '../lib/supabase';
import type { Message } from '@shared/types/models';
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js';
import { TYPING_THROTTLE_MS, TYPING_EXPIRE_MS } from '@shared/constants/limits';

/**
 * Realtime Service
 * 
 * Manages WebSocket connections for real-time updates including:
 * - Message INSERT, UPDATE, DELETE events
 * - User presence tracking
 * - Typing indicators
 * - Connection lifecycle management
 * 
 * Requirements: 6.1, 6.2, 6.3, 6.4, 6.7, 6.8, 6.9, 8.5, 9.1, 9.2
 */

export interface MessageHandlers {
  onInsert?: (message: Message) => void;
  onUpdate?: (message: Message) => void;
  onDelete?: (messageId: string) => void;
}

export interface PresenceState {
  user_id: string;
  username: string;
  status: 'online' | 'idle' | 'dnd' | 'offline';
  online_at: string;
}

export interface PresenceHandlers {
  onJoin?: (userId: string, state: PresenceState) => void;
  onLeave?: (userId: string) => void;
  onSync?: (presences: Record<string, PresenceState[]>) => void;
}

export interface TypingState {
  user_id: string;
  username: string;
  typing_at: number;
}

export interface TypingHandlers {
  onTypingStart?: (userId: string, username: string) => void;
  onTypingStop?: (userId: string) => void;
}

/**
 * Active channel subscriptions
 * Maps channel IDs to their Supabase realtime channels
 */
const activeChannels = new Map<string, RealtimeChannel>();

/**
 * Channel reference counts
 * Prevents unsubscribing when multiple components subscribe to same channel
 */
const channelRefCounts = new Map<string, number>();

/**
 * Typing indicator timers
 * Maps user IDs to their typing timeout timers
 */
const typingTimers = new Map<string, NodeJS.Timeout>();

/**
 * Typing indicator throttle timers
 * Maps channel IDs to their throttle timers
 */
const typingThrottles = new Map<string, number>();

/**
 * Cache of subscribed typing broadcast channels.
 * Ensures send() is called on an already-subscribed channel so
 * Supabase doesn't fall back to the REST API.
 */
const subscribedTypingChannels = new Map<string, ReturnType<typeof supabase.channel>>();

/**
 * Subscribe to real-time message events for a channel
 * 
 * Listens for INSERT, UPDATE, and DELETE events on the messages table
 * filtered by channel_id. Automatically handles deduplication and
 * connection lifecycle.
 * 
 * @param channelId - The channel ID to subscribe to
 * @param handlers - Callback functions for message events
 * @returns Unsubscribe function to clean up the subscription
 */
export function subscribeToChannel(
  channelId: string,
  handlers: MessageHandlers
): () => void {
  // Check if already subscribed
  if (activeChannels.has(channelId)) {
    // Increment reference count
    const refCount = channelRefCounts.get(channelId) || 0;
    channelRefCounts.set(channelId, refCount + 1);
    console.log(`Already subscribed to channel ${channelId}, refCount is now ${refCount + 1}`);
    return () => unsubscribeFromChannel(channelId);
  }

  // Set initial reference count
  channelRefCounts.set(channelId, 1);

  // Create a unique channel name for this subscription
  const channelName = `messages:${channelId}`;

  // Create the realtime channel
  const channel = supabase.channel(channelName);

  // Subscribe to INSERT events
  if (handlers.onInsert) {
    channel.on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `channel_id=eq.${channelId}`,
      },
      async (payload: RealtimePostgresChangesPayload<Message>) => {
        const newMessage = payload.new as Message;

        // Fetch the author profile to include in the message
        const { data: author } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', newMessage.author_id)
          .single();

        if (author) {
          newMessage.author = author;
        }

        handlers.onInsert?.(newMessage);
      }
    );
  }

  // Subscribe to UPDATE events
  if (handlers.onUpdate) {
    channel.on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'messages',
        filter: `channel_id=eq.${channelId}`,
      },
      async (payload: RealtimePostgresChangesPayload<Message>) => {
        const updatedMessage = payload.new as Message;

        // Fetch the author profile to include in the message
        const { data: author } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', updatedMessage.author_id)
          .single();

        if (author) {
          updatedMessage.author = author;
        }

        handlers.onUpdate?.(updatedMessage);
      }
    );
  }

  // Subscribe to DELETE events
  if (handlers.onDelete) {
    channel.on(
      'postgres_changes',
      {
        event: 'DELETE',
        schema: 'public',
        table: 'messages',
        filter: `channel_id=eq.${channelId}`,
      },
      (payload: RealtimePostgresChangesPayload<Message>) => {
        const deletedMessage = payload.old as Message;
        handlers.onDelete?.(deletedMessage.id);
      }
    );
  }

  // Subscribe to the channel
  channel.subscribe((status: string) => {
    if (status === 'SUBSCRIBED') {
      console.log(`Subscribed to channel ${channelId}`);
    } else if (status === 'CHANNEL_ERROR') {
      console.error(`Error subscribing to channel ${channelId}`);
    } else if (status === 'TIMED_OUT') {
      console.error(`Subscription to channel ${channelId} timed out`);
    }
  });

  // Store the channel reference
  activeChannels.set(channelId, channel);

  // Return unsubscribe function
  return () => unsubscribeFromChannel(channelId);
}

/**
 * Unsubscribe from a channel's real-time events
 * 
 * Cleans up the WebSocket subscription and removes the channel
 * from active subscriptions to prevent memory leaks.
 * 
 * @param channelId - The channel ID to unsubscribe from
 */
export async function unsubscribeFromChannel(channelId: string): Promise<void> {
  const channel = activeChannels.get(channelId);

  if (!channel) {
    console.warn(`No active subscription for channel ${channelId}`);
    return;
  }

  // Decrement reference count
  const refCount = (channelRefCounts.get(channelId) || 1) - 1;
  if (refCount > 0) {
    channelRefCounts.set(channelId, refCount);
    console.log(`Decremented refCount for channel ${channelId} to ${refCount}`);
    return;
  }

  // Ref count is 0, actually unsubscribe
  try {
    // Unsubscribe from the channel and await removal
    await supabase.removeChannel(channel);
    
    // Remove from active channels and ref counts
    activeChannels.delete(channelId);
    channelRefCounts.delete(channelId);
    console.log(`Unsubscribed from channel ${channelId}`);
  } catch (error) {
    console.error(`Error unsubscribing from channel ${channelId}:`, error);
  }
}

/**
 * Track user presence in a channel
 * 
 * Broadcasts the user's online status and listens for other users'
 * presence changes. Automatically handles presence sync and cleanup.
 * 
 * @param channelId - The channel ID to track presence in
 * @param userId - The current user's ID
 * @param username - The current user's username
 * @param status - The current user's status
 * @param handlers - Callback functions for presence events
 * @returns Unsubscribe function to stop tracking presence
 */
export function trackPresence(
  channelId: string,
  userId: string,
  username: string,
  status: 'online' | 'idle' | 'dnd' | 'offline',
  handlers: PresenceHandlers
): () => void {
  const channelName = `presence:${channelId}`;
  const channel = supabase.channel(channelName);

  // Track presence state
  const presenceState: PresenceState = {
    user_id: userId,
    username,
    status,
    online_at: new Date().toISOString(),
  };

  // Subscribe to presence events
  channel
    .on('presence', { event: 'sync' }, () => {
      const state = channel.presenceState();
      handlers.onSync?.(state as unknown as Record<string, PresenceState[]>);
    })
    .on('presence', { event: 'join' }, ({ key: _key, newPresences }: { key: string; newPresences: PresenceState[] }) => {
      const presence = newPresences[0] as PresenceState;
      handlers.onJoin?.(presence.user_id, presence);
    })
    .on('presence', { event: 'leave' }, ({ key: _key, leftPresences }: { key: string; leftPresences: PresenceState[] }) => {
      const presence = leftPresences[0] as PresenceState;
      handlers.onLeave?.(presence.user_id);
    })
    .subscribe(async (status: string) => {
      if (status === 'SUBSCRIBED') {
        // Track our presence
        await channel.track(presenceState);
        console.log(`Tracking presence in channel ${channelId}`);
      }
    });

  // Return unsubscribe function
  return () => {
    channel.untrack();
    supabase.removeChannel(channel);
    console.log(`Stopped tracking presence in channel ${channelId}`);
  };
}

/**
 * Send a typing indicator event
 * 
 * Broadcasts that the user is typing in a channel. Automatically
 * throttles events to maximum 1 per second to prevent spam.
 * 
 * @param channelId - The channel ID where the user is typing
 * @param userId - The user's ID
 * @param username - The user's username
 */
export function sendTypingIndicator(
  channelId: string,
  userId: string,
  username: string
): void {
  const now = Date.now();
  const lastSent = typingThrottles.get(channelId) || 0;

  // Throttle to max 1 event per second
  if (now - lastSent < TYPING_THROTTLE_MS) {
    return;
  }

  const channelName = `typing:${channelId}`;
  let channel = subscribedTypingChannels.get(channelName);
  if (!channel) {
    channel = supabase.channel(channelName);
    channel.subscribe();
    subscribedTypingChannels.set(channelName, channel);
  }

  const typingState: TypingState = {
    user_id: userId,
    username,
    typing_at: now,
  };

  // Broadcast typing event on subscribed channel
  channel.send({
    type: 'broadcast',
    event: 'typing',
    payload: typingState,
  });

  // Update throttle timestamp
  typingThrottles.set(channelId, now);
}

/**
 * Stop sending typing indicator
 * 
 * Broadcasts that the user has stopped typing in a channel.
 * 
 * @param channelId - The channel ID where the user stopped typing
 * @param userId - The user's ID
 */
export function stopTypingIndicator(
  channelId: string,
  userId: string
): void {
  const channelName = `typing:${channelId}`;
  const channel = subscribedTypingChannels.get(channelName);
  if (!channel) return; // no subscribed channel, nothing to send

  // Broadcast stop typing event on subscribed channel
  channel.send({
    type: 'broadcast',
    event: 'stop_typing',
    payload: { user_id: userId },
  });

  // Clear throttle
  typingThrottles.delete(channelId);
}

/**
 * Subscribe to typing indicators in a channel
 * 
 * Listens for typing events from other users and automatically
 * removes typing indicators after 5 seconds of inactivity.
 * 
 * @param channelId - The channel ID to listen for typing in
 * @param currentUserId - The current user's ID (to filter out own events)
 * @param handlers - Callback functions for typing events
 * @returns Unsubscribe function to stop listening
 */
export function subscribeToTyping(
  channelId: string,
  currentUserId: string,
  handlers: TypingHandlers
): () => void {
  const channelName = `typing:${channelId}`;
  const channel = supabase.channel(channelName);

  // Subscribe to typing events
  channel
    .on('broadcast', { event: 'typing' }, ({ payload }: { payload: TypingState }) => {
      const typingState = payload as TypingState;

      // Ignore own typing events
      if (typingState.user_id === currentUserId) {
        return;
      }

      handlers.onTypingStart?.(typingState.user_id, typingState.username);

      // Clear existing timer for this user
      const timerKey = `${channelId}:${typingState.user_id}`;
      const existingTimer = typingTimers.get(timerKey);
      if (existingTimer) {
        clearTimeout(existingTimer);
      }

      // Set timer to remove typing indicator after timeout
      const timer = setTimeout(() => {
        handlers.onTypingStop?.(typingState.user_id);
        typingTimers.delete(timerKey);
      }, TYPING_EXPIRE_MS);

      typingTimers.set(timerKey, timer);
    })
    .on('broadcast', { event: 'stop_typing' }, ({ payload }: { payload: { user_id: string } }) => {
      const { user_id } = payload as { user_id: string };

      // Ignore own events
      if (user_id === currentUserId) {
        return;
      }

      // Clear timer and call handler
      const timerKey = `${channelId}:${user_id}`;
      const timer = typingTimers.get(timerKey);
        if (timer) {
          clearTimeout(timer);
        }
        typingTimers.delete(timerKey);
        handlers.onTypingStop?.(user_id);
    })
    .subscribe((status: string) => {
      if (status === 'SUBSCRIBED') {
        console.log(`Subscribed to typing indicators in channel ${channelId}`);
      }
    });

  // Return unsubscribe function
  return () => {
    // Clear all timers for this channel
    const prefix = `${channelId}:`;
    for (const [key, timer] of typingTimers.entries()) {
      if (key.startsWith(prefix)) {
        clearTimeout(timer);
        typingTimers.delete(key);
      }
    }

    supabase.removeChannel(channel);
    console.log(`Unsubscribed from typing indicators in channel ${channelId}`);
  };
}

/**
 * Get all active channel subscriptions
 * 
 * Useful for debugging and monitoring active connections.
 * 
 * @returns Array of active channel IDs
 */
export function getActiveChannels(): string[] {
  return Array.from(activeChannels.keys());
}

/**
 * Unsubscribe from all active channels
 * 
 * Cleans up all WebSocket subscriptions. Should be called
 * when the user logs out or the app unmounts.
 */
export function unsubscribeAll(): void {
  activeChannels.forEach((channel, channelId) => {
    supabase.removeChannel(channel);
    console.log(`Unsubscribed from channel ${channelId}`);
  });

  activeChannels.clear();
  channelRefCounts.clear();

  // Clear all typing timers and cached typing channels
  typingTimers.forEach((timer) => clearTimeout(timer));
  typingTimers.clear();
  typingThrottles.clear();
  subscribedTypingChannels.forEach((ch) => supabase.removeChannel(ch));
  subscribedTypingChannels.clear();

  console.log('Unsubscribed from all channels');
}

/**
 * Check connection status
 * 
 * @returns Connection status of the Supabase realtime client
 */
export function getConnectionStatus(): string {
  // Access the realtime client's connection state
  const realtimeClient = (supabase as any).realtime;
  return realtimeClient?.connection?.connectionState || 'unknown';
}
