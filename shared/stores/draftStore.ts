import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createZustandStorage } from '../lib/storage';

/**
 * Draft metadata for tracking timestamps
 */
interface DraftMetadata {
  content: string;
  timestamp: number;
}

/**
 * Draft Store with cross-platform persistence
 * Stores message drafts by channelId or userId (for DMs)
 * Automatically cleans up drafts older than 7 days
 */
interface DraftStore {
  drafts: Record<string, DraftMetadata>;

  saveDraft: (key: string, content: string) => void;
  getDraft: (key: string) => string | undefined;
  clearDraft: (key: string) => void;
  cleanupOldDrafts: () => void;
}

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

export const useDraftStore = create<DraftStore>()(
  persist(
    (set, get) => ({
      drafts: {},

      saveDraft: (key, content) => {
        // Don't save empty drafts
        if (!content.trim()) {
          get().clearDraft(key);
          return;
        }

        set((state) => ({
          drafts: {
            ...state.drafts,
            [key]: {
              content,
              timestamp: Date.now(),
            },
          },
        }));
      },

      getDraft: (key) => {
        const draft = get().drafts[key];
        if (!draft) return undefined;

        // Check if draft is older than 7 days
        const age = Date.now() - draft.timestamp;
        if (age > SEVEN_DAYS_MS) {
          get().clearDraft(key);
          return undefined;
        }

        return draft.content;
      },

      clearDraft: (key) => {
        set((state) => {
          const { [key]: _, ...remainingDrafts } = state.drafts;
          return { drafts: remainingDrafts };
        });
      },

      cleanupOldDrafts: () => {
        const now = Date.now();
        set((state) => {
          const validDrafts: Record<string, DraftMetadata> = {};

          Object.entries(state.drafts).forEach(([key, draft]) => {
            const age = now - draft.timestamp;
            if (age <= SEVEN_DAYS_MS) {
              validDrafts[key] = draft;
            }
          });

          return { drafts: validDrafts };
        });
      },
    }),
    {
      name: 'flicko-drafts',
      storage: createJSONStorage(() => createZustandStorage()),
      // Run cleanup on store initialization
      onRehydrateStorage: () => (state) => {
        state?.cleanupOldDrafts();
      },
    }
  )
);
