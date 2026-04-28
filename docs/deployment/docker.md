# Docker Deployment

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

Flicko uses Docker Compose for production deployment. The production compose file (`docker-compose.prod.yml`, 455 lines) defines 9 containers across 3 isolated networks with resource limits, health checks, restart policies, and security configurations.

---

## Production Compose Architecture

### Networks (3 isolated networks)

```yaml
networks:
  flicko_edge:      # NGINX only — internet-facing
    ipam:
      config:
        - subnet: 172.20.0.0/24
  flicko_internal:  # Go services — no internet access
    internal: true
    ipam:
      config:
        - subnet: 172.20.1.0/24
  flicko_monitor:   # Monitoring stack — no internet access
    internal: true
    ipam:
      config:
        - subnet: 172.20.2.0/24
```

**Security rationale:** Only NGINX has a network with internet access. The Go services and monitoring stack are on `internal: true` networks, meaning they cannot initiate outbound connections. This prevents compromised containers from phoning home.

**Cross-network access:** NGINX connects to both `flicko_edge` and `flicko_internal` so it can forward requests. Prometheus connects to both `flicko_internal` and `flicko_monitor` to scrape metrics from Go services.

### Containers

#### 1. NGINX (Reverse Proxy)
```yaml
nginx:
  image: nginx:1.25-alpine
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./nginx/conf.d/:/etc/nginx/conf.d/:ro
    - ./secrets/origin.pem:/etc/nginx/ssl/origin.pem:ro
    - ./secrets/origin-key.pem:/etc/nginx/ssl/origin-key.pem:ro
  deploy:
    resources:
      limits: { memory: 128M, cpus: "0.25" }
      reservations: { memory: 64M }
  networks: [flicko_edge, flicko_internal]
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "nginx", "-t"]
    interval: 30s
    timeout: 10s
    retries: 3
```

**Configuration highlights:**
- Mounts `nginx.conf` as read-only
- Mounts Cloudflare Origin TLS certificates
- Only container with public port exposure
- Limited to 128 MB RAM

#### 2. ws-gateway (WebSocket)
```yaml
ws-gateway:
  build:
    context: ./services/ws-gateway
    dockerfile: Dockerfile.prod
  environment:
    - REDIS_URL=${REDIS_URL}
    - DATABASE_URL=${DATABASE_URL}
    - JWT_SECRET=${JWT_SECRET}
    - MAX_CONNECTIONS=6000
  deploy:
    resources:
      limits: { memory: 1G, cpus: "1.0" }
      reservations: { memory: 512M, cpus: "0.5" }
  networks: [flicko_internal, flicko_monitor]
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
    interval: 15s
    timeout: 5s
    retries: 5
  read_only: true
  security_opt:
    - no-new-privileges:true
```

**Security hardening:**
- `read_only: true` — Container filesystem is read-only
- `no-new-privileges: true` — Prevents privilege escalation
- No port exposure (accessed only through NGINX)
- 1 GB memory limit (adequate for 6K WebSocket connections)

#### 3. msg-service (REST API)
```yaml
msg-service:
  build:
    context: ./services/msg-service
    dockerfile: Dockerfile.prod
  environment:
    - REDIS_URL=${REDIS_URL}
    - DATABASE_URL=${DATABASE_URL}
    - JWT_SECRET=${JWT_SECRET}
    - BATCH_INSERT_SIZE=50
    - BATCH_INSERT_WINDOW=50ms
  deploy:
    resources:
      limits: { memory: 512M, cpus: "0.5" }
  networks: [flicko_internal, flicko_monitor]
  restart: unless-stopped
  read_only: true
```

#### 4. backend (Bot System)
Similar to msg-service but includes Cloudinary and LiveKit configuration.

#### 5-9. Monitoring Stack
- **Prometheus** — Scrapes metrics from all Go services every 15s
- **Grafana** — Dashboard UI with Prometheus and Loki data sources
- **Loki** — Receives JSON logs from all containers via Docker log driver
- **Node Flutterrter** — Host system metrics (CPU, RAM, disk, network)
- **NGINX Flutterrter** — NGINX stub_status metrics

---

## Dockerfile Pattern

All Go services use multi-stage builds:

```dockerfile
# Stage 1: Build
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /server ./cmd/server

# Stage 2: Runtime
FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

**Security features:**
- `CGO_ENABLED=0` — Static binary, no libc dependency
- `-ldflags="-w -s"` — Strip debug symbols (smaller binary)
- `alpine:3.19` — Minimal runtime image (~5 MB)
- `USER nonroot:nonroot` — Run as non-root user
- Only the compiled binary is in the final image (no source code)

---

## Docker Commands

```bash
# Start production stack
docker compose -f docker-compose.prod.yml up -d --build

# View logs
docker compose -f docker-compose.prod.yml logs -f --tail=100

# Restart single service
docker compose -f docker-compose.prod.yml restart ws-gateway

# Stop everything
docker compose -f docker-compose.prod.yml down

# Check resource usage
docker stats

# Enter container shell
docker compose -f docker-compose.prod.yml exec ws-gateway sh
```

---

## Volumes

| Volume | Container | Path | Purpose |
|--------|-----------|------|---------|
| `prometheus_data` | Prometheus | `/prometheus` | Metrics TSDB |
| `grafana_data` | Grafana | `/var/lib/grafana` | Dashboards, config |
| `loki_data` | Loki | `/loki` | Log index/chunks |

---

## Related Docs
- [Deployment Overview](overview.md) — Architecture context
- [Environment Setup](environment-setup.md) — Production env vars
- [Monitoring](monitoring.md) — Observability stack
