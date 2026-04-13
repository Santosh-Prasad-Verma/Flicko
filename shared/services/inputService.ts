/**
 * Enhanced Message Input Utilities
 *
 * Typing indicator, attachment handling, reply preview, edit mode.
 * Requirements: Feature 33 (Input Enhancement Features)
 */
import { supabase } from '../lib/supabase';

// ─── Typing Indicator ──────────────────────────────────────────────────────────

let typingTimeout: NodeJS.Timeout | null = null;

/**
 * Send a typing indicator to a channel.
 * Automatically debounces — call on every keystroke.
 */
export async function sendTypingIndicator(channelId: string, userId: string) {
  if (typingTimeout) return; // already sent recently

  try {
    await supabase.from('typing_indicators').upsert(
      { channel_id: channelId, user_id: userId, started_at: new Date().toISOString() },
      { onConflict: 'channel_id,user_id' },
    );
  } catch {}

  typingTimeout = setTimeout(() => {
    typingTimeout = null;
  }, 8000); // re-send at most every 8s
}

/**
 * Subscribe to typing indicators in a channel.
 * Returns an unsubscribe function.
 */
export function subscribeTypingIndicators(
  channelId: string,
  currentUserId: string,
  onTyping: (users: { user_id: string; username?: string }[]) => void,
) {
  const channel = supabase
    .channel(`typing:${channelId}`)
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'typing_indicators',
      filter: `channel_id=eq.${channelId}`,
    }, (payload) => {
      // Refetch active typers
      fetchActiveTypers(channelId, currentUserId).then(onTyping);
    })
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

async function fetchActiveTypers(
  channelId: string,
  excludeUserId: string,
): Promise<{ user_id: string; username?: string }[]> {
  const cutoff = new Date(Date.now() - 10000).toISOString();
  const { data } = await supabase
    .from('typing_indicators')
    .select('user_id, profiles!user_id(username)')
    .eq('channel_id', channelId)
    .neq('user_id', excludeUserId)
    .gte('started_at', cutoff);
  return (data ?? []).map((d: any) => ({
    user_id: d.user_id,
    username: d.profiles?.username,
  }));
}

// ─── Reply / Edit context ──────────────────────────────────────────────────────

export interface ReplyContext {
  messageId: string;
  authorName: string;
  contentPreview: string;
}

export interface EditContext {
  messageId: string;
  originalContent: string;
}

// ─── Attachments ───────────────────────────────────────────────────────────────

export interface PendingAttachment {
  id: string;
  uri: string;
  name: string;
  mimeType: string;
  size: number;
}

export const MAX_ATTACHMENT_SIZE = 25 * 1024 * 1024; // 25 MB
export const MAX_ATTACHMENTS_PER_MESSAGE = 10;

export const ALLOWED_FILE_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'video/mp4',
  'video/webm',
  'audio/mpeg',
  'audio/ogg',
  'application/pdf',
  'text/plain',
];

/**
 * Validate an attachment before uploading.
 */
export function validateAttachment(
  attachment: Pick<PendingAttachment, 'size' | 'mimeType'>,
): { valid: boolean; error?: string } {
  if (attachment.size > MAX_ATTACHMENT_SIZE) {
    return { valid: false, error: `File too large (max ${MAX_ATTACHMENT_SIZE / 1024 / 1024} MB)` };
  }
  if (!ALLOWED_FILE_TYPES.includes(attachment.mimeType)) {
    return { valid: false, error: 'File type not supported' };
  }
  return { valid: true };
}

/**
 * Upload a file to Supabase Storage and return the public URL.
 */
export async function uploadAttachment(
  serverId: string,
  channelId: string,
  file: PendingAttachment,
): Promise<string> {
  const path = `${serverId}/${channelId}/${Date.now()}_${file.name}`;

  const response = await fetch(file.uri);
  const blob = await response.blob();

  const { error } = await supabase.storage
    .from('attachments')
    .upload(path, blob, { contentType: file.mimeType });
  if (error) throw error;

  const { data } = supabase.storage.from('attachments').getPublicUrl(path);
  return data.publicUrl;
}

// ─── Typing display helper ────────────────────────────────────────────────────

/**
 * Format typing users into display text.
 * "Alice is typing...", "Alice and Bob are typing...", "Several people are typing..."
 */
export function formatTypingText(users: { username?: string }[]): string {
  if (users.length === 0) return '';
  if (users.length === 1) return `${users[0].username || 'Someone'} is typing...`;
  if (users.length === 2) return `${users[0].username} and ${users[1].username} are typing...`;
  if (users.length <= 4) return `${users.slice(0, -1).map((u) => u.username).join(', ')} and ${users[users.length - 1].username} are typing...`;
  return 'Several people are typing...';
}
