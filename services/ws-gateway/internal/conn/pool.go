package conn

import "sync"

// bufferPool is a sync.Pool of byte slices to reduce GC pressure
// during high-throughput fan-out. The gateway encodes frames into
// pooled buffers before writing to the WebSocket.
var bufferPool = sync.Pool{
	New: func() interface{} {
		b := make([]byte, 0, 4096)
		return &b
	},
}

// GetBuffer returns a *[]byte from the pool, reset to length 0.
func GetBuffer() *[]byte {
	bp := bufferPool.Get().(*[]byte)
	*bp = (*bp)[:0]
	return bp
}

// PutBuffer returns a *[]byte to the pool.
// Buffers that grew beyond 64 KiB are discarded to avoid holding
// excessive memory.
func PutBuffer(bp *[]byte) {
	if cap(*bp) > 65536 {
		return // let GC collect oversized buffers
	}
	bufferPool.Put(bp)
}
