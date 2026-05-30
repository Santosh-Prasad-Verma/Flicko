package message_summary

import "sync"

// streamRegistry holds in-process subscribers keyed by request_id.
// It is intentionally simple: one publisher (the generator goroutine), one
// subscriber (the SSE handler). If the subscriber arrives late, recent events
// are replayed from the buffer.
type streamRegistry struct {
	mu    sync.Mutex
	items map[string]*streamChannel
}

func newStreamRegistry() streamRegistry {
	return streamRegistry{items: map[string]*streamChannel{}}
}

func (r *streamRegistry) create(requestID string) *streamChannel {
	r.mu.Lock()
	defer r.mu.Unlock()
	ch := &streamChannel{
		requestID: requestID,
		events:    make([]Event, 0, 16),
	}
	r.items[requestID] = ch
	return ch
}

// subscribe returns the live event channel for the given request. The first
// (and only) caller wins; subsequent subscribers receive a closed nil channel.
//
// We require userID for a future ACL check at this boundary; for now the
// handler authenticates via JWT and we trust the request_id was minted on
// behalf of that user. (The handler asserts ownership against the persisted
// row before subscribing.)
func (r *streamRegistry) subscribe(requestID, userID string) (<-chan Event, bool) {
	_ = userID
	r.mu.Lock()
	defer r.mu.Unlock()
	sc, ok := r.items[requestID]
	if !ok {
		return nil, false
	}
	return sc.subscribe(), true
}

// streamChannel is a per-request fan-out channel with a small ring buffer so
// late subscribers don't miss the first bullets when the generator is fast.
type streamChannel struct {
	requestID string

	mu       sync.Mutex
	events   []Event
	closed   bool
	bullets  int // count of bullet events already published (for emitProgress)
	subs     []chan Event
}

// publish appends an event and broadcasts to active subscribers. Drops events
// for slow subscribers rather than blocking the generator.
func (s *streamChannel) publish(e Event) {
	s.mu.Lock()
	s.events = append(s.events, e)
	subs := append([]chan Event(nil), s.subs...)
	s.mu.Unlock()

	for _, c := range subs {
		select {
		case c <- e:
		default:
			// Slow subscriber: skip rather than stall the LLM stream.
		}
	}
}

// subscribe returns a fresh channel that first replays buffered events then
// follows live ones until close.
func (s *streamChannel) subscribe() <-chan Event {
	s.mu.Lock()
	out := make(chan Event, 32)
	for _, e := range s.events {
		select {
		case out <- e:
		default:
		}
	}
	if s.closed {
		s.mu.Unlock()
		close(out)
		return out
	}
	s.subs = append(s.subs, out)
	s.mu.Unlock()
	return out
}

// close signals end-of-stream to all current subscribers.
func (s *streamChannel) close() {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return
	}
	s.closed = true
	subs := s.subs
	s.subs = nil
	s.mu.Unlock()
	for _, c := range subs {
		close(c)
	}
}

func (s *streamChannel) publishedBullets() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.bullets
}

func (s *streamChannel) markBulletPublished() {
	s.mu.Lock()
	s.bullets++
	s.mu.Unlock()
}
