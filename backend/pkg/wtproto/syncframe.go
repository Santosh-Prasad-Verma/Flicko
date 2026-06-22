package wtproto

import (
	"github.com/vmihailenco/msgpack/v5"
)

type SyncFrame struct {
	Version      int     `msgpack:"v" json:"v"`
	Type         string  `msgpack:"type" json:"type"` // "anchor" | "reaction" | "heartbeat"
	SessionID    string  `msgpack:"session_id" json:"session_id"`
	HostID       string  `msgpack:"host_id" json:"host_id"`
	PositionMS   int     `msgpack:"position_ms" json:"position_ms"`
	Playing      bool    `msgpack:"playing" json:"playing"`
	Rate         float64 `msgpack:"rate" json:"rate"`
	WallClockMS  int64   `msgpack:"wall_clock_ms" json:"wall_clock_ms"`
	Seq          int     `msgpack:"seq" json:"seq"`
}

func MarshalSyncFrame(f *SyncFrame) ([]byte, error) {
	return msgpack.Marshal(f)
}

func UnmarshalSyncFrame(data []byte) (*SyncFrame, error) {
	var f SyncFrame
	if err := msgpack.Unmarshal(data, &f); err != nil {
		return nil, err
	}
	return &f, nil
}
