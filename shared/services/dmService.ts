import { supabase } from '../lib/supabase';
import { sanitizeHtml } from '@/lib/markdown';
import type { DirectMessage, User } from '@shared/types/models';

/**
 * Direct Message Service
 * 
 * Handles all direct message-related API operations including fetching
 * DM conversations, messages, and sending DMs with automatic conversation creation.
 * 
 * Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7
 */

export interface DMConversation {
  userId: string;
  user: User;
  lastMessage: DirectMessage | null;
  unreadCount: number;
}

export interface GetDMMessagesOptions {
  otherUserId: string;
  limit?: number;
  before?: string; // Message ID to fetch messages before (for pagination)
}

export interface SendDMInput {
  recipientId: string;
  content: string;
}

const MAX_MESSAGE_LENGTH = 2000;
const DEFAULT_PAGE_SIZE = 50;

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
  // Remove any HTML/script tags and event handlers
  return sanitizeHtml(content);
}

/**
 * Get all DM conversations for the authenticated user
 * 
 * Returns a list of users the current user has DM conversations with,
 * along with the last message and unread count for each conversation.
 * Ordered by most recent activity.
 * 
 * @returns Array of DM conversations ordered by most recent activity
 * @throws Error if user is not authenticated
 */
export async function getDMConversations(): Promise<DMConversation[]> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Get all DMs where user is sender or recipient
  const { data: messages, error } = await supabase
    .from('direct_messages')
    .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)')
    .or(`sender_id.eq.${user.id},recipient_id.eq.${user.id}`)
    .order('created_at', { ascending: false });

  if (error) {
    throw new Error(`Failed to fetch DM conversations: ${error.message}`);
  }

  if (!messages || messages.length === 0) {
    return [];
  }

  // Group messages by conversation partner
  const conversationMap = new Map<string, {
    user: User;
    lastMessage: DirectMessage;
    messages: DirectMessage[];
  }>();

  for (const message of messages) {
    // Determine the other user in the conversation
    const otherUserId = message.sender_id === user.id
      ? message.recipient_id
      : message.sender_id;

    const otherUser = message.sender_id === user.id
      ? message.recipient
      : message.sender;

    if (!conversationMap.has(otherUserId)) {
      conversationMap.set(otherUserId, {
        user: otherUser,
        lastMessage: message,
        messages: [message],
      });
    } else {
      conversationMap.get(otherUserId)!.messages.push(message);
    }
  }

  // Convert to array and calculate unread counts
  const conversations: DMConversation[] = [];

  for (const [userId, data] of conversationMap.entries()) {
    conversations.push({
      userId,
      user: data.user,
      lastMessage: data.lastMessage,
      unreadCount: 0, // Simplified for now - would need read tracking
    });
  }

  // Sort by last message timestamp (most recent first)
  conversations.sort((a, b) => {
    const aTime = a.lastMessage ? new Date(a.lastMessage.created_at).getTime() : 0;
    const bTime = b.lastMessage ? new Date(b.lastMessage.created_at).getTime() : 0;
    return bTime - aTime;
  });

  return conversations;
}

/**
 * Get direct messages between the authenticated user and another user
 * 
 * Fetches messages in reverse chronological order (newest first from DB),
 * but returns them in chronological order (oldest first) for display.
 * Supports pagination.
 * 
 * @param options - Query options including otherUserId, limit, and pagination cursor
 * @returns Array of direct messages in chronological order
 * @throws Error if user is not authenticated
 */
export async function getDMMessages(options: GetDMMessagesOptions): Promise<DirectMessage[]> {
  const { otherUserId, limit = DEFAULT_PAGE_SIZE, before } = options;

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Verify the other user exists
  const { data: otherUser, error: userError } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', otherUserId)
    .single();

  if (userError || !otherUser) {
    throw new Error('User not found');
  }

  // Build query for messages between the two users
  let query = supabase
    .from('direct_messages')
    .select('*, sender:profiles!sender_id(*)')
    .or(`and(sender_id.eq.${user.id},recipient_id.eq.${otherUserId}),and(sender_id.eq.${otherUserId},recipient_id.eq.${user.id})`)
    .order('created_at', { ascending: false })
    .limit(limit);

  // Add pagination cursor if provided
  if (before) {
    // Get the timestamp of the 'before' message
    const { data: beforeMessage } = await supabase
      .from('direct_messages')
      .select('created_at')
      .eq('id', before)
      .single();

    if (beforeMessage) {
      query = query.lt('created_at', beforeMessage.created_at);
    }
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch DM messages: ${error.message}`);
  }

  // Reverse to get chronological order (oldest to newest)
  return (data || []).reverse();
}

/**
 * Send a direct message to another user
 * 
 * Automatically creates a DM conversation if one doesn't exist.
 * Validates and sanitizes content before sending.
 * 
 * @param input - DM data including recipientId and content
 * @returns The created direct message
 * @throws Error if validation fails or recipient doesn't exist
 */
export async function sendDM(input: SendDMInput): Promise<DirectMessage> {
  const { recipientId, content } = input;

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate message content
  validateMessageContent(content);

  // Sanitize content to prevent XSS
  const sanitizedContent = sanitizeMessageContent(content.trim());

  // Verify recipient exists
  const { data: recipient, error: recipientError } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', recipientId)
    .single();

  if (recipientError || !recipient) {
    throw new Error('Recipient not found');
  }

  // Prevent sending DM to self
  if (recipientId === user.id) {
    throw new Error('Cannot send direct message to yourself');
  }

  // Create the direct message
  const { data: message, error } = await supabase
    .from('direct_messages')
    .insert({
      sender_id: user.id,
      recipient_id: recipientId,
      content: sanitizedContent,
    })
    .select('*, sender:profiles!sender_id(*)')
    .single();

  if (error) {
    throw new Error(`Failed to send direct message: ${error.message}`);
  }

  if (!message) {
    throw new Error('Direct message creation failed: No data returned');
  }

  return message;
}
