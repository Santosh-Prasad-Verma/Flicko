import { supabase } from '../lib/supabase';
import { notifyMessageCreate } from './botService';
import type { Message } from '@shared/types/models';

/**
 * Message Service
 * 
 * Handles all message-related API operations including CRUD operations,
 * pagination, validation, and XSS sanitization for messages in the Flicko application.
 * 
 * CRITICAL: All WRITE operations go through the backend msg-service API.
 * READ operations use Supabase directly for performance (cached, low latency).
 * This eliminates the dual-write-path bug that caused duplicate messages.
 * 
 * Requirements: 4.1, 4.2, 5.1, 5.2, 5.5, 5.6, 5.9, 25.1, 25.2, 25.3, 25.5, 25.6, 12.1, 12.2, 12.3, 12.4, 12.5
 */

export interface GetMessagesOptions {
  channelId: string;
  limit?: number;
  before?: string; // Message ID to fetch messages before (for pagination)
}

export interface SendMessageInput {
  channelId: string;
  content: string;
  replyToId?: string | null;
  replyMention?: boolean;
  attachments?: string[];
  isSilent?: boolean;
  isTTS?: boolean;
  nonce?: string;
}

export interface EditMessageInput {
  content: string;
}

import {
  MAX_MESSAGE_LENGTH,
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  DEFAULT_TIMEOUT_MS,
  CIRCUIT_BREAKER_THRESHOLD,
  CIRCUIT_BREAKER_RESET_MS,
  DEFAULT_MAX_RETRIES,
  RETRY_BASE_DELAY_MS,
} from '@shared/constants/limits';

// Import API URL from Config
const getApiUrl = () => {
  try {
    // Dynamic import to avoid circular dependency
    const { GO_BACKEND_URL } = require('@/constants/Config');
    return GO_BACKEND_URL;
  } catch {
    // Fallback for environments where Config isn't available
    return process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:8080';
  }
};

/**
 * Circuit breaker for API calls (HIGH-009).
 * Prevents cascading failures when backend is down.
 */
class CircuitBreaker {
  private failures = 0;
  private lastFailureTime = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';

  constructor(
    private threshold = CIRCUIT_BREAKER_THRESHOLD,
    private resetTimeout = CIRCUIT_BREAKER_RESET_MS
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'half-open';
      } else {
        throw new Error('Service temporarily unavailable (circuit breaker open)');
      }
    }

    try {
      const result = await operation();
      if (this.state === 'half-open') {
        this.reset();
      }
      return result;
    } catch (error) {
      this.recordFailure();
      throw error;
    }
  }

  private recordFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    if (this.failures >= this.threshold) {
      this.state = 'open';
      console.warn('[CircuitBreaker] opened due to repeated failures');
    }
  }

  private reset() {
    this.failures = 0;
    this.state = 'closed';
    console.info('[CircuitBreaker] reset');
  }
}

const apiCircuitBreaker = new CircuitBreaker();

/**
 * Retry wrapper for transient network failures (HIGH-007).
 */
async function withRetry<T>(
  operation: () => Promise<T>,
  maxRetries = 3,
  delayMs = 1000
): Promise<T> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error: any) {
      if (attempt === maxRetries) throw error;

      // Only retry on network errors, not validation errors
      if (
        error.message?.includes('Failed to fetch') ||
        error.message?.includes('Network request failed') ||
        error.message?.includes('AbortError') ||
        error.name === 'AbortError'
      ) {
        await new Promise((resolve) => setTimeout(resolve, delayMs * attempt));
        continue;
      }

      throw error; // Don't retry validation/auth errors
    }
  }
  throw new Error('Retry logic exhausted');
}

/**
 * Execute a query with an AbortController timeout (HIGH-003).
 */
function withTimeout(timeoutMs = DEFAULT_TIMEOUT_MS): { signal: AbortSignal; clear: () => void } {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  return {
    signal: controller.signal,
    clear: () => clearTimeout(timeoutId),
  };
}

/**
 * Get auth headers for backend API calls
 */
async function getAuthHeaders(): Promise<HeadersInit> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) {
    throw new Error('User not authenticated');
  }
  return {
    'Authorization': `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
  };
}

/**
 * Validate message content
 * 
 * @param content - The message content to validate
 * @throws Error if validation fails
 */
function validateMessageContent(content: string): void {
  if (!content || content.trim().length === 0) {
    throw new Error('Message content cannot be empty');
  }

  if (content.length > MAX_MESSAGE_LENGTH) {
    throw new Error(`Message content must be ${MAX_MESSAGE_LENGTH} characters or less`);
  }
}

/**
 * Sanitize message content to prevent XSS attacks
 * 
 * @param content - The message content to sanitize
 * @returns Sanitized content
 */
function sanitizeMessageContent(content: string): string {
  // Strip HTML tags and script content to prevent XSS
  return content
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, '')
    .replace(/on\w+="[^"]*"/gi, '');
}

/**
 * Get messages for a channel with pagination support
 * 
 * Fetches messages in reverse chronological order (newest first from DB),
 * but returns them in chronological order (oldest first) for display.
 * 
 * @param options - Query options including channelId, limit, and pagination cursor
 * @returns Array of messages in chronological order
 * @throws Error if user is not authenticated or doesn't have access
 */
export async function getMessages(options: GetMessagesOptions): Promise<Message[]> {
  let { channelId, limit = DEFAULT_PAGE_SIZE, before } = options;

  // HIGH-017: Enforce maximum page size
  if (limit > MAX_PAGE_SIZE) {
    console.warn(`[MessageService] Requested limit ${limit} exceeds max ${MAX_PAGE_SIZE}, capping`);
    limit = MAX_PAGE_SIZE;
  }
  if (limit < 1) {
    limit = DEFAULT_PAGE_SIZE;
  }

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the channel to get server_id
  const { data: channel, error: channelError } = await supabase
    .from('channels')
    .select('server_id')
    .eq('id', channelId)
    .single();

  if (channelError) {
    throw new Error(`Failed to fetch channel: ${channelError.message}`);
  }

  if (!channel) {
    throw new Error('Channel not found');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', channel.server_id)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // Build query for messages (HIGH-003: with timeout)
  const timeout = withTimeout();
  let data: any[] | null = null;
  try {
    let query = supabase
      .from('messages')
      .select('*, author:profiles(*)')
      .eq('channel_id', channelId)
      .order('created_at', { ascending: false })
      .limit(limit)
      .abortSignal(timeout.signal);

  // Add pagination cursor if provided
  if (before) {
    // Get the timestamp of the 'before' message
    const { data: beforeMessage } = await supabase
      .from('messages')
      .select('created_at')
      .eq('id', before)
      .single();

    if (beforeMessage) {
      query = query.lt('created_at', beforeMessage.created_at);
    }
  }

  const result = await query;
  data = result.data;

  timeout.clear();

  if (result.error) {
    throw new Error(`Failed to fetch messages: ${result.error.message}`);
  }
  } catch (err: any) {
    timeout.clear();
    if (err.name === 'AbortError') {
      throw new Error('Request timeout: Server took too long to respond');
    }
    throw err;
  }

  // Reverse to get chronological order (oldest to newest)
  const sortedMessages = (data || []).reverse();

  return sortedMessages;
}

/**
 * Send a new message to a channel
 * 
 * CRITICAL FIX: This now uses the backend msg-service API for writes.
 * Previously this wrote directly to Supabase which caused duplicate messages
 * when combined with the WebSocket write path.
 * 
 * @param input - Message data including channelId and content
 * @returns The created message
 * @throws Error if validation fails or user doesn't have access
 */
export async function sendMessage(input: SendMessageInput): Promise<Message> {
  const { channelId, content, replyToId = null, replyMention = true, attachments = [], isSilent = false, isTTS = false, nonce } = input;

  // Validate message content
  validateMessageContent(content);
  // Sanitize content to prevent XSS
  const sanitizedContent = sanitizeMessageContent(content.trim());

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the channel to get server_id
  const { data: channel, error: channelError } = await supabase
    .from('channels')
    .select('server_id')
    .eq('id', channelId)
    .single();

  if (channelError) {
    throw new Error(`Failed to fetch channel: ${channelError.message}`);
  }

  if (!channel) {
    throw new Error('Channel not found');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', channel.server_id)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // If replying, verify the reply-to message exists in the same channel
  if (replyToId) {
    const { data: replyToMessage } = await supabase
      .from('messages')
      .select('channel_id')
      .eq('id', replyToId)
      .single();

    if (!replyToMessage || replyToMessage.channel_id !== channelId) {
      throw new Error('Invalid reply: Referenced message not found in this channel');
    }
  }

  // CRITICAL FIX: Use backend msg-service API for writes (single write path)
  const apiUrl = getApiUrl();
  const nonceValue = nonce || crypto.randomUUID();

  const headers = await getAuthHeaders();

  const message = await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages`, {
          method: 'POST',
          headers: {
            ...headers,
            'X-Idempotency-Key': nonceValue,
          },
          body: JSON.stringify({
            channel_id: channelId,
            content: sanitizedContent,
            reply_to_id: replyToId,
            reply_mention: replyMention,
            attachments: attachments,
            is_silent: isSilent,
            is_tts: isTTS,
            nonce: nonceValue,
          }),
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to send message: ${res.status}`);
        }

        const result = await res.json();
        return result.data || result;
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );

  if (!message) {
    throw new Error('Message creation failed: No data returned');
  }

  // Notify backend bots (automod, leveling) — this is fire-and-forget
  try {
    await notifyMessageCreate({
      messageId: message.id,
      channelId: channelId,
      serverId: channel.server_id,
      content: sanitizedContent,
    });
  } catch (err) {
    // Bot notification is non-critical, log but don't fail
    console.warn('[MessageService] Bot notification failed:', err);
  }

  return message;
}

/**
 * Edit an existing message
 * 
 * CRITICAL FIX: This now uses the backend msg-service API for writes.
 * Previously this wrote directly to Supabase.
 * 
 * @param messageId - The ID of the message to edit
 * @param input - The new message content
 * @returns The updated message
 * @throws Error if validation fails or user is not the author
 */
export async function editMessage(
  messageId: string,
  input: EditMessageInput
): Promise<Message> {
  const { content } = input;

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate message content
  validateMessageContent(content);

  // Sanitize content to prevent XSS
  const sanitizedContent = sanitizeMessageContent(content.trim());

  // CRITICAL FIX: Use backend msg-service API for writes
  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  const updatedMessage = await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}`, {
          method: 'PATCH',
          headers,
          body: JSON.stringify({
            content: sanitizedContent,
          }),
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          if (res.status === 403 || res.status === 404) {
            throw new Error('Message not found or access denied: Only the message author can edit the message');
          }
          throw new Error(errorData.error || errorData.message || `Failed to edit message: ${res.status}`);
        }

        const result = await res.json();
        return result.data || result;
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );

  if (!updatedMessage) {
    throw new Error('Message not found or access denied');
  }

  return updatedMessage;
}

/**
 * Delete a message
 * 
 * CRITICAL FIX: This now uses the backend msg-service API for writes.
 * Previously this wrote directly to Supabase.
 * 
 * @param messageId - The ID of the message to delete
 * @throws Error if user is not the author or deletion fails
 */
export async function deleteMessage(messageId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // CRITICAL FIX: Use backend msg-service API for writes
  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}`, {
          method: 'DELETE',
          headers,
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          if (res.status === 403 || res.status === 404) {
            throw new Error('Message not found or access denied: Only the message author can delete the message');
          }
          throw new Error(errorData.error || errorData.message || `Failed to delete message: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Add a reaction to a message
 * 
 * @param messageId - The ID of the message to react to
 * @param emoji - The emoji to react with
 * @throws Error if user is not authenticated or operation fails
 */
export async function addReaction(messageId: string, emoji: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  if (!emoji || emoji.trim().length === 0) {
    throw new Error('Emoji cannot be empty');
  }

  // Use backend API for reactions
  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}/reactions/${encodeURIComponent(emoji.trim())}`, {
          method: 'PUT',
          headers,
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok && res.status !== 409) { // 409 = already reacted (ok to ignore)
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to add reaction: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Remove a reaction from a message
 * 
 * @param messageId - The ID of the message to remove reaction from
 * @param emoji - The emoji to remove
 * @throws Error if user is not authenticated or operation fails
 */
export async function removeReaction(messageId: string, emoji: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  if (!emoji || emoji.trim().length === 0) {
    throw new Error('Emoji cannot be empty');
  }

  // Use backend API for reactions
  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}/reactions/${encodeURIComponent(emoji.trim())}`, {
          method: 'DELETE',
          headers,
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok && res.status !== 404) { // 404 = not reacted (ok to ignore)
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to remove reaction: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Get reactions for a message
 * 
 * Aggregates reactions by emoji and includes user IDs.
 * 
 * @param messageId - The ID of the message
 * @returns Array of reactions with counts and user lists
 */
export async function getReactions(messageId: string): Promise<import('@shared/types/models').Reaction[]> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch all reactions for the message
  const { data: reactions, error } = await supabase
    .from('reactions')
    .select('emoji, user_id')
    .eq('message_id', messageId);

  if (error) {
    throw new Error(`Failed to fetch reactions: ${error.message}`);
  }

  if (!reactions || reactions.length === 0) {
    return [];
  }

  // Group reactions by emoji
  const reactionMap = new Map<string, { users: string[]; me: boolean }>();

  for (const reaction of reactions) {
    const existing = reactionMap.get(reaction.emoji);
    if (existing) {
      existing.users.push(reaction.user_id);
      if (reaction.user_id === user.id) {
        existing.me = true;
      }
    } else {
      reactionMap.set(reaction.emoji, {
        users: [reaction.user_id],
        me: reaction.user_id === user.id,
      });
    }
  }

  // Convert to array format
  return Array.from(reactionMap.entries()).map(([emoji, data]) => ({
    emoji,
    count: data.users.length,
    users: data.users,
    me: data.me,
  }));
}

/**
 * Bulk delete messages (moderation feature)
 * 
 * @param channelId - The channel ID
 * @param messageIds - Array of message IDs to delete (max 100)
 * @throws Error if user is not authenticated or operation fails
 */
export async function bulkDeleteMessages(channelId: string, messageIds: string[]): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  if (messageIds.length === 0) {
    return;
  }

  if (messageIds.length > 100) {
    throw new Error('Cannot delete more than 100 messages at once');
  }

  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/channels/${channelId}/messages/bulk-delete`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ message_ids: messageIds }),
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to bulk delete messages: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Pin a message
 * 
 * @param messageId - The ID of the message to pin
 * @throws Error if user is not authenticated or operation fails
 */
export async function pinMessage(messageId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}/pin`, {
          method: 'PUT',
          headers,
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to pin message: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Unpin a message
 * 
 * @param messageId - The ID of the message to unpin
 * @throws Error if user is not authenticated or operation fails
 */
export async function unpinMessage(messageId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}/pin`, {
          method: 'DELETE',
          headers,
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to unpin message: ${res.status}`);
        }
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );
}

/**
 * Get pinned messages for a channel
 * 
 * @param channelId - The channel ID
 * @returns Array of pinned messages
 */
export async function getPinnedMessages(channelId: string): Promise<Message[]> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  const timeout = withTimeout();
  try {
    const res = await fetch(`${apiUrl}/api/v1/channels/${channelId}/pins`, {
      headers,
      signal: timeout.signal,
    });

    timeout.clear();

    if (!res.ok) {
      const errorData = await res.json().catch(() => ({}));
      throw new Error(errorData.error || errorData.message || `Failed to get pinned messages: ${res.status}`);
    }

    const result = await res.json();
    return result.data || result || [];
  } catch (err: any) {
    timeout.clear();
    if (err.name === 'AbortError') {
      throw new Error('Request timeout: Server took too long to respond');
    }
    throw err;
  }
}

/**
 * Forward a message to another channel
 * 
 * @param messageId - The ID of the message to forward
 * @param targetChannelId - The channel to forward to
 * @returns The forwarded message
 */
export async function forwardMessage(messageId: string, targetChannelId: string): Promise<Message> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  const apiUrl = getApiUrl();
  const headers = await getAuthHeaders();

  const message = await apiCircuitBreaker.execute(() =>
    withRetry(async () => {
      const timeout = withTimeout();
      try {
        const res = await fetch(`${apiUrl}/m/messages/${messageId}/forward`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ target_channel_id: targetChannelId }),
          signal: timeout.signal,
        });

        timeout.clear();

        if (!res.ok) {
          const errorData = await res.json().catch(() => ({}));
          throw new Error(errorData.error || errorData.message || `Failed to forward message: ${res.status}`);
        }

        const result = await res.json();
        return result.data || result;
      } catch (err: any) {
        timeout.clear();
        if (err.name === 'AbortError') {
          throw new Error('Request timeout: Server took too long to respond');
        }
        throw err;
      }
    })
  );

  return message;
}