# Docker Compose Deployment

> **Reading time:** ~12 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

This is the definitive guide for deploying Flicko on a stand-alone Linux VPS utilizing Docker Compose. This topology is optimized for speed, cost (runs on a single node), and isolation.

---

## 1. Server Provisioning Requirements

- **OS:** Ubuntu 22.04 LTS or newer
- **CPU:** 2+ vCores
- **RAM:** 4GB minimum (8GB recommended for Prometheus/Grafana)
- **Ports:** Only 80 (HTTP) and 443 (HTTPS) should be exposed in your cloud firewall. Port 22 (SSH) should be restricted to your admin IP.

## 2. Preparing the Server

SSH into your freshly provisioned VPS and install the Docker engine.

```bash
# Update mirrors
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose V2
sudo apt-get install docker-compose-plugin
```

## 3. Cloning and Env Setup

Clone the repository into a secure location, e.g., `/opt/flicko`.

```bash
cd /opt
sudo git clone https://github.com/your-org/flicko.git
cd flicko
```

Copy the example environment file and carefully fill it out using credentials from Supabase, Upstash, and Cloudinary.

```bash
cp .env.example .env
nano .env
```
*(Reference the [Configuration Variables](../getting-started/configuration.md) documentation if you are unsure what a key requires).*

## 4. The Dockerfile Construction

All three Go services share a unified multi-stage build `Dockerfile` located in the root. 
Because Go produces statically linked binaries, the final Docker images are based on `distroless/static` or Alpine, weighing in at ~20MB and containing absolutely zero OS tools (meaning hackers cannot even execute `ls` or `bash` if they manage to breach the container).

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# The build arg determines WHICH of the 3 services gets compiled
ARG SERVICE_NAME=api
RUN CGO_ENABLED=0 go build -o /app/bin/server ./cmd/${SERVICE_NAME}

# Stage 2: Distroless production
FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/bin/server /server
ENTRYPOINT ["/server"]
```

## 5. The `docker-compose.prod.yml`

Our production orchestration file ensures auto-restarts, dedicated internal networking, and proper memory limits to prevent one service from choking the others.

```yaml
version: '3.8'

services:
  backend:
    build: 
      context: .
      args:
        SERVICE_NAME: api
    restart: always
    env_file: .env
    expose:
      - "8080"
    networks:
      - flicko-internal

  msg-service:
    build: 
      context: .
      args:
        SERVICE_NAME: msg-service
    restart: always
    env_file: .env
    expose:
      - "8082"
    networks:
      - flicko-internal

  ws-gateway:
    build: 
      context: .
      args:
        SERVICE_NAME: ws-gateway
    restart: always
    env_file: .env
    expose:
      - "8081"
    networks:
      - flicko-internal

  # ... NGINX and Prometheus definitions continue here

networks:
  flicko-internal:
    driver: bridge
```

*Note: We use `expose` instead of `ports`. This ensures the Go services bind ONLY to the internal Docker network, rendering them impossible to access from the public internet unless NGINX explicitly proxies the connection to them.*

## 6. Execution

Once your `.env` is configured and your SSL certificates are placed in `./nginx/certs/`, run the orchestration command in daemon mode:

```bash
sudo docker compose -f docker-compose.prod.yml up -d --build
```

You can verify the services are running and connected to their respective managed databases via:
```bash
sudo docker compose logs -f backend
```

## Updating (Zero-ish Downtime)

When a new version of Flicko is pulled, executing a rebuild minimizes downtime because Docker builds the new image alongside the running container, then swaps them atomically.

```bash
git pull origin main
sudo docker compose -f docker-compose.prod.yml up -d --build
```
Existing WebSockets will drop during the ~1.5s swap, but the React Native [`offline-mode.md`](../frontend/offline-mode.md) exponential backoff algorithm will automatically negotiate fresh connections instantly.
