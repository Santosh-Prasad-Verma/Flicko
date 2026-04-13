/**
 * Read State Store (Zustand)
 *
 * Tracks per-channel read positions and unread/mention counts.
 * Integrates with readStateService for Supabase persistence and
 * dispatches MESSAGE_ACK over WebSocket for real-time sync.
 *
 * Requirements: Feature 31 (Read States / Unread Tracking)
 */
import { create } from 'zustand';
import {
  getServerReadStates,
  markChannelRead as apiMarkRead,
  type ChannelReadState,
} from '../services/readStateService';

// ── Types ─────────────────────────────────────────────────────────────────

export interface ReadState {
  channelId: string;
  lastReadMessageId: string | null;
  unreadCount: number;
  mentionCount: number;
  lastReadAt: string | null;
  lastViewedAt: string | null;
}

export interface ReadStateStore {
  /** Per-channel read states */
  states: Map<string, ReadState>;

  /** Currently-open channel (unread count suppressed) */
  activeChannelId: string | null;

  /** Whether initial bulk load has happened */
  loaded: boolean;

  // ── Actions ───────────────────────────────────────────────────────────

  /** Load read states for all channels in one or more servers */
  loadReadStates: (userId: string, channelIds: string[]) => Promise<void>;

  /** Mark a channel as read (persists to Supabase) */
  markRead: (channelId: string, userId: string, lastMessageId: string) => Promise<void>;

  /** Mark all channels in a server as read */
  markServerRead: (userId: string, channelIds: string[]) => Promise<void>;

  /** Set the active (visible) channel  */
  setActiveChannel: (channelId: string | null) => void;

  /** Increment unread count for a channel (called from WS dispatch) */
  incrementUnread: (channelId: string) => void;

  /** Increment mention count for a channel */
  incrementMention: (channelId: string) => void;

  /** Update state from another device's ACK (WebSocket sync) */
  handleRemoteAck: (channelId: string, lastReadMessageId: string) => void;

  /** Get unread count for a channel */
  getUnreadCount: (channelId: string) => number;

  /** Get mention count for a channel */
  getMentionCount: (channelId: string) => number;

  /** Get total unread count across all channels */
  getTotalUnread: () => number;

  /** Get total mention count across all channels */
  getTotalMentions: () => number;

  /** Check if a channel has unread messages */
  isUnread: (channelId: string) => boolean;

  /** Reset store */
  reset: () => void;
}

// ── Helpers ─────────────────────────────────────────────────────────────

function mapFromApi(api: ChannelReadState): ReadState {
  return {
    channelId: api.channel_id,
    lastReadMessageId: api.last_read_message_id,
    unreadCount: 0, // Will be computed from latest message comparison
    mentionCount: api.mention_count,
    lastReadAt: api.last_read_at,
    lastViewedAt: null,
  };
}

// ── Store ───────────────────────────────────────────────────────────────

export const useReadStateStore = create<ReadStateStore>()((set, get) => ({
  states: new Map(),
  activeChannelId: null,
  loaded: false,

  loadReadStates: async (userId, channelIds) => {
    try {
      const apiStates = await getServerReadStates(userId, channelIds);
      const newMap = new Map(get().states);
      for (const state of apiStates) {
        newMap.set(state.channel_id, mapFromApi(state));
      }
      set({ states: newMap, loaded: true });
    } catch (err) {
      console.error('[readStateStore] loadReadStates failed:', err);
    }
  },

  markRead: async (channelId, userId, lastMessageId) => {
    // Optimistic update
    const newMap = new Map(get().states);
    const existing = newMap.get(channelId);
    newMap.set(channelId, {
      channelId,
      lastReadMessageId: lastMessageId,
      unreadCount: 0,
      mentionCount: 0,
      lastReadAt: new Date().toISOString(),
      lastViewedAt: new Date().toISOString(),
    });
    set({ states: newMap });

    try {
      await apiMarkRead(channelId, userId, lastMessageId);
    } catch (err) {
      // Revert on failure
      if (existing) {
        const revertMap = new Map(get().states);
        revertMap.set(channelId, existing);
        set({ states: revertMap });
      }
      console.error('[readStateStore] markRead failed:', err);
    }
  },

  markServerRead: async (userId, channelIds) => {
    const newMap = new Map(get().states);
    const rollbackStates = new Map<string, ReadState>();

    for (const chId of channelIds) {
      const existing = newMap.get(chId);
      if (existing) rollbackStates.set(chId, { ...existing });
      newMap.set(chId, {
        channelId: chId,
        lastReadMessageId: existing?.lastReadMessageId ?? null,
        unreadCount: 0,
        mentionCount: 0,
        lastReadAt: new Date().toISOString(),
        lastViewedAt: new Date().toISOString(),
      });
    }
    set({ states: newMap });

    try {
      const { markServerRead: apiMarkServerRead } = await import('../services/readStateService');
      await apiMarkServerRead(userId, channelIds);
    } catch (err) {
      // Revert
      const revertMap = new Map(get().states);
      rollbackStates.forEach((state, chId) => revertMap.set(chId, state));
      set({ states: revertMap });
      console.error('[readStateStore] markServerRead failed:', err);
    }
  },

  setActiveChannel: (channelId) => {
    set({ activeChannelId: channelId });
    // Clear unread count for the now-active channel
    if (channelId) {
      const newMap = new Map(get().states);
      const existing = newMap.get(channelId);
      if (existing && existing.unreadCount > 0) {
        newMap.set(channelId, { ...existing, unreadCount: 0, mentionCount: 0 });
        set({ states: newMap });
      }
    }
  },

  incrementUnread: (channelId) => {
    // Don't increment for the currently-viewed channel
    if (get().activeChannelId === channelId) return;

    const newMap = new Map(get().states);
    const existing = newMap.get(channelId);
    newMap.set(channelId, {
      channelId,
      lastReadMessageId: existing?.lastReadMessageId ?? null,
      unreadCount: (existing?.unreadCount ?? 0) + 1,
      mentionCount: existing?.mentionCount ?? 0,
      lastReadAt: existing?.lastReadAt ?? null,
      lastViewedAt: existing?.lastViewedAt ?? null,
    });
    set({ states: newMap });
  },

  incrementMention: (channelId) => {
    if (get().activeChannelId === channelId) return;

    const newMap = new Map(get().states);
    const existing = newMap.get(channelId);
    newMap.set(channelId, {
      channelId,
      lastReadMessageId: existing?.lastReadMessageId ?? null,
      unreadCount: (existing?.unreadCount ?? 0) + 1,
      mentionCount: (existing?.mentionCount ?? 0) + 1,
      lastReadAt: existing?.lastReadAt ?? null,
      lastViewedAt: existing?.lastViewedAt ?? null,
    });
    set({ states: newMap });
  },

  handleRemoteAck: (channelId, lastReadMessageId) => {
    const newMap = new Map(get().states);
    const existing = newMap.get(channelId);
    newMap.set(channelId, {
      channelId,
      lastReadMessageId,
      unreadCount: 0,
      mentionCount: 0,
      lastReadAt: new Date().toISOString(),
      lastViewedAt: existing?.lastViewedAt ?? null,
    });
    set({ states: newMap });
  },

  getUnreadCount: (channelId) => {
    return get().states.get(channelId)?.unreadCount ?? 0;
  },

  getMentionCount: (channelId) => {
    return get().states.get(channelId)?.mentionCount ?? 0;
  },

  getTotalUnread: () => {
    let total = 0;
    get().states.forEach((state) => {
      total += state.unreadCount;
    });
    return total;
  },

  getTotalMentions: () => {
    let total = 0;
    get().states.forEach((state) => {
      total += state.mentionCount;
    });
    return total;
  },

  isUnread: (channelId) => {
    return (get().states.get(channelId)?.unreadCount ?? 0) > 0;
  },

  reset: () => set({ states: new Map(), activeChannelId: null, loaded: false }),
}));
