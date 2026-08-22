# Quick Start

> **Reading time:** ~5 minutes · **Audience:** Experienced Developers · **Last Updated:** 2026-04-11

This is the fast-track setup guide for experienced developers who are comfortable with Go, Flutter, Docker, PostgreSQL, and Redis. If you want detailed explanations of every step, use the [Installation Guide](installation.md) instead. This page assumes you have all [prerequisites](prerequisites.md) installed and cloud accounts set up.

---

## 60-Second Setup

```bash
# Clone and install root tools (Husky, Prettier, lint-staged)
git clone https://github.com/Santosh-Prasad-Verma/Flicko.git && cd Flicko && npm install

# Configure environment
cp .env.example .env           # Edit with Supabase, Redis, Cloudinary, LiveKit creds
cp mobile/.env.example mobile/.env  # Edit with API URLs (use LAN IP, not localhost)

# Apply database schema (65 migrations)
cd supabase && npx supabase link --project-ref YOUR_REF && npx supabase db push && cd ..

# Start all 3 backend services (each in a separate terminal)
cd services/msg-service && go mod download && go run ./cmd/server      # Terminal 1 → :8081
cd services/ws-gateway && go mod download && go run ./cmd/gateway     # Terminal 2 → :8080
cd backend && go mod download && go run ./cmd/server                  # Terminal 3 → :8080

# Start mobile app
cd mobile && flutter pub get && flutter run    # Terminal 4 → select device or simulator
```

---

## Architecture at a Glance

```
📱 Mobile App (Flutter v3.22+, Riverpod)
    │
    ├──REST──→ NGINX ──→ msg-service :8081 ──→ PostgreSQL (Supabase)
    │                                    └──→ Redis Pub/Sub (Upstash)
    │
    ├──WS────→ NGINX ──→ ws-gateway :8080 ←── Redis Pub/Sub
    │
    └──CMDS──→ NGINX ──→ backend :8080 ──→ PostgreSQL
                          ├── 8 bots (Mod, AutoMod, Welcome, Level, Music, Ticket, Poll, Star)
                          ├── 95 service files
                          ├── 22 models
                          └── 10-layer middleware
```

---

## Environment Variables (Minimum Required)

```env
# .env (root) — used by all 3 Go services
DATABASE_URL=postgresql://postgres.REF:PASS@HOST:6543/postgres?sslmode=require
SUPABASE_URL=https://REF.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
REDIS_URL=rediss://default:TOKEN@HOST.upstash.io:6379
JWT_SECRET=your-supabase-jwt-secret-at-least-32-chars
CLOUDINARY_CLOUD_NAME=your_cloud
CLOUDINARY_API_KEY=123456789
CLOUDINARY_API_SECRET=your_secret
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=APIxxxxxxx
LIVEKIT_API_SECRET=your_livekit_secret

# mobile/.env — used by Flutter app
FLICKO_API_URL=https://192.168.1.X:8081
FLICKO_WS_URL=wss://192.168.1.X:8080/ws
FLICKO_SUPABASE_URL=https://REF.supabase.co
FLICKO_SUPABASE_ANON_KEY=eyJhbGci...
```

> **⚠️ Mobile URLs:** Use your machine's LAN IP (`hostname -I` on Linux, `ifconfig | grep "inet "` on macOS). Simulators/devices can't resolve `localhost`.

---

## Service Health Checks

```bash
# msg-service
curl http://localhost:8081/api/v1/health                # → {"status":"ok"}

# ws-gateway (WebSocket handshake test)
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGVzdA==" \
     http://localhost:8080/ws

# backend (check startup log for "all bots started, count: 8")
```

---

## Docker Quick Start (Alternative)

If you prefer Docker over running services individually:

```bash
# Build and start all containers (9 services, 3 networks)
docker compose -f docker-compose.dev.yml up --build

# Or production stack with monitoring
docker compose -f docker-compose.prod.yml up -d
```

**Container resource allocation:**
| Container | RAM | CPU | Port |
|-----------|-----|-----|------|
| nginx | 128 MB | 0.15 | 80, 443 |
| ws-gateway | 1 GB | 1.0 | 8080 |
| msg-service | 512 MB | 0.5 | 8081 |
| backend | 512 MB | 0.5 | 8080 |
| prometheus | 512 MB | 0.5 | 9090 |
| grafana | 256 MB | 0.25 | 3000 |
| loki | 512 MB | 0.25 | 3100 |

---

## Common Commands

```bash
# Run all Go tests (42 test files)
cd backend && go test -v ./...
cd services/msg-service && go test -v ./...
cd services/ws-gateway && go test -v ./...

# Format code (also runs on pre-commit via Husky)
gofmt -w backend/ services/         # Go
npx prettier --write .               # TypeScript/JSON/YAML

# View structured Go logs (pipe through jq)
go run ./cmd/server 2>&1 | jq .

# Database operations
npx supabase migration new your_migration_name   # Create migration
npx supabase db push                              # Apply migrations
npx supabase db reset                             # Reset database

# Generate encryption key
openssl rand -hex 32
```

---

## What To Do Next

| Your Role | Start With |
|-----------|------------|
| **Backend developer** | [Backend: Overview](../backend/overview.md) → [Architecture: System Overview](../architecture/system-overview.md) |
| **Mobile developer** | [Frontend: Overview](../frontend/overview.md) → [Frontend: Pages & Routes](../frontend/pages-routes.md) |
| **DevOps/SRE** | [Deployment: Docker](../deployment/docker.md) → [Deployment: Monitoring](../deployment/monitoring.md) |
| **Security reviewer** | [Security: Overview](../security/overview.md) → [Security: Middleware Pipeline](../security/middleware-pipeline.md) |
| **Feature contributor** | [Contributing Guide](../CONTRIBUTING.md) → [Features: Feature Index](../features/feature-index.md) |

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `connection refused` (DB) | Wrong port in DATABASE_URL | Use port 6543 (Supavisor), not 5432 |
| `401 Unauthorized` on all requests | JWT_SECRET mismatch | Copy exact JWT secret from Supabase Dashboard |
| App doesn't build | Missing dependencies or codegen | Run `flutter pub get` and `build_runner` |
| Messages don't appear in real-time | ws-gateway not running | Start ws-gateway in separate terminal |
| Bot commands don't work | `backend` service not running | Start backend service; check for "all bots started" log |
| File uploads fail | Cloudinary credentials wrong | Verify all 3 Cloudinary env vars |
| `too many connections` | Using direct DB port | Switch DATABASE_URL to port 6543 |
| `address already in use` | Port conflict | Kill process: `lsof -ti:8080 \| xargs kill` |

Full troubleshooting: [Troubleshooting Guide](troubleshooting.md)

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
