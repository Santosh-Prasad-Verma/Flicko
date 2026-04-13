// ============================================================================
// Flicko — WebSocket Protocol Types (TypeScript)
// ============================================================================
// Mirrors services/shared/protocol/*.go exactly.
// Every OpCode, payload struct, and close code from the Go gateway.
// ============================================================================

// ── OpCodes ─────────────────────────────────────────────────────────────────

/** Wire op-codes — must stay in sync with shared/protocol/opcodes.go */
export enum OpCode {
  /** Server → Client: event delivery */
  Dispatch = 0,
  /** Bidirectional: keep-alive heartbeat */
  Heartbeat = 1,
  /** Client → Server: first message after WS open (JWT auth) */
  Identify = 2,
  /** Bidirectional: online / idle / dnd / offline */
  PresenceUpdate = 3,
  /** Client → Server: user started typing */
  TypingStart = 4,
  /** Client → Server: send a chat message */
  MessageCreate = 5,
  /** Server → Client: delivery confirmation */
  MessageAck = 6,
  /** Server → Client: error response */
  Error = 7,
  /** Client → Server: subscribe to channel */
  ChannelSub = 8,
  /** Client → Server: unsubscribe from channel */
  ChannelUnsub = 9,
  /** Server → Client: post-identify success */
  Ready = 10,
}

// ── Gateway envelope ────────────────────────────────────────────────────────

/** Top-level wire frame for every WebSocket message (matches GatewayMessage). */
export interface GatewayMessage<D = unknown> {
  /** Operation code */
  op: OpCode;
  /** Payload (shape depends on op/t) */
  d: D;
  /** Sequence number (dispatch only, for resume) */
  s?: number;
  /** Event type string (dispatch only, e.g. "MESSAGE_CREATE") */
  t?: string;
  /** Idempotency nonce */
  n?: string;
}

// ── Payloads ────────────────────────────────────────────────────────────────

/** Client → Server: sent immediately after WS open */
export interface IdentifyPayload {
  token: string;
  device_id: string;
}

/** Server → Client: response to successful Identify */
export interface ReadyPayload {
  session_id: string;
  user_id: string;
  guilds: string[];
  resume_url?: string;
}

/** Bidirectional message payload */
export interface MessagePayload {
  id?: string;
  channel_id: string;
  author_id?: string;
  content: string;
  nonce: string;
  timestamp?: number;
  attachments?: AttachmentPayload[];
}

export interface AttachmentPayload {
  id: string;
  filename: string;
  content_type: string;
  size: number;
  url: string;
}

/** Typing indicator */
export interface TypingPayload {
  channel_id: string;
  user_id?: string;
  timestamp: number;
}

/** Presence status change */
export interface PresencePayload {
  user_id: string;
  status: 'online' | 'idle' | 'dnd' | 'offline';
  last_seen?: number;
}

/** Channel subscription */
export interface ChannelSubPayload {
  channel_id: string;
}

/** Server → Client error */
export interface ErrorPayload {
  code: number;
  message: string;
  retry: boolean;
}

/** Server → Client delivery confirmation */
export interface AckPayload {
  nonce: string;
  message_id: string;
}

// ── Close codes (mirrors shared/protocol/errors.go) ─────────────────────────

export enum CloseCode {
  UnknownError = 4000,
  InvalidPayload = 4001,
  NotAuthenticated = 4003,
  AuthFailed = 4004,
  AlreadyAuthenticated = 4005,
  RateLimited = 4008,
  SessionTimeout = 4009,
  InvalidChannel = 4010,
  ServerFull = 4011,
}

/** Close codes where reconnecting is pointless (need new auth, etc.) */
export const NON_RETRYABLE_CODES = new Set<number>([
  CloseCode.AuthFailed,
  CloseCode.NotAuthenticated,
  CloseCode.AlreadyAuthenticated,
  CloseCode.ServerFull,
]);

// ── Dispatch event names (t field on OpCode.Dispatch) ───────────────────────

export enum DispatchEvent {
  MessageCreate = 'MESSAGE_CREATE',
  MessageUpdate = 'MESSAGE_UPDATE',
  MessageDelete = 'MESSAGE_DELETE',
  TypingStart = 'TYPING_START',
  PresenceUpdate = 'PRESENCE_UPDATE',
  ChannelUpdate = 'CHANNEL_UPDATE',
  MemberJoin = 'MEMBER_JOIN',
  MemberLeave = 'MEMBER_LEAVE',
}

// ── Connection state ────────────────────────────────────────────────────────

export type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'resuming';

// ── Client event map (for the EventEmitter) ─────────────────────────────────

export interface WSEventMap {
  message: MessagePayload;
  typing: TypingPayload;
  presence: PresencePayload;
  connected: ReadyPayload;
  disconnected: { code: number; reason: string };
  error: ErrorPayload;
  connection_failed: { attempts: number };
}
