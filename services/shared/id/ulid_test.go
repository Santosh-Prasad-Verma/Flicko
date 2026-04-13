package id

import (
	"sync"
	"testing"
	"time"
)

func TestNew_ReturnsValidULID(t *testing.T) {
	id := New()

	if len(id) != 26 {
		t.Errorf("expected 26 char ULID, got %d chars: %s", len(id), id)
	}

	if !IsValid(id) {
		t.Errorf("generated ULID is not valid: %s", id)
	}
}

func TestNew_Uniqueness(t *testing.T) {
	seen := make(map[string]bool)
	count := 10000

	for i := 0; i < count; i++ {
		id := New()
		if seen[id] {
			t.Fatalf("duplicate ULID generated: %s (after %d iterations)", id, i)
		}
		seen[id] = true
	}
}

func TestNew_Sortable(t *testing.T) {
	// ULIDs generated later should sort after earlier ones.
	// We need a small delay to ensure different timestamps.
	id1 := New()
	time.Sleep(2 * time.Millisecond)
	id2 := New()

	if id1 >= id2 {
		t.Errorf("expected id1 < id2 (time-sorted), got id1=%s, id2=%s", id1, id2)
	}
}

func TestNew_ConcurrentSafety(t *testing.T) {
	// Spawn 100 goroutines each generating 100 ULIDs.
	// No panics, no duplicates.
	const goroutines = 100
	const perGoroutine = 100

	var mu sync.Mutex
	seen := make(map[string]bool)
	var wg sync.WaitGroup

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			local := make([]string, perGoroutine)
			for j := 0; j < perGoroutine; j++ {
				local[j] = New()
			}

			mu.Lock()
			defer mu.Unlock()
			for _, id := range local {
				if seen[id] {
					t.Errorf("duplicate ULID in concurrent generation: %s", id)
					return
				}
				seen[id] = true
			}
		}()
	}

	wg.Wait()

	expected := goroutines * perGoroutine
	if len(seen) != expected {
		t.Errorf("expected %d unique ULIDs, got %d", expected, len(seen))
	}
}

func TestIsValid(t *testing.T) {
	tests := []struct {
		input string
		valid bool
	}{
		{New(), true},
		{"01HXK5N7Q8B3JMVKXV5T3ZJ9RM", true},   // 26 chars, valid ULID
		{"01HXK5N7Q8B3JMVKXV5T3ZJ9RMX", false}, // 27 chars — too long
		{"", false},
		{"not-a-ulid-at-all!!!!!!!!!", false},
		{"00000000000000000000000000", true}, // Zero ULID is technically valid
		{"short", false},                     // too short
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			if IsValid(tt.input) != tt.valid {
				t.Errorf("IsValid(%q) = %v, want %v", tt.input, !tt.valid, tt.valid)
			}
		})
	}
}

func TestTimestamp(t *testing.T) {
	before := time.Now()
	id := New()
	after := time.Now()

	ts := Timestamp(id)

	if ts.Before(before.Add(-time.Millisecond)) || ts.After(after.Add(time.Millisecond)) {
		t.Errorf("timestamp %v not between %v and %v", ts, before, after)
	}
}

func TestTimestamp_InvalidInput(t *testing.T) {
	ts := Timestamp("invalid")
	if !ts.IsZero() {
		t.Errorf("expected zero time for invalid input, got %v", ts)
	}
}

func TestParse_Valid(t *testing.T) {
	original := New()
	parsed, err := Parse(original)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if parsed.String() != original {
		t.Errorf("round-trip failed: %s != %s", parsed.String(), original)
	}
}

func TestParse_Invalid(t *testing.T) {
	_, err := Parse("not-valid")
	if err == nil {
		t.Fatal("expected error for invalid ULID")
	}
}

func BenchmarkNew(b *testing.B) {
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = New()
		}
	})
}
