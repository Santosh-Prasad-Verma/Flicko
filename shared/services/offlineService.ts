/**
 * Offline Support & Cache Service
 *
 * AsyncStorage-based caching layer for offline reads, optimistic writes,
 * and a queue for pending mutations that sync when back online.
 * Requirements: Features 34-35 (Offline Support)
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';

// ─── Cache Keys ────────────────────────────────────────────────────────────────

const PREFIX = '@flicko_cache/';

export const CacheKeys = {
  servers: () => `${PREFIX}servers`,
  serverChannels: (serverId: string) => `${PREFIX}server_channels/${serverId}`,
  channelMessages: (channelId: string) => `${PREFIX}channel_messages/${channelId}`,
  user: () => `${PREFIX}user`,
  readStates: () => `${PREFIX}read_states`,
  dmConversations: () => `${PREFIX}dm_conversations`,
  pendingQueue: () => `${PREFIX}pending_queue`,
} as const;

// ─── Generic cache ops ─────────────────────────────────────────────────────────

/**
 * Write a value to the cache with optional TTL (in seconds).
 */
export async function cacheSet<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
  const entry = {
    data: value,
    timestamp: Date.now(),
    expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null,
  };
  await AsyncStorage.setItem(key, JSON.stringify(entry));
}

/**
 * Read a value from the cache. Returns null if expired or missing.
 */
export async function cacheGet<T>(key: string): Promise<T | null> {
  const raw = await AsyncStorage.getItem(key);
  if (!raw) return null;

  try {
    const entry = JSON.parse(raw);
    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      await AsyncStorage.removeItem(key);
      return null;
    }
    return entry.data as T;
  } catch {
    return null;
  }
}

/**
 * Delete a cache entry.
 */
export async function cacheDelete(key: string): Promise<void> {
  await AsyncStorage.removeItem(key);
}

/**
 * Clear all Flicko cache entries.
 */
export async function cacheClear(): Promise<void> {
  const keys = await AsyncStorage.getAllKeys();
  const flickoKeys = keys.filter((k) => k.startsWith(PREFIX));
  if (flickoKeys.length > 0) {
    await AsyncStorage.multiRemove(flickoKeys);
  }
}

// ─── Offline Queue ─────────────────────────────────────────────────────────────

export interface PendingMutation {
  id: string;
  type: 'send_message' | 'edit_message' | 'delete_message' | 'react' | 'mark_read';
  payload: Record<string, any>;
  createdAt: number;
  retries: number;
}

/**
 * Add a mutation to the offline queue.
 */
export async function queueMutation(mutation: Omit<PendingMutation, 'retries'>): Promise<void> {
  const queue = await getPendingQueue();
  queue.push({ ...mutation, retries: 0 });
  await AsyncStorage.setItem(CacheKeys.pendingQueue(), JSON.stringify(queue));
}

/**
 * Get all pending mutations.
 */
export async function getPendingQueue(): Promise<PendingMutation[]> {
  const raw = await AsyncStorage.getItem(CacheKeys.pendingQueue());
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

/**
 * Remove a mutation from the queue (after successful sync).
 */
export async function removeMutation(mutationId: string): Promise<void> {
  const queue = await getPendingQueue();
  const updated = queue.filter((m) => m.id !== mutationId);
  await AsyncStorage.setItem(CacheKeys.pendingQueue(), JSON.stringify(updated));
}

/**
 * Increment retry count for a failed mutation.
 */
export async function incrementRetry(mutationId: string): Promise<void> {
  const queue = await getPendingQueue();
  const updated = queue.map((m) =>
    m.id === mutationId ? { ...m, retries: m.retries + 1 } : m,
  );
  await AsyncStorage.setItem(CacheKeys.pendingQueue(), JSON.stringify(updated));
}

/**
 * Purge mutations that exceeded max retries.
 */
export async function purgeFailedMutations(maxRetries = 5): Promise<PendingMutation[]> {
  const queue = await getPendingQueue();
  const failed = queue.filter((m) => m.retries >= maxRetries);
  const remaining = queue.filter((m) => m.retries < maxRetries);
  await AsyncStorage.setItem(CacheKeys.pendingQueue(), JSON.stringify(remaining));
  return failed;
}

// ─── Network state ─────────────────────────────────────────────────────────────

export type NetworkState = 'online' | 'offline' | 'unknown';

/**
 * Get current network state.
 */
export async function getNetworkState(): Promise<NetworkState> {
  const state = await NetInfo.fetch();
  if (state.isConnected === true) return 'online';
  if (state.isConnected === false) return 'offline';
  return 'unknown';
}

/**
 * Subscribe to network state changes.
 * Returns an unsubscribe function.
 */
export function subscribeNetworkState(
  onChange: (state: NetworkState) => void,
): () => void {
  const unsubscribe = NetInfo.addEventListener((state) => {
    if (state.isConnected === true) onChange('online');
    else if (state.isConnected === false) onChange('offline');
    else onChange('unknown');
  });
  return unsubscribe;
}

// ─── Cache-first data fetcher ──────────────────────────────────────────────────

/**
 * Fetch data with cache-first strategy.
 * Returns cached data immediately, then fetches fresh data in background.
 */
export async function cacheFirstFetch<T>(
  cacheKey: string,
  fetcher: () => Promise<T>,
  ttlSeconds = 300,
): Promise<{ data: T | null; source: 'cache' | 'network' | 'error' }> {
  // Try cache first
  const cached = await cacheGet<T>(cacheKey);
  if (cached !== null) {
    // Background refresh
    fetcher()
      .then((fresh) => cacheSet(cacheKey, fresh, ttlSeconds))
      .catch(() => {});
    return { data: cached, source: 'cache' };
  }

  // No cache — try network
  try {
    const fresh = await fetcher();
    await cacheSet(cacheKey, fresh, ttlSeconds);
    return { data: fresh, source: 'network' };
  } catch {
    return { data: null, source: 'error' };
  }
}

// ─── MED-013: Auto-sync queue on reconnect ─────────────────────────────────────

export type MutationHandler = (mutation: PendingMutation) => Promise<void>;

let _mutationHandlers: Map<string, MutationHandler> = new Map();
let _syncUnsubscribe: (() => void) | null = null;
let _isSyncing = false;

/**
 * Register a handler for a specific mutation type.
 * Called by services (e.g., messageService) at init time.
 */
export function registerMutationHandler(type: PendingMutation['type'], handler: MutationHandler): void {
  _mutationHandlers.set(type, handler);
}

/**
 * Process the pending queue — called automatically on reconnect.
 * Processes mutations in FIFO order. Failed mutations are retried up to maxRetries.
 */
export async function processPendingQueue(maxRetries = 5): Promise<{ processed: number; failed: number }> {
  if (_isSyncing) return { processed: 0, failed: 0 };
  _isSyncing = true;

  let processed = 0;
  let failed = 0;

  try {
    const queue = await getPendingQueue();
    if (queue.length === 0) return { processed: 0, failed: 0 };

    for (const mutation of queue) {
      const handler = _mutationHandlers.get(mutation.type);
      if (!handler) {
        console.warn(`[OfflineSync] No handler for mutation type: ${mutation.type}`);
        continue;
      }

      try {
        await handler(mutation);
        await removeMutation(mutation.id);
        processed++;
      } catch (err) {
        console.warn(`[OfflineSync] Failed to sync mutation ${mutation.id}:`, err);
        if (mutation.retries + 1 >= maxRetries) {
          await removeMutation(mutation.id);
          failed++;
        } else {
          await incrementRetry(mutation.id);
        }
      }
    }
  } finally {
    _isSyncing = false;
  }

  return { processed, failed };
}

/**
 * Start listening for network reconnection and auto-sync pending mutations.
 * Call this once at app startup. Returns an unsubscribe function.
 */
export function startOfflineSync(): () => void {
  if (_syncUnsubscribe) return _syncUnsubscribe;

  let wasOffline = false;

  _syncUnsubscribe = subscribeNetworkState(async (state) => {
    if (state === 'offline') {
      wasOffline = true;
      return;
    }

    if (state === 'online' && wasOffline) {
      wasOffline = false;
      console.log('[OfflineSync] Back online — processing pending queue');
      const result = await processPendingQueue();
      if (result.processed > 0 || result.failed > 0) {
        console.log(`[OfflineSync] Synced: ${result.processed} ok, ${result.failed} failed`);
      }
    }
  });

  return () => {
    if (_syncUnsubscribe) {
      _syncUnsubscribe();
      _syncUnsubscribe = null;
    }
  };
}
