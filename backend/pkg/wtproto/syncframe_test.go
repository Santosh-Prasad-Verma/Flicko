package wtproto

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestSyncFrameSerialization(t *testing.T) {
	now := time.Now().UnixMilli()
	frame := &SyncFrame{
		Version:     1,
		Type:        "anchor",
		SessionID:   "wt_session_123",
		HostID:      "user_abc",
		PositionMS:  42000,
		Playing:     true,
		Rate:        1.0,
		WallClockMS: now,
		Seq:         15,
	}

	data, err := MarshalSyncFrame(frame)
	assert.NoError(t, err)
	assert.NotEmpty(t, data)

	decoded, err := UnmarshalSyncFrame(data)
	assert.NoError(t, err)
	assert.NotNil(t, decoded)

	assert.Equal(t, frame.Version, decoded.Version)
	assert.Equal(t, frame.Type, decoded.Type)
	assert.Equal(t, frame.SessionID, decoded.SessionID)
	assert.Equal(t, frame.HostID, decoded.HostID)
	assert.Equal(t, frame.PositionMS, decoded.PositionMS)
	assert.Equal(t, frame.Playing, decoded.Playing)
	assert.Equal(t, frame.Rate, decoded.Rate)
	assert.Equal(t, frame.WallClockMS, decoded.WallClockMS)
	assert.Equal(t, frame.Seq, decoded.Seq)
}
