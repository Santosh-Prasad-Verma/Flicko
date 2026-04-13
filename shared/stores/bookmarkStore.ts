/**
 * Bookmarks / Saved Messages Store (Feature 19)
 *
 * Manages user's bookmarked/saved messages with folder organization.
 * Persists to Supabase saved_messages table.
 */
import { create } from 'zustand';
import { supabase } from '../services/supabase';

export interface SavedMessage {
  id: string;
  user_id: string;
  message_id: string;
  folder: string;
  note: string | null;
  saved_at: string;
  // Denormalized for display
  message_content?: string;
  message_author?: string;
  channel_name?: string;
  server_name?: string;
}

interface BookmarkStore {
  savedMessages: SavedMessage[];
  folders: string[];
  loading: boolean;

  loadSavedMessages: (userId: string) => Promise<void>;
  saveMessage: (userId: string, messageId: string, folder?: string, note?: string) => Promise<void>;
  unsaveMessage: (savedMessageId: string) => Promise<void>;
  updateNote: (savedMessageId: string, note: string) => Promise<void>;
  moveToFolder: (savedMessageId: string, folder: string) => Promise<void>;
  createFolder: (name: string) => void;
  isSaved: (messageId: string) => boolean;
}

export const useBookmarkStore = create<BookmarkStore>()((set, get) => ({
  savedMessages: [],
  folders: ['default'],
  loading: false,

  loadSavedMessages: async (userId) => {
    set({ loading: true });
    try {
      const { data, error } = await supabase
        .from('saved_messages')
        .select('*')
        .eq('user_id', userId)
        .order('saved_at', { ascending: false });

      if (!error && data) {
        set({ savedMessages: data as SavedMessage[] });
        const uniqueFolders = new Set(['default', ...data.map((m: any) => m.folder || 'default')]);
        set({ folders: Array.from(uniqueFolders) });
      }
    } catch (err) {
      console.error('[bookmarkStore] loadSavedMessages failed:', err);
    } finally {
      set({ loading: false });
    }
  },

  saveMessage: async (userId, messageId, folder = 'default', note) => {
    const newSaved: SavedMessage = {
      id: `temp-${Date.now()}`,
      user_id: userId,
      message_id: messageId,
      folder,
      note: note || null,
      saved_at: new Date().toISOString(),
    };

    // Optimistic add
    set((state) => ({ savedMessages: [newSaved, ...state.savedMessages] }));

    try {
      const { data, error } = await supabase
        .from('saved_messages')
        .insert({ user_id: userId, message_id: messageId, folder, note })
        .select()
        .single();

      if (!error && data) {
        set((state) => ({
          savedMessages: state.savedMessages.map((m) =>
            m.id === newSaved.id ? (data as SavedMessage) : m
          ),
        }));
      }
    } catch (err) {
      // Revert
      set((state) => ({
        savedMessages: state.savedMessages.filter((m) => m.id !== newSaved.id),
      }));
      console.error('[bookmarkStore] saveMessage failed:', err);
    }
  },

  unsaveMessage: async (savedMessageId) => {
    const prev = get().savedMessages;
    set((state) => ({
      savedMessages: state.savedMessages.filter((m) => m.id !== savedMessageId),
    }));

    try {
      await supabase.from('saved_messages').delete().eq('id', savedMessageId);
    } catch (err) {
      set({ savedMessages: prev });
      console.error('[bookmarkStore] unsaveMessage failed:', err);
    }
  },

  updateNote: async (savedMessageId, note) => {
    set((state) => ({
      savedMessages: state.savedMessages.map((m) =>
        m.id === savedMessageId ? { ...m, note } : m
      ),
    }));

    try {
      await supabase.from('saved_messages').update({ note }).eq('id', savedMessageId);
    } catch (err) {
      console.error('[bookmarkStore] updateNote failed:', err);
    }
  },

  moveToFolder: async (savedMessageId, folder) => {
    set((state) => ({
      savedMessages: state.savedMessages.map((m) =>
        m.id === savedMessageId ? { ...m, folder } : m
      ),
    }));

    try {
      await supabase.from('saved_messages').update({ folder }).eq('id', savedMessageId);
    } catch (err) {
      console.error('[bookmarkStore] moveToFolder failed:', err);
    }
  },

  createFolder: (name) => {
    set((state) => ({
      folders: state.folders.includes(name) ? state.folders : [...state.folders, name],
    }));
  },

  isSaved: (messageId) => {
    return get().savedMessages.some((m) => m.message_id === messageId);
  },
}));
