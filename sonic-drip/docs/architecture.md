# Sonic Drip — Production Architecture

> **Spotify Integration for Flicko** — Scalable, Secure, Production-Ready Design
> 
> Version 2.0 — Enterprise Architecture Edition

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Technology Stack](#technology-stack)
4. [Component Design](#component-design)
5. [Data Flow](#data-flow)
6. [Scaling Strategy](#scaling-strategy)
7. [Failure Points & Mitigations](#failure-points--mitigations)
8. [Security Considerations](#security-considerations)
9. [Production Readiness Checklist](#production-readiness-checklist)
10. [Monitoring & Observability](#monitoring--observability)

---

## Overview

### What is Sonic Drip?

Sonic Drip is Flicko's music integration feature that allows users to:
- Connect their Spotify account
- Search and browse music
- Control playback remotely (play, pause, skip, seek)
- Create and manage playlists
- Share playlists to friends and server channels
- See what friends are listening to (Listen Along)
- Server-wide music events with shared queue

### Key Metrics Target

| Metric | Target |
|--------|--------|
| Concurrent Users | 10,000,000+ |
| Requests per Second | 100,000+ |
| Latency (p99) | < 200ms |
| Uptime SLA | 99.95% |
| Data Durability | 99.999999999% (11 9's) |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        CLIENT LAYER                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐              │
│   │   Flutter Mobile    │     │    Flutter Web      │     │   Desktop (Electron)│              │
│   │   (iOS/Android)     │     │    (Browser)        │     │    (Windows/Mac)    │              │
│   │                     │     │                     │     │                     │              │
│   │  • Riverpod 3.0     │     │  • Same Codebase    │     │  • Same Codebase    │              │
│   │  • Dio HTTP Client  │     │  • WebSocket        │     │  • Native Plugins   │              │
│   │  • Centrifugo WS    │     │    Reconnection     │     │                     │              │
│   └──────────┬──────────┘     └──────────┬──────────┘     └──────────┬──────────┘              │
│              │                           │                           │                          │
└──────────────┼───────────────────────────┼───────────────────────────┼──────────────────────────┘
               │                           │                           │
               │                           │                           │
               └───────────────────────────┼───────────────────────────┘
                                           │
                                           │ HTTPS / WSS
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      EDGE LAYER                                                  │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              Cloudflare Edge Network                                    │   │
│   │                                                                                         │   │
│   │   • DDoS Protection (Layer 3/4/7)                                                      │   │
│   │   • WAF Rules (OWASP Top 10)                                                           │   │
│   │   • Bot Management                                                                     │   │
│   │   • Rate Limiting (Token Bucket)                                                       │   │
│   │   • SSL/TLS Termination                                                                │   │
│   │   • Anycast Routing (Global PoPs)                                                      │   │
│   │   • Argo Smart Routing (30% faster)                                                    │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
                                           │
                                           │ Load Balanced
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   KUBERNETES CLUSTER                                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                            INGRESS CONTROLLER (NGINX)                                   │   │
│   │                                                                                         │   │
│   │   • mTLS between services                                                              │   │
│   │   • Request ID injection                                                               │   │
│   │   • Circuit breaker patterns                                                           │   │
│   │   • Zero-downtime rolling deployments                                                  │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                           │                                                      │
│              ┌────────────────────────────┼────────────────────────────┐                        │
│              │                            │                            │                        │
│              ▼                            ▼                            ▼                        │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   Go API Gateway    │    │   Centrifugo WS     │    │   SpotAPI Service   │                 │
│   │   (Flicko Backend)  │    │   (WebSocket Hub)   │    │   (Python)          │                 │
│   │                     │    │                     │    │                     │                 │
│   │   • gRPC Router     │    │   • Redis Engine    │    │   • FastAPI         │                 │
│   │   • JWT Validation  │    │   • History Replay  │    │   • SpotAPI Wrapper │                 │
│   │   • Rate Limiting   │    │   • Presence        │    │   • Session Manager │                 │
│   │   • Request Routing │    │   • User Presence   │    │   • Queue Consumer  │                 │
│   │                     │    │                     │    │                     │                 │
│   │   Pods: 10-100      │    │   Pods: 5-20        │    │   Pods: 5-50        │                 │
│   │   CPU: 1-4 cores    │    │   CPU: 2-8 cores    │    │   CPU: 2-4 cores    │                 │
│   │   RAM: 2-8 GB       │    │   RAM: 4-16 GB      │    │   RAM: 4-8 GB       │                 │
│   └──────────┬──────────┘    └──────────┬──────────┘    └──────────┬──────────┘                 │
│              │                            │                            │                        │
│              └────────────────────────────┼────────────────────────────┘                        │
│                                           │                                                      │
└───────────────────────────────────────────┼──────────────────────────────────────────────────────┘
                                            │
                                            │ Internal Network
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      DATA LAYER                                                 │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   PostgreSQL 16     │    │   Redis Cluster     │    │   Object Storage    │                 │
│   │   (Primary DB)      │    │   (Cache/Queue)     │    │   (S3/MinIO)        │                 │
│   │                     │    │                     │    │                     │                 │
│   │   • Partitioning    │    │   • Cluster Mode    │    │   • Album Art       │                 │
│   │   • Read Replicas   │    │   • Sentinel        │    │   • Playlist Covers │                 │
│   │   • Connection Pool │    │   • Lua Scripts     │    │   • User Uploads    │                 │
│   │   • pgx CopyFrom    │    │   • Pub/Sub         │    │   • CDN Backed      │                 │
│   │                     │    │                     │    │                     │                 │
│   │   Primary: 1        │    │   Nodes: 6          │    │   Regions: 3        │                 │
│   │   Replicas: 3       │    │   Replicas: 3       │    │   Replication: Yes  │                 │
│   └──────────┬──────────┘    └──────────┬──────────┘    └──────────┬──────────┘                 │
│              │                            │                            │                        │
│   ┌──────────┴──────────┐    ┌──────────┴──────────┐    ┌──────────┴──────────┐                 │
│   │   PgBouncer         │    │   Asynq Workers     │    │   CDN               │                 │
│   │   (Connection Pool) │    │   (Task Queue)      │    │   (Cloudflare R2)   │                 │
│   │                     │    │                     │    │                     │                 │
│   │   Max Conns: 10000  │    │   Workers: 100+     │    │   Edge PoPs: 300+   │                 │
│   └─────────────────────┘    │   Queues: 10        │    └─────────────────────┘                 │
│                              └─────────────────────┘                                           │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ External API
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   EXTERNAL SERVICES                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   Spotify API       │    │   CAPTCHA Solver    │    │   Monitoring        │                 │
│   │   (Private + Public)│    │   (Capsolver)       │    │   (Datadog/Grafana) │                 │
│   │                     │    │                     │    │                     │                 │
│   │   • Rate: ~100/s    │    │   • ReCaptcha v2    │    │   • APM Traces      │                 │
│   │   • Private API     │    │   • hCaptcha        │    │   • Logs            │                 │
│   │   • WebSocket       │    │   • ~$2/1000 solves │    │   • Metrics         │                 │
│   └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                 │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Client Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| **Mobile Framework** | Flutter 3.22+ | Single codebase, hot reload, native performance |
| **State Management** | Riverpod 3.0 | Compile-safe, testable, async support |
| **HTTP Client** | Dio + Retry Interceptor | Automatic retries, interceptors, FormData |
| **WebSocket** | Centrifuge Dart SDK | Auto-reconnect, presence, history |
| **Local Cache** | Hive / SharedPreferences | Fast key-value, encrypted support |
| **Deep Links** | app_links + uni_links | Spotify app integration |

### Backend Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| **API Server** | Go 1.22+ | High concurrency, low latency, type-safe |
| **HTTP Router** | Chi / Gorilla Mux | Lightweight, middleware support |
| **gRPC** | grpc-go | Inter-service communication |
| **Validation** | go-playground/validator | Struct tag validation |
| **WebSocket Hub** | Centrifugo v5 | Scale to millions, Redis engine |
| **Music Service** | Python + FastAPI | SpotAPI integration, async support |
| **Task Queue** | Asynq (Redis-backed) | Distributed task processing |

### Data Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| **Primary Database** | PostgreSQL 16 | ACID, partitioning, pgx driver |
| **Connection Pool** | PgBouncer | 10K+ concurrent connections |
| **Cache Layer** | Redis 7 Cluster | Sub-ms latency, Lua scripts |
| **Message Queue** | Redis Streams / Asynq | At-least-once delivery |
| **Object Storage** | Cloudflare R2 / MinIO | Zero egress fees, S3 compatible |
| **Search** | Meilisearch / Typesense | Fast fuzzy search for songs |

### Infrastructure

| Component | Technology | Reason |
|-----------|------------|--------|
| **Container Orchestration** | Kubernetes (EKS/GKE) | Auto-scaling, self-healing |
| **Service Mesh** | Istio / Linkerd | mTLS, traffic management |
| **CI/CD** | GitHub Actions + ArgoCD | GitOps, canary deployments |
| **Secrets** | HashiCorp Vault | Dynamic secrets, rotation |
| **CDN** | Cloudflare | Global PoPs, DDoS protection |
| **DNS** | Cloudflare DNS | Anycast, failover |

---

## Component Design

### 1. Go API Gateway (Flicko Backend)

```
backend/internal/handlers/music/
├── search_handler.go        # Song/Album/Artist search
├── player_handler.go        # Play/Pause/Skip/Seek/Volume
├── playlist_handler.go      # CRUD operations
├── session_handler.go       # Spotify auth & tokens
├── share_handler.go         # Share to channel/friends
├── listen_along_handler.go  # Real-time listening sessions
└── middleware.go            # Rate limiting, auth, logging
```

**Key Patterns:**

```go
// Circuit breaker for SpotAPI calls
type SpotAPIClient struct {
    client    *http.Client
    breaker   *circuitbreaker.CircuitBreaker
    retry     *retry.Retry
    rateLimit *rate.Limiter
}

func (c *SpotAPIClient) Play(ctx context.Context, req *PlayRequest) error {
    return c.breaker.Call(func() error {
        return c.retry.Do(ctx, func() error {
            return c.play(ctx, req)
        })
    })
}
```

### 2. SpotAPI Python Service

```
services/spotapi-service/
├── app/
│   ├── main.py              # FastAPI app
│   ├── routers/
│   │   ├── auth.py          # Login, session management
│   │   ├── player.py        # Playback control
│   │   ├── search.py        # Music search
│   │   └── playlist.py      # Playlist operations
│   ├── services/
│   │   ├── spotify_client.py    # SpotAPI wrapper
│   │   ├── session_manager.py   # Cookie encryption/storage
│   │   └── device_manager.py    # Device discovery
│   ├── websocket/
│   │   └── spotify_ws.py    # Real-time state sync
│   └── workers/
│       ├── login_worker.py  # Background login tasks
│       └── sync_worker.py   # State synchronization
├── Dockerfile
├── requirements.txt
└── pyproject.toml
```

### 3. Session Management

```python
# Encrypted session storage
class SessionManager:
    def __init__(self, vault_client: VaultClient, redis: Redis):
        self.vault = vault_client
        self.redis = redis
        self.encryption_key = vault_client.get_key("spotify-sessions")
    
    async def store_session(self, user_id: str, cookies: dict):
        # Encrypt cookies with AES-256-GCM
        encrypted = self.encrypt(cookies)
        
        # Store in Redis with TTL (refresh daily)
        await self.redis.setex(
            f"spotify:session:{user_id}",
            86400,  # 24 hours
            encrypted
        )
        
        # Also persist to PostgreSQL for recovery
        await self.db.insert_session(user_id, encrypted)
    
    async def get_session(self, user_id: str) -> dict:
        # Try Redis first (L1 cache)
        cached = await self.redis.get(f"spotify:session:{user_id}")
        if cached:
            return self.decrypt(cached)
        
        # Fall back to PostgreSQL
        stored = await self.db.get_session(user_id)
        if stored:
            # Re-warm cache
            await self.redis.setex(
                f"spotify:session:{user_id}",
                86400,
                stored
            )
            return self.decrypt(stored)
        
        raise SessionNotFoundError(user_id)
```

### 4. Real-time State Sync (Centrifugo)

```
Channel Structure:
├── user:{user_id}:music          # Personal playback state
├── server:{server_id}:music      # Server music events
├── listen_along:{session_id}     # Listen Along sessions
└── playlist:{playlist_id}:updates # Playlist updates
```

**WebSocket Message Types:**

```json
// Playback state update
{
  "type": "PLAYBACK_UPDATE",
  "data": {
    "track_id": "6l8GvAyoUZwFDuSbsxDpSR",
    "track_name": "Bohemian Rhapsody",
    "artist": "Queen",
    "is_playing": true,
    "position_ms": 45000,
    "duration_ms": 354000,
    "device_name": "iPhone 15 Pro"
  }
}

// Listen Along invitation
{
  "type": "LISTEN_ALONG_INVITE",
  "data": {
    "host_user_id": "abc123",
    "host_username": "music_lover",
    "track_name": "Bohemian Rhapsody",
    "expires_at": "2026-05-17T11:00:00Z"
  }
}

// Playlist shared to channel
{
  "type": "PLAYLIST_SHARED",
  "data": {
    "playlist_id": "xyz789",
    "playlist_name": "My Vibes",
    "track_count": 42,
    "share_url": "https://open.spotify.com/playlist/xyz789",
    "shared_by": {
      "user_id": "abc123",
      "username": "music_lover",
      "avatar_url": "https://..."
    }
  }
}
```

---

## Data Flow

### Flow 1: User Authentication

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Flutter    │     │  Go Backend  │     │ SpotAPI Svc  │     │   Spotify    │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │                    │
       │ POST /auth/connect│                    │                    │
       │ {email, password} │                    │                    │
       │───────────────────▶                    │                    │
       │                    │                    │                    │
       │                    │ gRPC LoginRequest  │                    │
       │                    │───────────────────▶                    │
       │                    │                    │                    │
       │                    │                    │ POST /login        │
       │                    │                    │ with CAPTCHA       │
       │                    │                    │───────────────────▶
       │                    │                    │                    │
       │                    │                    │   Session Cookies  │
       │                    │                    │◀───────────────────
       │                    │                    │                    │
       │                    │  SessionResponse   │                    │
       │                    │◀───────────────────                    │
       │                    │                    │                    │
       │                    │ Encrypt & Store    │                    │
       │                    │ in Redis/Postgres  │                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │  200 OK + Token    │                    │                    │
       │◀───────────────────                    │                    │
       │                    │                    │                    │
```

### Flow 2: Play a Song

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Flutter    │     │  Go Backend  │     │ SpotAPI Svc  │     │   Spotify    │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │                    │
       │ POST /player/play  │                    │                    │
       │ {track_id}         │                    │                    │
       │───────────────────▶                    │                    │
       │                    │                    │                    │
       │                    │ Validate user     │                    │
       │                    │ Check rate limit  │                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │                    │ Get session        │                    │
       │                    │ from Redis         │                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │                    │ gRPC PlayRequest   │                    │
       │                    │ {track_id, session}│                    │
       │                    │───────────────────▶                    │
       │                    │                    │                    │
       │                    │                    │ Player.add_to_queue
       │                    │                    │ Player.skip_next   │
       │                    │                    │───────────────────▶
       │                    │                    │                    │
       │                    │                    │   200 OK           │
       │                    │                    │◀───────────────────
       │                    │                    │                    │
       │                    │  PlayResponse      │                    │
       │                    │◀───────────────────                    │
       │                    │                    │                    │
       │                    │ Publish to Centrifugo                  │
       │                    │ (NOW_PLAYING event)│                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │  200 OK            │                    │                    │
       │◀───────────────────                    │                    │
       │                    │                    │                    │
       │                    │                    │                    │
       │ WS: NOW_PLAYING    │                    │                    │
       │◀───────────────────────────────────────                    │
       │                    │                    │                    │
```

### Flow 3: Share Playlist to Channel

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Flutter    │     │  Go Backend  │     │  PostgreSQL  │     │  Centrifugo  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │                    │
       │ POST /playlist/share                   │                    │
       │ {playlist_id, channel_id}              │                    │
       │───────────────────▶                    │                    │
       │                    │                    │                    │
       │                    │ Verify user has    │                    │
       │                    │ permission to post │                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │                    │ Get playlist info  │                    │
       │                    │ from Spotify       │                    │
       │                    │─────────┐          │                    │
       │                    │         │          │                    │
       │                    │◀────────┘          │                    │
       │                    │                    │                    │
       │                    │ Insert message     │                    │
       │                    │ into DB            │                    │
       │                    │───────────────────▶                    │
       │                    │                    │                    │
       │                    │                    │  201 Created       │
       │                    │                    │◀───────────────────
       │                    │                    │                    │
       │                    │ Publish to channel │                    │
       │                    │───────────────────────────────────────▶
       │                    │                    │                    │
       │                    │                    │                    │
       │  201 Created       │                    │                    │
       │◀───────────────────                    │                    │
       │                    │                    │                    │
       │                    │                    │                    │
       │ WS: PLAYLIST_SHARED (all channel members)                   │
       │◀────────────────────────────────────────────────────────────
       │                    │                    │                    │
```

---

## Scaling Strategy

### Horizontal Scaling

```
┌─────────────────────────────────────────────────────────────────┐
│                    HORIZONTAL POD AUTOSCALER                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Go API Gateway:                                                │
│  • Min replicas: 10                                             │
│  • Max replicas: 100                                            │
│  • Scale on: CPU > 70% OR RPS > 1000/pod                       │
│  • Scale down: 5 minutes stabilization                          │
│                                                                  │
│  SpotAPI Service:                                               │
│  • Min replicas: 5                                              │
│  • Max replicas: 50                                             │
│  • Scale on: Request queue depth > 100                         │
│  • Pre-warm during peak hours (6PM-12AM local)                 │
│                                                                  │
│  Centrifugo:                                                    │
│  • Min replicas: 5                                              │
│  • Max replicas: 20                                             │
│  • Scale on: WebSocket connections > 50K/pod                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Database Scaling

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PostgreSQL (Primary):                                          │
│  • Partitioning by user_id (hash)                              │
│  • Partitioning by created_at (time-based for logs)            │
│  • Connection pooling via PgBouncer (10K connections)          │
│  • Read replicas: 3 (in different AZs)                         │
│  • Point-in-time recovery enabled                              │
│                                                                  │
│  Tables:                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ spotify_sessions (partitioned by user_id hash)          │   │
│  │ ├── spotify_sessions_p0                                 │   │
│  │ ├── spotify_sessions_p1                                 │   │
│  │ ├── ...                                                 │   │
│  │ └── spotify_sessions_p15                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ music_events (partitioned by created_at monthly)        │   │
│  │ ├── music_events_2026_05                                │   │
│  │ ├── music_events_2026_06                                │   │
│  │ └── ...                                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Redis Cluster:                                                 │
│  • 6 master nodes (sharded by user_id)                         │
│  • 3 replicas per master                                        │
│  • Lua scripts for atomic operations                           │
│  • Pub/Sub for real-time events                                │
│                                                                  │
│  Keys:                                                           │
│  • spotify:session:{user_id}          → 24h TTL               │
│  • spotify:device:{user_id}           → 1h TTL                │
│  • spotify:state:{user_id}            → 5m TTL (refresh)      │
│  • ratelimit:music:{user_id}          → sliding window        │
│  • queue:playback                     → Asynq tasks           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Caching Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTI-TIER CACHING                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  L1: Client-Side (Flutter)                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Hive cache for user preferences                       │   │
│  │ • In-memory cache for search results (5 min)            │   │
│  │ • Playlist metadata cache (1 hour)                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  L2: CDN Edge (Cloudflare)                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Album art (1 year, immutable)                         │   │
│  │ • Artist images (1 year)                                │   │
│  │ • Static playlist covers (1 day)                        │   │
│  │ • API responses for public data (1 min)                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  L3: Application Cache (Redis)                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Spotify sessions (24 hours)                           │   │
│  │ • Device lists (1 hour)                                 │   │
│  │ • Playback state (5 minutes)                            │   │
│  │ • Search results (10 minutes)                           │   │
│  │ • User library (30 minutes)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  L4: Database (PostgreSQL)                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Persistent sessions (encrypted)                       │   │
│  │ • Event logs (audit trail)                              │   │
│  │ • User preferences                                      │   │
│  │ • Shared playlists metadata                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Failure Points & Mitigations

### Critical Failure Points

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PRODUCTION FAILURE POINTS                                          │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 1. SPOTIFY API RATE LIMITING / BAN                                                        │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: CRITICAL - Could disable all music functionality                                    │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Too many requests from same IP/service account                                          │  │
│  │ • Detected automated access (SpotAPI usage)                                               │  │
│  │ • Geographic anomalies (requests from unusual locations)                                  │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Token bucket rate limiter per user (10 req/min)                                       │  │
│  │ ✅ Global rate limiter for SpotAPI service (100 req/s)                                   │  │
│  │ ✅ Request queuing with priority (playback > search > metadata)                          │  │
│  │ ✅ Multiple Spotify service accounts (round-robin)                                       │  │
│  │ ✅ Residential proxy rotation for SpotAPI requests                                       │  │
│  │ ✅ Circuit breaker: Stop requests when error rate > 10%                                  │  │
│  │ ✅ Fallback: Deep link to Spotify app when API fails                                     │  │
│  │ ✅ Graceful degradation: Show cached data, queue actions for retry                       │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 2. CAPTCHA SOLVER FAILURE / BAN                                                           │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: HIGH - New users cannot connect Spotify                                             │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Capsolver service outage                                                                │  │
│  │ • CAPTCHA type change (Spotify updates protection)                                        │  │
│  │ • Account exhaustion on solver service                                                    │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Multiple CAPTCHA solver providers (Capsolver, 2Captcha, Anti-Captcha)                 │  │
│  │ ✅ Cookie import fallback (user manually exports from browser)                           │  │
│  │ ✅ Session reuse: Only require CAPTCHA on first login                                     │  │
│  │ ✅ Queue login requests during peak hours                                                 │  │
│  │ ✅ Alert when solve rate drops below 80%                                                  │  │
│  │ ✅ Documentation for users on manual cookie export                                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 3. SESSION EXPIRATION / INVALIDATION                                                      │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: HIGH - Users lose Spotify connection unexpectedly                                   │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Spotify invalidates sessions (security event, password change)                         │  │
│  │ • Session cookies expire (typically 14-30 days)                                          │  │
│  │ • User revokes access from Spotify account settings                                      │  │
│  │ • IP address change triggers security lock                                               │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Session refresh job runs every 12 hours                                               │  │
│  │ ✅ Detect 401 errors and mark session invalid                                            │  │
│  │ ✅ Push notification to user: "Reconnect Spotify"                                        │  │
│  │ ✅ Automatic re-login attempt with stored credentials (encrypted)                        │  │
│  │
│  │ ✅ Session health check endpoint for proactive detection                               │  │
│  │ ✅ Multiple sessions per user (backup account)                                          │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 4. WEBSOCKET DISCONNECTION / RECONNECTION STORM                                          │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: MEDIUM - Playback state desync, poor UX                                            │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Network issues (mobile data switching, WiFi drop)                                      │  │
│  │ • Centrifugo server restart / deployment                                                 │  │
│  │ • Client backgrounding (mobile OS killing connections)                                   │  │
│  │ • Mass reconnection after outage (thundering herd)                                       │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Exponential backoff for reconnection (1s, 2s, 4s, 8s... max 30s)                      │  │
│  │ ✅ Jitter added to reconnection delay                                                    │  │
│  │ ✅ History recovery in Centrifugo (replay missed messages)                              │  │
│  │ ✅ Client-side state reconciliation on reconnect                                        │  │
│  │ ✅ Heartbeat / ping-pong to detect stale connections                                     │  │
│  │ ✅ Connection multiplexing (single WS for all subscriptions)                            │  │
│  │ ✅ Offline queue: Store actions while disconnected, replay on reconnect                 │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 5. SPOTIFY PRIVATE API CHANGES                                                            │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: CRITICAL - Could break all SpotAPI functionality                                   │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Spotify updates their private API endpoints                                            │  │
│  │ • New authentication requirements                                                         │  │
│  │ • GraphQL schema changes                                                                  │  │
│  │ • Client fingerprint detection changes                                                    │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Monitor SpotAPI GitHub for updates                                                    │  │
│  │ ✅ Canary deployment: Test changes with 1% of users first                               │  │
│  │ ✅ Feature flag: Ability to disable SpotAPI instantly                                    │  │
│  │ ✅ Fallback to public Spotify API (limited features)                                    │  │
│  │ ✅ Fallback to deep linking (opens Spotify app)                                         │  │
│  │ ✅ Contract tests: Validate API responses match expected schema                          │  │
│  │ ✅ Alert on response structure changes                                                   │  │
│  │ ✅ Maintain version compatibility layer                                                  │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 6. REDIS CLUSTER FAILURE                                                                   │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: HIGH - Loss of sessions, queues, real-time state                                   │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Primary node failure                                                                    │  │
│  │ • Network partition                                                                       │  │
│  │ • Memory exhaustion                                                                       │  │
│  │ • Persistence failure                                                                     │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Redis Cluster with 3 replicas per shard                                               │  │
│  │ ✅ Automatic failover (Redis Sentinel)                                                   │  │
│  │ ✅ Persistence fallback: PostgreSQL for sessions                                         │  │
│  │ ✅ Memory limit alerts at 80% capacity                                                   │  │
│  │ ✅ Eviction policy: volatile-lru for non-critical keys                                   │  │
│  │ ✅ Multi-AZ deployment                                                                    │  │
│  │ ✅ Regular backup to S3                                                                   │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 7. POSTGRESQL CONNECTION POOL EXHAUSTION                                                  │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: HIGH - All DB-dependent features fail                                               │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Connection leaks (not returning connections to pool)                                   │  │
│  │ • Long-running queries blocking connections                                              │  │
│  │ • Traffic spike exceeding pool capacity                                                  │  │
│  │ • Transaction deadlocks                                                                   │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ PgBouncer with 10K connection limit                                                   │  │
│  │ ✅ Connection timeout (30 seconds max)                                                   │  │
│  │ ✅ Query timeout (10 seconds)                                                            │  │
│  │ ✅ Connection health checks                                                               │  │
│  │ ✅ Pool metrics monitoring                                                                │  │
│  │ ✅ Automatic connection recycling                                                         │  │
│  │ ✅ Read replicas for search queries                                                       │  │
│  │ ✅ Statement timeout prevents runaway queries                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 8. SPOTIFY APP NOT INSTALLED / NOT ACTIVE                                                 │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: MEDIUM - Playback commands have no effect                                           │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • User doesn't have Spotify installed                                                     │  │
│  │ • Spotify app is not running                                                              │  │
│  │ • No active Spotify device                                                                │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Device detection: Check for active devices before playback                           │  │
│  │ ✅ Clear error message: "Open Spotify on a device to play music"                         │  │
│  │ ✅ One-tap deep link to open Spotify app                                                 │  │
│  │ ✅ Web player fallback: https://open.spotify.com                                         │  │
│  │ ✅ Device list in UI showing available targets                                           │  │
│  │ ✅ Background keepalive (Spotify Web API for device activation)                         │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 9. LEGAL / TERMS OF SERVICE VIOLATION                                                     │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: CRITICAL - Could require feature removal                                            │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Spotify detects unauthorized API usage                                                  │  │
│  │ • Legal cease and desist                                                                  │  │
│  │ • User data privacy concerns                                                              │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Official Spotify Web API integration as primary (with Premium requirement)           │  │
│  │ ✅ SpotAPI as optional "enhanced" mode (user acknowledges risk)                         │  │
│  │ ✅ Clear TOS in app: "Not affiliated with Spotify"                                       │  │
│  │ ✅ User consent: "I understand this uses unofficial API"                                 │  │
│  │ ✅ Data minimization: Don't store more than necessary                                   │  │
│  │ ✅ Quick kill switch: Disable SpotAPI within 5 minutes                                  │  │
│  │ ✅ Legal consultation before launch                                                      │  │
│  │ ✅ Alternative: Integrate Apple Music / YouTube Music as backup                         │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 10. MEMORY LEAK IN SPOTAPI SERVICE                                                        │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │ Risk: MEDIUM - Service degradation, eventual crash                                        │  │
│  │                                                                                            │  │
│  │ Causes:                                                                                    │  │
│  │ • Python garbage collection issues                                                        │  │
│  │ • Unclosed HTTP connections                                                               │  │
│  │ • Session object accumulation                                                             │  │
│  │                                                                                            │  │
│  │ Mitigations:                                                                               │  │
│  │ ✅ Memory limits in Kubernetes (4GB hard limit)                                          │  │
│  │ ✅ Automatic pod restart when memory > 80%                                               │  │
│  │ ✅ Context managers for all connections                                                  │  │
│  │ ✅ Weak references for cached sessions                                                    │  │
│  │ ✅ LRU cache with size limit                                                              │  │
│  │ ✅ Memory profiling in CI                                                                 │  │
│  │ ✅ Graceful shutdown: Drain connections before termination                               │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Failure Mode Decision Matrix

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                          FAILURE RESPONSE MATRIX                                                 │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Failure Type          │ Severity │ Auto-Recover │ User Impact │ Action                        │
│  ──────────────────────┼──────────┼──────────────┼─────────────┼───────────────────────────────│
│  Spotify API 429       │ High     │ Yes (queue)  │ Delayed     │ Queue request, retry later    │
│  Spotify API 401       │ Medium   │ Yes (refresh)│ Brief       │ Refresh session, retry        │
│  Spotify API 500       │ Low      │ Yes (retry)  │ Brief       │ Exponential backoff retry     │
│  Spotify API permaban  │ Critical │ No           │ Full        │ Fallback to deep links        │
│  CAPTCHA solver fail   │ Medium   │ Yes (backup) │ Delayed     │ Try alternate solver          │
│  Session expired       │ Medium   │ Partial      │ Action req  │ Notify user to reconnect     │
│  Redis failover        │ Low      │ Yes          │ Brief       │ Automatic replica promotion   │
│  PostgreSQL failover   │ Low      │ Yes          │ Brief       │ Automatic replica promotion   │
│  Centrifugo restart    │ Low      │ Yes          │ Brief       │ Client auto-reconnect         │
│  SpotAPI pod crash     │ Low      │ Yes          │ None        │ K8s restarts pod              │
│  SpotAPI memory OOM    │ Medium   │ Yes          │ Brief       │ Kill pod, restart             │
│  Private API change    │ Critical │ No           │ Full        │ Feature flag disable          │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Security Considerations

### Authentication & Authorization

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY ARCHITECTURE                                              │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ AUTHENTICATION LAYERS                                                                      │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                            │  │
│  │  Layer 1: Flicko Authentication                                                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ • JWT tokens (RS256 signed)                                                         │  │  │
│  │  │ • Refresh tokens (httpOnly, secure, sameSite cookies)                               │  │  │
│  │  │ • Token rotation every 15 minutes                                                   │  │  │
│  │  │ • IP binding for sensitive operations                                               │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                            │  │
│  │  Layer 2: Spotify Session Security                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ • Session cookies encrypted at rest (AES-256-GCM)                                   │  │  │
│  │  │ • Encryption keys stored in HashiCorp Vault                                         │  │  │
│  │  │ • Key rotation every 30 days                                                        │  │  │
│  │  │ • Session isolation per user (no sharing)                                           │  │  │
│  │  │ • Credentials stored encrypted with user-derived key                                │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                            │  │
│  │  Layer 3: Service-to-Service Auth                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ • mTLS between Go Backend and SpotAPI Service                                       │  │  │
│  │  │ • gRPC interceptors for token validation                                            │  │  │
│  │  │ • Service mesh (Istio) for automatic mTLS                                           │  │  │
│  │  │ • API keys for external service access                                              │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ DATA ENCRYPTION                                                                            │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                            │  │
│  │  At Rest:                                                                                  │  │
│  │  • PostgreSQL: TDE (Transparent Data Encryption)                                          │  │
│  │  • Redis: Encrypted sessions with application-layer encryption                           │  │
│  │  • S3/MinIO: Server-side encryption (SSE-S3)                                             │  │
│  │  • Backups: Encrypted with customer-managed keys                                         │  │
│  │                                                                                            │  │
│  │  In Transit:                                                                               │  │
│  │  • Client ↔ Edge: TLS 1.3                                                                 │  │
│  │  • Edge ↔ Backend: TLS 1.3                                                                │  │
│  │  • Internal: mTLS (Istio)                                                                 │  │
│  │  • External APIs: TLS 1.3                                                                 │  │
│  │                                                                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ SECRETS MANAGEMENT                                                                         │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                            │  │
│  │  HashiCorp Vault:                                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Path                      │ Secret Type              │ Rotation                    │  │  │
│  │  │ ──────────────────────────┼──────────────────────────┼─────────────────────────────│  │  │
│  │  │ secret/spotify/encrypt    │ AES-256 key              │ Every 30 days               │  │  │
│  │  │ secret/captcha/capsolver  │ API key                  │ On-demand                   │  │  │
│  │  │ secret/captcha/2captcha   │ API key                  │ On-demand                   │  │  │
│  │  │ secret/db/postgres        │ Connection string        │ On rotation                 │  │  │
│  │  │ secret/redis/cluster      │ Connection string        │ On rotation                 │  │  │
│  │  │ secret/jwt/signing        │ RSA private key          │ Every 90 days               │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                            │  │
│  │  Kubernetes Secrets:                                                                        │  │
│  │  • Mounted from Vault via CSI driver                                                       │  │
│  │  • Never stored in etcd directly                                                          │  │
│  │  • Auto-rotation with pod restart                                                          │  │
│  │                                                                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ INPUT VALIDATION & SANITIZATION                                                            │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                            │  │
│  │  Go Backend:                                                                               │  │
│  │  • go-playground/validator for struct validation                                          │  │
│  │  • Spotify ID validation (regex: ^[a-zA-Z0-9]{22}$)                                      │  │
│  │  • SQL injection prevention (parameterized queries)                                       │  │
│  │  • XSS prevention (HTML escaping in responses)                                           │  │
│  │  • Request size limits (1MB max)                                                          │  │
│  │                                                                                            │  │
│  │  Python SpotAPI Service:                                                                   │  │
│  │  • Pydantic models for request validation                                                 │  │
│  │  • Type coercion with bounds checking                                                     │  │
│  │  • Command injection prevention (no shell=True)                                          │  │
│  │  • Path traversal prevention                                                               │  │
│  │                                                                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ RATE LIMITING                                                                               │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                            │  │
│  │  Per-User Limits (Token Bucket):                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Endpoint              │ Burst │ Rate      │ Window                                  │  │  │
│  │  │ ──────────────────────┼───────┼───────────┼─────────────────────────────────────────│  │  │
│  │  │ /auth/connect         │ 3     │ 1/hour    │ Sliding                                 │  │  │
│  │  │ /search               │ 20    │ 10/minute │ Sliding                                 │  │  │
│  │  │ /player/play          │ 30    │ 15/minute │ Sliding                                 │  │  │
│  │  │ /player/seek          │ 60    │ 30/minute │ Sliding                                 │  │  │
│  │  │ /playlist/create      │ 10    │ 5/hour    │ Sliding                                 │  │  │
│  │  │ /playlist/add         │ 50    │ 20/hour   │ Sliding                                 │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                            │  │
│  │  Global Limits (Redis Sliding Window):                                                     │  │
│  │  • Total API requests: 100,000/second                                                     │  │
│  │  • Spotify API calls: 100/second (protect quota)                                         │  │
│  │  • WebSocket connections: 1,000,000 total                                                 │  │
│  │                                                                                            │  │
│  │  Implementation:                                                                            │  │
│  │  • Redis Lua script for atomic token bucket                                               │  │
│  │  • Distributed across all pods                                                            │  │
│  │  • Headers returned: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset         │  │
│  │                                                                                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### OWASP Top 10 Mitigations

| Vulnerability | Mitigation |
|--------------|------------|
| **A01: Broken Access Control** | JWT validation, resource ownership checks, RBAC |
| **A02: Cryptographic Failures** | AES-256-GCM, TLS 1.3, Vault-managed keys |
| **A03: Injection** | Parameterized queries, input validation, ORM |
| **A04: Insecure Design** | Threat modeling, security architecture review |
| **A05: Security Misconfiguration** | Hardened containers, no default creds, CSP |
| **A06: Vulnerable Components** | Dependabot, SCA scanning, pinned versions |
| **A07: Auth Failures** | MFA support, session timeouts, secure cookies |
| **A08: Data Integrity** | Code signing, image signing, signed commits |
| **A09: Logging/Monitoring** | Structured logs, alerts, audit trails |
| **A10: SSRF** | Whitelisted egress, no user URLs, network policies |

---

## Production Readiness Checklist

### Pre-Launch

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PRODUCTION READINESS CHECKLIST                                      │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  INFRASTRUCTURE                                                                                  │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Kubernetes cluster deployed with auto-scaling                                                │
│  □ Pod resource limits defined (CPU, memory)                                                   │
│  □ Horizontal Pod Autoscaler configured                                                         │
│  □ Ingress controller with TLS termination                                                      │
│  □ Service mesh (Istio/Linkerd) for mTLS                                                       │
│  □ Network policies defined (zero-trust)                                                       │
│  □ CDN configured for static assets                                                            │
│  □ DDoS protection enabled (Cloudflare)                                                        │
│  □ Multi-AZ deployment                                                                          │
│  □ Backup and restore tested                                                                    │
│                                                                                                  │
│  DATABASE                                                                                        │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ PostgreSQL cluster with read replicas                                                        │
│  □ Connection pooling (PgBouncer)                                                               │
│  □ Partitioning strategy implemented                                                            │
│  □ Point-in-time recovery enabled                                                              │
│  □ Backup retention policy (30 days)                                                           │
│  □ Redis Cluster with sentinel                                                                  │
│  □ Redis persistence enabled (AOF + RDB)                                                       │
│  □ Connection limits tested                                                                     │
│                                                                                                  │
│  SECURITY                                                                                        │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ All secrets in HashiCorp Vault                                                               │
│  □ Encryption at rest enabled                                                                   │
│  □ TLS 1.3 everywhere                                                                           │
│  □ mTLS between services                                                                        │
│  □ Rate limiting configured                                                                     │
│  □ WAF rules deployed                                                                           │
│  □ Security headers set (CSP, HSTS, X-Frame-Options)                                           │
│  □ Dependency scanning in CI                                                                    │
│  □ Container image scanning                                                                     │
│  □ Penetration testing completed                                                                │
│                                                                                                  │
│  MONITORING                                                                                      │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Prometheus metrics exposed                                                                   │
│  □ Grafana dashboards created                                                                   │
│  □ Alerting rules configured                                                                    │
│  □ Log aggregation (Loki/Elasticsearch)                                                        │
│  □ Distributed tracing (Jaeger/Tempo)                                                          │
│  □ Error tracking (Sentry)                                                                      │
│  □ Synthetic monitoring (health checks)                                                        │
│  □ SLA/SLO dashboards                                                                           │
│                                                                                                  │
│  RELIABILITY                                                                                     │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Circuit breakers implemented                                                                 │
│  □ Retry logic with exponential backoff                                                        │
│  □ Graceful degradation tested                                                                  │
│  □ Chaos engineering tested                                                                     │
│  □ Disaster recovery plan documented                                                           │
│  □ Runbooks created for incidents                                                              │
│  □ On-call rotation established                                                                 │
│  □ Incident response process defined                                                           │
│                                                                                                  │
│  CODE QUALITY                                                                                    │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Unit test coverage > 80%                                                                    │
│  □ Integration tests passing                                                                    │
│  □ Load tests completed (target RPS achieved)                                                  │
│  □ Code review process in place                                                                 │
│  □ Linting in CI                                                                                │
│  □ Type checking (Go, Python, Dart)                                                            │
│  □ Documentation complete                                                                       │
│                                                                                                  │
│  COMPLIANCE                                                                                      │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ GDPR compliance (data deletion, export)                                                     │
│  □ Privacy policy updated                                                                       │
│  □ Terms of service include Spotify disclaimer                                                 │
│  □ Data retention policy defined                                                               │
│  □ Audit logging enabled                                                                        │
│  □ User consent flow implemented                                                               │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Monitoring & Observability

### Key Metrics

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              METRICS & ALERTS                                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  GOLDEN SIGNALS (SRE)                                                                           │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│                                                                                                  │
│  Latency:                                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Metric                              │ P50    │ P95    │ P99    │ Alert Threshold       │   │
│  │ ────────────────────────────────────┼────────┼────────┼────────┼───────────────────────│   │
│  │ http_request_duration_seconds       │ 50ms   │ 150ms  │ 300ms  │ P99 > 500ms (warning) │   │
│  │ spotify_api_request_duration        │ 100ms  │ 300ms  │ 600ms  │ P99 > 1s (warning)    │   │
│  │ websocket_message_delivery          │ 5ms    │ 20ms   │ 50ms   │ P99 > 100ms (warning) │   │
│  │ db_query_duration_seconds           │ 10ms   │ 50ms   │ 100ms  │ P99 > 200ms (warning) │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  Traffic:                                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Metric                              │ Current │ Peak    │ Capacity │ Alert              │   │
│  │ ────────────────────────────────────┼─────────┼─────────┼──────────┼────────────────────│   │
│  │ http_requests_per_second            │ 10K     │ 50K     │ 100K     │ >80% capacity      │   │
│  │ websocket_connections_active        │ 100K    │ 500K    │ 1M       │ >80% capacity      │   │
│  │ spotify_api_calls_per_second        │ 50      │ 80      │ 100      │ >80% capacity      │   │
│  │ redis_ops_per_second                │ 50K     │ 200K    │ 500K     │ >80% capacity      │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  Errors:                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Metric                              │ Threshold │ Severity │ Action                     │   │
│  │ ────────────────────────────────────┼───────────┼──────────┼────────────────────────────│   │
│  │ http_error_rate_5xx                 │ >1%       │ Critical │ Page on-call               │   │
│  │ http_error_rate_4xx                 │ >5%       │ Warning  │ Investigate                │   │
│  │ spotify_api_error_rate              │ >10%      │ Critical │ Enable fallback            │   │
│  │ spotapi_service_error_rate          │ >5%       │ Warning  │ Check logs                 │   │
│  │ websocket_disconnect_rate           │ >5%/min   │ Warning  │ Check Centrifugo           │   │
│  │ db_connection_errors                │ >0       │ Critical │ Check PostgreSQL           │   │
│  │ redis_connection_errors             │ >0       │ Critical │ Check Redis cluster        │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  Saturation:                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Resource                            │ Warning │ Critical │ Action                     │   │
│  │ ────────────────────────────────────┼─────────┼──────────┼────────────────────────────│   │
│  │ CPU utilization                    │ >70%    │ >90%      │ Scale out                  │   │
│  │ Memory utilization                 │ >80%    │ >95%      │ Scale out, check leaks     │   │
│  │ Disk usage                         │ >80%    │ >95%      │ Cleanup, expand            │   │
│  │ Network I/O                        │ >70%    │ >90%      │ Scale out                  │   │
│  │ DB connections                     │ >80%    │ >95%      │ Scale PgBouncer            │   │
│  │ Redis memory                       │ >80%    │ >95%      │ Evict, scale               │   │
│  │ Pod restart count                  │ >3/hour │ >10/hour  │ Investigate crash          │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  BUSINESS METRICS                                                                                │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│                                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Metric                                      │ Dashboard     │ Alert                     │   │
│  │ ────────────────────────────────────────────┼───────────────┼───────────────────────────│   │
│  │ spotify_connections_total                   │ Yes           │ < 100 (daily)             │   │
│  │ spotify_connections_active_24h              │ Yes           │ Drop > 50%                │   │
│  │ songs_played_total                          │ Yes           │ None                      │   │
│  │ playlists_created_total                     │ Yes           │ None                      │   │
│  │ playlists_shared_total                      │ Yes           │ None                      │   │
│  │ listen_along_sessions_active                │ Yes           │ None                      │   │
│  │ captcha_solve_success_rate                  │ Yes           │ < 80%                     │   │
│  │ session_refresh_success_rate                │ Yes           │ < 95%                     │   │
│  │ average_queue_time_ms                       │ Yes           │ > 5000ms                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Alert Routing

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              ALERT ROUTING                                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Severity Levels:                                                                                │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│                                                                                                  │
│  P1 - Critical (Page immediately)                                                               │
│  ├── Spotify API completely blocked                                                             │
│  ├── Database cluster down                                                                      │
│  ├── Redis cluster down                                                                         │
│  ├── All SpotAPI pods crash-looping                                                            │
│  └── Data breach detected                                                                       │
│      → PagerDuty → Phone call + SMS to on-call                                                 │
│      → Slack #incidents-critical                                                               │
│                                                                                                  │
│  P2 - High (Page within 15 minutes)                                                             │
│  ├── Error rate > 5%                                                                            │
│  ├── Latency P99 > 1 second                                                                     │
│  ├── CAPTCHA solver failure rate > 50%                                                         │
│  └── Memory utilization > 90%                                                                   │
│      → PagerDuty → Push notification to on-call                                                │
│      → Slack #incidents-high                                                                    │
│                                                                                                  │
│  P3 - Warning (Respond within 1 hour)                                                           │
│  ├── Error rate > 1%                                                                            │
│  ├── Latency P99 > 500ms                                                                        │
│  ├── CPU utilization > 80%                                                                      │
│  └── Session refresh failures > 5%                                                             │
│      → Slack{}
 #alerts-warning                                                               │
│                                                                                                  │
│  P4 - Info (Review daily)                                                                       │
│  ├── Non-critical service degradation                                                          │
│  ├── Certificate expiration warnings (7 days)                                                  │
│  └── Capacity planning alerts                                                                   │
│      → Slack #alerts-info                                                                       │
│      → Email digest                                                                             │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Logging Strategy

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              LOGGING ARCHITECTURE                                                │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Log Structure (JSON):                                                                           │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│                                                                                                  │
│  {                                                                                               │
│    "timestamp": "2026-05-17T10:30:45.123Z",                                                     │
│    "level": "INFO",                                                                              │
│    "service": "spotapi-service",                                                                 │
│    "version": "1.2.3",                                                                           │
│    "trace_id": "abc123def456",                                                                   │
│    "span_id": "789ghi012",                                                                       │
│    "user_id": "user_123",                                                                        │
│    "request_id": "req_456",                                                                      │
│    "message": "Playback command sent",                                                          │
│    "context": {                                                                                  │
│      "track_id": "6l8GvAyoUZwFDuSbsxDpSR",                                                      │
│      "action": "play",                                                                           │
│      "device_id": "web_player_abc"                                                              │
│    },                                                                                            │
│    "duration_ms": 45,                                                                            │
│    "status": "success"                                                                           │
│  }                                                                                               │
│                                                                                                  │
│  Log Levels:                                                                                     │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  • DEBUG: Development only (disabled in production)                                             │
│  • INFO: Normal operations (requests, state changes)                                            │
│  • WARN: Recoverable errors (retries, fallbacks)                                                │
│  • ERROR: Failures requiring attention (failed requests, errors)                                │
│  • FATAL: Service cannot continue (startup failures)                                            │
│                                                                                                  │
│  Retention:                                                                                      │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  • Hot storage (Loki): 7 days                                                                   │
│  • Warm storage (S3): 30 days                                                                   │
│  • Cold storage (Glacier): 1 year (for audit)                                                  │
│                                                                                                  │
│  Sensitive Data:                                                                                 │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  • NEVER log: passwords, session cookies, API keys, tokens                                     │
│  • Mask: email addresses (u***@domain.com), track IDs in debug logs                            │
│  • Hash: user IDs in public dashboards                                                          │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Estimation

### Monthly Infrastructure Cost (100K Daily Active Users)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              COST BREAKDOWN                                                      │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  COMPUTE                                                                                         │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  Kubernetes Cluster (EKS/GKE)                                                                   │
│  ├── 50 nodes (c6i.2xlarge) @ $0.34/hr                       = $12,240/month                  │
│  ├── Load balancers (ALB)                                     = $500/month                     │
│  └── NAT Gateway                                              = $1,000/month                   │
│  Subtotal: $13,740/month                                                                        │
│                                                                                                  │
│  DATABASE                                                                                        │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  PostgreSQL (RDS)                                                                               │
│  ├── Primary (db.r6g.xlarge)                                  = $350/month                     │
│  ├── 3 Read Replicas                                          = $700/month                     │
│  └── Storage (1TB)                                            = $100/month                     │
│                                                                                                  │
│  Redis Cluster (ElastiCache)                                                                    │
│  ├── 6 nodes (cache.r6g.large)                                = $1,800/month                   │
│  └── Storage (100GB)                                          = $50/month                      │
│  Subtotal: $3,000/month                                                                         │
│                                                                                                  │
│  NETWORKING & CDN                                                                               │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  Cloudflare Pro                                                = $20/month                      │
│  Cloudflare R2 (10TB storage)                                 = $150/month                     │
│  Bandwidth (50TB/month)                                       = $0 (free with R2)              │
│  Subtotal: $170/month                                                                           │
│                                                                                                  │
│  EXTERNAL SERVICES                                                                              │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  CAPTCHA Solver (Capsolver)                                                                    │
│  ├── 100K solves/month @ $0.002/solve                         = $200/month                     │
│                                                                                                  │
│  Monitoring (Datadog/Grafana Cloud)                                                            │
│  ├── 50 hosts @ $15/host                                      = $750/month                     │
│  ├── Logs (100GB)                                             = $50/month                      │
│  └── APM                                                       = $100/month                     │
│  Subtotal: $1,100/month                                                                         │
│                                                                                                  │
│  SECRETS & SECURITY                                                                             │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  HashiCorp Vault (Cloud)                                       = $200/month                     │
│  SSL Certificates (Cloudflare)                                 = $0 (included)                  │
│  Subtotal: $200/month                                                                           │
│                                                                                                  │
│  ═════════════════════════════════════════════════════════════════════════════════════════════  │
│  TOTAL ESTIMATED MONTHLY COST: ~$18,210/month                                                   │
│  Cost per Daily Active User: ~$0.18/month                                                       │
│  ═════════════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                                  │
│  Scaling to 1M DAU:                                                                             │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  • Compute: 10x ($137,400)                                                                      │
│  • Database: 5x ($15,000)                                                                       │
│  • External: 10x ($11,000)                                                                      │
│  • Estimated: ~$170,000/month ($0.17/DAU)                                                       │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Roadmap

### Phase 1: MVP (Weeks 1-4)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│  MVP DELIVERABLES                                                                               │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Week 1-2: Core Infrastructure                                                                  │
│  ├── SpotAPI Python service (basic)                                                            │
│  ├── Go backend music handlers (search, play, pause)                                           │
│  ├── PostgreSQL schema for sessions                                                            │
│  ├── Redis for session caching                                                                 │
│  └── Basic authentication flow                                                                  │
│                                                                                                  │
│  Week 3-4: Mobile Integration                                                                   │
│  ├── Flutter Sonic Drip screen updates                                                         │
│  ├── Music search functionality                                                                │
│  ├── Playback controls (play, pause, skip)                                                     │
│  ├── Session management UI                                                                     │
│  └── Deep link fallback                                                                        │
│                                                                                                  │
│  MVP Features:                                                                                   │
│  ✅ Connect Spotify account                                                                     │
│  ✅ Search for songs                                                                            │
│  ✅ Play/Pause/Skip                                                                             │
│  ✅ Create basic playlists                                                                      │
│  ✅ View now playing                                                                            │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 2: Social Features (Weeks 5-8)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│  SOCIAL FEATURES                                                                                │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Week 5-6: Playlist Sharing                                                                     │
│  ├── Share playlist to channel                                                                 │
│  ├── Playlist embed in messages                                                                │
│  ├── Add to library from shared playlist                                                       │
│  └── Collaborative playlists                                                                   │
│                                                                                                  │
│  Week 7-8: Listen Along                                                                         │
│  ├── Real-time sync via Centrifugo                                                             │
│  ├── Host/Join sessions                                                                        │
│  ├── Queue management for host                                                                 │
│  └── Presence indicators                                                                       │
│                                                                                                  │
│  Features:                                                                                       │
│  ✅ Share playlists to channels                                                                 │
│  ✅ Listen Along with friends                                                                   │
│  ✅ See what friends are playing                                                               │
│  ✅ Collaborative queue                                                                         │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 3: Scale & Reliability (Weeks 9-12)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│  SCALE & RELIABILITY                                                                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  Week 9-10: Resilience                                                                          │
│  ├── Circuit breakers                                                                          │
│  ├── Automatic session refresh                                                                 │
│  ├── Graceful degradation                                                                      │
│  ├── Multiple CAPTCHA solvers                                                                  │
│  └── Fallback mechanisms                                                                       │
│                                                                                                  │
│  Week 11-12: Observability                                                                      │
│  ├── Prometheus metrics                                                                        │
│  ├── Grafana dashboards                                                                        │
│  ├── Alerting rules                                                                            │
│  ├── Distributed tracing                                                                       │
│  └── Runbooks                                                                                  │
│                                                                                                  │
│  Production Ready:                                                                               │
│  ✅ Auto-scaling                                                                                │
│  ✅ Circuit breakers                                                                            │
│  ✅ Rate limiting                                                                               │
│  ✅ Monitoring & alerts                                                                         │
│  ✅ Disaster recovery                                                                           │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Appendix

### A. API Reference

| Endpoint | Method | Description | Rate Limit |
|----------|--------|-------------|------------|
| `/api/v1/music/auth/connect` | POST | Connect Spotify account | 3/hour |
| `/api/v1/music/auth/status` | GET | Check connection status | 10/min |
| `/api/v1/music/auth/disconnect` | DELETE | Disconnect Spotify | 5/hour |
| `/api/v1/music/search` | GET | Search songs/albums/artists | 20/min |
| `/api/v1/music/search/songs` | GET | Search songs only | 20/min |
| `/api/v1/music/search/albums` | GET | Search albums only | 20/min |
| `/api/v1/music/search/artists` | GET | Search artists only | 20/min |
| `/api/v1/music/player/state` | GET | Get current playback state | 30/min |
| `/api/v1/music/player/play` | POST | Play track | 30/min |
| `/api/v1/music/player/pause` | POST | Pause playback | 30/min |
| `/api/v1/music/player/skip` | POST | Skip next/prev | 30/min |
| `/api/v1/music/player/seek` | POST | Seek to position | 60/min |
| `/api/v1/music/player/volume` | POST | Set volume | 60/min |
| `/api/v1/music/player/queue` | POST | Add to queue | 50/min |
| `/api/v1/music/player/devices` | GET | List available devices | 10/min |
| `/api/v1/music/playlist` | POST | Create playlist | 10/hour |
| `/api/v1/music/playlist/{id}` | GET | Get playlist info | 60/min |
| `/api/v1/music/playlist/{id}` | PUT | Update playlist | 20/hour |
| `/api/v1/music/playlist/{id}` | DELETE | Delete playlist | 10/hour |
| `/api/v1/music/playlist/{id}/tracks` | POST | Add tracks | 50/hour |
| `/api/v1/music/playlist/{id}/tracks/{track_id}` | DELETE | Remove track | 50/hour |
| `/api/v1/music/playlist/{id}/share` | POST | Share to channel | 20/hour |
| `/api/v1/music/library` | GET | Get user's library | 30/min |
| `/api/v1/music/library/tracks` | GET | Get saved tracks | 30/min |
| `/api/v1/music/listen-along/create` | POST | Create session | 10/hour |
| `/api/v1/music/listen-along/{id}/join` | POST | Join session | 30/hour |
| `/api/v1/music/listen-along/{id}/leave` | POST | Leave session | 30/hour |

### B. Database Schema

```sql
-- Spotify sessions (partitioned by user_id hash)
CREATE TABLE spotify_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    encrypted_session BYTEA NOT NULL,
    device_id       TEXT,
    status          TEXT DEFAULT 'active', -- 'active', 'expired', 'revoked'
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    expires_at      TIMESTAMPTZ
) PARTITION BY HASH (user_id);

-- Create 16 partitions
CREATE TABLE spotify_sessions_p0 PARTITION OF spotify_sessions FOR VALUES WITH (MODULUS 16, REMAINDER 0);
CREATE TABLE spotify_sessions_p1 PARTITION OF spotify_sessions FOR VALUES WITH (MODULUS 16, REMAINDER 1);
-- ... (p2 through p15)

-- Music events (partitioned by month)
CREATE TABLE music_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    event_type      TEXT NOT NULL, -- 'play', 'pause', 'skip', 'seek', 'playlist_create', etc.
    track_id        TEXT,
    playlist_id     TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE music_events_2026_05 PARTITION OF music_events 
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Shared playlists
CREATE TABLE shared_playlists (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id     TEXT NOT NULL,
    playlist_name   TEXT,
    spotify_url     TEXT NOT NULL,
    track_count     INTEGER DEFAULT 0,
    shared_by       UUID NOT NULL REFERENCES users(id),
    channel_id      UUID REFERENCES channels(id),
    server_id       UUID REFERENCES servers(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Listen Along sessions
CREATE TABLE listen_along_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_user_id    UUID NOT NULL REFERENCES users(id),
    track_id        TEXT,
    is_playing      BOOLEAN DEFAULT false,
    position_ms     INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL
);

CREATE TABLE listen_along_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES listen_along_sessions(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    joined_at       TIMESTAMPTZ DEFAULT now(),
    UNIQUE (session_id, user_id)
);

-- Indexes
CREATE INDEX idx_spotify_sessions_user ON spotify_sessions (user_id);
CREATE INDEX idx_spotify_sessions_status ON spotify_sessions (status) WHERE status = 'active';
CREATE INDEX idx_music_events_user ON music_events (user_id, created_at DESC);
CREATE INDEX idx_shared_playlists_channel ON shared_playlists (channel_id, created_at DESC);
CREATE INDEX idx_listen_along_host ON listen_along_sessions (host_user_id);
```

### C. Redis Key Schema

```
# Sessions
spotify:session:{user_id}              -> encrypted_session (24h TTL)
spotify:device:{user_id}               -> device_list_json (1h TTL)
spotify:state:{user_id}                -> playback_state_json (5m TTL)

# Rate Limits
ratelimit:music:search:{user_id}       -> token_bucket (sliding window)
ratelimit:music:play:{user_id}         -> token_bucket
ratelimit:spotify:global               -> sliding_window_counter

# Queues (Asynq)
queue:spotify:login                    -> login_tasks
queue:spotify:refresh                  -> refresh_tasks
queue:spotify:playback                 -> playback_tasks

# Presence
presence:music:{user_id}               -> {device_id, last_seen}
presence:listen_along:{session_id}     -> set of user_ids

# Cache
cache:search:{query_hash}              -> search_results_json (10m TTL)
cache:playlist:{playlist_id}           -> playlist_info_json (30m TTL)
cache:library:{user_id}                -> library_json (30m TTL)
```

---

## Summary

Sonic Drip enables Flicko users to integrate Spotify directly into their social experience:

1. **No Premium Required** - SpotAPI bypasses Spotify's Premium requirement
2. **Full Playback Control** - Play, pause, skip, seek, volume, queue
3. **Social Features** - Share playlists, Listen Along with friends
4. **Production Ready** - Scaling to millions with proper failure handling
5. **Fallback Strategies** - Deep links, public API, graceful degradation

**Key Risk:** Spotify private API changes could break functionality. Always maintain fallback to deep links and consider official Spotify Web API integration as primary (with Premium requirement).

---

*Document Version: 2.0 | Last Updated: 2026-05-17 | Author: Flicko Architecture Team*


---

## Prevention Strategies & Solutions

This section provides detailed implementation solutions for preventing each failure point identified in the Failure Mode Decision Matrix.

---

### 1. Preventing Spotify API Rate Limiting / Bans

**Root Cause:** Spotify detects automated access patterns and enforces rate limits per IP/service account.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    SPOTIFY API RATE LIMIT PREVENTION                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│                                    ┌─────────────────┐                                          │
│                                    │   User Request  │                                          │
│                                    └────────┬────────┘                                          │
│                                             │                                                    │
│                                             ▼                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         LAYER 1: USER-LEVEL RATE LIMITER                                  │   │
│  │                                                                                           │   │
│  │  Token Bucket Algorithm (Redis Lua Script):                                               │   │
│  │  • Capacity: 10 tokens                                                                    │   │
│  │  • Refill Rate: 1 token/6 seconds                                                         │   │
│  │  • Per-user isolation                                                                     │   │
│  │                                                                                           │   │
│  │  Implementation:                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ -- Redis Lua Script for Atomic Token Bucket                                         │  │   │
│  │  │ local key = KEYS[1]                                                                 │  │   │
│  │  │ local capacity = tonumber(ARGV[1])                                                  │  │   │
│  │  │ local rate = tonumber(ARGV[2])         -- tokens per second                         │  │   │
│  │  │ local now = tonumber(ARGV[3])                                                       │  │   │
│  │  │                                                                                     │  │   │
│  │  │ local bucket = redis.call('HMGET', key, 'tokens', 'last_update')                   │  │   │
│  │  │ local tokens = tonumber(bucket[1])                                                  │  │   │
│  │  │ local last_update = tonumber(bucket[2])                                             │  │   │
│  │  │                                                                                     │  │   │
│  │  │ if not tokens then tokens = capacity end                                            │  │   │
│  │  │                                                                                     │  │   │
│  │  │ local elapsed = math.max(0, now - last_update)                                      │  │   │
│  │  │ local tokens_to_add = math.floor(elapsed * rate)                                    │  │   │
│  │  │ tokens = math.min(capacity, tokens + tokens_to_add)                                 │  │   │
│  │  │                                                                                     │  │   │
│  │  │ if tokens > 0 then                                                                  │  │   │
│  │  │     tokens = tokens - 1                                                             │  │   │
│  │  │     redis.call('HMSET', key, 'tokens', tokens, 'last_update', now)                  │  │   │
│  │  │     redis.call('PEXPIRE', key, 60000)                                               │  │   │
│  │  │     return 1  -- Allowed                                                            │  │   │
│  │  │ else                                                                                │  │   │
│  │  │     return 0  -- Rate limited                                                       │  │   │
│  │  │ end                                                                                 │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                             │                                                    │
│                                             ▼                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                      LAYER 2: GLOBAL SPOTAPI RATE LIMITER                                 │   │
│  │                                                                                           │   │
│  │  Sliding Window Counter (All SpotAPI instances combined):                                 │   │
│  │  • Global limit: 100 requests/second to Spotify                                          │   │
│  │  • Distributed across all pods via Redis                                                 │   │
│  │  • Priority queue: playback > search > metadata                                          │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ Priority Queue Implementation (Go):                                                  │  │   │
│  │  │                                                                                      │  │   │
│  │  │ type Priority int                                                                   │  │   │
│  │  │ const (                                                                             │  │   │
│  │  │     PriorityPlayback Priority = iota  // Highest                                    │  │   │
│  │  │     PrioritySearch                   // Medium                                      │  │   │
│  │  │     PriorityMetadata                 // Lowest                                      │  │   │
│  │  │ )                                                                                   │  │   │
│  │  │                                                                                     │  │   │
│  │  │ type SpotifyRequest struct {                                                        │  │   │
│  │  │     Priority  Priority                                                             │  │   │
│  │  │     UserID   string                                                                │  │   │
│  │  │     Action   string                                                                │  │   │
│  │  │     Payload  interface{}                                                           │  │   │
│  │  │     Response chan *Response                                                        │  │   │
│  │  │ }                                                                                   │  │   │
│  │  │                                                                                     │  │   │
│  │  │ type RequestQueue struct {                                                          │  │   │
│  │  │     high   chan *SpotifyRequest  // Playback                                        │  │   │
│  │  │     medium chan *SpotifyRequest  // Search                                          │  │   │
│  │  │     low    chan *SpotifyRequest  // Metadata                                        │  │   │
│  │  │     limiter *rate.Limiter        // 100 req/s global                                │  │   │
│  │  │ }                                                                                   │  │   │
│  │  │                                                                                     │  │   │
│  │  │ func (q *RequestQueue) Process() {                                                  │  │   │
│  │  │     for {                                                                           │  │   │
│  │  │         q.limiter.Wait(context.Background())                                        │  │   │
│  │  │                                                                                     │  │   │
│  │  │         select {                                                                    │  │   │
│  │  │         case req := <-q.high:                                                       │  │   │
│  │  │             q.execute(req)                                                          │  │   │
│  │  │         default:                                                                    │  │   │
│  │  │             select {                                                                │  │   │
│  │  │             case req := <-q.high:                                                   │  │   │
│  │  │                 q.execute(req)                                                      │  │   │
│  │  │             case req := <-q.medium:                                                 │  │   │
│  │  │                 q.execute(req)                                                      │  │   │
│  │  │             case req := <-q.low:                                                    │  │   │
│  │  │                 q.execute(req)                                                      │  │   │
│  │  │             }                                                                       │  │   │
│  │  │         }                                                                           │  │   │
│  │  │     }                                                                               │  │   │
│  │  │ }                                                                                   │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                             │                                                    │
│                                             ▼                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    LAYER 3: RESIDENTIAL PROXY ROTATION                                    │   │
│  │                                                                                           │   │
│  │  Pool Configuration:                                                                       │   │
│  │  • 1000+ residential IP addresses                                                         │   │
│  │  • Geographic distribution matching user locations                                        │   │
│  │  • Rotating proxy per request (sticky session for login flow)                            │   │
│  │                                                                                           │   │
│  │  Proxy Selection Strategy:                                                                │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ 1. Login requests: Use sticky session proxy (same IP for entire auth flow)           │  │   │
│  │  │ 2. Playback requests: Round-robin from pool                                          │  │   │
│  │  │ 3. Search requests: Use cheapest/fastest proxy                                       │  │   │
│  │  │ 4. On 429 error: Blacklist proxy for 1 hour, retry with different proxy             │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                                           │   │
│  │  Code Example:                                                                             │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ class ProxyManager:                                                                  │  │   │
│  │  │     def __init__(self):                                                              │  │   │
│  │  │         self.pool = ResidentialProxyPool(                                           │  │   │
│  │  │             provider="brightdata",  # or iproyal, smartproxy                        │  │   │
│  │  │             pool_size=1000,                                                          │  │   │
│  │  │             geo_targeting=True                                                       │  │   │
│  │  │         )                                                                            │  │   │
│  │  │         self.blacklist = TTLCache(maxsize=10000, ttl=3600)                          │  │   │
│  │  │                                                                                      │  │   │
│  │  │     def get_proxy(self, user_id: str, request_type: str) -> str:                    │  │   │
│  │  │         if request_type == "login":                                                  │  │   │
│  │  │         # Sticky session for login flow                                             │  │   │
│  │  │             return self.pool.get_sticky_proxy(user_id)                              │  │   │
│  │  │                                                                                      │  │   │
│  │  │         # Round-robin with blacklist check                                           │  │   │
│  │  │         for _ in range(10):  # Max 10 attempts                                       │  │   │
│  │  │             proxy = self.pool.get_random_proxy()                                    │  │   │
│  │  │             if proxy not in self.blacklist:                                          │  │   │
│  │  │                 return proxy                                                         │  │   │
│  │  │         raise NoProxyAvailableError()                                                │  │   │
│  │  │                                                                                      │  │   │
│  │  │     def mark_failed(self, proxy: str):                                               │  │   │
│  │  │         self.blacklist[proxy] = True                                                │  │   │
│  │  │         metrics.proxy_blacklisted.inc()                                             │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                             │                                                    │
│                                             ▼                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                      LAYER 4: CIRCUIT BREAKER                                             │   │
│  │                                                                                           │   │
│  │  States: CLOSED → OPEN → HALF-OPEN → CLOSED                                              │   │
│  │                                                                                           │   │
│  │  Configuration:                                                                            │   │
│  │  • Error threshold: 10% errors in 1 minute                                                │   │
│  │  • Open duration: 30 seconds                                                              │   │
│  │  • Half-open requests: 3                                                                  │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Go implementation with sony/gobreaker                                            │  │   │
│  │  │                                                                                      │  │   │
│  │  │ var spotifyBreaker = gobreaker.NewCircuitBreaker(gobreaker.Settings{                │  │   │
│  │  │     Name:        "SpotifyAPI",                                                       │  │   │
│  │  │     MaxRequests: 3,                  // Half-open state                              │  │   │
│  │  │     Interval:    time.Minute,        // Stats reset                                  │  │   │
│  │  │     Timeout:     30 * time.Second,   // Open → Half-open                             │  │   │
│  │  │     ReadyToTrip: func(counts gobreaker.Counts) bool {                                │  │   │
│  │  │         return counts.ConsecutiveFailures > 5 ||                                     │  │   │
│  │  │                float64(counts.TotalFailures)/float64(counts.Requests) > 0.1         │  │   │
│  │  │     },                                                                               │  │   │
│  │  │     OnStateChange: func(name string, from, to gobreaker.State) {                     │  │   │
│  │  │         log.Warn("circuit breaker state changed",                                    │  │   │
│  │  │             zap.String("name", name),                                                │  │   │
│  │  │             zap.String("from", from.String()),                                       │  │   │
│  │  │             zap.String("to", to.String()))                                           │  │   │
│  │  │                                                                                      │  │   │
│  │  │         if to == gobreaker.StateOpen {                                               │  │   │
│  │  │             // Trigger fallback mode                                                 │  │   │
│  │  │             featureFlags.Disable("spotapi_playback")                                │  │   │
│  │  │             alertManager.Trigger("spotify_api_degraded")                            │  │   │
│  │  │         }                                                                            │  │   │
│  │  │     },                                                                               │  │   │
│  │  │ })                                                                                   │  │   │
│  │  │                                                                                      │  │   │
│  │  │ func callSpotifyAPI(ctx context.Context, req *Request) (*Response, error) {          │  │   │
│  │  │     result, err := spotifyBreaker.Execute(func() (interface{}, error) {              │  │   │
│  │  │         return doSpotifyRequest(ctx, req)                                            │  │   │
│  │  │     })                                                                               │  │   │
│  │  │                                                                                      │  │   │
│  │  │     if err == gobreaker.ErrOpenState {                                               │  │   │
│  │  │         // Circuit is open, use fallback                                             │  │   │
│  │  │         return fallbackToDeepLink(ctx, req)                                          │  │   │
│  │  │     }                                                                                │  │   │
│  │  │     return result.(*Response), err                                                   │  │   │
│  │  │ }                                                                                    │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Go Implementation - Complete Rate Limiter:**

```go
// backend/internal/middleware/spotify_rate_limiter.go

package middleware

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type SpotifyRateLimiter struct {
	redis       *redis.Client
	userLimit   int           // tokens per user
	globalLimit int           // global req/sec
	window      time.Duration // sliding window
}

func NewSpotifyRateLimiter(rdb *redis.Client) *SpotifyRateLimiter {
	return &SpotifyRateLimiter{
		redis:       rdb,
		userLimit:   10,              // 10 requests per user per window
		globalLimit: 100,             // 100 global requests per second
		window:      time.Minute,     // 1 minute window
	}
}

// AllowUser checks if user can make a request (Token Bucket)
func (r *SpotifyRateLimiter) AllowUser(ctx context.Context, userID string) (bool, time.Duration, error) {
	key := fmt.Sprintf("ratelimit:spotify:user:%s", userID)
	now := float64(time.Now().UnixMilli())

	// Lua script for atomic token bucket check
	script := redis.NewScript(`
		local key = KEYS[1]
		local capacity = tonumber(ARGV[1])
		local rate = tonumber(ARGV[2])
		local now = tonumber(ARGV[3])
		
		local bucket = redis.call('HMGET', key, 'tokens', 'last_update')
		local tokens = tonumber(bucket[1])
		local last_update = tonumber(bucket[2])
		
		if not tokens then
			tokens = capacity
			last_update = now
		end
		
		local elapsed = math.max(0, (now - last_update) / 1000)
		local tokens_to_add = math.floor(elapsed * rate)
		tokens = math.min(capacity, tokens + tokens_to_add)
		
		local retry_after = 0
		if tokens > 0 then
			tokens = tokens - 1
			redis.call('HMSET', key, 'tokens', tokens, 'last_update', now)
			redis.call('PEXPIRE', key, 60000)
			return {1, 0}
		else
			retry_after = math.ceil(1 / rate * 1000)
			return {0, retry_after}
		end
	`)

	result, err := script.Run(ctx, r.redis, []string{key}, 
		r.userLimit,           // capacity
		float64(r.userLimit)/60.0, // rate (tokens/sec)
		now,
	).Slice()
	
	if err != nil {
		return false, 0, err
	}

	allowed := result[0].(int64) == 1
	retryAfter := time.Duration(result[1].(int64)) * time.Millisecond
	
	return allowed, retryAfter, nil
}

// AllowGlobal checks global rate limit (Sliding Window)
func (r *SpotifyRateLimiter) AllowGlobal(ctx context.Context) (bool, error) {
	key := "ratelimit:spotify:global"
	now := time.Now().Unix()
	windowStart := now - int64(r.window.Seconds())

	script := redis.NewScript(`
		local key = KEYS[1]
		local limit = tonumber(ARGV[1])
		local window_start = tonumber(ARGV[2])
		local now = tonumber(ARGV[3])
		
		-- Remove old entries
		redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)
		
		-- Count current
		local count = redis.call('ZCARD', key)
		
		if count < limit then
			redis.call('ZADD', key, now, now .. '-' .. math.random())
			redis.call('EXPIRE', key, 120)
			return 1
		else
			return 0
		end
	`)

	result, err := script.Run(ctx, r.redis, []string{key}, 
		r.globalLimit * int(r.window.Seconds()),
		windowStart,
		now,
	).Int()
	
	if err != nil {
		return false, err
	}

	return result == 1, nil
}
```

---

### 2. Preventing CAPTCHA Solver Failure

**Root Cause:** CAPTCHA solving services can fail, get banned, or change pricing.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    CAPTCHA SOLVER HIGH AVAILABILITY                                              │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         MULTI-PROVIDER CAPTCHA SOLVER                                     │   │
│  │                                                                                           │   │
│  │  Provider Priority:                                                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ 1. Capsolver (Primary)       - $0.002/solve, 95% success rate                      │   │   │
│  │  │ 2. 2Captcha (Backup)         - $0.003/solve, 92% success rate                      │   │   │
│  │  │ 3. Anti-Captcha (Backup)     - $0.002/solve, 90% success rate                      │   │   │
│  │  │ 4. Manual Cookie Import      - User extracts cookies from browser (free)           │   │   │
│  │  └────────────────────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ class MultiCaptchaSolver:                                                             │  │   │
│  │  │     def __init__(self):                                                               │  │   │
│  │  │         self.providers = [                                                           │  │   │
│  │  │             CapsolverClient(api_key=settings.CAPSOLVER_KEY),                        │  │   │
│  │  │             TwoCaptchaClient(api_key=settings.TWOCAPTCHA_KEY),                      │  │   │
│  │  │             AntiCaptchaClient(api_key=settings.ANTICAPTCHA_KEY),                    │  │   │
│  │  │         ]                                                                             │  │   │
│  │  │         self.health_checker = HealthChecker()                                        │  │   │
│  │  │                                                                                       │  │   │
│  │  │     async def solve(self, captcha_type: str, site_key: str, page_url: str) -> str:   │  │   │
│  │  │         for provider in self.providers:                                              │  │   │
│  │  │             if not self.health_checker.is_healthy(provider.name):                   │  │   │
│  │  │                 continue                                                              │  │   │
│  │  │                                                                                       │  │   │
│  │  │             try:                                                                      │  │   │
│  │  │                 start = time.time()                                                   │  │   │
│  │  │                 result = await provider.solve(captcha_type, site_key, page_url)      │  │   │
│  │  │                 duration = time.time() - start                                        │  │   │
│  │  │                                                                                       │  │   │
│  │  │                 metrics.captcha_solve_success.labels(                                │  │   │
│  │  │                     provider=provider.name                                            │  │   │
│  │  │                 ).inc()                                                               │  │   │
│  │  │                 metrics.captcha_solve_duration.labels(                               │  │   │
│  │  │                     provider=provider.name                                            │  │   │
│  │  │                 ).observe(duration)                                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │                 return result                                                         │  │   │
│  │  │                                                                                       │  │   │
│  │  │             except (CaptchaSolverError, TimeoutError) as e:                          │  │   │
│  │  │                 self.health_checker.mark_unhealthy(                                  │  │   │
│  │  │                     provider.name,                                                    │  │   │
│  │  │                     duration=300  // 5 minutes                                        │  │   │
│  │  │                 )                                                                     │  │   │
│  │  │                 metrics.captcha_solve_failure.labels(                                │  │   │
│  │  │                     provider=provider.name, error=type(e).__name__                   │  │   │
│  │  │                 ).inc()                                                               │  │   │
│  │  │                 continue                                                              │  │   │
│  │  │                                                                                       │  │   │
│  │  │         raise AllCaptchaSolversFailedError("No healthy captcha solver available")     │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         COOKIE IMPORT FALLBACK                                            │   │
│  │                                                                                           │   │
│  │  When CAPTCHA solving fails, users can manually import cookies:                          │   │
│  │                                                                                           │   │
│  │  User Flow:                                                                                │   │
│  │  1. Open Spotify.com in browser and login                                                 │   │
│  │  2. Open Developer Tools → Application → Cookies                                         │   │
│  │  3. Export cookies (sp_dc, sp_key, sp_t, etc.)                                           │   │
│  │  4. Paste into Flicko "Import Session" screen                                            │   │
│  │  5. Flicko validates and stores encrypted session                                        │   │
│  │                                                                                           │   │
│  │  UI Implementation:                                                                        │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Flutter - Cookie Import Screen                                                    │  │   │
│  │  │ class CookieImportScreen extends StatefulWidget {                                    │  │   │
│  │  │   @override                                                                           │  │   │
│  │  │   Widget build(BuildContext context) {                                               │  │   │
│  │  │     return Scaffold(                                                                 │  │   │
│  │  │       appBar: AppBar(title: Text('Import Spotify Session')),                         │  │   │
│  │  │       body: Column(                                                                  │  │   │
│  │  │         children: [                                                                  │  │   │
│  │  │           // Instructions                                                            │  │   │
│  │  │           _buildInstructions(),                                                      │  │   │
│  │  │                                                                                      │  │   │
│  │  │           // Cookie input                                                            │  │   │
│  │  │           TextField(                                                                 │  │   │
│  │  │             decoration: InputDecoration(                                             │  │   │
│  │  │               labelText: 'Paste cookies (JSON format)',                              │  │   │
│  │  │               hintText: '{"sp_dc": "...", "sp_key": "..."}',                         │  │   │
│  │  │             ),                                                                       │  │   │
│  │  │             maxLines: 5,                                                             │  │   │
│  │  │             onChanged: (value) => _cookies = value,                                  │  │   │
│  │  │           ),                                                                         │  │   │
│  │  │                                                                                      │  │   │
│  │  │           // Browser extension link                                                  │  │   │
│  │  │           TextButton(                                                                │  │   │
│  │  │             onPressed: () => _openExtensionDownload(),                               │  │   │
│  │  │             child: Text('Download browser extension for auto-export'),               │  │   │
│  │  │           ),                                                                         │  │   │
│  │  │                                                                                      │  │   │
│  │  │           ElevatedButton(                                                            │  │   │
│  │  │             onPressed: _importCookies,                                               │  │   │
│  │  │             child: Text('Import Session'),                                           │  │   │
│  │  │           ),                                                                         │  │   │
│  │  │         ],                                                                           │  │   │
│  │  │       ),                                                                             │  │   │
│  │  │     );                                                                               │  │   │
│  │  │   }                                                                                  │  │   │
│  │  │ }                                                                                    │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Preventing Session Expiration / Invalidation

**Root Cause:** Spotify sessions expire or get invalidated by security events.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    SESSION HEALTH MANAGEMENT                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    PROACTIVE SESSION REFRESH WORKER                                       │   │
│  │                                                                                           │   │
│  │  Runs every 6 hours to refresh sessions before they expire                               │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ # Python - Session Refresh Worker (Asynq Task)                                       │  │   │
│  │  │                                                                                       │  │   │
│  │  │ async def refresh_user_session(user_id: str) -> dict:                                │  │   │
│  │  │     """Refresh Spotify session before it expires"""                                  │  │   │
│  │  │     # Get encrypted session from storage                                             │  │   │
│  │  │     encrypted_session = await session_store.get(user_id)                             │  │   │
│  │  │     if not encrypted_session:                                                        │  │   │
│  │  │         return {"status": "no_session"}                                              │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Decrypt session                                                                 │  │   │
│  │  │     session = decrypt_session(encrypted_session)                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Check if refresh is needed                                                     │  │   │
│  │  │     session_age = time.time() - session.get('created_at', 0)                         │  │   │
│  │  │     if session_age < MAX_SESSION_AGE * 0.7:  # Refresh at 70% of max age            │  │   │
│  │  │         return {"status": "not_needed"}                                              │  │   │
│  │  │                                                                                       │  │   │
│  │  │     try:                                                                              │  │   │
│  │  │         # Use SpotAPI to refresh session                                             │  │   │
│  │  │         login = Login.from_cookies(session['cookies'])                               │  │   │
│  │  │                                                                                       │  │   │
│  │  │         # Make a lightweight API call to check session validity                      │  │   │
│  │  │         user_info = await login.get_user_info()                                      │  │   │
│  │  │                                                                                       │  │   │
│  │  │         # Session is still valid, update timestamp                                   │  │   │
│  │  │         session['last_validated'] = time.time()                                      │  │   │
│  │  │         await session_store.save(user_id, encrypt_session(session))                  │  │   │
│  │  │                                                                                       │  │   │
│  │  │         metrics.session_refresh_success.inc()                                        │  │   │
│  │  │         return {"status": "refreshed"}                                               │  │   │
│  │  │                                                                                       │  │   │
│  │  │     except SessionExpiredError:                                                      │  │   │
│  │  │         # Session is invalid, mark for re-auth                                       │  │   │
│  │  │         await session_store.mark_invalid(user_id)                                    │  │   │
│  │  │                                                                                       │  │   │
│  │  │         # Send push notification to user                                             │  │   │
│  │  │         await push_notifier.send(                                                    │  │   │
│  │  │             user_id,                                                                 │  │   │
│  │  │             title="Spotify Session Expired",                                         │  │   │
│  │  │             body="Please reconnect your Spotify account",                            │  │   │
│  │  │             action="reconnect_spotify"                                               │  │   │
│  │  │         )                                                                             │  │   │
│  │  │                                                                                       │  │   │
│  │  │         metrics.session_expired.inc()                                                │  │   │
│  │  │         return {"status": "expired", "notified": True}                               │  │   │
│  │  │                                                                                       │  │   │
│  │  │     except Exception as e:                                                           │  │   │
│  │  │         metrics.session_refresh_error.labels(error=type(e).__name__).inc()           │  │   │
│  │  │         return {"status": "error", "message": str(e)}                                │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    REACTIVE SESSION VALIDATION                                            │   │
│  │                                                                                           │   │
│  │  On every API request, check if session is still valid                                   │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Go - Session Validation Middleware                                                │  │   │
│  │  │                                                                                       │  │   │
│  │  │ func ValidateSpotifySession(next http.Handler) http.Handler {                        │  │   │
│  │  │     return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {           │  │   │
│  │  │         userID := auth.UserIDFromContext(r.Context())                                │  │   │
│  │  │         if userID == "" {                                                            │  │   │
│  │  │             next.ServeHTTP(w, r)                                                     │  │   │
│  │  │             return                                                                   │  │   │
│  │  │         }                                                                             │  │   │
│  │ {}
│  │  │                                                                                       │  │   │
│  │  │         // Check session health from Redis cache                                     │  │   │
│  │  │         sessionHealth := getSessionHealth(userID)                                    │  │   │
│  │  │                                                                                       │  │   │
│  │  │         switch sessionHealth {                                                        │  │   │
│  │  │         case HealthValid:                                                            │  │   │
│  │  │             // Session is healthy, proceed                                           │  │   │
│  │  │             next.ServeHTTP(w, r)                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │         case HealthUnknown:                                                          │  │   │
│  │  │             // Need to validate session                                              │  │   │
│  │  │             valid, err := validateSession(r.Context(), userID)                       │  │   │
│  │  │             if err != nil {                                                          │  │   │
│  │  │                 respondError(w, http.StatusInternalServerError, err)                  │  │   │
│  │  │                 return                                                               │  │   │
│  │  │             }                                                                        │  │   │
│  │  │             if !valid {                                                              │  │   │
│  │  │                 // Session invalid, return error                                     │  │   │
│  │  │                 respondJSON(w, http.StatusUnauthorized, map[string]interface{}{      │  │   │
│  │  │                     "error": "spotify_session_invalid",                              │  │   │
│  │  │                     "message": "Your Spotify session has expired. Please reconnect.",│  │   │
│  │  │                     "reconnect_url": "/settings/spotify/connect",                    │  │   │
│  │  │                 })                                                                   │  │   │
│  │  │                 return                                                               │  │   │
│  │  │             }                                                                        │  │   │
│  │  │             // Cache valid status                                                    │  │   │
│  │  │             setSessionHealth(userID, HealthValid, 5*time.Minute)                    │  │   │
│  │  │             next.ServeHTTP(w, r)                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │         case HealthInvalid:                                                          │  │   │
│  │  │             // Already known to be invalid                                           │  │   │
│  │  │             respondJSON(w, http.StatusUnauthorized, map[string]interface{}{          │  │   │
│  │  │                 "error": "spotify_session_invalid",                                  │  │   │
│  │  │                 "message": "Your Spotify session has expired. Please reconnect.",    │  │   │
│  │  │             })                                                                       │  │   │
│  │  │         }                                                                            │  │   │
│  │  │     })                                                                               │  │   │
│  │  │ }                                                                                    │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    AUTOMATIC RE-LOGIN ATTEMPT                                              │   │
│  │                                                                                           │   │
│  │  If user stored credentials, attempt automatic re-login                                  │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ async def attempt_auto_relogin(user_id: str) -> bool:                                │  │   │
│  │  │     """Try to automatically re-login using stored credentials"""                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Check if user has stored credentials                                           │  │   │
│  │  │     credentials = await credential_store.get(user_id)                                │  │   │
│  │  │     if not credentials:                                                              │  │   │
│  │  │         return False                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Check rate limit for auto-relogin attempts                                     │  │   │
│  │  │     attempts = await redis.get(f"relogin_attempts:{user_id}")                        │  │   │
│  │  │     if attempts and int(attempts) >= 3:                                              │  │   │
│  │  │         logger.info("too many relogin attempts", user_id=user_id)                    │  │   │
│  │  │         return False                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Increment attempt counter                                                      │  │   │
│  │  │     await redis.incr(f"relogin_attempts:{user_id}")                                  │  │   │
│  │  │     await redis.expire(f"relogin_attempts:{user_id}", 86400)  # 24 hours             │  │   │
│  │  │                                                                                       │  │   │
│  │  │     try:                                                                              │  │   │
│  │  │         # Attempt login with CAPTCHA solver                                          │  │   │
│  │  │         login = Login(                                                               │  │   │
│  │  │             config=Config(solver=capsolver_client),                                 │  │   │
│  │  │             password=decrypt(credentials['password']),                               │  │   │
│  │  │             email=credentials['email']                                               │  │   │
│  │  │         )                                                                             │  │   │
│  │  │         login.login()                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │         # Success! Store new session                                                 │  │   │
│  │  │         await session_store.save(user_id, encrypt(login.get_cookies()))              │  │   │
│  │  │         await redis.delete(f"relogin_attempts:{user_id}")                            │  │   │
│  │  │                                                                                       │  │   │
│  │  │         # Notify user of successful reconnection                                     │  │   │
│  │  │         await push_notifier.send(                                                    │  │   │
│  │  │             user_id,                                                                 │  │   │
│  │  │             title="Spotify Reconnected",                                             │  │   │
│  │  │             body="Your Spotify account has been automatically reconnected."         │  │   │
│  │  │         )                                                                             │  │   │
│  │  │                                                                                       │  │   │
│  │  │         metrics.auto_relogin_success.inc()                                           │  │   │
│  │  │         return True                                                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │     except Exception as e:                                                           │  │   │
│  │  │         logger.error("auto relogin failed", user_id=user_id, error=str(e))           │  │   │
│  │  │         metrics.auto_relogin_failure.labels(error=type(e).__name__).inc()            │  │   │
│  │  │         return False                                                                 │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 4. Preventing WebSocket Disconnection Storms

**Root Cause:** Network issues cause mass reconnections, overwhelming servers.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    WEBSOCKET RESILIENCE                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    CLIENT-SIDE RECONNECTION STRATEGY                                      │   │
│  │                                                                                           │   │
│  │  Exponential Backoff with Jitter:                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Dart - WebSocket Reconnection Handler                                             │  │   │
│  │  │                                                                                       │  │   │
│  │  │ class WebSocketReconnector {                                                         │  │   │
│  │  │   static const int maxRetries = 10;                                                  │  │   │
│  │  │   static const Duration baseDelay = Duration(seconds: 1);                            │  │   │
│  │  │   static const Duration maxDelay = Duration(seconds: 30);                            │  │   │
│  │  │                                                                                       │  │   │
│  │  │   int _retryCount = 0;                                                               │  │   │
│  │  │   Timer? _reconnectTimer;                                                            │  │   │
│  │  │                                                                                       │  │   │
│  │  │   Duration _calculateDelay() {                                                       │  │   │
│  │  │     // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s...                        │  │   │
│  │  │     final exponential = baseDelay * (1 << _retryCount);                              │  │   │
│  │  │     final capped = exponential < maxDelay ? exponential : maxDelay;                  │  │   │
│  │  │                                                                                       │  │   │
│  │  │     // Add jitter (±25%) to prevent thundering herd                                  │  │   │
│  │  │     final jitter = capped.inMilliseconds * 0.25 * (Random().nextDouble() - 0.5);     │  │   │
│  │  │     return Duration(milliseconds: capped.inMilliseconds + jitter.toInt());           │  │   │
│  │  │   }                                                                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │   Future<void> connect() async {                                                     │  │   │
│  │  │     try {                                                                             │  │   │
│  │  │       _retryCount = 0;                                                               │  │   │
│  │  │       await _doConnect();                                                            │  │   │
│  │  │     } catch (e) {                                                                     │  │   │
│  │  │       _scheduleReconnect();                                                          │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │   }                                                                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │   void _scheduleReconnect() {                                                        │  │   │
│  │  │     if (_retryCount >= maxRetries) {                                                 │  │   │
│  │  │       _showConnectionError();                                                        │  │   │
│  │  │       return;                                                                         │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     _retryCount++;                                                                    │  │   │
│  │  │     final delay = _calculateDelay();                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     logger.info('Reconnecting in ${delay.inMilliseconds}ms (attempt $_retryCount)'); │  │   │
│  │  │                                                                                       │  │   │
│  │  │     _reconnectTimer = Timer(delay, () async {                                        │  │   │
│  │  │       try {                                                                           │  │   │
│  │  │         await _doConnect();                                                          │  │   │
│  │  │         // Success - reset retry count                                               │  │   │
│  │  │         _retryCount = 0;                                                             │  │   │
│  │  │       } catch (e) {                                                                   │  │   │
│  │  │         _scheduleReconnect();                                                        │  │   │
│  │  │       }                                                                               │  │  │
│  │  │     });                                                                               │  │   │
│  │  │   }                                                                                   │  │   │
│  │  │ }                                                                                     │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    CENTRIFUGO HISTORY RECOVERY                                            │   │
│  │                                                                                           │   │
│  │  Server Configuration:                                                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // config.json                                                                        │  │   │
│  │  │ {                                                                                     │  │   │
│  │  │   "v3_use_offset": true,                                                              │  │   │
│  │  │   "history_size": 100,           // Keep last 100 messages                           │  │   │
│  │  │   "history_ttl": "300s",         // 5 minutes retention                              │  │   │
│  │  │   "recover": true,               // Enable recovery on reconnect                     │  │   │
│  │  │   "client_insecure": false,                                                            │  │   │
│  │  │   "token_hmac_secret_key": "${CENTRIFUGO_SECRET}",                                     │  │   │
│  │  │   "engine": {                                                                          │  │   │
│  │  │     "type": "redis",                                                                   │  │   │
│  │  │     "redis": {                                                                         │  │   │
│  │  │       "host": "redis-cluster",                                                         │  │   │
│  │  │       "port": 6379                                                                     │  │   │
│  │  │     }                                                                                  │  │   │
│  │  │   },                                                                                   │  │   │
│  │  │   "namespaces": [                                                                      │  │   │
│  │  │     {                                                                                  │  │   │
│  │  │       "name": "music",                                                                 │  │   │
│  │  │       "history_size": 100,                                                             │  │   │
│  │  │       "history_ttl": "300s",                                                           │  │   │
│  │  │       "force_recovery": true,   // Force client to recover                            │  │   │
│  │  │       "force_positioning": true  // Ensure message ordering                           │  │   │
│  │  │     }                                                                                  │  │   │
│  │  │   ]                                                                                    │  │   │
│  │  │ }                                                                                      │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    SERVER-SIDE CONNECTION LIMITING                                        │   │
│  │                                                                                           │   │
│  │  Prevent thundering herd with connection rate limiting:                                  │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Go - Connection Rate Limiter for Centrifugo Proxy                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │ type ConnectionLimiter struct {                                                       │  │   │
│  │  │     redis       *redis.Client                                                        │  │   │
│  │  │     maxPerMin   int           // Max new connections per minute                      │  │   │
│  │  │     maxPerUser  int           // Max connections per user                            │  │   │
│  │  │ }                                                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │ func (l *ConnectionLimiter) AllowConnect(ctx context.Context, userID string) bool { │  │   │
│  │  │     // Check global connection rate                                                  │  │   │
│  │  │     globalKey := "ws:connect:global"                                                 │  │   │
│  │  │     globalCount, _ := l.redis.Incr(ctx, globalKey).Result()                          │  │   │
│  │  │     if globalCount == 1 {                                                            │  │   │
│  │  │         l.redis.Expire(ctx, globalKey, time.Minute)                                  │  │   │
│  │  │     }                                                                                │  │   │
│  │  │     if globalCount > int64(l.maxPerMin) {                                            │  │   │
│  │  │         return false  // Rate limited                                                │  │   │
│  │  │     }                                                                                │  │   │
│  │  │                                                                                       │  │   │
│  │  │     // Check per-user connection count                                               │  │   │
│  │  │     userKey := fmt.Sprintf("ws:connect:user:%s", userID)                             │  │   │
│  │  │     userCount, _ := l.redis.Incr(ctx, userKey).Result()                              │  │   │
│  │  │     if userCount == 1 {                                                              │  │   │
│  │  │         l.redis.Expire(ctx, userKey, time.Minute)                                    │  │   │
│  │  │     }                                                                                │  │   │
│  │  │     if userCount > int64(l.maxPerUser) {                                             │  │   │
│  │  │         return false  // User has too many connections                               │  │   │
│  │  │     }                                                                                │  │   │
│  │  │                                                                                       │  │   │
│  │  │     return true                                                                       │  │   │
│  │  │ }                                                                                     │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 5. Preventing Spotify Private API Changes

**Root Cause:** Spotify can change their private API at any time without notice.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    API CHANGE DETECTION & ADAPTATION                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    CONTRACT TESTING                                                        │   │
│  │                                                                                           │   │
│  │  Automated tests that validate API response structure:                                   │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ # Python - API Contract Tests                                                        │  │   │
│  │  │                                                                                       │  │   │
│  │  │ @pytest.fixture                                                                      │  │   │
│  │  │ def spotify_contract():                                                              │  │   │
│  │  │     """Expected API response structure"""                                            │  │   │
│  │  │     return {                                                                          │  │   │
│  │  │         "search": {                                                                   │  │   │
│  │  │             "required_fields": ["data", "data.searchV2", "data.searchV2.tracksV2"], │  │   │
│  │  │             "track_fields": ["id", "name", "artists", "album", "duration_ms"],       │  │   │
│  │  │         },                                                                            │  │   │
│  │  │         "player": {                                                                   │  │   │
│  │  │             "required_fields": ["is_playing", "progress_ms", "item"],                │  │   │
│  │  │         },                                                                            │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │ def test_search_response_contract(spotify_contract):                                 │  │   │
│  │  │     """Validate search API response structure"""                                      │  │   │
│  │  │     song = Song()                                                                     │  │   │
│  │  │     response = song.query_songs("test query", limit=1)                               │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Validate required fields exist                                                 │  │   │
│  │  │     for field_path in spotify_contract["search"]["required_fields"]:                 │  │   │
│  │  │         assert get_nested(response, field_path) is not None, \                       │  │   │
│  │  │             f"Missing required field: {field_path}"                                  │  │   │
│  │  │                                                                                       │  │   │
│  │  │     # Validate track structure                                                       │  │   │
│  │  │     tracks = response["data"]["searchV2"]["tracksV2"]["items"]                        │  │   │
│  │  │     if tracks:                                                                        │  │   │
│  │  │         track = tracks[0]["item"]["data"]                                            │  │   │
│  │  │         for field in spotify_contract["search"]["track_fields"]:                     │  │   │
│  │  │             assert field in track, f"Missing track field: {field}"                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │ def test_player_response_contract(spotify_contract):                                 │  │   │
│  │  │     """Validate player API response structure"""                                      │  │   │
│  │  │     # Similar validation for player endpoints...                                      │  │   │
│  │  │     pass                                                                              │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    RUNTIME SCHEMA VALIDATION                                               │   │
│  │                                                                                           │   │
│  │  Alert when response structure changes:                                                  │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Go - Response Schema Validator                                                    │  │   │
│  │  │                                                                                       │  │   │
│  │  │ type SchemaValidator struct {                                                         │  │   │
│  │  │     expectedSchemas map[string]*jsonschema.Schema                                    │  │   │
│  │  │     alertManager  *AlertManager                                                      │  │   │
│  │  │ }                                                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │ func (v *SchemaValidator) ValidateResponse(endpoint string, response []byte) error { │  │   │
│  │  │     schema, ok := v.expectedSchemas[endpoint]                                        │  │   │
│  │  │     if !ok {                                                                          │  │   │
│  │  │         return nil  // No schema defined                                             │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     var data interface{}                                                              │  │   │
│  │  │     if err := json.Unmarshal(response, &data); err != nil {                          │  │   │
│  │  │         return err                                                                    │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     if err := schema.Validate(data); err != nil {                                    │  │   │
│  │  │         // Schema mismatch - alert                                                   │  │   │
│  │  │         v.alertManager.Trigger(Alert{                                                │  │   │
│  │  │             Severity: "critical",                                                    │  │   │
│  │  │             Message:  fmt.Sprintf("Spotify API schema change detected: %s", endpoint),│  │   │
│  │  │             Details:  err.Error(),                                                   │  │   │
│  │  │         })                                                                            │  │   │
│  │  │         metrics.schema_validation_errors.Inc()                                       │  │   │
│  │  │         return err                                                                    │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │                                                                                       │  │   │
│  │  │     return nil                                                                        │  │   │
│  │  │ }                                                                                     │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    FEATURE FLAG KILL SWITCH                                                │   │
│  │                                                                                           │   │
│  │  Instantly disable SpotAPI if API changes break functionality:                           │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ // Go - Feature Flag Manager                                                         │  │   │
│  │  │                                                                                       │  │   │
│  │  │ type FeatureFlags struct {                                                            │  │   │
│  │  │     redis *redis.Client                                                              │  │   │
│  │  │ }                                                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │ func (f *FeatureFlags) IsEnabled(feature string) bool {                              │  │   │
│  │  │     key := fmt.Sprintf("feature:%s:enabled", feature)                                │  │   │
│  │  │     val, err := f.redis.Get(context.Background(), key).Result()                      │  │   │
│  │  │     if err == redis.Nil {                                                            │  │   │
│  │  │         return true  // Default to enabled                                            │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │     return val == "true"                                                              │  │   │
│  │  │ }                                                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │ func (f *FeatureFlags) Disable(feature string) error {                               │  │   │
│  │  │     key := fmt.Sprintf("feature:%s:enabled", feature)                                │  │   │
│  │  │     return f.redis.Set(context.Background(), key, "false", 0).Err()                  │  │   │
│  │  │ }                                                                                     │  │   │
│  │  │                                                                                       │  │   │
│  │  │ // Usage in handler                                                                   │  │   │
│  │  │ func (h *MusicHandler) PlayTrack(w http.ResponseWriter, r *http.Request) {           │  │   │
│  │  │     if !h.featureFlags.IsEnabled("spotapi_playback") {                               │  │   │
│  │  │         // Fallback to deep link                                                     │  │   │
│  │  │         respondJSON(w, http.StatusOK, map[string]interface{}{                        │  │   │
│  │  │             "status": "fallback",                                                    │  │   │
│  │  │             "message": "Playback temporarily unavailable. Opening Spotify app...",   │  │   │
│  │  │             "deep_link": "spotify:track:" + trackID,                                 │  │   │
│  │  │         })                                                                            │  │   │
│  │  │         return                                                                        │  │   │
│  │  │     }                                                                                 │  │   │
│  │  │     // ... normal SpotAPI flow                                                       │  │   │
│  │  │ }                                                                                     │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    SPOTAPI VERSION MONITORING                                              │   │
│  │                                                                                           │   │
│  │  Monitor SpotAPI GitHub for updates:                                                     │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ # GitHub Actions - Daily check for SpotAPI updates                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │ name: Check SpotAPI Updates                                                          │  │   │
│  │  │ on:                                                                                   │  │   │
│  │  │   schedule:                                                                           │  │   │
│  │  │     - cron: '0 6 * * *'  # Daily at 6 AM UTC                                        │  │   │
│  │  │                                                                                       │  │   │
│  │  │ jobs:                                                                                 │  │   │
│  │  │   check-updates:                                                                      │  │   │
│  │  │     runs-on: ubuntu-latest                                                           │  │   │
│  │  │     steps:                                                                            │  │   │
│  │  │       - name: Check SpotAPI version                                                  │  │   │
│  │  │         run: |                                                                         │  │   │
│  │  │           CURRENT_VERSION=$(cat spotapi-version.txt)                                │  │   │
│  │  │           LATEST_VERSION=$(curl -s https://pypi.org/pypi/spotapi/json | \           │  │   │
│  │  │             jq -r '.info.version')                                                   │  │   │
│  │  │                                                                                       │  │   │
│  │  │           if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then                       │  │   │
│  │  │             echo "::warning::SpotAPI updated from $CURRENT_VERSION to $LATEST_VERSION"│  │  │
│  │  │             # Post to Slack                                                          │  │   │
│  │  │             curl -X POST -H 'Content-type: application/json' \                       │  │   │
│  │  │               --data "{\"text\":\"⚠️ SpotAPI updated to $LATEST_VERSION. Review changes.\"} \│  │   │
│  │  │               $SLACK_WEBHOOK                                                         │  │   │
│  │  │           fi                                                                          │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 6. Preventing Database & Redis Failures

**Root Cause:** Hardware failures, memory exhaustion, connection pool issues.

**Prevention Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    DATABASE HIGH AVAILABILITY                                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    POSTGRESQL CLUSTER                                                      │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                          ┌─────────────┐                                             │  │   │
│  │  │                          │  Primary    │ (AZ-1)                                     │  │   │
│  │  │                          │  Read/Write │                                             │  │   │
│  │  │                          └──────┬──────┘                                             │  │   │
│  │  │                                 │                                                    │  │   │
│  │  │              ┌──────────────────┼──────────────────┐                                │  │   │
│  │  │              │                  │                  │                                │  │   │
│  │  │              ▼                  ▼                  ▼                                │  │   │
│  │  │     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                         │  │   │
│  │  │     │  Replica 1  │     │  Replica 2  │     │  Replica 3  │                         │  │   │
│  │  │     │   (AZ-2)    │     │   (AZ-3)    │     │   (AZ-1)    │                         │  │   │
│  │  │     │  Read Only  │     │  Read Only  │     │  Read Only  │                         │  │   │
│  │  │     └─────────────┘     └─────────────┘     └─────────────┘                         │  │   │
│  │  │                                                                                       │  │   │
│  │  │     Automatic Failover: Primary fails → Replica promoted in < 60 seconds            │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                                           │   │
│  │  Connection Pool Configuration:                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ # PgBouncer Configuration                                                            │  │   │
│  │  │ [pgbouncer]                                                                          │  │   │
│  │  │ database_hosts = primary.internal,replica1.internal,replica2.internal               │  │   │
│  │  │ listen_port = 6432                                                                   │  │   │
│  │  │ max_client_conn ={}
10000                                                                  │  │   │
│  │  │ default_pool_size = 50                                                              │  │   │
│  │  │ min_pool_size = 10                                                                  │  │   │
│  │  │ reserve_pool_size = 10                                                              │  │   │
│  │  │ reserve_pool_timeout = 5                                                            │  │   │
│  │  │ max_db_connections = 200                                                            │  │   │
│  │  │ pool_mode = transaction                                                              │  │   │
│  │  │ server_reset_query = DISCARD ALL                                                    │  │   │
│  │  │ server_check_query = SELECT 1                                                       │  │   │
│  │  │ server_check_delay = 30                                                             │  │   │
│  │  │ query_timeout = 10                                                                  │  │   │
│  │  │                                                                                       │  │   │
│  │  │ # Read/Write Split                                                                   │  │   │
│  │  │ [databases]                                                                          │  │   │
│  │  │ music_primary = host=primary.internal port=5432 dbname=music                         │  │   │
│  │  │ music_read = host=replica1.internal,replica2.internal port=5432 dbname=music         │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    REDIS CLUSTER                                                          │   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ Cluster Configuration (6 masters + 6 replicas):                                      │  │   │
│  │  │                                                                                       │  │   │
│  │  │      Master 1 (Shard 0)     Master 2 (Shard 1)     Master 3 (Shard 2)               │  │   │
│  │  │         ┌─────┐              ┌─────┐              ┌─────┐                            │  │   │
│  │  │         │     │              │     │              │     │                            │  │   │
│  │  │         │ M1  │              │ M2  │              │ M3  │                            │  │   │
│  │  │         │     │              │     │              │     │                            │  │   │
│  │  │         └──┬──┘              └──┬──┘              └──┬──┘                            │  │   │
│  │  │            │                    │                    │                              │  │   │
│  │  │      ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐                        │  │   │
│  │  │      │           │        │           │        │           │                        │  │   │
│  │  │   ┌──┴──┐     ┌──┴──┐  ┌──┴──┐     ┌──┴──┐  ┌──┴──┐     ┌──┴──┐                    │  │   │
│  │  │   │ R1  │     │ R1  │  │ R2  │     │ R2  │  │ R3  │     │ R3  │                    │  │   │
│  │  │   └─────┘     └─────┘  └─────┘     └─────┘  └─────┘     └─────┘                    │  │   │
│  │  │   Replica    Replica   Replica    Replica   Replica    Replica                      │  │   │
│  │  │                                                                                       │  │   │
│  │  │ Automatic failover: Master fails → Replica promoted in < 10 seconds                 │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                                           │   │
│  │  Configuration:                                                                            │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │ # redis.conf (per node)                                                              │  │   │
│  │  │ cluster-enabled yes                                                                  │  │   │
│  │  │ cluster-config-file nodes.conf                                                       │  │   │
│  │  │ cluster-node-timeout 5000                                                            │  │   │
│  │  │ cluster-require-full-coverage no  # Continue if some shards are down                │  │   │
│  │  │                                                                                       │  │   │
│  │  │ # Persistence                                                                         │  │   │
│  │  │ appendonly yes                                                                        │  │   │
│  │  │ appendfsync everysec                                                                  │  │   │
│  │  │ save 900 1                                                                            │  │   │
│  │  │ save 300 10                                                                           │  │   │
│  │  │ save 60 10000                                                                         │  │   │
│  │  │                                                                                       │  │   │
│  │  │ # Memory management                                                                   │  │   │
│  │  │ maxmemory 8gb                                                                         │  │   │
│  │  │ maxmemory-policy volatile-lru                                                        │  │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 7. Graceful Degradation Summary

**When all else fails, fall back gracefully:**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    GRACEFUL DEGRADATION FLOW                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                                          │   │
│   │                                    SPOTAPI AVAILABLE                                     │   │
│   │                                          │                                               │   │
│   │                            ┌─────────────┴─────────────┐                                │   │
│   │                            │                           │                                │   │
│   │                            ▼                           ▼                                │   │
│   │                    Full Features                 Basic Features                         │   │
│   │                    • Play/Pause                   • Deep link to Spotify                │   │
│   │                    • Skip/Seek                    • Search (public API)                  │   │
│   │                    • Queue management             • View playlists                       │   │
│   │                    • Volume control                                                      │   │
│   │                    • Listen Along                                                        │   │
│   │                    • Real-time sync                                                      │   │
│   │                            │                           │                                │   │
│   │                            └─────────────┬─────────────┘                                │   │
│   │                                          │                                               │   │
│   │                                          ▼                                               │   │
│   │                              SPOTAPI UNAVAILABLE                                         │   │
│   │                                          │                                               │   │
│   │                            ┌─────────────┴─────────────┐                                │   │
│   │                            │                           │                                │   │
│   │                            ▼                           ▼                                │   │
│   │                   Cached Data Fallback           Minimal Fallback                       │   │
│   │                   • Show last played             • Show "Service Unavailable"           │   │
│   │                   • Show cached playlists        • Link to Spotify app                  │   │
│   │                   • Queue actions for retry      • Basic error message                  │   │
│   │                   • "Reconnect" prompt                                                 │   │
│   │                                                                                          │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                  │
│   Degradation Response Codes:                                                                   │
│   ──────────────────────────────────────────────────────────────────────────────────────────── │
│   {                                                                                              │
│     "status": "degraded",                                                                        │
│     "features_available": ["search", "deep_link"],                                              │
│     "features_unavailable": ["playback_control", "queue", "listen_along"],                      │
│     "fallback_action": "deep_link",                                                             │
│     "deep_link": "spotify:track:6l8GvAyoUZwFDuSbsxDpSR",                                        │
│     "message": "Enhanced playback is temporarily unavailable. Opening Spotify app..."           │
│   }                                                                                              │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Prevention Implementation Checklist

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION CHECKLIST                                                      │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  RATE LIMITING                                                                                   │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ User-level token bucket implemented (Redis Lua)                                             │
│  □ Global rate limiter for Spotify API calls                                                   │
│  □ Priority queue for playback > search > metadata                                             │
│  □ Residential proxy pool configured                                                            │
│  □ Circuit breaker with automatic fallback                                                      │
│                                                                                                  │
│  CAPTCHA RELIABILITY                                                                             │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Multiple CAPTCHA providers configured (Capsolver, 2Captcha, Anti-Captcha)                   │
│  □ Provider health monitoring implemented                                                       │
│  □ Cookie import fallback UI created                                                            │
│  □ Browser extension for cookie export developed                                                │
│  □ Alert on solve rate drop below 80%                                                          │
│                                                                                                  │
│  SESSION MANAGEMENT                                                                              │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Session encryption (AES-256-GCM) implemented                                                 │
│  □ Proactive refresh worker (every 6 hours)                                                    │
│  □ Reactive validation middleware                                                               │
│  □ Automatic re-login with stored credentials                                                   │
│  □ Push notification on session expiration                                                      │
│                                                                                                  │
│  WEBSOCKET RESILIENCE                                                                            │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Exponential backoff with jitter in client                                                    │
│  □ Centrifugo history recovery enabled                                                          │
│  □ Connection rate limiting on server                                                           │
│  □ Offline queue for pending actions                                                            │
│  □ State reconciliation on reconnect                                                            │
│                                                                                                  │
│  API CHANGE DETECTION                                                                            │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Contract tests for API responses                                                             │
│  □ Runtime schema validation                                                                    │
│  □ Feature flag kill switch                                                                     │
│  □ SpotAPI version monitoring (GitHub Actions)                                                  │
│  □ Alert on schema validation failures                                                          │
│                                                                                                  │
│  DATABASE HA                                                                                     │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ PostgreSQL primary + 3 read replicas                                                          │
│  □ PgBouncer connection pooling                                                                  │
│  □ Automatic failover configured                                                                 │
│  □ Redis Cluster (6 master + 6 replicas)                                                        │
│  □ Persistence enabled (AOF + RDB)                                                               │
│                                                                                                  │
│  MONITORING & ALERTING                                                                           │
│  ────────────────────────────────────────────────────────────────────────────────────────────── │
│  □ Golden signals dashboards (latency, traffic, errors, saturation)                             │
│  □ Business metrics tracked                                                                      │
│  □ P1/P2/P3/P4 alert routing configured                                                         │
│  □ Runbooks created for each failure mode                                                       │
│  □ On-call rotation established                                                                 │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

*This document provides complete prevention strategies for all identified failure points. Each solution includes implementation code, configuration, and operational procedures.*
