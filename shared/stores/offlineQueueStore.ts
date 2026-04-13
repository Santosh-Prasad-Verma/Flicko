/**
 * Offline Queue Store (Zustand)
 *
 * Provides reactive state for the offline message queue and
 * network connectivity status, wrapping offlineService.
 *
 * Requirements: Features 34-35 (Offline Support)
 */
import { create } from 'zustand';
import {
  type PendingMutation,
  type NetworkState,
  getPendingQueue,
  queueMutation,
  removeMutation,
  getNetworkState,
  subscribeNetworkState,
  processPendingQueue,
  startOfflineSync,
} from '../services/offlineService';

interface OfflineQueueStore {
  /** Current network state */
  networkState: NetworkState;

  /** Queue of pending mutations */
  queue: PendingMutation[];

  /** Whether the queue is currently being processed */
  processing: boolean;

  /** Cleanup function for network listener */
  _unsubscribe: (() => void) | null;

  // ── Actions ───────────────────────────────────────────────────────────

  /** Initialize network monitoring and load persisted queue */
  init: () => Promise<void>;

  /** Add a mutation to the queue */
  enqueue: (mutation: Omit<PendingMutation, 'retries'>) => Promise<void>;

  /** Remove a mutation from the queue */
  dequeue: (mutationId: string) => Promise<void>;

  /** Process all pending mutations */
  processQueue: () => Promise<{ processed: number; failed: number }>;

  /** Refresh queue from AsyncStorage */
  refreshQueue: () => Promise<void>;

  /** Tear down listeners */
  destroy: () => void;

  /** Check if we're online */
  isOnline: () => boolean;
}

export const useOfflineQueueStore = create<OfflineQueueStore>()((set, get) => ({
  networkState: 'unknown',
  queue: [],
  processing: false,
  _unsubscribe: null,

  init: async () => {
    // Load initial state
    const [networkState, queue] = await Promise.all([
      getNetworkState(),
      getPendingQueue(),
    ]);

    set({ networkState, queue });

    // Subscribe to network changes
    const unsubscribe = subscribeNetworkState((state) => {
      const prev = get().networkState;
      set({ networkState: state });

      // Auto-process queue on reconnect
      if (prev !== 'online' && state === 'online') {
        get().processQueue();
      }
    });

    // Also start the background sync loop
    const syncCleanup = startOfflineSync();

    set({
      _unsubscribe: () => {
        unsubscribe();
        syncCleanup();
      },
    });
  },

  enqueue: async (mutation) => {
    await queueMutation(mutation);
    const queue = await getPendingQueue();
    set({ queue });
  },

  dequeue: async (mutationId) => {
    await removeMutation(mutationId);
    const queue = await getPendingQueue();
    set({ queue });
  },

  processQueue: async () => {
    if (get().processing) return { processed: 0, failed: 0 };
    set({ processing: true });

    try {
      const result = await processPendingQueue();
      const queue = await getPendingQueue();
      set({ queue, processing: false });
      return result;
    } catch (err) {
      set({ processing: false });
      console.error('[offlineQueueStore] processQueue failed:', err);
      return { processed: 0, failed: 0 };
    }
  },

  refreshQueue: async () => {
    const queue = await getPendingQueue();
    set({ queue });
  },

  destroy: () => {
    const unsub = get()._unsubscribe;
    if (unsub) unsub();
    set({ _unsubscribe: null });
  },

  isOnline: () => get().networkState === 'online',
}));
