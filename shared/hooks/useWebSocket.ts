// ============================================================================
// useWebSocket — React hook for the Flicko WS gateway
// ============================================================================
// Connects on mount, disconnects on unmount, and handles token refresh.
// Returns stable references that never change identity between renders.
// ============================================================================

import { useEffect, useRef, useCallback, useSyncExternalStore } from 'react';
import { useAuthStore } from '../stores/authStore';
import { WebSocketManager, wsManager } from '../services/ws/WebSocketManager';
import type { ConnectionState, WSEventMap } from '../services/ws/types';

// ── Gateway URL ─────────────────────────────────────────────────────────────
// In production the URL comes from ReadyPayload.resume_url or env.
// For dev / mobile, default to the same host that served the bundle.
const WS_URL =
  (typeof process !== 'undefined' && process.env?.EXPO_PUBLIC_WS_URL) ||
  'wss://flicko.dev/ws';

// ── Thin external-store adapter for connectionState ─────────────────────────
// React 18's useSyncExternalStore gives us tear-free reads of the WS state.

let _stateSnapshot: ConnectionState = wsManager.connectionState;

function subscribeToState(onStoreChange: () => void): () => void {
  const unsubs = [
    wsManager.on('connected', () => {
      _stateSnapshot = 'connected';
      onStoreChange();
    }),
    wsManager.on('disconnected', () => {
      _stateSnapshot = 'disconnected';
      onStoreChange();
    }),
  ];
  return () => unsubs.forEach((u) => u());
}

function getStateSnapshot(): ConnectionState {
  return _stateSnapshot;
}

// ── Hook ────────────────────────────────────────────────────────────────────

export interface UseWebSocket {
  /** Current connection state. */
  connectionState: ConnectionState;
  /** Send a message; resolves with server ACK. */
  sendMessage: typeof wsManager.sendMessage;
  /** Subscribe to a channel's events. */
  subscribe: typeof wsManager.subscribe;
  /** Unsubscribe from a channel. */
  unsubscribe: typeof wsManager.unsubscribe;
  /** Send a typing indicator (auto-throttled). */
  sendTyping: typeof wsManager.sendTyping;
  /** Register a WS event listener; returns unsubscribe. */
  on: typeof wsManager.on;
}

export function useWebSocket(): UseWebSocket {
  const session = useAuthStore((s: any) => s.session);
  const token = session?.access_token ?? null;
  const prevTokenRef = useRef<string | null>(null);

  // ── Connect / disconnect lifecycle ──────────────────────────────────────
  useEffect(() => {
    if (!token) {
      wsManager.disconnect();
      prevTokenRef.current = null;
      return;
    }

    // Token changed while connected → reconnect with new token
    if (prevTokenRef.current && prevTokenRef.current !== token) {
      prevTokenRef.current = token;
      wsManager.reconnect();
      return;
    }

    prevTokenRef.current = token;

    wsManager.connect(WS_URL, token).catch((_err: unknown) => {
      console.error('[useWebSocket] Connection failed:', _err);
    });

    return () => {
      // Component unmounting → disconnect
      wsManager.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  // ── Reactive connection state ───────────────────────────────────────────
  const connectionState = useSyncExternalStore(
    subscribeToState,
    getStateSnapshot,
    getStateSnapshot, // SSR snapshot (same for RN)
  );

  // ── Stable method references ────────────────────────────────────────────
  const sendMessage = useCallback(
    (channelId: string, content: string, nonce?: string) =>
      wsManager.sendMessage(channelId, content, nonce),
    [],
  );
  const subscribe = useCallback(
    (channelId: string) => wsManager.subscribe(channelId),
    [],
  );
  const unsubscribe = useCallback(
    (channelId: string) => wsManager.unsubscribe(channelId),
    [],
  );
  const sendTyping = useCallback(
    (channelId: string) => wsManager.sendTyping(channelId),
    [],
  );
  const on = useCallback(
    <K extends keyof WSEventMap>(
      event: K,
      handler: (data: WSEventMap[K]) => void,
    ) => wsManager.on(event, handler),
    [],
  );

  return {
    connectionState,
    sendMessage,
    subscribe,
    unsubscribe,
    sendTyping,
    on,
  };
}
