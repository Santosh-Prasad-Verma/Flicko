# Sonic Drip

> **Spotify Integration for Flicko** — Music streaming, sharing, and social listening

## Overview

Sonic Drip enables Flicko users to connect their Spotify accounts and enjoy:

- **Music Search** — Search millions of tracks, albums, and artists
- **Remote Playback** — Control playback (play, pause, skip, seek, volume)
- **Playlist Management** — Create, edit, and share playlists
- **Social Sharing** — Share playlists to friends and server channels
- **Listen Along** — Real-time listening sessions with friends

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](./docs/getting-started.md) | Quick start guide and overview |
| [Architecture](./docs/architecture.md) | Full system architecture design |
| [Implementation Plan](./docs/implementation-plan.md) | Detailed 18-week implementation timeline |
| [Critical Fixes](./docs/critical-fixes.md) | Security fixes and production hardening |

## Architecture

```
Flutter Mobile/Web → Cloudflare Edge → Kubernetes Cluster
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            Go API Gateway       Centrifugo WebSocket    SpotAPI Service
            (10-100 pods)        (5-20 pods)             (5-50 pods)
                    │                      │                      │
                    └──────────────────────┼──────────────────────┘
                                           │
                                           ▼
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
              PostgreSQL 16          Redis Cluster          Spotify API
              (Partitioned)          (Cache + Queue)
```

## Key Features

### 🔐 Secure Authentication
- User solves CAPTCHA themselves in WebView
- We NEVER store Spotify passwords
- Session cookies encrypted with AES-256-GCM

### ⚡ High Performance
- < 200ms p99 latency target
- 100K+ requests per second
- 10M+ concurrent users supported

### 🔄 Real-time Sync
- Centrifugo WebSocket hub
- Instant playback state updates
- Listen Along with sub-second sync

### 🛡️ Production Ready
- Multi-region DR
- Circuit breakers
- Graceful degradation

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter + Riverpod |
| Backend | Go + Chi |
| Music Service | Python + FastAPI |
| Database | PostgreSQL 16 |
| Cache | Redis 7 Cluster |
| WebSocket | Centrifugo v5 |
| Infrastructure | Kubernetes + Istio |

## Quick Start

```bash
# SpotAPI Service
cd services/spotapi-service
pip install -r requirements.txt
uvicorn app.main:app --reload

# Go Backend
cd backend
go run cmd/server/main.go

# Flutter App
cd mobile
flutter run
```

## Project Structure

```
sonic-drip/
├── docs/
│   ├── getting-started.md      # Quick start guide
│   ├── architecture.md         # System architecture
│   ├── implementation-plan.md  # Development timeline
│   └── critical-fixes.md       # Security hardening
├── services/
│   └── spotapi-service/        # Python FastAPI service
│       ├── app/
│       │   ├── main.py
│       │   ├── routers/
│       │   └── services/
│       └── requirements.txt
└── README.md
```

## Target Metrics

| Metric | Target |
|--------|--------|
| Concurrent Users | 10,000,000+ |
| Requests/Second | 100,000+ |
| Latency (p99) | < 200ms |
| Uptime SLA | 99.95% |

## Status

🚧 **In Development** — Phase 1: Foundation

## License

Proprietary — Flicko Organization
