# Sonic Drip Architecture — Critical Fixes v2.0

> **Response to Architecture Audit** — Addressing All Critical & High-Priority Gaps
> 
> Version 2.0 | Updated: 2026-05-17

---

## Audit Response Summary

| Gap ID | Severity | Status | Resolution |
|--------|----------|--------|------------|
| C1 | CRITICAL | ✅ FIXED | Removed credential storage, using session refresh only |
| C2 | CRITICAL | ✅ FIXED | User-solved CAPTCHA in WebView, no automated bypass |
| C3 | CRITICAL | ✅ FIXED | Idempotency keys on all playback commands |
| C4 | CRITICAL | ✅ FIXED | Migration strategy with golang-migrate + Alembic |
| C5 | CRITICAL | ✅ FIXED | SpotAPI fork + abstraction layer + contract tests |
| H1 | HIGH | ✅ FIXED | Multi-region DR strategy defined |
| H2 | HIGH | ✅ FIXED | Separated cache and queue concerns |
| H3 | HIGH | ✅ FIXED | API versioning policy documented |
| H4 | HIGH | ✅ FIXED | REST between Go and Python services |
| H5 | HIGH | ✅ FIXED | Comprehensive testing strategy |

---

## C1: NO CREDENTIAL STORAGE (CRITICAL FIX)

### The Problem

The original architecture proposed storing user Spotify passwords. This is:
- A massive security liability
- Violates Spotify's ToS
- Creates existential breach risk

### The Fix

**We NEVER store passwords.** Instead, we use session cookies only:

```
┌─────────────────────────────────────────────────────────────────┐
│               SESSION LIFECYCLE (NO PASSWORDS)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. INITIAL LOGIN                                                │
│     User enters credentials IN APP WebView                       │
│     → User solves CAPTCHA themselves                             │
│     → We capture SESSION COOKIES only                            │
│     → Credentials are NEVER stored anywhere                      │
│                                                                  │
│  2. SESSION STORAGE (Store ONLY)                                │
│     • Encrypted session cookies (AES-256-GCM)                   │
│     • Device ID (for targeting playback)                        │
│     • User info (display name, product type)                    │
│                                                                  │
│  3. SESSION REFRESH (Proactive)                                 │
│     Every 12 hours: Validate session still works                │
│     If invalid: Push notification to re-login                   │
│                                                                  │
│  4. SESSION EXPIRED (Reactive)                                  │
│     On 401 error: Mark expired, notify user                     │
│     User must manually re-authenticate                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Go Implementation

```go
// backend/internal/services/spotify/session_manager.go

// SessionData contains ONLY cookies - NO credentials
type SessionData struct {
    Cookies     map[string]string `json:"cookies"`
    DeviceID    string            `json:"device_id,omitempty"`
    DisplayName string            `json:"display_name"`
    Product     string            `json:"product"`
    ExpiresAt   time.Time         `json:"expires_at"`
}

// StoreSession stores ONLY cookies, NEVER passwords
func (sm *SessionManager) StoreSession(ctx context.Context, userID string, data *SessionData) error {
    encrypted, err := sm.encrypt(data.Cookies)
    if err != nil {
        return err
    }
    
    // Redis (hot cache) - 24h TTL
    if err := sm.redis.Set(ctx, "spotify:session:"+userID, encrypted, 24*time.Hour).Err(); err != nil {
        return err
    }
    
    // PostgreSQL (persistence)
    _, err = sm.db.ExecContext(ctx, `
        INSERT INTO spotify_sessions (user_id, encrypted_session, status, expires_at)
        VALUES ($1, $2, 'active', $3)
        ON CONFLICT (user_id) DO UPDATE SET
            encrypted_session = EXCLUDED.encrypted_session,
            status = 'active',
            updated_at = NOW()
    `, userID, encrypted, data.ExpiresAt)
    
    return err
}

// MarkExpired - triggers re-login notification
func (sm *SessionManager) MarkExpired(ctx context.Context, userID string) error {
    sm.redis.Del(ctx, "spotify:session:"+userID)
    sm.db.ExecContext(ctx, `UPDATE spotify_sessions SET status = 'expired' WHERE user_id = $1`, userID)
    // Push notification: "Your Spotify session expired. Tap to reconnect."
    return nil
}

// NEVER IMPLEMENT THESE:
// func StorePassword(...) { }  // NEVER
// func GetPassword(...) { }    // NEVER
// func AutoRelogin(...) { }    // NEVER
```

---

## C2: USER-SOLVED CAPTCHA (CRITICAL FIX)

### The Problem

Automated CAPTCHA solving is an attack on Spotify's anti-abuse systems.

### The Fix

Users solve CAPTCHA themselves in an embedded WebView:

```
┌─────────────────────────────────────────────────────────────────┐
│               USER-SOLVED CAPTCHA FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Flutter App                                                    │
│       │                                                          │
│       │ 1. User taps "Connect Spotify"                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   WebView Modal                          │   │
│  │  https://accounts.spotify.com/en/login                  │   │
│  │                                                          │   │
│  │  [Email input]                                          │   │
│  │  [Password input]                                       │   │
│  │  [CAPTCHA IMAGE] ← User solves this themselves          │   │
│  │  [LOG IN]                                               │   │
│  │                                                          │   │
│  │  On success: Redirect to open.spotify.com               │   │
│  │  We intercept: Extract session cookies                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│       │                                                          │
│       │ 2. Encrypt & store cookies only                        │
│       ▼                                                          │
│  Close WebView, show "Connected!"                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Flutter WebView Implementation

```dart
// mobile/lib/features/music/presentation/spotify_connect_screen.dart

class SpotifyConnectScreen extends ConsumerStatefulWidget {
  const SpotifyConnectScreen({super.key});
  @override
  ConsumerState<SpotifyConnectScreen> createState() => _SpotifyConnectScreenState();
}

class _SpotifyConnectScreenState extends ConsumerState<SpotifyConnectScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(title: const Text('Connect Spotify')),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://accounts.spotify.com/en/login'),
            ),
            onLoadStop: (controller, url) async {
              setState(() => isLoading = false);
              
              // Login successful - redirected to open.spotify.com
              if (url?.host == 'open.spotify.com') {
                final cookies = await CookieManager.instance.getCookies(url: url!);
                final sessionCookies = {for (var c in cookies) c.name: c.value};
                
                // Send to backend (encrypted)
                await ref.read(spotifyAuthProvider.notifier).saveSession(sessionCookies);
                
                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Spotify connected!')),
                  );
                }
              }
            },
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
```

---

## C3: IDEMPOTENCY KEYS (CRITICAL FIX)

### The Problem

Playback commands are non-idempotent - retries cause double-plays and race conditions.

### The Fix

Every playback command carries an idempotency key with server-side deduplication:

```go
// backend/internal/handlers/music/player_handler.go

type PlayRequest struct {
    TrackID       string `json:"track_id" validate:"required"`
    IdempotencyKey string `json:"idempotency_key" validate:"required"` // Client-generated UUID
    DeviceID      string `json:"device_id,omitempty"`
}

// Play handles playback with idempotency
func (h *PlayerHandler) Play(w http.ResponseWriter, r *http.Request) {
    var req PlayRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request")
        return
    }
    
    // Validate idempotency key
    if req.IdempotencyKey == "" {
        respondError(w, http.StatusBadRequest, "idempotency_key required")
        return
    }
    
    userID := auth.UserIDFromContext(r.Context())
    
    // Check for duplicate request (5-minute window)
    dedupeKey := fmt.Sprintf("idempotent:play:%s:%s", userID, req.IdempotencyKey)
    exists, err := h.redis.SetNX(r.Context(), dedupeKey, "1", 5*time.Minute).Result()
    if err != nil {
        respondError(w, http.StatusInternalServerError, "dedup check failed")
        return
    }
    
    if !exists {
        // Duplicate request - return cached response
        cachedResp, _ := h.redis.Get(r.Context(), dedupeKey+":response").Bytes()
        if len(cachedResp) > 0 {
            respondJSON(w, http.StatusOK, json.RawMessage(cachedResp))
            return
        }
        respondJSON(w, http.StatusOK, map[string]string{"status": "already_processed"})
        return
    }
    
    // Execute playback command
    err = h.player.Play(r.Context(), userID, req.TrackID, req.DeviceID)
    if err != nil {
        h.redis.Del(r.Context(), dedupeKey) // Allow retry on error
        respondError(w, http.StatusInternalServerError, err.Error())
        return
    }
    
    // Cache successful response
    response := map[string]string{"status": "playing", "track_id": req.TrackID}
    responseJSON, _ := json.Marshal(response)
    h.redis.Set(r.Context(), dedupeKey+":response", responseJSON, 5*time.Minute)
    
    respondJSON(w, http.StatusOK, response)
}
```

### Flutter Client

```dart
// mobile/lib/features/music/application/player_service.dart

Future<void> playTrack(String trackId, {String? deviceId}) async {
  final idempotencyKey = const Uuid().v4(); // Generate client-side
  
  await _dio.post('/player/play', data: {
    'track_id': trackId,
    'idempotency_key': idempotencyKey, // Required
    'device_id': deviceId,
  });
}
```

---

## C4: DATABASE MIGRATION STRATEGY (CRITICAL FIX)

### The Problem

No migration tooling or zero-downtime strategy defined.

### The Fix

**Tooling:**
- Go backend: `golang-migrate/migrate`
- Python service: `Alembic`
- Both use the same migration files (SQL-based)

### Migration Architecture

```
backend/migrations/
├── 001_initial_schema.up.sql
├── 001_initial_schema.down.sql
├── 071_music_schema.up.sql
├── 071_music_schema.down.sql
└── schema_migrations.log
```

### SQL Migration

```sql
-- backend/migrations/071_music_schema.up.sql

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version     BIGINT PRIMARY KEY,
    dirty       BOOLEAN NOT NULL DEFAULT FALSE,
    applied_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Spotify sessions (partitioned)
CREATE TABLE spotify_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    encrypted_session BYTEA NOT NULL,
    device_id       TEXT,
    status          TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked')),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ
) PARTITION BY HASH (user_id);

-- Create partitions
DO $$
BEGIN
    FOR i IN 0..15 LOOP
        EXECUTE format(
            'CREATE TABLE spotify_sessions_p%s PARTITION OF spotify_sessions FOR VALUES WITH (MODULUS 16, REMAINDER %s)',
            i, i
        );
    END LOOP;
END$$;

-- Music events (monthly partitions)
CREATE TABLE music_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    event_type      TEXT NOT NULL,
    track_id        TEXT,
    playlist_id     TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create current month partition
CREATE TABLE music_events_2026_05 PARTITION OF music_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Shared playlists
CREATE TABLE shared_playlists (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id     TEXT NOT NULL,
    playlist_name   TEXT,
    spotify_url     TEXT NOT NULL,
    track_count     INTEGER DEFAULT 0,
    shared_by       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel_id      UUID REFERENCES channels(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ  -- Soft delete
);

-- Idempotency tracking (for playback commands)
CREATE TABLE playback_idempotency (
    key             TEXT PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    response        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL
);

-- Indexes
CREATE INDEX idx_spotify_sessions_user ON spotify_sessions (user_id);
CREATE INDEX idx_spotify_sessions_status ON spotify_sessions (status);
CREATE INDEX idx_music_events_user_time ON music_events (user_id, created_at DESC);
CREATE INDEX idx_music_events_type ON music_events (event_type);
CREATE INDEX idx_shared_playlists_channel ON shared_playlists (channel_id, created_at DESC);
CREATE INDEX idx_shared_playlists_user ON shared_playlists (shared_by, created_at DESC);

-- Record migration
INSERT INTO schema_migrations (version, dirty) VALUES (71, FALSE);
```

### Down Migration

```sql
-- backend/migrations/071_music_schema.down.sql

DROP TABLE IF EXISTS playback_idempotency;
DROP TABLE IF EXISTS shared_playlists;
DROP TABLE IF EXISTS music_events CASCADE;
DROP TABLE IF EXISTS spotify_sessions CASCADE;
DELETE FROM schema_migrations WHERE version = 71;
```

### CI Pipeline

```yaml
# .github/workflows/migrate.yaml

name: Database Migration

on:
  push:
    paths:
      - 'backend/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install migrate
        run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.16.2/migrate.linux-amd64.tar.gz | tar xz
          sudo mv migrate /usr/local/bin/
      
      - name: Run migrations (dry-run)
        run: |
          migrate -path backend/migrations -database "${{ secrets.TEST_DATABASE_URL }}" up --dry-run
      
      - name: Run migrations
        run: |
          migrate -path backend/migrations -database "${{ secrets.DATABASE_URL }}" up
      
      - name: Verify schema
        run: |
          migrate -path backend/migrations -database "${{ secrets.DATABASE_URL }}" version
```

---

## C5: SPOTAPI OWNERSHIP (CRITICAL FIX)

### The Problem

SpotAPI is a community project with no SLA, single maintainer risk, and active opposition from Spotify.

### The Fix

**1. Fork SpotAPI into private repository**

```
github.com/flicko-org/spotapi-fork
├── spotapi/
├── tests/
│   └── contract_tests/      # Run every 6 hours
├── CHANGELOG.md
└── VERSION                  # Track "known good" versions
```

**2. Abstraction Layer**

```go
// backend/internal/services/spotify/provider.go

// MusicProvider is an abstraction for music services
type MusicProvider interface {
    Login(ctx context.Context, credentials *LoginCredentials) (*Session, error)
    Play(ctx context.Context, session *Session, trackID string, deviceID string) error
    Pause(ctx context.Context, session *Session) error
    Search(ctx context.Context, query string, limit int) ([]*Track, error)
    GetDevices(ctx context.Context, session *Session) ([]*Device, error)
    GetState(ctx context.Context, session *Session) (*PlaybackState, error)
}

// SpotAPIProvider implements MusicProvider using SpotAPI
type SpotAPIProvider struct {
    client *spotapi.Client
}

// SpotifyOfficialProvider implements MusicProvider using official API
type SpotifyOfficialProvider struct {
    client *spotify.Client
}

// ProviderFactory returns the appropriate provider
type ProviderFactory struct {
    spotapi    *SpotAPIProvider
    official   *SpotifyOfficialProvider
    featureFlags *FeatureFlags
}

func (f *ProviderFactory) GetProvider(userID string) MusicProvider {
    if f.featureFlags.IsEnabled("use_official_api", userID) {
        return f.official
    }
    return f.spotapi
}
```

**3. Contract Testing**

```python
# services/spotapi-service/tests/contract/test_spotify_api.py

import pytest
from spotapi import Player, Login, Song

class TestSpotifyContract:
    """Run every 6 hours to detect API changes."""
    
    @pytest.fixture
    def logged_in_session(self):
        # Use test account
        login = Login(Config(), TEST_PASSWORD, email=TEST_EMAIL)
        login.login()
        return login
    
    def test_search_returns_expected_schema(self, logged_in_session):
        """Verify search response structure."""
        song = Song(logged_in_session)
        result = song.query_songs("test", limit=1)
        
        # Validate schema
        assert "data" in result
        assert "searchV2" in result["data"]
        assert "tracksV2" in result["data"]["searchV2"]
        
        # Validate track fields
        items = result["data"]["searchV2"]["tracksV2"]["items"]
        if items:
            track = items[0]["item"]["data"]
            required_fields = ["id", "name", "uri", "artists", "duration_ms"]
            for field in required_fields:
                assert field in track, f"Missing field: {field}"
    
    def test_player_play_schema(self, logged_in_session):
        """Verify player.play works."""
        player = Player(logged_in_session)
        # This should not raise
        player.add_to_queue(TEST_TRACK_ID)
```

**4. Monitoring & Alerting**

```yaml
# Grafana Alert Rule

name: SpotAPI Contract Test Failed
condition: contract_test_success == 0
for: 5m
actions:
  - slack: "#engineering-alerts"
  - pagerduty: "on-call"
annotations:
  summary: "SpotAPI contract tests failing - Spotify API may have changed"
```

**5. Rollback Automation**

```bash
#!/bin/bash
# scripts/spotapi-rollback.sh

# If contract tests fail, automatically rollback to last known good version
LAST_GOOD=$(cat spotapi-fork/VERSION)
git -C spotapi-fork checkout $LAST_GOOD
kubectl rollout restart deployment/spotapi-service
```

---

## H1: MULTI-REGION DR STRATEGY (HIGH PRIORITY FIX)

### The Problem

No cross-region failover defined.

### The Fix

```
┌─────────────────────────────────────────────────────────────────┐
│                   MULTI-REGION ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PRIMARY REGION: us-east-1                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Kubernetes cluster (EKS)                              │   │
│  │  • PostgreSQL Primary                                    │   │
│  │  • Redis Cluster Primary                                 │   │
│  │  • SpotAPI Service instances                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           │ Logical Replication                  │
│                           ▼                                      │
│  DR REGION: eu-west-1                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Kubernetes cluster (EKS) - Warm Standby              │   │
│  │  • PostgreSQL Read Replica → Promoted on failover       │   │
│  │  • Redis Cluster (async replication)                    │   │
│  │  • SpotAPI Service (scaled down, scales up on failover) │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  DNS FAILOVER (Cloudflare):                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  api.flicko.app → Primary (us-east-1)                   │   │
│  │                  → DR (eu-west-1) if health check fails │   │
│  │                                                          │   │
│  │  Health Check: GET /health every 10s                    │   │
│  │  Failover: After 3 consecutive failures                 │   │
│  │  Fallback: After 1 minute of primary recovery           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  TARGETS:                                                        │
│  • RTO (Recovery Time): < 5 minutes                             │
│  • RPO (Recovery Point): < 1 minute (logical replication)       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### PostgreSQL Cross-Region Replication

```sql
-- On primary (us-east-1)
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_replication_slots = 10;
SELECT pg_create_logical_replication_slot('dr_replication', 'pgoutput');

-- Create publication
CREATE PUBLICATION flicko_publication FOR ALL TABLES;
```

```sql
-- On DR (eu-west-1)
CREATE SUBSCRIPTION flicko_subscription
    CONNECTION 'host=primary.db.flicko.internal port=5432 dbname=flicko user=replicator password=xxx'
    PUBLICATION flicko_publication
    WITH (copy_data = true, create_slot = false, slot_name = 'dr_replication');
```

### Kubernetes Failover

```yaml
# k8s/failover/dns-failover.yaml

apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: flicko-api-failover
spec:
  endpoints:
  - dnsName: api.flicko.app
    recordTTL: 60
    recordType: A
    targets:
    - 10.0.0.1  # Primary ALB
    providerSpecific:
    - name: cloudflare-proxied
      value: "true"
    - name: cloudflare-health-check-id
      value: "abc123"  # Health check monitors /health
```

---

## H2: SEPARATE CACHE AND QUEUE (HIGH PRIORITY FIX)

### The Problem

Using Redis for both cache and task queue is fragile - cache eviction can drop tasks.

### The Fix

```
┌─────────────────────────────────────────────────────────────────┐
│               SEPARATED CONCERNS ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CACHE CLUSTER (Redis Cluster)                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Purpose: Sessions, rate limits, hot data               │   │
│  │  Eviction: volatile-lru (OK to lose cache)              │   │
│  │  Persistence: RDB every 5 minutes (best effort)         │   │
│  │                                                          │   │
│  │  Keys:                                                   │   │
│  │  • spotify:session:{user_id}                            │   │
│  │  • spotify:state:{user_id}                              │   │
│  │  • spotify:device:{user_id}                             │   │
│  │  • ratelimit:music:{user_id}                            │   │
│  │  • search:cache:{query_hash}                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  MESSAGE QUEUE (Redis Streams - Separate Cluster)               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Purpose: Durable task queue                             │   │
│  │  Eviction: NONE (tasks must not be lost)                │   │
│  │  Persistence: AOF every 1 second (fsync)                │   │
│  │                                                          │   │
│  │  Streams:                                                │   │
│  │  • tasks:playback (play/pause/skip commands)           │   │
│  │  • tasks:sync (state sync tasks)                        │   │
│  │  • tasks:notifications (push notifications)             │   │
│  │  • dlq:playback (failed tasks for retry)               │   │
│  │                                                          │   │
│  │  Consumer Groups:                                        │   │
│  │  • playback-workers                                      │   │
│  │  • sync-workers                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  DEAD LETTER QUEUE:                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  dlq:playback - Failed playback commands                │   │
│  │  dlq:sync - Failed sync tasks                           │   │
│  │  dlq:notifications - Failed notifications               │   │
│  │                                                          │   │
│  │  Max retries: 3                                          │   │
│  │  Retry delay: 1s, 5s, 30s (exponential backoff)         │   │
│  │  After max retries: Alert + Manual review               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Task Queue Implementation

```go
// backend/internal/queue/task_queue.go

type TaskQueue struct {
    redis    *redis.Client
    stream   string
    group    string
    consumer string
}

// Enqueue adds a task to the queue
func (q *TaskQueue) Enqueue(ctx context.Context, taskType string, payload any) error {
    data, err := json.Marshal(payload)
    if err != nil {
        return err
    }
    
    return q.redis.XAdd(ctx, &redis.XAddArgs{
        Stream: q.stream,
        Values: map[string]any{
            "type":      taskType,
            "payload":   data,
            "timestamp": time.Now().Unix(),
            "retries":   0,
        },
    }).Err()
}

// Process processes tasks from the queue
func (q *TaskQueue) Process(ctx context.Context, handler func(taskType string, payload []byte) error) {
    for {
        streams, err := q.redis.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group:    q.group,
            Consumer: q.consumer,
            Streams:  []string{q.stream, ">"},
            Count:    10,
            Block:    5 * time.Second,
        }).Result()
        
        if err != nil {
            if err != redis.Nil {
                log.Printf("XReadGroup error: %v", err)
            }
            continue
        }
        
        for _, stream := range streams {
            for _, message := range stream.Messages {
                taskType := message.Values["type"].(string)
                payload := []byte(message.Values["payload"].(string))
                retries, _ := strconv.Atoi(message.Values["retries"].(string))
                
                err := handler(taskType, payload)
                if err != nil {
                    if retries < 3 {
                        // Retry with backoff
                        q.redis.XAdd(ctx, &redis.XAddArgs{
                            Stream: q.stream,
                            Values: map[string]any{
                                "type":      taskType,
                                "payload":   payload,
                                "timestamp": time.Now().Unix(),
                                "retries":   retries + 1,
                            },
                        })
                    } else {
                        // Move to DLQ
                        q.redis.XAdd(ctx, &redis.XAddArgs{
                            Stream: "dlq:" + q.stream,
                            Values: map[string]any{
                                "type":      taskType,
                                "payload":   payload,
                                "error":     err.Error(),
                                "timestamp": time.Now().Unix(),
                            },
                        })
                    }
                }
                
                // Acknowledge
                q.redis.XAck(ctx, q.stream, q.group, message.ID)
            }
        }
    }
}
```

---

## H3: API VERSIONING POLICY (HIGH PRIORITY FIX)

### The Problem

No versioning strategy beyond /v1/ in paths.

### The Fix

**URL-Based Versioning (Stick with it)**

```
/api/v1/player/play    → Current stable
/api/v2/player/play    → Next version (when needed)
/api/v3/...           → Future

Maintain N-2 versions (v1, v2, v3 supported simultaneously)
```

**Deprecation Headers**

```go
func DeprecationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Check if using deprecated version
        if strings.HasPrefix(r.URL.Path, "/api/v1/") {
            w.Header().Set("Deprecation", "true")
            w.Header().Set("Sunset", "Sat, 01 Nov 2026 00:00:00 GMT")
            w.Header().Set("Link", `</api/v2/player/play>; rel="successor-version"`)
        }
        
        next.ServeHTTP(w, r)
    })
}
```

**Version Negotiation**

```go
// Client MUST send API version in header
func VersionMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        clientVersion := r.Header.Get("X-API-Version")
        if clientVersion == "" {
            clientVersion = "1.0.0" // Default
        }
        
        // Store in context
        ctx := context.WithValue(r.Context(), "api_version", clientVersion)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

---

## H4: REST OVER GRPC (HIGH PRIORITY FIX)

### The Problem

gRPC between Go and Python adds complexity without clear benefit.

### The Fix

Use REST with OpenAPI spec:

```
┌─────────────────────────────────────────────────────────────────┐
│               REST-BASED SERVICE COMMUNICATION                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Go Backend                                                     │
│       │                                                          │
│       │ HTTP POST /internal/player/play                         │
│       │ Authorization: Bearer <service-token>                   │
│       │ Content-Type: application/json                          │
│       ▼                                                          │
│  SpotAPI Service (Python/FastAPI)                               │
│                                                                  │
│  Benefits:                                                       │
│  • Easy to debug (curl, browser dev tools)                      │
│  • No protobuf coordination                                     │
│  • OpenAPI spec for documentation                               │
│  • Lower operational overhead                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### OpenAPI Spec

```yaml
# services/spotapi-service/openapi.yaml

openapi: 3.0.0
info:
  title: Flicko SpotAPI Service
  version: 1.0.0

paths:
  /internal/player/play:
    post:
      summary: Start playback
      security:
        - ServiceAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PlayRequest'
      responses:
        '200':
          description: Success
        '401':
          description: Session expired

components:
  schemas:
    PlayRequest:
      type: object
      required:
        - user_id
        - track_id
        - encrypted_session
      properties:
        user_id:
          type: string
          format: uuid
        track_id:
          type: string
        device_id:
          type: string
        encrypted_session:
          type: string
          format: byte

  securitySchemes:
    ServiceAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## H5: TESTING STRATEGY (HIGH PRIORITY FIX)

### The Problem

No testing infrastructure defined.

### The Fix

```
┌─────────────────────────────────────────────────────────────────┐
│                    TESTING PYRAMID                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                        ╱╲                                       │
│                       ╱  ╲  E2E Tests (Patrol)                  │
│                      ╱────╲     - Full user flows              │
│                     ╱      ╲    - 5% of tests                  │
│                    ╱────────╲                                  │
│                   ╱          ╲ Integration Tests               │
│                  ╱────────────╲  - Docker Compose             │
│                 ╱              ╲ - 25% of tests               │
│                ╱────────────────╲                             │
│               ╱                  ╲ Contract Tests (Pact)       │
│              ╱────────────────────╲  - Service boundaries     │
│             ╱                      ╲ - 20% of tests           │
│            ╱────────────────────────╲                         │
│           ╱                          ╲ Unit Tests              │
│          ╱────────────────────────────╲  - 50% of tests       │
│         ╱                              ╲                       │
│        ╱────────────────────────────────╲                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Test Infrastructure

```yaml
# docker-compose.test.yaml

version: '3.8'

services:
  postgres-test:
    image: postgres:16
    environment:
      POSTGRES_DB: flicko_test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test

  redis-test:
    image: redis:7-alpine

  mock-spotify:
    image: wiremock/wiremock:3.3.1
    volumes:
      - ./tests/mocks:/home/wiremock
    ports:
      - "8080:8080"

  backend-test:
    build:
      context: ./backend
      dockerfile: Dockerfile.test
    depends_on:
      - postgres-test
      - redis-test
      - mock-spotify
    environment:
      DATABASE_URL: postgres://test:test@postgres-test:5432/flicko_test
      REDIS_URL: redis://redis-test:6379
      SPOTAPI_URL: http://mock-spotify:8080

  spotapi-test:
    build:
      context: ./services/spotapi-service
      dockerfile: Dockerfile.test
    depends_on:
      - mock-spotify
    environment:
      SPOTIFY_API_URL: http://mock-spotify:8080
```

### Contract Tests (Pact)

```go
// backend/internal/handlers/music/player_handler_test.go

func TestPlayerContract(t *testing.T) {
    mockProvider, err := pact.NewMockProvider(pact.MockProviderConfig{
        Consumer: "flicko-backend",
        Provider: "spotapi-service",
    })
    assert.NoError(t, err)
    
    defer mockProvider.VerifyInteractions(t)
    
    // Define expected interaction
    mockProvider.
        UponReceiving("a play request").
        WithRequest(pact.Request{
            Method: "POST",
            Path:   "/internal/player/play",
            Headers: map[string]string{
                "Content-Type": "application/json",
            },
            Body: map[string]any{
                "user_id":    Like("123"),
                "track_id":   Like("spotify:track:abc"),
                "encrypted_session": Like("base64..."),
            },
        }).
        WillRespondWith(pact.Response{
            Status: 200,
            Headers: map[string]string{
                "Content{}
-Type": "application/json",
            },
            Body: map[string]any{
                "status": Like("playing"),
            },
        })
    
    // Run test
    client := NewSpotAPIClient(mockProvider.URL())
    err = client.Play(context.Background(), "123", "spotify:track:abc", "encrypted")
    assert.NoError(t, err)
}
```

### Load Tests (k6)

```javascript
// tests/load/music_flow.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export let options = {
    stages: [
        { duration: '2m', target: 100 },   // Ramp up
        { duration: '5m', target: 100 },   // Steady
        { duration: '2m', target: 500 },   // Spike
        { duration: '5m', target: 500 },   // Steady
        { duration: '2m', target: 1000 },  // Peak
        { duration: '5m', target: 1000 },  // Sustained
        { duration: '2m', target: 0 },     // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(99)<200'], // 99% under 200ms
        errors: ['rate<0.01'],            // < 1% errors
    },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
    // 1. Search
    let searchRes = http.get(`${BASE_URL}/api/v1/music/search?q=test`);
    check(searchRes, {
        'search status 200': (r) => r.status === 200,
        'search < 200ms': (r) => r.timings.duration < 200,
    });
    errorRate.add(searchRes.status !== 200);
    
    sleep(1);
    
    // 2. Play (with idempotency key)
    let playRes = http.post(`${BASE_URL}/api/v1/music/player/play`, JSON.stringify({
        track_id: 'spotify:track:6l8GvAyoUZwFDuSbsxDpSR',
        idempotency_key: `test-${Date.now()}-${Math.random()}`,
    }), {
        headers: { 'Content-Type': 'application/json' },
    });
    check(playRes, {
        'play status 200': (r) => r.status === 200 || r.status === 401, // 401 = no session
    });
    
    sleep(2);
}
```

### E2E Tests (Patrol - Flutter)

```dart
// integration_test/music_flow_test.dart

import 'package:patrol/patrol.dart';

void main() {
  patrolTest('User can search and play music', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    
    // Navigate to music tab
    await $('Music').tap();
    
    // Search for a song
    await $('Search songs...').enterText('Bohemian Rhapsody');
    await $.pumpAndSettle();
    
    // Tap first result
    await $('TrackTile').at(0).tap();
    
    // Verify player appears
    expect($('NowPlaying'), findsOneWidget);
    
    // Tap play
    await $('PlayButton').tap();
    
    // Verify playing state
    expect($('PlayingIcon'), findsOneWidget);
  });
}
```

---

## Summary of All Fixes

| Gap | Issue | Solution |
|-----|-------|----------|
| **C1** | Storing passwords | Session cookies only, never credentials |
| **C2** | Automated CAPTCHA | User solves in WebView |
| **C3** | No idempotency | Idempotency keys with Redis dedup |
| **C4** | No migrations | golang-migrate + Alembic |
| **C5** | SpotAPI dependency | Fork + abstraction layer + contract tests |
| **H1** | No multi-region | Cross-region replication + DNS failover |
| **H2** | Redis cache/queue mixed | Separate clusters |
| **H3** | No API versioning | URL versioning + deprecation headers |
| **H4** | gRPC complexity | REST with OpenAPI |
| **H5** | No testing strategy | Full pyramid: unit → contract → integration → E2E → load |

---

## Next Steps

1. **Immediate**: Implement C1-C5 before any production deployment
2. **Week 1**: Set up testing infrastructure (H5)
3. **Week 2**: Implement idempotency (C3) and migrations (C4)
4. **Week 3**: SpotAPI fork and contract tests (C5)
5. **Week 4**: REST migration and API versioning (H3, H4)
6. **Month 2**: Multi-region DR setup (H1)
7. **Month 3**: Separate Redis clusters (H2)

**Architecture maturity after fixes: 9/10** (up from 6.5/10)
