// Package conn implements the per-connection goroutine pair (readPump /
// writePump), the ConnectionManager, and buffer pooling for the Flicko
// WebSocket gateway.
//
// Each authenticated client gets:
//   - 1 readPump goroutine  — reads WS frames, rate-limits, dispatches
//   - 1 writePump goroutine — drains send channel, coalesces writes, pings
//
// Both goroutines exit cleanly when the connection closes or the
// Manager unregisters the client.
package conn

import (
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"
	"golang.org/x/time/rate"

	"github.com/flicko-org/flicko/services/ws-gateway/internal/protocol"
)

// Wire-protocol constants from Production-Architecture.md §3.3.
const (
	WriteWait      = 10 * time.Second // Max time to write a frame.
	PongWait       = 60 * time.Second // Deadline for next pong.
	PingPeriod     = 54 * time.Second // Must be < PongWait.
	MaxMessageSize = 4096             // Max inbound frame bytes.
	SendChanSize   = 256              // Buffered outbound channel.

	// DefaultWSRate is the per-client message rate (messages/sec).
	DefaultWSRate = 10
	// DefaultWSBurst is the per-client burst allowance.
	DefaultWSBurst = 20
	// MaxConsecutiveRateLimited is the threshold after which a client
	// is assumed to be a misbehaving bot and forcibly disconnected.
	MaxConsecutiveRateLimited = 50
)

// newline separates coalesced messages in a single WS write.
var newline = []byte{'\n'}

// Client represents a single authenticated WebSocket connection.
type Client struct {
	// ID is a unique session identifier (ULID).
	ID string

	// SessionID allows a disconnecting client to resume previous subscriptions.
	SessionID string

	// UserID is the authenticated user's ID.
	UserID string

	Conn *websocket.Conn

	// Manager is the parent connection manager.
	Manager *Manager

	// Send is the buffered outbound message channel.
	// writePump reads from this. FanoutToChannel writes to it.
	Send chan []byte

	// Channels tracks which channel IDs this client is subscribed to.
	Channels map[string]bool

	// CreatedAt is the time the client connected.
	CreatedAt time.Time

	// limiter is the per-connection token-bucket rate limiter.
	limiter *rate.Limiter

	// consecutiveRL counts consecutive rate-limited messages.
	// Reset to 0 on any allowed message. When it reaches
	// MaxConsecutiveRateLimited the client is disconnected (bot detection).
	consecutiveRL int

	// Atomic counters for metrics.
	msgSent     atomic.Int64
	msgReceived atomic.Int64
	lastActive  atomic.Value // stores time.Time
}

// NewClient creates a Client ready for readPump/writePump.
func NewClient(id, sessionID, userID string, conn *websocket.Conn, mgr *Manager, rateLimit int, rateBurst int) *Client {
	c := &Client{
		ID:        id,
		SessionID: sessionID,
		UserID:    userID,
		Conn:      conn,
		Manager:   mgr,
		Send:      make(chan []byte, SendChanSize),
		Channels:  make(map[string]bool),
		CreatedAt: time.Now(),
		limiter:   rate.NewLimiter(rate.Limit(rateLimit), rateBurst),
	}
	c.lastActive.Store(time.Now())
	return c
}

// readPump runs in its own goroutine per connection.
// It reads messages from the WebSocket and dispatches to the Manager.
//
// Exit path: any read error (including clean close) triggers
// Manager.Unregister + Conn.Close. This is the ONLY goroutine that
// calls Unregister.
func (c *Client) ReadPump() {
	defer func() {
		c.Manager.Unregister(c)
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(MaxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(PongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(PongWait))
		c.lastActive.Store(time.Now())
		return nil
	})

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err,
				websocket.CloseGoingAway,
				websocket.CloseNormalClosure) {
				c.Manager.log.Warn("unexpected close",
					zap.Error(err),
					zap.String("user_id", c.UserID),
					zap.String("client_id", c.ID),
				)
			}
			return
		}

		// Rate limiting — send error frame but don't disconnect
		// (unless we detect a bot pattern).
		if !c.limiter.Allow() {
			c.consecutiveRL++
			c.sendError(protocol.ErrRateLimited)

			// Bot detection: too many consecutive rate-limited messages.
			if c.consecutiveRL >= MaxConsecutiveRateLimited {
				c.Manager.log.Warn("bot detected: consecutive rate limit exceeded",
					zap.String("user_id", c.UserID),
					zap.String("client_id", c.ID),
					zap.Int("consecutive", c.consecutiveRL),
				)
				return // triggers deferred Unregister + Close
			}
			continue
		}

		// Allowed message resets the bot-detection counter.
		c.consecutiveRL = 0

		c.msgReceived.Add(1)
		c.lastActive.Store(time.Now())

		// Parse and route to manager.
		c.Manager.HandleInbound(c, message)
	}
}

// writePump runs in its own goroutine per connection.
// It drains the Send channel and writes to the WebSocket.
//
// MESSAGE COALESCING: after writing one message, it drains
// len(c.Send) additional messages into the same write frame,
// separated by newlines. This is critical for throughput in
// hot channels.
//
// Exit path: Send channel closed (by Manager) or write error.
func (c *Client) WritePump() {
	ticker := time.NewTicker(PingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(WriteWait))
			if !ok {
				// Manager closed the channel — send close frame.
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Batch: drain send channel into single write frame.
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write(newline)
				w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

			c.msgSent.Add(int64(1 + n))

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(WriteWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// sendError writes a protocol error frame to the client's Send channel.
// Non-blocking: if Send is full the error is dropped (the slow-consumer
// path will handle disconnection).
func (c *Client) sendError(closeErr *protocol.CloseError) {
	raw, err := protocol.NewErrorMessage(closeErr.Code, closeErr.Text, protocol.IsRetryableClose(closeErr.Code))
	if err != nil {
		return
	}
	select {
	case c.Send <- raw:
	default:
		// Send buffer full — drop the error frame.
	}
}

// MsgSent returns the total messages written by this client.
func (c *Client) MsgSent() int64 { return c.msgSent.Load() }

// MsgReceived returns the total messages read from this client.
func (c *Client) MsgReceived() int64 { return c.msgReceived.Load() }

// LastActive returns the time of the last client activity.
func (c *Client) LastActive() time.Time {
	if t, ok := c.lastActive.Load().(time.Time); ok {
		return t
	}
	return c.CreatedAt
}
