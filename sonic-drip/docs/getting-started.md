# Sonic Drip — Production Implementation Guide

> **Spotify Integration for Flicko** — Public Release Ready
> 
> Version 2.0 — Production Architecture for Millions of Users

---

## Overview

Sonic Drip is Flicko's music integration feature that enables users to:
- Connect their Spotify account
- Search and browse music
- Control playback remotely (play, pause, skip, seek)
- Create and manage playlists
- Share playlists to friends and server channels
- Listen Along with friends in real-time

### Target Metrics

| Metric | Target |
|--------|--------|
| Concurrent Users | 10,000,000+ |
| Requests per Second | 100,000+ |
| Latency (p99) | < 200ms |
| Uptime SLA | 99.95% |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        CLIENT LAYER                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│   ┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐              │
│   │   Flutter Mobile    │     │    Flutter Web      │     │   Desktop (Electron)│              │
│   │   (iOS/Android)     │     │    (Browser)        │     │    (Windows/Mac)    │              │
│   └──────────┬──────────┘     └──────────┬──────────┘     └──────────┬──────────┘              │
└──────────────┼───────────────────────────┼───────────────────────────┼──────────────────────────┘
               │                           │                           │
               └───────────────────────────┼───────────────────────────┘
                                           │ HTTPS / WSS
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      EDGE LAYER                                                  │
│                              Cloudflare Edge Network                                            │
│   • DDoS Protection • WAF • Rate Limiting • SSL/TLS • Anycast Routing • CDN                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   KUBERNETES CLUSTER                                            │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   Go API Gateway    │    │   Centrifugo WS     │    │   SpotAPI Service   │                 │
│   │   (Flicko Backend)  │    │   (WebSocket Hub)   │    │   (Python)          │                 │
│   │   Pods: 10-100      │    │   Pods: 5-20        │    │   Pods: 5-50        │                 │
│   └──────────┬──────────┘    └──────────┬──────────┘    └──────────┬──────────┘                 │
└──────────────┼───────────────────────────┼───────────────────────────┼──────────────────────────┘
               │                           │                           │
               └───────────────────────────┼───────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      DATA LAYER                                                 │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   PostgreSQL 16     │    │   Redis Cluster     │    │   Object Storage    │                 │
│   │   (Primary DB)      │    │   (Cache/Queue)     │    │   (S3/MinIO)        │                 │
│   │   Primary: 1        │    │   Nodes: 6          │    │   Regions: 3        │                 │
│   │   Replicas: 3       │    │   Replicas: 3       │    │   Replication: Yes  │                 │
│   └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   EXTERNAL SERVICES                                             │
│   ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                 │
│   │   Spotify API       │    │   Monitoring        │    │   CAPTCHA (optional)│                 │
│   │   (Private + Public)│    │   (Datadog/Grafana) │    │   (User-solved)     │                 │
│   └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Client Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| Mobile Framework | Flutter 3.22+ | Single codebase, native performance |
| State Management | Riverpod 3.0 | Compile-safe, testable, async support |
| HTTP Client | Dio + Retry Interceptor | Automatic retries, interceptors |
| WebSocket | Centrifuge Dart SDK | Auto-reconnect, presence, history |

### Backend Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| API Server | Go 1.22+ | High concurrency, low latency |
| HTTP Router | Chi | Lightweight, middleware support |
| WebSocket Hub | Centrifugo v5 | Scale to millions, Redis engine |
| Music Service | Python + FastAPI | SpotAPI integration, async support |
| Task Queue | Asynq (Redis-backed) | Distributed task processing |

### Data Layer

| Component | Technology | Reason |
|-----------|------------|--------|
| Primary Database | PostgreSQL 16 | ACID, partitioning, pgx driver |
| Connection Pool | PgBouncer | 10K+ concurrent connections |
| Cache Layer | Redis 7 Cluster | Sub-ms latency, Lua scripts |
| Message Queue | Redis Streams | At-least-once delivery |
| Object Storage | Cloudflare R2 | Zero egress fees, S3 compatible |

### Infrastructure

| Component | Technology | Reason |
|-----------|------------|--------|
| Container Orchestration | Kubernetes (EKS/GKE) | Auto-scaling, self-healing |
| Service Mesh | Istio | mTLS, traffic management |
| CI/CD | GitHub Actions + ArgoCD | GitOps, canary deployments |
| Secrets | HashiCorp Vault | Dynamic secrets, rotation |
| CDN | Cloudflare | Global PoPs, DDoS protection |

---

## Critical Security Considerations

### ⚠️ Never Store Credentials

We NEVER store user Spotify passwords. Authentication flow:

1. User taps "Connect Spotify" in app
2. WebView opens Spotify login page
3. User enters credentials and solves CAPTCHA themselves
4. On success, we capture session cookies only
5. Cookies are encrypted with AES-256-GCM and stored

```go
// Store ONLY cookies, NEVER passwords
type SessionData struct {
    Cookies     map[string]string `json:"cookies"`
    DeviceID    string            `json:"device_id,omitempty"`
    DisplayName string            `json:"display_name"`
    Product     string            `json:"product"`
    ExpiresAt   time.Time         `json:"expires_at"`
}

// NEVER IMPLEMENT THESE:
// func StorePassword(...) { }  // NEVER
// func GetPassword(...) { }    // NEVER
```

### Idempotency Keys

All playback commands require idempotency keys to prevent duplicate plays:

```go
type PlayRequest struct {
    TrackID       string `json:"track_id" validate:"required"`
    IdempotencyKey string `json:"idempotency_key" validate:"required"` // Client-generated UUID
    DeviceID      string `json:"device_id,omitempty"`
}
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-4)

- Infrastructure setup (Kubernetes, PostgreSQL, Redis)
- Database schema with migrations
- SpotAPI Python service
- Authentication flow with WebView login
- Go backend session handlers

### Phase 2: Core Features (Weeks 5-8)

- Search and discovery
- Playback control
- Device management
- Now Playing state sync

### Phase 3: Social Features (Weeks 9-12)

- Playlist CRUD operations
- Share to channel/friends
- Listen Along sessions
- Real-time sync via Centrifugo

### Phase 4: Scale & Reliability (Weeks 13-16)

- Circuit breakers and fallbacks
- Multi-region DR
- Load testing (100K RPS target)
- Security hardening

### Phase 5: Production Launch (Weeks 17-18)

- Canary deployment (1% → 10% → 50% → 100%)
- Monitoring verification
- Performance optimization

---

## Deployment

### Infrastructure Requirements

| Component | Production | Notes |
|-----------|------------|-------|
| Kubernetes Nodes | 50-100 | Auto-scaling |
| PostgreSQL | Primary + 3 replicas | Partitioned |
| Redis Cluster | 6 nodes + replicas | Separate cache/queue |
| SpotAPI Pods | 5-50 | Python workers |
| Centrifugo Pods | 5-20 | WebSocket hub |

### Environment Variables

```env
# Database
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# Encryption
ENCRYPTION_KEY=your-32-byte-key

# Spotify
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...

# Monitoring
DATADOG_API_KEY=...
SENTRY_DSN=...

# WebSocket
CENTRIFUGO_API_KEY=...
CENTRIFUGO_TOKEN_HMAC_KEY=...
```

### Kubernetes Deployment

```yaml
# k8s/sonic-drip/backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonic-drip-backend
spec:
  replicas: 10
  selector:
    matchLabels:
      app: sonic-drip-backend
  template:
    spec:
      containers:
      - name: backend
        image: flicko/sonic-drip-backend:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
```

---

## Monitoring & Observability

### Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| p99 Latency | < 200ms | > 500ms |
| Error Rate | < 0.1% | > 1% |
| WebSocket Connections | Track | N/A |
| Spotify API Errors | < 1% | > 5% |

### Dashboards

- **Overview**: RPS, latency, error rate
- **Spotify**: API calls, rate limits, session health
- **WebSocket**: Connections, message throughput
- **Infrastructure**: CPU, memory, database queries

---

## Testing Strategy

| Test Type | Tool | Coverage Target |
|-----------|------|-----------------|
| Unit Tests | Go testing, pytest | > 80% |
| Contract Tests | Pact | All service boundaries |
| Integration Tests | Docker Compose | Critical paths |
| E2E Tests | Patrol | User flows |
| Load Tests | k6 | 100K RPS |

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| [architecture.md](./architecture.md) | Full system architecture |
| [implementation-plan.md](./implementation-plan.md) | Detailed 18-week plan |
| [critical-fixes.md](./critical-fixes.md) | Security fixes and mitigations |

---

## Quick Start

```bash
# Clone
git clone https://github.com/flicko/flicko.git
cd flicko/sonic-drip

# Backend
cd services/spotapi-service
pip install -r requirements.txt
uvicorn app.main:app --reload

# Go Backend
cd ../../backend
go run cmd/server/main.go

# Flutter
cd ../../mobile
flutter run
```

---

## Next Steps

1. Review [architecture.md](./architecture.md) for full system design
2. Read [critical-fixes.md](./critical-fixes.md) for security requirements
3. Follow [implementation-plan.md](./implementation-plan.md) for detailed tasks
4. Set up development environment
5. Begin Phase 1 implementation
