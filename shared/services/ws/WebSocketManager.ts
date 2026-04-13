// ============================================================================
// Flicko — WebSocket Client Manager (Singleton)
// ============================================================================
// Manages the full WS lifecycle: connect → identify → heartbeat → dispatch.
// Mirrors the Flicko gateway protocol (services/shared/protocol).
//
// Features:
//   • Exponential-backoff reconnect with jitter
//   • Heartbeat (54s send, 10s ack deadline)
//   • Channel subscription tracking + resubscribe on reconnect
//   • Promise-based message sending with ACK resolution
//   • Typed event emitter
//   • Per-channel typing throttle (5 s)
// ============================================================================

import { Platform } from 'react-native';
import * as Crypto from 'expo-crypto';
import {
  type GatewayMessage,
  type IdentifyPayload,
  type ReadyPayload,
  type MessagePayload,
  type TypingPayload,
  type PresencePayload,
  type ChannelSubPayload,
  type ErrorPayload,
  type AckPayload,
  type ConnectionState,
  type WSEventMap,
  OpCode,
  CloseCode,
  DispatchEvent,
  NON_RETRYABLE_CODES,
} from './types';

// ── Helpers ─────────────────────────────────────────────────────────────────

/** Generate a ULID-ish nonce (26-char Crockford base32 via random bytes). */
function generateNonce(): string {
  // Use expo-crypto for RN-safe randomness; falls back to Math.random UUIDs
  // only if unavailable (never in practice on RN ≥ 0.70).
  return Crypto.randomUUID();
}

// ── Tiny typed EventEmitter ─────────────────────────────────────────────────

type Handler<T = unknown> = (data: T) => void;

class Emitter<M extends Record<string, any>> {
  private _listeners = new Map<keyof M, Set<Handler<any>>>();

  on<K extends keyof M>(event: K, fn: Handler<M[K]>): () => void {
    if (!this._listeners.has(event)) this._listeners.set(event, new Set());
    this._listeners.get(event)!.add(fn);
    return () => {
      this._listeners.get(event)?.delete(fn);
    };
  }

  emit<K extends keyof M>(event: K, data: M[K]): void {
    this._listeners.get(event)?.forEach((fn) => {
      try {
        fn(data);
      } catch (e) {
        console.error(`[WS] event handler error (${String(event)}):`, e);
      }
    });
  }

  removeAll(): void {
    this._listeners.clear();
  }
}

// ── Pending ACK tracker ─────────────────────────────────────────────────────

interface PendingAck {
  resolve: (ack: AckPayload) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

// ── Constants ───────────────────────────────────────────────────────────────

const HEARTBEAT_INTERVAL_MS = 54_000; // Must match server PingPeriod (54 s)
const HEARTBEAT_TIMEOUT_MS = 10_000; // If no pong in 10 s → dead
const ACK_TIMEOUT_MS = 10_000; // Message ACK deadline
const TYPING_THROTTLE_MS = 5_000; // Per-channel typing cooldown

// Reconnect backoff
const BACKOFF_INITIAL_MS = 1_000;
const BACKOFF_MAX_MS = 30_000;
const BACKOFF_MULTIPLIER = 2;
const BACKOFF_JITTER_MS = 500;
const MAX_RECONNECT_ATTEMPTS = 5;

// ── MED-006: Reconnect state persistence interface ──────────────────────────

/**
 * Optional storage adapter for persisting reconnect state across app restarts.
 * On mobile, implement this with AsyncStorage. On web, localStorage suffices.
 */
export interface ReconnectPersistence {
  getFailureCount(): Promise<number>;
  setFailureCount(count: number): Promise<void>;
  getLastFailureTimestamp(): Promise<number | null>;
  setLastFailureTimestamp(ts: number): Promise<void>;
  clear(): Promise<void>;
}

/** Duration after which persisted failure count resets (5 minutes). */
const RECONNECT_STATE_EXPIRY_MS = 5 * 60 * 1_000;

// ── WebSocketManager ────────────────────────────────────────────────────────

export class WebSocketManager {
  // ── Singleton ───────────────────────────────────────────────────────────
  private static _instance: WebSocketManager | null = null;

  static get instance(): WebSocketManager {
    if (!WebSocketManager._instance) {
      WebSocketManager._instance = new WebSocketManager();
    }
    return WebSocketManager._instance;
  }

  /** Destroy the singleton (tests / hot-reload). */
  static reset(): void {
    WebSocketManager._instance?.destroy();
    WebSocketManager._instance = null;
  }

  // ── State ───────────────────────────────────────────────────────────────
  private _ws: WebSocket | null = null;
  private _state: ConnectionState = 'disconnected';
  private _sessionId: string | null = null;
  private _sequence = 0;

  // Connection params (kept for reconnect)
  private _url: string | null = null;
  private _token: string | null = null;

  // Heartbeat
  private _heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private _heartbeatAckTimer: ReturnType<typeof setTimeout> | null = null;
  private _awaitingHeartbeatAck = false;

  // CRIT-005: Identify timeout
  private _identifyTimeout: ReturnType<typeof setTimeout> | null = null;

  // HIGH-001: State lock to prevent race conditions
  private _stateLock = false;

  // Reconnect
  private _reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private _reconnectAttempts = 0;
  private _intentionalClose = false;

  // MED-006: Optional persistence adapter for cross-session reconnect state
  private _reconnectPersistence: ReconnectPersistence | null = null;

  // Subscriptions
  private _subscribedChannels = new Set<string>();

  // Pending message ACKs keyed by nonce
  private _pendingAcks = new Map<string, PendingAck>();

  // Typing throttle: channelId → last-sent timestamp
  private _typingThrottles = new Map<string, number>();

  // Event bus
  private _emitter = new Emitter<WSEventMap>();

  // ── Public getters ──────────────────────────────────────────────────────

  get connectionState(): ConnectionState {
    return this._state;
  }
  get sessionId(): string | null {
    return this._sessionId;
  }
  get sequence(): number {
    return this._sequence;
  }

  // HIGH-001: Async lock to prevent race conditions in connect/disconnect
  private async _withLock<T>(fn: () => Promise<T>): Promise<T> {
    while (this._stateLock) {
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    this._stateLock = true;
    try {
      return await fn();
    } finally {
      this._stateLock = false;
    }
  }

  // ── Connection lifecycle ────────────────────────────────────────────────

  /**
   * Open a WebSocket and authenticate.
   * Resolves when OpReady is received; rejects on auth failure or timeout.
   * HIGH-001: Wrapped in state lock to prevent race conditions.
   */
  connect(url: string, token: string): Promise<void> {
    return this._withLock(async () => {
      // MED-006: Load persisted reconnect state from previous session
      await this._loadPersistedReconnectState();

      // Already connected / connecting with same params
      if (
        this._ws &&
        (this._state === 'connected' || this._state === 'connecting') &&
        this._url === url &&
        this._token === token
      ) {
        return Promise.resolve();
      }

      // Tear down any existing socket first
      this._cleanupSocket();

      this._url = url;
      this._token = token;
      this._intentionalClose = false;
      this._setState('connecting');

      return new Promise<void>((resolve, reject) => {
        const ws = new WebSocket(url);
        this._ws = ws;

        // Timeout the entire handshake after 15 s
        const handshakeTimeout = setTimeout(() => {
          reject(new Error('WebSocket handshake timed out'));
          this._cleanupSocket();
        }, 15_000);

        ws.onopen = () => {
          // CRIT-005: Set identify timeout - reject if no OpReady within 10s
          this._identifyTimeout = setTimeout(() => {
            reject(new Error('OpIdentify timeout - no OpReady received'));
            this._cleanupSocket();
          }, 10_000);

          // Immediately send OpIdentify
          this._send<IdentifyPayload>({
            op: OpCode.Identify,
            d: {
              token,
              device_id: `${Platform.OS}-${Platform.Version}`,
            },
          });
        };

      ws.onmessage = (event: { data: string }) => {
        const msg = this._parse(event.data);
        if (!msg) return;

        // During handshake, intercept Ready / Error
        if (this._state === 'connecting' || this._state === 'resuming') {
          if (msg.op === OpCode.Ready) {
            clearTimeout(handshakeTimeout);
            this._handleReady(msg.d as ReadyPayload);
            resolve();
            return;
          }
          if (msg.op === OpCode.Error) {
            clearTimeout(handshakeTimeout);
            const err = msg.d as ErrorPayload;
            reject(new Error(`Auth error ${err.code}: ${err.message}`));
            this._cleanupSocket();
            return;
          }
        }

        this._handleMessage(msg);
      };

      ws.onerror = () => {
        // onerror is always followed by onclose in RN; real handling there.
      };

      ws.onclose = (event: { code: number; reason?: string }) => {
        clearTimeout(handshakeTimeout);
        // CRIT-005: Clear identify timeout on close
        if (this._identifyTimeout) {
          clearTimeout(this._identifyTimeout);
          this._identifyTimeout = null;
        }

        const wasConnected = this._state === 'connected';
        this._setState('disconnected');
        this._stopHeartbeat();

        this._emitter.emit('disconnected', {
          code: event.code,
          reason: event.reason ?? '',
        });

        if (!this._intentionalClose && wasConnected) {
          this._scheduleReconnect();
        }

        // If we were still in the handshake, reject the connect promise
        if (this._state !== 'connected') {
          reject(new Error(`WebSocket closed: ${event.code} ${event.reason}`));
        }
      };
    });
    }); // end _withLock
  }

  /** Gracefully close the socket. No auto-reconnect. */
  disconnect(): void {
    this._intentionalClose = true;
    this._cleanupSocket();
    this._clearReconnect();
    this._setState('disconnected');
    this._sessionId = null;
    this._sequence = 0;
    this._subscribedChannels.clear();
    this._rejectAllPending('Disconnected');
  }

  /** Force a reconnect cycle (e.g. after token refresh). */
  reconnect(): void {
    if (!this._url || !this._token) return;
    this._intentionalClose = true; // suppress auto-reconnect from close
    this._cleanupSocket();
    this._intentionalClose = false;
    this._reconnectAttempts = 0;
    this._doReconnect();
  }

  /** Tear everything down (singleton reset / unmount). */
  destroy(): void {
    this.disconnect();
    this._emitter.removeAll();
    this._typingThrottles.clear();
  }

  /**
   * MED-006: Set a persistence adapter for cross-session reconnect state.
   * Call this early (e.g. at app startup) before connect().
   */
  setReconnectPersistence(persistence: ReconnectPersistence): void {
    this._reconnectPersistence = persistence;
  }

  // ── Message sending ─────────────────────────────────────────────────────

  /**
   * Send a chat message and wait for the server ACK.
   * Rejects after 10 s if no ACK received.
   */
  sendMessage(
    channelId: string,
    content: string,
    nonce?: string,
  ): Promise<AckPayload> {
    // HIGH-009: Validate message size before sending
    const MAX_MESSAGE_BYTES = 4096;
    const contentBytes = new TextEncoder().encode(content).length;

    if (contentBytes > MAX_MESSAGE_BYTES) {
      return Promise.reject(
        new Error(`Message too large: ${contentBytes} bytes (max ${MAX_MESSAGE_BYTES})`)
      );
    }

    if (content.trim().length === 0) {
      return Promise.reject(new Error('Message cannot be empty'));
    }

    const actualNonce = nonce ?? generateNonce();

    return new Promise<AckPayload>((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pendingAcks.delete(actualNonce);
        reject(new TimeoutError(`ACK timeout for nonce ${actualNonce}`));
      }, ACK_TIMEOUT_MS);

      this._pendingAcks.set(actualNonce, { resolve, reject, timer });

      const payload: MessagePayload = {
        channel_id: channelId,
        content: content.trim(),
        nonce: actualNonce,
      };

      this._send<MessagePayload>({
        op: OpCode.MessageCreate,
        d: payload,
        n: actualNonce,
      });
    });
  }

  // ── Channel subscriptions ───────────────────────────────────────────────

  subscribe(channelId: string): void {
    this._subscribedChannels.add(channelId);
    if (this._state === 'connected') {
      this._send<ChannelSubPayload>({
        op: OpCode.ChannelSub,
        d: { channel_id: channelId },
      });
    }
  }

  unsubscribe(channelId: string): void {
    this._subscribedChannels.delete(channelId);
    if (this._state === 'connected') {
      this._send<ChannelSubPayload>({
        op: OpCode.ChannelUnsub,
        d: { channel_id: channelId },
      });
    }
  }

  // ── Typing ──────────────────────────────────────────────────────────────

  /** Send a typing indicator (throttled to once per 5 s per channel). */
  sendTyping(channelId: string): void {
    const now = Date.now();
    const last = this._typingThrottles.get(channelId) ?? 0;
    if (now - last < TYPING_THROTTLE_MS) return;

    this._typingThrottles.set(channelId, now);
    this._send<TypingPayload>({
      op: OpCode.TypingStart,
      d: {
        channel_id: channelId,
        timestamp: now,
      },
    });
  }

  // ── Presence ────────────────────────────────────────────────────────────

  updatePresence(status: PresencePayload['status']): void {
    this._send({
      op: OpCode.PresenceUpdate,
      d: { user_id: '', status, last_seen: Date.now() },
    });
  }

  // ── Event bus ─────────────────────────────────────────────────────────

  /** Subscribe to a client-side event. Returns unsubscribe function. */
  on<K extends keyof WSEventMap>(
    event: K,
    handler: (data: WSEventMap[K]) => void,
  ): () => void {
    return this._emitter.on(event, handler);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Private internals
  // ═════════════════════════════════════════════════════════════════════════

  // ── State transitions ───────────────────────────────────────────────────

  private _setState(s: ConnectionState): void {
    this._state = s;
  }

  // ── Handshake ───────────────────────────────────────────────────────────

  private _handleReady(payload: ReadyPayload): void {
    // CRIT-005: Clear identify timeout on successful ready
    if (this._identifyTimeout) {
      clearTimeout(this._identifyTimeout);
      this._identifyTimeout = null;
    }

    this._sessionId = payload.session_id;
    this._reconnectAttempts = 0;
    this._setState('connected');
    this._startHeartbeat();
    this._resubscribeAll();

    // MED-006: Clear persisted failure state on successful connection
    if (this._reconnectPersistence) {
      this._reconnectPersistence.clear().catch(() => {});
    }

    this._emitter.emit('connected', payload);
  }

  // ── Incoming message router ─────────────────────────────────────────────

  private _handleMessage(msg: GatewayMessage): void {
    switch (msg.op) {
      case OpCode.Dispatch:
        this._handleDispatch(msg);
        break;
      case OpCode.Heartbeat:
        // Server is pinging us — reply immediately
        this._sendHeartbeat();
        break;
      case OpCode.MessageAck:
        this._handleAck(msg.d as AckPayload);
        break;
      case OpCode.Error:
        this._handleError(msg.d as ErrorPayload);
        break;
      case OpCode.Ready:
        // Already handled in connect() promise; but if we get a late one:
        this._handleReady(msg.d as ReadyPayload);
        break;
      default:
        break;
    }
  }

  private _handleDispatch(msg: GatewayMessage): void {
    // Track sequence for future resume
    if (msg.s !== undefined) {
      this._sequence = msg.s;
    }

    switch (msg.t) {
      case DispatchEvent.MessageCreate:
      case DispatchEvent.MessageUpdate:
      case DispatchEvent.MessageDelete:
        this._emitter.emit('message', msg.d as MessagePayload);
        break;
      case DispatchEvent.TypingStart:
        this._emitter.emit('typing', msg.d as TypingPayload);
        break;
      case DispatchEvent.PresenceUpdate:
        this._emitter.emit('presence', msg.d as PresencePayload);
        break;
      default:
        // Unknown dispatch — ignore (forward-compatible)
        break;
    }
  }

  private _handleAck(ack: AckPayload): void {
    const pending = this._pendingAcks.get(ack.nonce);
    if (!pending) return;
    clearTimeout(pending.timer);
    this._pendingAcks.delete(ack.nonce);
    pending.resolve(ack);
  }

  private _handleError(err: ErrorPayload): void {
    this._emitter.emit('error', err);

    if (!err.retry) {
      // Fatal error — close without reconnect
      this._intentionalClose = true;
      this._ws?.close(CloseCode.UnknownError, err.message);
    }
  }

  // ── Heartbeat ───────────────────────────────────────────────────────────

  private _startHeartbeat(): void {
    this._stopHeartbeat();
    this._awaitingHeartbeatAck = false;

    this._heartbeatTimer = setInterval(() => {
      if (this._awaitingHeartbeatAck) {
        // Missed ack → consider dead
        console.warn('[WS] Heartbeat ACK missed — reconnecting');
        this._reconnectAfterDead();
        return;
      }
      this._sendHeartbeat();
      this._awaitingHeartbeatAck = true;

      this._heartbeatAckTimer = setTimeout(() => {
        if (this._awaitingHeartbeatAck) {
          console.warn('[WS] Heartbeat ACK timeout — reconnecting');
          this._reconnectAfterDead();
        }
      }, HEARTBEAT_TIMEOUT_MS);
    }, HEARTBEAT_INTERVAL_MS);
  }

  private _stopHeartbeat(): void {
    if (this._heartbeatTimer) {
      clearInterval(this._heartbeatTimer);
      this._heartbeatTimer = null;
    }
    if (this._heartbeatAckTimer) {
      clearTimeout(this._heartbeatAckTimer);
      this._heartbeatAckTimer = null;
    }
    this._awaitingHeartbeatAck = false;
  }

  private _sendHeartbeat(): void {
    this._awaitingHeartbeatAck = false; // reset on incoming heartbeat too
    this._send({ op: OpCode.Heartbeat, d: { sequence: this._sequence } });
  }

  /** Server-initiated heartbeat ack resets the flag. */
  private _onHeartbeatAck(): void {
    this._awaitingHeartbeatAck = false;
    if (this._heartbeatAckTimer) {
      clearTimeout(this._heartbeatAckTimer);
      this._heartbeatAckTimer = null;
    }
  }

  // ── Reconnect ─────────────────────────────────────────────────────────

  private _reconnectAfterDead(): void {
    this._intentionalClose = true; // suppress double-reconnect from onclose
    this._cleanupSocket();
    this._intentionalClose = false;
    this._scheduleReconnect();
  }

  private _scheduleReconnect(): void {
    if (this._reconnectTimer) return;

    this._reconnectAttempts++;

    // MED-006: Persist failure state for cross-session backoff
    if (this._reconnectPersistence) {
      this._reconnectPersistence.setFailureCount(this._reconnectAttempts).catch(() => {});
      this._reconnectPersistence.setLastFailureTimestamp(Date.now()).catch(() => {});
    }

    if (this._reconnectAttempts > MAX_RECONNECT_ATTEMPTS) {
      console.error(`[WS] Giving up after ${MAX_RECONNECT_ATTEMPTS} attempts`);
      this._emitter.emit('connection_failed', {
        attempts: this._reconnectAttempts,
      });
      return;
    }

    const base = Math.min(
      BACKOFF_INITIAL_MS * Math.pow(BACKOFF_MULTIPLIER, this._reconnectAttempts - 1),
      BACKOFF_MAX_MS,
    );
    const jitter = (Math.random() * 2 - 1) * BACKOFF_JITTER_MS;
    const delay = Math.max(0, base + jitter);

    console.log(
      `[WS] Reconnect attempt ${this._reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS} in ${Math.round(delay)} ms`,
    );

    this._reconnectTimer = setTimeout(() => {
      this._reconnectTimer = null;
      this._doReconnect();
    }, delay);
  }

  private async _doReconnect(): Promise<void> {
    if (!this._url || !this._token) return;
    this._setState('resuming');
    try {
      await this.connect(this._url, this._token);
    } catch {
      // connect() rejected — schedule another attempt
      this._scheduleReconnect();
    }
  }

  private _clearReconnect(): void {
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
    this._reconnectAttempts = 0;

    // MED-006: Clear persisted reconnect state on success or intentional disconnect
    if (this._reconnectPersistence) {
      this._reconnectPersistence.clear().catch(() => {});
    }
  }

  /**
   * MED-006: Load persisted reconnect state from a previous session.
   * If failures are recent (within RECONNECT_STATE_EXPIRY_MS), carry them
   * forward so we don't hammer the server after a restart-loop.
   */
  private async _loadPersistedReconnectState(): Promise<void> {
    if (!this._reconnectPersistence) return;
    try {
      const lastTs = await this._reconnectPersistence.getLastFailureTimestamp();
      if (lastTs && (Date.now() - lastTs) < RECONNECT_STATE_EXPIRY_MS) {
        const count = await this._reconnectPersistence.getFailureCount();
        if (count > 0) {
          this._reconnectAttempts = count;
          console.log(`[WS] Loaded persisted reconnect failures: ${count}`);
        }
      } else {
        // Stale data — clear it
        await this._reconnectPersistence.clear();
      }
    } catch {
      // Non-critical: start fresh
    }
  }

  // ── Resubscribe all channels after reconnect ──────────────────────────

  private _resubscribeAll(): void {
    for (const channelId of this._subscribedChannels) {
      this._send<ChannelSubPayload>({
        op: OpCode.ChannelSub,
        d: { channel_id: channelId },
      });
    }
  }

  // ── Low-level send / parse ────────────────────────────────────────────

  private _send<D = unknown>(msg: GatewayMessage<D>): void {
    if (!this._ws || this._ws.readyState !== WebSocket.OPEN) {
      console.warn('[WS] Tried to send on closed socket', OpCode[msg.op]);
      return;
    }
    this._ws.send(JSON.stringify(msg));
  }

  private _parse(raw: string | ArrayBuffer | Blob): GatewayMessage | null {
    try {
      if (typeof raw !== 'string') {
        // In React Native, we should always receive strings.
        // ArrayBuffer/Blob are unlikely but handled defensively.
        return null;
      }
      return JSON.parse(raw) as GatewayMessage;
    } catch {
      console.error('[WS] Failed to parse incoming frame');
      return null;
    }
  }

  // ── Socket cleanup ────────────────────────────────────────────────────

  private _cleanupSocket(): void {
    if (!this._ws) return;
    // Remove handlers so late-firing callbacks don't trip us
    this._ws.onopen = null;
    this._ws.onmessage = null;
    this._ws.onerror = null;
    this._ws.onclose = null;

    if (
      this._ws.readyState === WebSocket.OPEN ||
      this._ws.readyState === WebSocket.CONNECTING
    ) {
      this._ws.close(1000, 'Client disconnect');
    }
    this._ws = null;
    this._stopHeartbeat();
  }

  // ── Pending ACK cleanup ───────────────────────────────────────────────

  private _rejectAllPending(reason: string): void {
    for (const [nonce, pending] of this._pendingAcks) {
      clearTimeout(pending.timer);
      pending.reject(new Error(reason));
      this._pendingAcks.delete(nonce);
    }
  }
}

// ── Custom error class ──────────────────────────────────────────────────────

export class TimeoutError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TimeoutError';
  }
}

// ── Default singleton export ────────────────────────────────────────────────

export const wsManager = WebSocketManager.instance;
