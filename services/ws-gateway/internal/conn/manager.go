package conn

import (
	"context"
	crand "crypto/rand"
	"encoding/json"
	"math/big"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/ws-gateway/internal/protocol"
)

// Publisher is the interface for publishing messages to Redis Pub/Sub.
// Decouples the Manager from the pubsub package.
type Publisher interface {
	Publish(ctx context.Context, channelID string, message []byte) error
	PublishTyping(ctx context.Context, channelID string, payload []byte) error
}

// PresenceUpdater is the interface for updating user presence in Redis.
type PresenceUpdater interface {
	SetPresence(ctx context.Context, userID, status, gatewayID string) error
	SetTyping(ctx context.Context, channelID, userID string) error
	RefreshPresence(ctx context.Context, userID, gatewayID string) error
	RegisterSession(ctx context.Context, userID, gatewayID string) error
	UnregisterSession(ctx context.Context, userID, gatewayID string) error
}

// ChannelSubscriber is the interface for managing Redis Pub/Sub
// subscriptions. When the first local client subscribes to a channel
// we call Subscribe; when the last local client leaves we call
// Unsubscribe. This keeps the gateway subscribed only to channels it
// has active consumers for.
type ChannelSubscriber interface {
	Subscribe(ctx context.Context, topic string) error
	Unsubscribe(topic string) error
}

// MessageForwarder is the interface for forwarding WS message creates
// to the msg-service REST API. This ensures messages are persisted to
// PostgreSQL before any Pub/Sub publish happens.
type MessageForwarder interface {
	// ForwardMessage sends a message create request to msg-service.
	// Returns the created message ID or an error.
	ForwardMessage(ctx context.Context, channelID, authorID, content, nonce string) (messageID string, err error)
}

// channelClients holds a set of clients subscribed to a channel.
type channelClients struct {
	mu      sync.RWMutex
	clients map[string]*Client
}

// Manager is the central connection registry. It processes register /
// unregister events, maintains per-channel client sets, and handles
// inbound message routing.
//
// All mutation of the clients and channels maps flows through the
// register/unregister channels or sync.Map operations. Run() is the
// single event-loop goroutine that processes registrations.
type Manager struct {
	clients  sync.Map // map[string]*Client  (clientID → *Client)
	channels sync.Map // map[string]*channelClients
	sessions sync.Map // map[string][]string (sessionID -> channelIDs)

	register   chan *Client
	unregister chan *Client

	publisher  Publisher
	presence   PresenceUpdater
	subscriber ChannelSubscriber
	forwarder  MessageForwarder
	gatewayID  string
	log        *zap.Logger

	// Metrics counters.
	activeConns atomic.Int64
	totalConns  atomic.Int64
}

// NewManager creates a Manager ready for Run().
func NewManager(pub Publisher, pres PresenceUpdater, gatewayID string, log *zap.Logger) *Manager {
	m := &Manager{
		register:   make(chan *Client, 256),
		unregister: make(chan *Client, 256),
		publisher:  pub,
		presence:   pres,
		gatewayID:  gatewayID,
		log:        log.Named("manager"),
	}

	// HIGH-008: Start periodic cleanup of empty channel entries to prevent memory leaks
	go m.startCleanup(context.Background())

	return m
}

// SetSubscriber wires the ChannelSubscriber after construction.
// This breaks the circular dependency: Manager needs PubSub for
// Subscribe/Unsubscribe, PubSub needs Manager for FanoutToChannel.
func (m *Manager) SetSubscriber(cs ChannelSubscriber) {
	m.subscriber = cs
}

// SetForwarder wires the MessageForwarder for persist-before-publish flow.
func (m *Manager) SetForwarder(f MessageForwarder) {
	m.forwarder = f
}

// Run is the main event loop. It must be started as a goroutine.
// It exits cleanly when ctx is cancelled.
func (m *Manager) Run(ctx context.Context) {
	for {
		select {
		case client := <-m.register:
			m.clients.Store(client.ID, client)
			m.activeConns.Add(1)
			m.totalConns.Add(1)
			m.log.Info("client registered",
				zap.String("client_id", client.ID),
				zap.String("user_id", client.UserID),
			)
			if m.presence != nil {
				_ = m.presence.RegisterSession(context.Background(), client.UserID, m.gatewayID)
			}
			if client.SessionID != "" {
				if saved, ok := m.sessions.Load(client.SessionID); ok {
					for _, ch := range saved.([]string) {
						m.SubscribeToChannel(client, ch)
					}
				}
			}

		case client := <-m.unregister:
			if _, loaded := m.clients.LoadAndDelete(client.ID); loaded {
				close(client.Send)
				m.removeFromAllChannels(client)
				m.activeConns.Add(-1)
				m.log.Info("client unregistered",
					zap.String("client_id", client.ID),
					zap.String("user_id", client.UserID),
				)
				if m.presence != nil {
					// Only remove gateway affinity if this was the user's last connection on this gateway
					if m.CountUserClients(client.UserID) == 0 {
						_ = m.presence.UnregisterSession(context.Background(), client.UserID, m.gatewayID)
					}
				}
			}

		case <-ctx.Done():
			m.log.Info("manager shutting down")
			m.closeAll()
			return
		}
	}
}

// CountUserClients returns the number of active clients on this gateway for the given UserID.
func (m *Manager) CountUserClients(userID string) int {
	count := 0
	m.clients.Range(func(_, value interface{}) bool {
		c := value.(*Client)
		if c.UserID == userID {
			count++
		}
		return true
	})
	return count
}

// Register queues a client for registration.
func (m *Manager) Register(client *Client) {
	m.register <- client
}

// Unregister queues a client for unregistration.
func (m *Manager) Unregister(client *Client) {
	m.unregister <- client
}

// SubscribeToChannel adds a client to a channel's fan-out set.
// If this is the first local client for the channel the Manager also
// subscribes via Redis Pub/Sub (through the ChannelSubscriber).
func (m *Manager) SubscribeToChannel(client *Client, channelID string) {
	val, loaded := m.channels.LoadOrStore(channelID, &channelClients{
		clients: make(map[string]*Client),
	})
	cc := val.(*channelClients)

	cc.mu.Lock()
	cc.clients[client.ID] = client
	cc.mu.Unlock()

	client.Channels[channelID] = true

	if client.SessionID != "" {
		var newChannels []string
		if saved, ok := m.sessions.Load(client.SessionID); ok {
			newChannels = saved.([]string)
			found := false
			for _, c := range newChannels {
				if c == channelID {
					found = true
					break
				}
			}
			if !found {
				newChannels = append(newChannels, channelID)
			}
		} else {
			newChannels = []string{channelID}
		}
		m.sessions.Store(client.SessionID, newChannels)
	}

	// First local client → subscribe in Redis.
	if !loaded && m.subscriber != nil {
		if err := m.subscriber.Subscribe(context.Background(), channelID); err != nil {
			m.log.Error("pubsub subscribe",
				zap.String("channel_id", channelID),
				zap.Error(err),
			)
		}
	}

	m.log.Debug("channel subscribe",
		zap.String("client_id", client.ID),
		zap.String("channel_id", channelID),
	)
}

// UnsubscribeFromChannel removes a client from a channel's fan-out set.
// If this was the last local client for the channel the Manager also
// unsubscribes from Redis Pub/Sub.
func (m *Manager) UnsubscribeFromChannel(client *Client, channelID string) {
	val, ok := m.channels.Load(channelID)
	if !ok {
		return
	}
	cc := val.(*channelClients)

	cc.mu.Lock()
	delete(cc.clients, client.ID)
	empty := len(cc.clients) == 0
	cc.mu.Unlock()

	// Clean up empty channel entries.
	if empty {
		m.channels.Delete(channelID)

		// Last local client → unsubscribe from Redis.
		if m.subscriber != nil {
			if err := m.subscriber.Unsubscribe(channelID); err != nil {
				m.log.Error("pubsub unsubscribe",
					zap.String("channel_id", channelID),
					zap.Error(err),
				)
			}
		}
	}

	delete(client.Channels, channelID)

	if client.SessionID != "" {
		if saved, ok := m.sessions.Load(client.SessionID); ok {
			channels := saved.([]string)
			newChannels := []string{}
			for _, c := range channels {
				if c != channelID {
					newChannels = append(newChannels, c)
				}
			}
			if len(newChannels) > 0 {
				m.sessions.Store(client.SessionID, newChannels)
			} else {
				m.sessions.Delete(client.SessionID)
			}
		}
	}
}

// FanoutToChannel delivers a message to all clients in a channel.
//
// CRITICAL: Non-blocking send with slow consumer detection.
// If a client's Send channel is full (256 buffered messages),
// the client is disconnected — they can reconnect and fetch
// missed messages via the REST API.
func (m *Manager) FanoutToChannel(channelID string, message []byte, excludeClientID string) {
	val, ok := m.channels.Load(channelID)
	if !ok {
		return
	}
	cc := val.(*channelClients)

	cc.mu.RLock()
	defer cc.mu.RUnlock()

	for id, client := range cc.clients {
		if id == excludeClientID {
			continue
		}

		select {
		case client.Send <- message:
			// Delivered to buffer immediately.
		default:
			// SLOW CONSUMER: send channel full.
			// Try again with a grace period in a goroutine so we don't block the fanout loop.
			go func(c *Client, msg []byte) {
				timer := time.NewTimer(2 * time.Second)
				defer timer.Stop()

				select {
				case c.Send <- msg:
					// Delivered after a short delay.
				case <-timer.C:
					// Still full after grace period.
					// Disconnect — they'll reconnect and catch up via REST.
					m.log.Warn("slow consumer disconnected after grace period",
						zap.String("user_id", c.UserID),
						zap.String("channel_id", channelID),
					)
					m.unregister <- c
				}
			}(client, message)
		}
	}
}

// FanoutToUser delivers a message to all active client connections for a specific user ID on this gateway.
func (m *Manager) FanoutToUser(userID string, message []byte) {
	m.clients.Range(func(_, value interface{}) bool {
		c := value.(*Client)
		if c.UserID == userID {
			select {
			case c.Send <- message:
				// Delivered to buffer immediately.
			default:
				// Slow consumer: try in a goroutine with grace period.
				go func(client *Client, msg []byte) {
					timer := time.NewTimer(2 * time.Second)
					defer timer.Stop()

					select {
					case client.Send <- msg:
						// Delivered after short delay
					case <-timer.C:
						m.log.Warn("slow consumer disconnected after user fanout grace period",
							zap.String("user_id", client.UserID),
							zap.String("client_id", client.ID),
						)
						m.unregister <- client
					}
				}(c, message)
			}
		}
		return true
	})
}

func (m *Manager) HandleInbound(client *Client, msgData []byte) {
	var msg protocol.GatewayMessage
	err := json.Unmarshal(msgData, &msg)
	if err != nil {
		m.log.Debug("invalid frame", zap.Error(err), zap.String("client_id", client.ID))
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	switch msg.Op {
	case protocol.OpHeartbeat:
		m.handleHeartbeat(client)

	case protocol.OpMessageCreate:
		m.handleMessageCreate(client, &msg)

	case protocol.OpTypingStart:
		m.handleTypingStart(client, &msg)

	case protocol.OpChannelSub:
		m.handleChannelSub(client, &msg)

	case protocol.OpChannelUnsub:
		m.handleChannelUnsub(client, &msg)

	case protocol.OpPresenceUpdate:
		m.handlePresenceUpdate(client, &msg)

	default:
		m.log.Debug("unknown opcode",
			zap.Int("op", int(msg.Op)),
			zap.String("client_id", client.ID),
		)
		client.sendError(protocol.ErrInvalidPayload)
	}
}

// ── Inbound handlers ────────────────────────────────────────────────

func (m *Manager) handleHeartbeat(client *Client) {
	raw, err := protocol.NewHeartbeatAck()
	if err != nil {
		m.log.Error("encode heartbeat ack", zap.Error(err))
		return
	}
	select {
	case client.Send <- raw:
	default:
		// Slow consumer — will be caught by FanoutToChannel.
	}
}

func (m *Manager) handleMessageCreate(client *Client, msg *protocol.GatewayMessage) {
	payload, err := protocol.DecodePayload[protocol.MessagePayload](msg)
	if err != nil {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	if payload.ChannelID == "" || payload.Content == "" {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	// Stamp author on server side.
	payload.AuthorID = client.UserID

	// Forward to msg-service REST API for persist-before-publish flow.
	// The msg-service handles: validation → rate limit → DB write → Redis Pub/Sub publish.
	if m.forwarder != nil {
		msgID, err := m.forwarder.ForwardMessage(
			context.Background(),
			payload.ChannelID,
			client.UserID,
			payload.Content,
			msg.N,
		)
		if err != nil {
			m.log.Error("forward message to msg-service",
				zap.Error(err),
				zap.String("channel_id", payload.ChannelID),
				zap.String("user_id", client.UserID),
			)
			client.sendError(protocol.ErrInvalidPayload)
			return
		}

		// Send ACK with nonce + created message ID back to the sender.
		if msg.N != "" {
			ackRaw, err := protocol.NewAckMessage(msg.N, msgID)
			if err == nil {
				select {
				case client.Send <- ackRaw:
				default:
				}
			}
		}
		return
	}

	// Fallback: direct pub/sub publish (no DB persistence).
	// Used when msg-service forwarder is not configured.
	dispatchRaw, err := protocol.EncodeDispatch("MESSAGE_CREATE", 0, payload)
	if err != nil {
		m.log.Error("encode dispatch", zap.Error(err))
		return
	}

	if m.publisher != nil {
		if err := m.publisher.Publish(context.Background(), payload.ChannelID, dispatchRaw); err != nil {
			m.log.Error("redis publish", zap.Error(err), zap.String("channel_id", payload.ChannelID))
		}
	}

	if msg.N != "" {
		ackRaw, err := protocol.NewAckMessage(msg.N, "")
		if err == nil {
			select {
			case client.Send <- ackRaw:
			default:
			}
		}
	}
}

func (m *Manager) handleTypingStart(client *Client, msg *protocol.GatewayMessage) {
	payload, err := protocol.DecodePayload[protocol.TypingPayload](msg)
	if err != nil {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	if payload.ChannelID == "" {
		return
	}

	// Update Redis typing indicator (ephemeral, skip DB).
	if m.presence != nil {
		_ = m.presence.SetTyping(context.Background(), payload.ChannelID, client.UserID)
	}

	// Build dispatch for fan-out to other subscribers.
	payload.UserID = client.UserID
	dispatchRaw, err := protocol.EncodeDispatch("TYPING_START", 0, payload)
	if err != nil {
		return
	}

	// Publish to Redis Pub/Sub for cross-gateway delivery.
	// This ensures users on OTHER gateway instances see typing indicators.
	if m.publisher != nil {
		if err := m.publisher.PublishTyping(context.Background(), payload.ChannelID, dispatchRaw); err != nil {
			m.log.Warn("publish typing failed",
				zap.String("channel_id", payload.ChannelID),
				zap.Error(err),
			)
		}
	}

	// Also fan out to LOCAL channel clients, excluding the sender.
	m.FanoutToChannel(payload.ChannelID, dispatchRaw, client.ID)
}

func (m *Manager) handleChannelSub(client *Client, msg *protocol.GatewayMessage) {
	payload, err := protocol.DecodePayload[protocol.ChannelSubPayload](msg)
	if err != nil {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	if payload.ChannelID == "" {
		client.sendError(protocol.ErrInvalidChannel)
		return
	}

	m.SubscribeToChannel(client, payload.ChannelID)
}

func (m *Manager) handleChannelUnsub(client *Client, msg *protocol.GatewayMessage) {
	payload, err := protocol.DecodePayload[protocol.ChannelSubPayload](msg)
	if err != nil {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	if payload.ChannelID == "" {
		return
	}

	m.UnsubscribeFromChannel(client, payload.ChannelID)
}

func (m *Manager) handlePresenceUpdate(client *Client, msg *protocol.GatewayMessage) {
	payload, err := protocol.DecodePayload[protocol.PresencePayload](msg)
	if err != nil {
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	// Validate status.
	switch payload.Status {
	case "online", "idle", "dnd", "offline":
	default:
		client.sendError(protocol.ErrInvalidPayload)
		return
	}

	// Update Redis presence.
	if m.presence != nil {
		_ = m.presence.SetPresence(context.Background(), client.UserID, payload.Status, m.gatewayID)
	}

	// Fan out presence change to all channels the client is in.
	payload.UserID = client.UserID
	dispatchRaw, err := protocol.EncodeDispatch("PRESENCE_UPDATE", 0, payload)
	if err != nil {
		return
	}
	for channelID := range client.Channels {
		m.FanoutToChannel(channelID, dispatchRaw, client.ID)
	}
}

// ── Internal helpers ────────────────────────────────────────────────

// removeFromAllChannels unsubscribes a client from every channel.
func (m *Manager) removeFromAllChannels(client *Client) {
	for channelID := range client.Channels {
		m.UnsubscribeFromChannel(client, channelID)
	}
}

// closeAll disconnects every connected client with graceful connection draining.
// Called during shutdown to prevent a "thundering herd" reconnection storm.
func (m *Manager) closeAll() {
	m.log.Info("commencing graceful connection draining for active clients")

	var clientsToClose []*Client
	m.clients.Range(func(key, value interface{}) bool {
		clientsToClose = append(clientsToClose, value.(*Client))
		return true
	})

	if len(clientsToClose) == 0 {
		m.log.Info("no active clients to drain")
		return
	}

	const batchSize = 50
	const baseDelay = 100 * time.Millisecond

	for i, client := range clientsToClose {
		// Send CloseServiceRestart (1012) close control frame to prompt backoff reconnection
		msg := websocket.FormatCloseMessage(websocket.CloseServiceRestart, "Server is restarting, reconnecting with backoff...")
		_ = client.Conn.WriteControl(websocket.CloseMessage, msg, time.Now().Add(500*time.Millisecond))

		close(client.Send)
		client.Conn.Close()
		m.clients.Delete(client.ID)
		m.activeConns.Add(-1)

		// Introduce randomized batch delays to space out reconnect requests
		if (i+1)%batchSize == 0 {
			jitterVal, err := crand.Int(crand.Reader, big.NewInt(50))
			jitterMs := int64(25)
			if err == nil {
				jitterMs = jitterVal.Int64()
			}
			jitter := time.Duration(jitterMs) * time.Millisecond
			time.Sleep(baseDelay + jitter)
		}
	}
	m.log.Info("graceful connection draining complete", zap.Int("total_drained", len(clientsToClose)))
}

// ActiveConnections returns the current connection count.
func (m *Manager) ActiveConnections() int64 {
	return m.activeConns.Load()
}

// TotalConnections returns the lifetime connection count.
func (m *Manager) TotalConnections() int64 {
	return m.totalConns.Load()
}

// RangeClients calls fn with each connected user's ID. Used by the
// presence heartbeat loop to refresh TTLs. fn must not block.
func (m *Manager) RangeClients(fn func(userID string)) {
	seen := make(map[string]struct{})
	m.clients.Range(func(_, value interface{}) bool {
		c := value.(*Client)
		if _, ok := seen[c.UserID]; !ok {
			seen[c.UserID] = struct{}{}
			fn(c.UserID)
		}
		return true
	})
}

// startCleanup periodically removes empty channel entries to prevent memory leaks (HIGH-008).
func (m *Manager) startCleanup(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			m.cleanupEmptyChannels()
		case <-ctx.Done():
			return
		}
	}
}

// cleanupEmptyChannels removes channelClients entries with zero clients.
func (m *Manager) cleanupEmptyChannels() {
	var cleaned int
	m.channels.Range(func(key, value interface{}) bool {
		cc := value.(*channelClients)

		cc.mu.RLock()
		isEmpty := len(cc.clients) == 0
		cc.mu.RUnlock()

		if isEmpty {
			m.channels.Delete(key)
			cleaned++
		}

		return true
	})

	if cleaned > 0 {
		m.log.Debug("cleaned up empty channels", zap.Int("count", cleaned))
	}
}
