// Package handler provides HTTP handlers for the Flicko WebSocket gateway.
//
// HandleWebSocket upgrades the HTTP connection, enforces a 5-second
// identify timeout, validates the JWT via shared/auth, and hands
// the connection off to the ConnectionManager.
package handler

import (
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/auth"
	"github.com/flicko-org/flicko/services/shared/id"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/conn"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/protocol"
)

// WSHandler holds the dependencies for the WebSocket upgrade handler.
type WSHandler struct {
	upgrader       websocket.Upgrader
	manager        *conn.Manager
	keySet         *auth.KeySet
	rateLimit      int
	rateBurst      int
	maxConns       int64
	allowedOrigins map[string]bool
	log            *zap.Logger
}

// NewWSHandler creates a WSHandler ready to accept connections.
// corsOrigins is a comma-separated list of allowed origins. Empty = allow all.
func NewWSHandler(
	mgr *conn.Manager,
	keySet *auth.KeySet,
	rateLimit, rateBurst int,
	maxConns int64,
	readBuf, writeBuf int,
	corsOrigins string,
	log *zap.Logger,
) *WSHandler {
	origins := make(map[string]bool)
	if corsOrigins != "" {
		for _, o := range strings.Split(corsOrigins, ",") {
			o = strings.TrimSpace(o)
			if o != "" {
				origins[strings.ToLower(o)] = true
			}
		}
	}

	h := &WSHandler{
		manager:        mgr,
		keySet:         keySet,
		rateLimit:      rateLimit,
		rateBurst:      rateBurst,
		maxConns:       maxConns,
		allowedOrigins: origins,
		log:            log.Named("ws"),
	}

	h.upgrader = websocket.Upgrader{
		ReadBufferSize:    readBuf,
		WriteBufferSize:   writeBuf,
		EnableCompression: true, // MED-016: permessage-deflate for bandwidth savings
		CheckOrigin:       h.checkOrigin,
	}

	return h
}

// checkOrigin validates the request origin against the allowed list.
// Returns true if no allowed origins are configured (dev mode) or if
// the request origin matches one of the allowed origins.
func (h *WSHandler) checkOrigin(r *http.Request) bool {
	if len(h.allowedOrigins) == 0 {
		return true // dev mode: allow all
	}
	origin := strings.ToLower(r.Header.Get("Origin"))
	return h.allowedOrigins[origin]
}

// ServeHTTP upgrades the connection and runs the identify flow.
//
// Protocol:
//  1. Upgrade to WebSocket.
//  2. Wait ≤5 s for OpIdentify carrying JWT.
//  3. Validate JWT via auth.IdentifyWithTimeout.
//  4. Register client in Manager, send OpReady.
//  5. Launch readPump + writePump goroutines.
//
// Any failure closes the socket with the appropriate 4xxx code.
func (h *WSHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// ── Connection limit ────────────────────────────────────
	if h.manager.ActiveConnections() >= h.maxConns {
		h.log.Warn("server full, rejecting connection")
		http.Error(w, "server full", http.StatusServiceUnavailable)
		return
	}

	// ── Upgrade ─────────────────────────────────────────────
	ws, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.log.Warn("upgrade failed", zap.Error(err))
		return // Upgrader already wrote HTTP error
	}

	// ── Identify within 5 s ─────────────────────────────────
	ws.SetReadDeadline(time.Now().Add(auth.IdentifyTimeout))

	_, raw, err := ws.ReadMessage()
	if err != nil {
		h.closeWithError(ws, protocol.ErrSessionTimeout)
		return
	}

	msg, err := protocol.Decode(raw)
	if err != nil {
		h.closeWithError(ws, protocol.ErrInvalidPayload)
		return
	}

	if msg.Op != protocol.OpIdentify {
		h.closeWithError(ws, protocol.ErrNotAuthenticated)
		return
	}

	identifyPayload, err := protocol.DecodePayload[protocol.IdentifyPayload](msg)
	if err != nil {
		h.closeWithError(ws, protocol.ErrInvalidPayload)
		return
	}

	// ── Validate JWT ────────────────────────────────────────
	// Convert protocol.IdentifyPayload → auth.IdentifyPayload.
	authPayload := auth.IdentifyPayload{
		Token:     identifyPayload.Token,
		SessionID: identifyPayload.SessionID,
		DeviceID:  identifyPayload.DeviceID,
	}

	claims, err := auth.ValidateIdentify(h.keySet, authPayload)
	if err != nil {
		h.log.Debug("identify failed", zap.Error(err))
		h.closeWithError(ws, protocol.ErrAuthFailed)
		return
	}

	// ── Create client ───────────────────────────────────────
	clientID := id.New()
	client := conn.NewClient(
		clientID,
		identifyPayload.SessionID,
		claims.Subject,
		ws,
		h.manager,
		h.rateLimit,
		h.rateBurst,
	)

	// ── Send Ready ──────────────────────────────────────────
	readyRaw, err := protocol.NewReadyMessage(identifyPayload.SessionID, claims.Subject, nil, "")
	if err != nil {
		h.log.Error("encode ready", zap.Error(err))
		h.closeWithError(ws, protocol.NewCloseError(protocol.CloseUnknownError))
		return
	}

	ws.SetWriteDeadline(time.Now().Add(conn.WriteWait))
	if err := ws.WriteMessage(websocket.TextMessage, readyRaw); err != nil {
		h.log.Warn("write ready failed", zap.Error(err))
		ws.Close()
		return
	}

	// Clear the read deadline — readPump will manage its own.
	ws.SetReadDeadline(time.Time{})

	// ── Register + start pumps ──────────────────────────────
	h.manager.Register(client)
	go client.WritePump()
	go client.ReadPump()

	h.log.Info("client connected",
		zap.String("client_id", clientID),
		zap.String("user_id", claims.Subject),
	)
}

// closeWithError sends a Close frame with the protocol close code
// and then closes the underlying connection.
func (h *WSHandler) closeWithError(ws *websocket.Conn, closeErr *protocol.CloseError) {
	closeMsg := websocket.FormatCloseMessage(closeErr.Code, closeErr.Text)
	ws.WriteControl(
		websocket.CloseMessage,
		closeMsg,
		time.Now().Add(conn.WriteWait),
	)
	ws.Close()
}
