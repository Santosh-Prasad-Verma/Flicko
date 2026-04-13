package protocol

import "testing"

func TestOpCode_String(t *testing.T) {
tests := []struct {
op   OpCode
want string
}{
{OpDispatch, "DISPATCH"},
{OpHeartbeat, "HEARTBEAT"},
{OpIdentify, "IDENTIFY"},
{OpPresenceUpdate, "PRESENCE_UPDATE"},
{OpTypingStart, "TYPING_START"},
{OpMessageCreate, "MESSAGE_CREATE"},
{OpMessageAck, "MESSAGE_ACK"},
{OpError, "ERROR"},
{OpChannelSub, "CHANNEL_SUB"},
{OpChannelUnsub, "CHANNEL_UNSUB"},
{OpReady, "READY"},
{OpCode(99), "UNKNOWN"},
}
for _, tc := range tests {
t.Run(tc.want, func(t *testing.T) {
got := tc.op.String()
if got != tc.want {
t.Errorf("OpCode(%d).String() = %q, want %q", tc.op, got, tc.want)
}
})
}
}

func TestOpCode_IsClientOp(t *testing.T) {
clientOps := []OpCode{
OpHeartbeat, OpIdentify, OpPresenceUpdate,
OpTypingStart, OpMessageCreate, OpChannelSub, OpChannelUnsub,
}
for _, op := range clientOps {
if !op.IsClientOp() {
t.Errorf("%s should be a client op", op)
}
}

nonClientOps := []OpCode{OpDispatch, OpMessageAck, OpError, OpReady}
for _, op := range nonClientOps {
if op.IsClientOp() {
t.Errorf("%s should NOT be a client op", op)
}
}
}

func TestOpCode_IsServerOp(t *testing.T) {
serverOps := []OpCode{
OpDispatch, OpMessageAck, OpError, OpReady, OpPresenceUpdate,
}
for _, op := range serverOps {
if !op.IsServerOp() {
t.Errorf("%s should be a server op", op)
}
}

nonServerOps := []OpCode{
OpHeartbeat, OpIdentify, OpTypingStart,
OpMessageCreate, OpChannelSub, OpChannelUnsub,
}
for _, op := range nonServerOps {
if op.IsServerOp() {
t.Errorf("%s should NOT be a server op", op)
}
}
}

func TestOpCode_Values(t *testing.T) {
// Ensure opcodes match the exact numeric values from the architecture doc.
tests := []struct {
op   OpCode
want int
}{
{OpDispatch, 0},
{OpHeartbeat, 1},
{OpIdentify, 2},
{OpPresenceUpdate, 3},
{OpTypingStart, 4},
{OpMessageCreate, 5},
{OpMessageAck, 6},
{OpError, 7},
{OpChannelSub, 8},
{OpChannelUnsub, 9},
{OpReady, 10},
}
for _, tc := range tests {
if int(tc.op) != tc.want {
t.Errorf("%s = %d, architecture requires %d", tc.op, tc.op, tc.want)
}
}
}
