# Sonic Drip

> **Music Streaming for Flicko** — JioSaavn + YouTube powered music search, playback, and social listening

## Overview

Sonic Drip enables Flicko users to stream music using the **Drip Bash** engine (BlackHole-style):

- **Music Search** — Search millions of tracks, albums, and artists via JioSaavn + YouTube
- **Full-Song Streaming** — Stream full songs with DES-decrypted JioSaavn URLs and YouTube audio
- **Playlist Management** — Create, edit, and share playlists
- **Social Sharing** — Share playlists to friends and server channels
- **Listen Along** — Real-time listening sessions with friends

> **Note:** Spotify and iTunes integrations were removed. All music search and streaming
> is handled client-side via JioSaavn (primary) and YouTube (fallback). No external music
> API keys or services are required.

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](./docs/getting-started.md) | Quick start guide and overview *(historical — references deprecated Spotify flow)* |
| [Architecture](./docs/architecture.md) | Full system architecture design |
| [Implementation Plan](./docs/implementation-plan.md) | Development timeline *(historical — references deprecated Spotify flow)* |
| [Critical Fixes](./docs/critical-fixes.md) | Security fixes and production hardening |

## Architecture

```
Flutter Mobile/Web → Cloudflare Edge → Kubernetes Cluster
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            Go API Gateway       Centrifugo WebSocket    Drip Bash (client-side)
            (10-100 pods)        (5-20 pods)             JioSaavn + YouTube
                    │                      │
                    └──────────────────────┘
                                           │
                                           ▼
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
              PostgreSQL 16          Redis Cluster          JioSaavn API
              (Partitioned)          (Cache + Queue)        (Direct / saavn.dev)
```

## Key Features

### 🎵 Drip Bash Engine
- Direct JioSaavn API with DES decryption (BlackHole pattern)
- YouTube Explode for YouTube audio streams
- Invidious fallback for reliability
- 320kbps audio quality

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
| Music Engine | Drip Bash (client-side JioSaavn + YouTube) |
| Database | PostgreSQL 16 |
| Cache | Redis 7 Cluster |
| WebSocket | Centrifugo v5 |
| Infrastructure | Kubernetes + Istio |

## Quick Start

```bash
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

🚧 **In Development** — Drip Bash engine active (JioSaavn + YouTube)

## License

Proprietary — Flicko Organization
