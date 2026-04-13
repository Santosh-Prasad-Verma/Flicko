// ============================================================================
// Flicko — Message Zustand Store
// ============================================================================
// Manages messages by channel with:
//   • Optimistic send (show immediately, reconcile on ACK / error)
//   • Failed-message retry queue
//   • WebSocket dispatch handler wiring
// ============================================================================

import { create } from 'zustand';
import type { Message } from '../types/models';
import type { AckPayload, MessagePayload } from '../services/ws/types';
import { wsManager } from '../services/ws/WebSocketManager';

// ── Optimistic message status ───────────────────────────────────────────────

export type MessageStatus = 'sending' | 'sent' | 'failed';

export interface LocalMessage extends Message {
  /** Client-generated nonce for ACK correlation */
  _nonce?: string;
  /** Delivery status (only present on locally-sent messages) */
  _status?: MessageStatus;
}

// ── Retry queue entry ───────────────────────────────────────────────────────

export interface FailedMessage {
  channelId: string;
  content: string;
  nonce: string;
  /** ISO timestamp of original attempt */
  failedAt: string;
}

// ── Store shape ─────────────────────────────────────────────────────────────

interface MessageStore {
  /** Messages keyed by channelId → ordered array (newest last) */
  messages: Record<string, LocalMessage[]>;

  /** Messages that failed to send and can be retried */
  retryQueue: FailedMessage[];

  /** Whether we're loading older messages for a channel (pagination) */
  loadingMore: Record<string, boolean>;

  // ── Actions ─────────────────────────────────────────────────────────────

  /** Insert a message (from WS dispatch or REST fetch). Deduplicates by id. */
  addMessage: (channelId: string, message: LocalMessage) => void;

  /** Bulk-insert (e.g. initial fetch or catching up after reconnect). */
  addMessages: (channelId: string, messages: LocalMessage[]) => void;

  /** Optimistically insert a message the local user is sending. */
  addOptimistic: (
    channelId: string,
    content: string,
    nonce: string,
    authorId: string,
  ) => void;

  /** Mark an optimistic message as sent and patch in the server ID. */
  confirmMessage: (nonce: string, ack: AckPayload) => void;

  /** Mark an optimistic message as failed. */
  failMessage: (nonce: string) => void;

  /** Retry a failed message. Moves it back to "sending" state. */
  retryMessage: (nonce: string) => void;

  /** Remove a failed message from the retry queue permanently. */
  discardFailed: (nonce: string) => void;

  /** Handle an incoming WS dispatch payload. */
  handleDispatch: (payload: MessagePayload, eventType: string) => void;

  /** Update a message in-place (edit, reaction change, etc.). */
  updateMessage: (channelId: string, messageId: string, patch: Partial<Message>) => void;

  /** Remove a message (delete event). */
  removeMessage: (channelId: string, messageId: string) => void;

  /** Clear all messages for a channel (e.g. channel switch cleanup). */
  clearChannel: (channelId: string) => void;

  /** Set loading-more state for a channel. */
  setLoadingMore: (channelId: string, loading: boolean) => void;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function ensureChannel(
  messages: Record<string, LocalMessage[]>,
  channelId: string,
): LocalMessage[] {
  return messages[channelId] ?? [];
}

function dedup(arr: LocalMessage[], msg: LocalMessage): LocalMessage[] {
  // If a message with the same id already exists, ignore the duplicate
  // This solves the dual realtime path duplicate delivery issue.
  const exists = arr.some((m) => m.id === msg.id);
  if (exists) {
    return arr;
  }
  return [...arr, msg];
}

// ── Store ───────────────────────────────────────────────────────────────────

export const useMessageStore = create<MessageStore>()((set, get) => ({
  messages: {},
  retryQueue: [],
  loadingMore: {},

  // ── Core mutations ──────────────────────────────────────────────────────

  addMessage: (channelId, message) =>
    set((state) => ({
      messages: {
        ...state.messages,
        [channelId]: dedup(ensureChannel(state.messages, channelId), message),
      },
    })),

  addMessages: (channelId, msgs) =>
    set((state) => {
      const existing = ensureChannel(state.messages, channelId);
      const existingIds = new Set(existing.map((m) => m.id));
      const newMsgs = msgs.filter((m) => !existingIds.has(m.id));
      
      // Prevent unnecessary memory allocation if there are no new messages
      // This stops infinite React render cycles when polling or when array references change
      if (newMsgs.length === 0) {
        return state;
      }
      
      return {
        messages: {
          ...state.messages,
          [channelId]: [...newMsgs, ...existing],
        },
      };
    }),

  // ── Optimistic send ─────────────────────────────────────────────────────

  addOptimistic: (channelId, content, nonce, authorId) => {
    const optimistic: LocalMessage = {
      id: `optimistic-${nonce}`,
      channel_id: channelId,
      author_id: authorId,
      content,
      type: 'default',
      reply_to_id: null,
      thread_id: null,
      attachments: [],
      embeds: [],
      reactions: [],
      mentions: [],
      mention_roles: [],
      mention_everyone: false,
      pinned: false,
      edited: false,
      edited_at: null,
      created_at: new Date().toISOString(),
      updated_at: null,
      _nonce: nonce,
      _status: 'sending',
    };

    set((state) => ({
      messages: {
        ...state.messages,
        [channelId]: [...ensureChannel(state.messages, channelId), optimistic],
      },
    }));
  },

  confirmMessage: (nonce, ack) =>
    set((state) => {
      const updated = { ...state.messages };
      for (const channelId of Object.keys(updated)) {
        const idx = updated[channelId].findIndex((m) => m._nonce === nonce);
        if (idx !== -1) {
          const copy = [...updated[channelId]];
          copy[idx] = {
            ...copy[idx],
            id: ack.message_id,
            _status: 'sent',
          };
          updated[channelId] = copy;
          break;
        }
      }
      // Also remove from retry queue if present
      return {
        messages: updated,
        retryQueue: state.retryQueue.filter((m) => m.nonce !== nonce),
      };
    }),

  failMessage: (nonce) =>
    set((state) => {
      const updated = { ...state.messages };
      let failedEntry: FailedMessage | null = null;

      for (const channelId of Object.keys(updated)) {
        const idx = updated[channelId].findIndex((m) => m._nonce === nonce);
        if (idx !== -1) {
          const copy = [...updated[channelId]];
          copy[idx] = { ...copy[idx], _status: 'failed' };
          updated[channelId] = copy;

          failedEntry = {
            channelId,
            content: copy[idx].content,
            nonce,
            failedAt: new Date().toISOString(),
          };
          break;
        }
      }

      return {
        messages: updated,
        retryQueue: failedEntry
          ? [...state.retryQueue, failedEntry]
          : state.retryQueue,
      };
    }),

  retryMessage: (nonce) => {
    const { retryQueue } = get();
    const entry = retryQueue.find((m) => m.nonce === nonce);
    if (!entry) return;

    // Move back to "sending"
    set((state) => {
      const updated = { ...state.messages };
      const channelMsgs = updated[entry.channelId];
      if (channelMsgs) {
        const idx = channelMsgs.findIndex((m) => m._nonce === nonce);
        if (idx !== -1) {
          const copy = [...channelMsgs];
          copy[idx] = { ...copy[idx], _status: 'sending' };
          updated[entry.channelId] = copy;
        }
      }
      return {
        messages: updated,
        retryQueue: state.retryQueue.filter((m) => m.nonce !== nonce),
      };
    });

    // Re-send over WS
    wsManager
      .sendMessage(entry.channelId, entry.content, entry.nonce)
      .then((ack) => get().confirmMessage(nonce, ack))
      .catch(() => get().failMessage(nonce));
  },

  discardFailed: (nonce) =>
    set((state) => {
      // Remove from retry queue AND from messages list
      const updated = { ...state.messages };
      for (const channelId of Object.keys(updated)) {
        updated[channelId] = updated[channelId].filter(
          (m) => m._nonce !== nonce,
        );
      }
      return {
        messages: updated,
        retryQueue: state.retryQueue.filter((m) => m.nonce !== nonce),
      };
    }),

  // ── WS dispatch handler ─────────────────────────────────────────────────

  handleDispatch: (payload, eventType) => {
    const store = get();
    const channelId = payload.channel_id;

    switch (eventType) {
      case 'MESSAGE_CREATE': {
        const msg: LocalMessage = {
          id: payload.id ?? '',
          channel_id: channelId,
          author_id: payload.author_id ?? '',
          content: payload.content,
          type: 'default',
          reply_to_id: null,
          thread_id: null,
          attachments: (payload.attachments ?? []).map((a) => ({
            id: a.id,
            filename: a.filename,
            url: a.url,
            size: a.size,
            content_type: a.content_type,
            width: null,
            height: null,
          })),
          embeds: [],
          reactions: [],
          mentions: [],
          mention_roles: [],
          mention_everyone: false,
          pinned: false,
          edited: false,
          edited_at: null,
          created_at: payload.timestamp
            ? new Date(payload.timestamp).toISOString()
            : new Date().toISOString(),
          updated_at: null,
          _status: 'sent',
        };

        // If we sent this message, the optimistic copy already exists — reconcile
        if (payload.nonce) {
          const existing = ensureChannel(store.messages, channelId);
          const optIdx = existing.findIndex((m) => m._nonce === payload.nonce);
          if (optIdx !== -1) {
            // Replace optimistic with server-confirmed
            set((state) => {
              const copy = [...ensureChannel(state.messages, channelId)];
              copy[optIdx] = { ...msg, _nonce: payload.nonce, _status: 'sent' };
              return {
                messages: { ...state.messages, [channelId]: copy },
              };
            });
            return;
          }
        }

        store.addMessage(channelId, msg);
        break;
      }
      case 'MESSAGE_UPDATE':
        if (payload.id) {
          store.updateMessage(channelId, payload.id, {
            content: payload.content,
            edited: true,
            edited_at: new Date().toISOString(),
          });
        }
        break;
      case 'MESSAGE_DELETE':
        if (payload.id) {
          store.removeMessage(channelId, payload.id);
        }
        break;
      default:
        break;
    }
  },

  // ── CRUD helpers ────────────────────────────────────────────────────────

  updateMessage: (channelId, messageId, patch) =>
    set((state) => {
      const msgs = ensureChannel(state.messages, channelId);
      const idx = msgs.findIndex((m) => m.id === messageId);
      if (idx === -1) return state;
      const copy = [...msgs];
      copy[idx] = { ...copy[idx], ...patch };
      return { messages: { ...state.messages, [channelId]: copy } };
    }),

  removeMessage: (channelId, messageId) =>
    set((state) => ({
      messages: {
        ...state.messages,
        [channelId]: ensureChannel(state.messages, channelId).filter(
          (m) => m.id !== messageId,
        ),
      },
    })),

  clearChannel: (channelId) =>
    set((state) => {
      const { [channelId]: _, ...rest } = state.messages;
      return { messages: rest };
    }),

  setLoadingMore: (channelId, loading) =>
    set((state) => ({
      loadingMore: { ...state.loadingMore, [channelId]: loading },
    })),
}));
