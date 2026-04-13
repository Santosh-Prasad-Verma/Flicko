import { supabase } from '../lib/supabase';
import type { Message } from '@shared/types/models';

/**
 * Search Service
 * 
 * Handles message search functionality with debouncing, permission filtering,
 * relevance-based ordering, full-text highlights, and sort options.
 * 
 * Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7
 */

export type SearchSortOrder = 'relevance' | 'newest' | 'oldest';

export interface SearchMessagesOptions {
  query: string;
  limit?: number;
  sortOrder?: SearchSortOrder;
}

export interface SearchMessageResult extends Message {
  highlighted_content?: string;
  rank?: number;
}

export interface SearchMessagesResult {
  messages: SearchMessageResult[];
  hasMore: boolean;
}

const DEFAULT_SEARCH_LIMIT = 50;
const DEBOUNCE_DELAY = 300; // milliseconds

/**
 * Debounce helper function
 * 
 * Creates a debounced version of a function that delays execution
 * until after the specified delay has elapsed since the last call.
 * 
 * @param func - The function to debounce
 * @param delay - The delay in milliseconds
 * @returns Debounced function
 */
function debounce<T extends (...args: any[]) => any>(
  func: T,
  delay: number
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  return function (this: any, ...args: Parameters<T>) {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      func.apply(this, args);
    }, delay);
  };
}

/**
 * Get all channel IDs that the user has access to
 * 
 * This includes channels from all servers where the user is a member.
 * 
 * @returns Array of channel IDs the user can access
 * @throws Error if user is not authenticated
 */
async function getUserAccessibleChannels(): Promise<string[]> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Get all servers where the user is a member
  const { data: memberships, error: membershipError } = await supabase
    .from('server_members')
    .select('server_id')
    .eq('user_id', user.id);

  if (membershipError) {
    throw new Error(`Failed to fetch user memberships: ${membershipError.message}`);
  }

  if (!memberships || memberships.length === 0) {
    return [];
  }

  const serverIds = memberships.map(m => m.server_id);

  // Get all channels from those servers
  const { data: channels, error: channelsError } = await supabase
    .from('channels')
    .select('id')
    .in('server_id', serverIds);

  if (channelsError) {
    throw new Error(`Failed to fetch accessible channels: ${channelsError.message}`);
  }

  return (channels || []).map(c => c.id);
}

/**
 * Search for messages containing the query text
 * 
 * Uses the search_messages_with_highlights RPC function for full-text
 * search with **bold** highlight markers and configurable sort order.
 * Falls back to ilike-based search if the RPC is unavailable.
 * 
 * @param options - Search options including query, limit, and sortOrder
 * @returns Search results with highlighted content and pagination info
 * @throws Error if user is not authenticated or search fails
 */
export async function searchMessages(
  options: SearchMessagesOptions
): Promise<SearchMessagesResult> {
  const { query, limit = DEFAULT_SEARCH_LIMIT, sortOrder = 'relevance' } = options;

  // Validate query
  if (!query || query.trim().length === 0) {
    return {
      messages: [],
      hasMore: false,
    };
  }

  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Get all channels the user has access to
  const accessibleChannelIds = await getUserAccessibleChannels();

  if (accessibleChannelIds.length === 0) {
    return {
      messages: [],
      hasMore: false,
    };
  }

  // Try the RPC with highlights first
  try {
    const { data, error } = await supabase.rpc('search_messages_with_highlights', {
      search_query: query.trim(),
      channel_ids: accessibleChannelIds,
      sort_order: sortOrder,
      max_results: limit + 1,
    });

    if (!error && data) {
      const messages = data as SearchMessageResult[];
      const hasMore = messages.length > limit;
      if (hasMore) messages.pop();

      return { messages, hasMore };
    }

    // If RPC fails (e.g. migration not applied), fall through to legacy
    console.warn('[SearchService] RPC fallback:', error?.message);
  } catch {
    // Fall through to legacy search
  }

  // Legacy ilike-based search (fallback)
  // MED-018: Sanitize search input — escape SQL wildcards to prevent injection
  const sanitizedQuery = query.trim()
    .replace(/\\/g, '\\\\')
    .replace(/%/g, '\\%')
    .replace(/_/g, '\\_');
  const searchPattern = `%${sanitizedQuery}%`;

  const { data, error } = await supabase
    .from('messages')
    .select('*, author:profiles(*)')
    .in('channel_id', accessibleChannelIds)
    .ilike('content', searchPattern)
    .order('created_at', { ascending: sortOrder === 'oldest' })
    .limit(limit + 1);

  if (error) {
    throw new Error(`Failed to search messages: ${error.message}`);
  }

  const messages = (data || []) as SearchMessageResult[];
  const hasMore = messages.length > limit;

  if (hasMore) {
    messages.pop();
  }

  // Add simple highlight markers for fallback path
  const queryLower = query.toLowerCase();
  for (const msg of messages) {
    if (msg.content) {
      msg.highlighted_content = msg.content.replace(
        new RegExp(`(${query.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi'),
        '**$1**',
      );
    }
  }

  // Sort by relevance if needed (already sorted by created_at from DB)
  if (sortOrder === 'relevance') {
    messages.sort((a, b) => {
      const aContent = (a.content || '').toLowerCase();
      const bContent = (b.content || '').toLowerCase();

      const aExact = aContent === queryLower;
      const bExact = bContent === queryLower;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      const aStarts = aContent.startsWith(queryLower);
      const bStarts = bContent.startsWith(queryLower);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return 0;
    });
  }

  return { messages, hasMore };
}

/**
 * Create a debounced version of searchMessages
 * 
 * This function returns a debounced search function that delays execution
 * by 300ms after the last call, preventing excessive API calls while typing.
 * 
 * @param callback - Callback function to receive search results
 * @returns Debounced search function
 */
export function createDebouncedSearch(
  callback: (result: SearchMessagesResult | Error) => void
): (query: string) => void {
  return debounce(async (query: string) => {
    try {
      const result = await searchMessages({ query });
      callback(result);
    } catch (error) {
      callback(error as Error);
    }
  }, DEBOUNCE_DELAY);
}
