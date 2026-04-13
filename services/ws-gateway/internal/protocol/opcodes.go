// Package protocol is the ws-gateway's internal API for the Flicko
// WebSocket wire protocol.
//
// It re-exports the canonical types from shared/protocol (opcodes,
// payloads, close codes) and layers on gateway-specific concerns:
// frame-size enforcement, convenience Encode/Decode functions, and
// the CloseError type used by the connection writer.
//
// Gateway code imports this ONE package — never shared/protocol
// directly — so the gateway's protocol surface is explicit.
package protocol

import (
	proto "github.com/flicko-org/flicko/services/shared/protocol"
)

// OpCode is the numeric operation code for every WebSocket frame.
// Values match the Production-Architecture.md §3.8 exactly.
type OpCode = proto.OpCode

// Client → Server and Server → Client operation codes.
const (
	OpDispatch       = proto.OpDispatch       // 0  — Server → Client: event delivery
	OpHeartbeat      = proto.OpHeartbeat      // 1  — Client → Server: keep-alive
	OpIdentify       = proto.OpIdentify       // 2  — Client → Server: auth on connect
	OpPresenceUpdate = proto.OpPresenceUpdate // 3  — Bidirectional: status change
	OpTypingStart    = proto.OpTypingStart    // 4  — Client → Server: typing indicator
	OpMessageCreate  = proto.OpMessageCreate  // 5  — Client → Server: send message
	OpMessageAck     = proto.OpMessageAck     // 6  — Server → Client: delivery ack
	OpError          = proto.OpError          // 7  — Server → Client: error
	OpChannelSub     = proto.OpChannelSub     // 8  — Client → Server: subscribe
	OpChannelUnsub   = proto.OpChannelUnsub   // 9  — Client → Server: unsubscribe
	OpReady          = proto.OpReady          // 10 — Server → Client: post-identify
)
