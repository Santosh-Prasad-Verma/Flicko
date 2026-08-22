# Prerequisites

> **Reading time:** ~15 minutes · **Audience:** New Developers · **Last Updated:** 2026-04-11

This guide details every tool, runtime, and cloud account required to develop, build, and run Flicko locally. For each prerequisite, you'll find the exact version required, why Flicko needs it, installation commands for macOS, Linux, and Windows, verification commands, and common issues with solutions. Do not skip any prerequisite — the setup will fail if any tool is missing or at the wrong version.

---

## Table of Contents

- [Quick Checklist](#quick-checklist)
- [Go](#go)
- [Flutter SDK](#flutter-sdk)
- [Docker and Docker Compose](#docker-and-docker-compose)
- [Git](#git)
- [Cloud Accounts](#cloud-accounts)
  - [Supabase](#supabase)
  - [Upstash Redis](#upstash-redis)
  - [Cloudinary](#cloudinary)
  - [LiveKit](#livekit)
- [Tooling (Node.js)](#tooling-nodejs)
- [Mobile Development Tools](#mobile-development-tools)
  - [iOS Development (macOS only)](#ios-development-macos-only)
  - [Android Development](#android-development)

---

## Quick Checklist

Run these commands to verify all prerequisites are installed. Every command should return a version number without errors.

```bash
# Core tools
go version          # Expected: go1.25+
flutter --version   # Expected: Flutter 3.22+
docker --version    # Expected: Docker 24.0+
docker compose version  # Expected: v2.20+
git --version       # Expected: git 2.30+

# Optional (for development tooling)
node --version      # Expected: v18.0.0+ (Husky/Prettier)
npm --version       # Expected: 9.0.0+
jq --version        # JSON log parsing
psql --version      # PostgreSQL client
redis-cli --version # Redis client
```

If any command fails or shows an older version than required, follow the detailed installation instructions below for that specific tool.

---

## Go

**Required Version:** 1.22 or higher (recommended: 1.25)
**Verification:** `go version`
**Why Flicko needs it:** All three backend microservices (`ws-gateway`, `msg-service`, `backend`) are written in Go. Go's goroutine-based concurrency model is essential for the WebSocket gateway, which manages thousands of simultaneous connections. Go's compiled binary output enables Alpine-based Docker containers as small as 15 MB. The `go.work` workspace file links the three service modules together for shared package imports.

### Installation

<details>
<summary><strong>macOS</strong></summary>

```bash
# Option 1: Homebrew (recommended)
brew install go

# Option 2: Official installer
# Download from https://go.dev/dl/ and run the .pkg installer

# Option 3: Version manager (gvm) for managing multiple Go versions
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source ~/.gvm/scripts/gvm
gvm install go1.25 -B
gvm use go1.25 --default
```

</details>

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

```bash
# Option 1: Official tarball (recommended — apt version is often outdated)
wget https://go.dev/dl/go1.25.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.linux-amd64.tar.gz

# Add to PATH in ~/.bashrc or ~/.zshrc
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# Option 2: Snap
sudo snap install go --classic
```

</details>

<details>
<summary><strong>Windows</strong></summary>

```powershell
# Option 1: Official MSI installer
# Download from https://go.dev/dl/ and run the .msi installer
# It automatically adds Go to PATH

# Option 2: Chocolatey
choco install golang

# Option 3: Scoop
scoop install go
```

</details>

### Verification

```bash
$ go version
go version go1.25.0 linux/amd64

$ go env GOPATH
/home/user/go

$ go env GOROOT
/usr/local/go
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `go: command not found` | Go not in PATH | Add `export PATH=$PATH:/usr/local/go/bin` to your shell profile |
| `go version` shows < 1.22 | Old version installed via apt | Uninstall apt version, install from official tarball |
| `cannot find module providing package` | Module not downloaded | Run `go mod download` in the service directory |
| `go.work: no go.work file found` | Not in workspace root | Navigate to `services/` directory which contains `go.work` |

### Go Editor Setup

For the best development experience with Flicko's Go codebase, configure your editor with the Go Language Server (gopls). This provides autocompletion, error detection, and jump-to-definition across all 95+ service files, 22 models, and 10 middleware layers.

**VS Code:** Install the "Go" extension by the Go Team at Google. It will prompt you to install gopls, dlv (debugger), and other tools automatically.

**GoLand/IntelliJ:** Go support is built-in. Open the `services/` directory as the project root so the `go.work` file is detected correctly.

---

---

## Flutter SDK

**Required Version:** 3.22 or higher
**Verification:** `flutter --version`
**Why Flicko needs it:** The Flicko mobile application is built using Flutter for true cross-platform performance (iOS + Android) from a single codebase. It leverages Dart 3.4+ features and the Riverpod state management framework for predictable, testable app logic.

### Installation

Follow the official Flutter installation guide for your platform:
- [macOS Installation](https://docs.flutter.dev/get-started/install/macos)
- [Linux Installation](https://docs.flutter.dev/get-started/install/linux)
- [Windows Installation](https://docs.flutter.dev/get-started/install/windows)

### Verification

```bash
$ flutter doctor
# Should show green checkmarks for Flutter, Android toolchain, and Xcode (if on macOS)
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `flutter: command not found` | Flutter not in PATH | Add the `flutter/bin` directory to your shell PATH |
| `cmdline-tools component is missing` | Android SDK missing tools | Install "Android SDK Command-line Tools" in Android Studio SDK Manager |
| `CocoaPods not installed` | Missing iOS dependency | `brew install cocoapods` or `sudo gem install cocoapods` |

---

## Docker and Docker Compose

**Required Version:** Docker Engine 24.0+, Docker Compose v2.20+
**Verification:** `docker --version` and `docker compose version`
**Why Flicko needs it:** The production deployment uses Docker Compose to orchestrate 9 containers across 3 isolated networks. Docker is also useful for local development to run the complete stack with monitoring. The Go services use multi-stage Dockerfiles for optimized Alpine-based production images (~15 MB each). Even if you don't need Docker for daily development, you'll need it to test production configuration changes or run the monitoring stack locally.

### What Flicko Runs in Docker

| Container | Image | Purpose | RAM Limit |
|-----------|-------|---------|----------|
| nginx | nginx:1.25-alpine | TLS termination, rate limiting | 128 MB |
| ws-gateway | Multi-stage Go build | WebSocket connections | 1 GB |
| msg-service | Multi-stage Go build | REST API | 512 MB |
| backend | Multi-stage Go build | Bot framework | 512 MB |
| prometheus | prom/prometheus:latest | Metrics TSDB | 512 MB |
| grafana | grafana/grafana:latest | Dashboards | 256 MB |
| loki | grafana/loki:latest | Log aggregation | 512 MB |
| node-exporter | prom/node-exporter | Host metrics | 64 MB |
| nginx-exporter | nginx/nginx-prometheus-exporter | NGINX metrics | 32 MB |

### Installation

<details>
<summary><strong>macOS</strong></summary>

```bash
# Docker Desktop (includes Docker Engine + Docker Compose)
# Download from https://www.docker.com/products/docker-desktop/
# Or via Homebrew:
brew install --cask docker
```

</details>

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

```bash
# Official Docker installation
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group (no sudo needed for docker commands)
sudo usermod -aG docker $USER
newgrp docker

# Docker Compose v2 (plugin — already included with Docker Engine 24+)
# Verify: docker compose version

# If compose is missing:
sudo apt install docker-compose-plugin
```

</details>

<details>
<summary><strong>Windows</strong></summary>

```powershell
# Docker Desktop for Windows
# Download from https://www.docker.com/products/docker-desktop/
# Requires WSL2 backend (Docker Desktop will prompt you to install it)
```

</details>

### Verification

```bash
$ docker --version
Docker version 24.0.7, build afdd53b

$ docker compose version
Docker Compose version v2.23.3

$ docker run hello-world
# Should print "Hello from Docker!"
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `permission denied` on Linux | User not in docker group | `sudo usermod -aG docker $USER && newgrp docker` |
| `docker compose` not found | Old Docker version | Upgrade Docker Engine or install compose plugin |
| Port conflicts | Another service on same port | Stop conflicting service or change port in `.env` |
| Out of disk space | Old images/containers | `docker system prune -a` (removes all unused data) |

---

## Git

**Required Version:** 2.30+
**Verification:** `git --version`
**Why Flicko needs it:** Version control for the monorepo. Husky pre-commit hooks (installed via `npm install` at the root) require Git to intercept commits and run formatting checks. The project uses conventional commit messages and feature branch workflow.

### Installation

Git is usually pre-installed on macOS and Linux. If not:

```bash
# macOS
brew install git   # or: xcode-select --install

# Linux (Ubuntu/Debian)
sudo apt install git

# Windows
# Download from https://git-scm.com/download/win
# Or: choco install git
```

### Required Configuration

```bash
# Set your identity (used in commit metadata)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Recommended: default branch name
git config --global init.defaultBranch main

# Recommended: auto-resolve CRLF issues (important on Windows)
git config --global core.autocrlf input   # macOS/Linux
git config --global core.autocrlf true    # Windows
```

---

## Cloud Accounts

Flicko depends on 4 cloud services for data persistence, real-time communication, media storage, and voice/video. All services offer free tiers sufficient for development.

### Supabase

**What it provides:** PostgreSQL database, authentication (email/password, OAuth), Edge Functions (serverless), Realtime (change data capture), and Row-Level Security policies.

**Why Flicko needs it:** Supabase is the primary database for all Flicko data — users, servers, channels, messages, roles, bots, and more. The 65 SQL migrations define the complete schema. Supabase Auth handles user registration, login, JWT tokens, and OAuth providers (Google, GitHub, Discord, Apple). Edge Functions power GIF search (GIPHY API) and push notification delivery.

**Free tier:** 2 projects, 500 MB database, 1 GB bandwidth, 50,000 monthly active users.

**Setup steps:**

1. Go to [supabase.com](https://supabase.com) and create an account
2. Create a new project — choose a strong database password and your nearest region
3. Wait for the project to initialize (~2 minutes)
4. Navigate to **Settings → API** to find:
   - `SUPABASE_URL` — Project URL (e.g., `https://abcdefgh.supabase.co`)
   - `SUPABASE_ANON_KEY` — Public anonymous key (safe for client-side)
   - `SUPABASE_SERVICE_ROLE_KEY` — Service role key (backend only, never expose)
5. Navigate to **Settings → Database** to find:
   - `DATABASE_URL` — Connection string (use port 6543 for connection pooler/Supavisor, not 5432)

```env
# Example Supabase configuration
SUPABASE_URL=https://abcdefgh.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
DATABASE_URL=postgresql://postgres.abcdefgh:YourPassword@aws-0-us-east-1.pooler.supabase.com:6543/postgres
```

> **Important:** Always use port `6543` (Supavisor connection pooler) instead of `5432` (direct connection). Supavisor efficiently manages connection pools across Flicko's three services, preventing connection exhaustion.

### Upstash Redis

**What it provides:** Serverless Redis with TLS encryption, REST API, and Pub/Sub support.

**Why Flicko needs it:** Redis serves four critical functions in Flicko: (1) Pub/Sub messaging — when `msg-service` creates a message, it publishes to a Redis channel that `ws-gateway` subscribes to for real-time delivery; (2) Session caching — JWT session metadata and user preferences are cached for fast lookup; (3) Rate limiting — distributed rate limit counters across all three services; (4) Dead letter queue — the message batcher stores failed inserts for later retry.

**Free tier:** 10,000 commands/day, 256 MB storage, 1 database.

**Setup steps:**

1. Go to [upstash.com](https://upstash.com) and create an account
2. Create a new Redis database — choose your nearest region, enable TLS
3. Copy the connection details:
   - `REDIS_URL` — Redis connection string with TLS (starts with `rediss://`)

```env
# Example Upstash Redis configuration
REDIS_URL=rediss://default:AbCdEfGhIjKlMnOpQrStUvWxYz@us1-lasting-koala-12345.upstash.io:6379
```

> **Note:** The URL starts with `rediss://` (double 's') — this indicates TLS encryption. Flicko's Redis client (`services/shared/redis/`) is configured to handle TLS connections automatically when it detects the `rediss://` scheme.

### Cloudinary

**What it provides:** Cloud-based image and video management with CDN delivery, on-the-fly transformations, and signed direct uploads.

**Why Flicko needs it:** All user-uploaded media in Flicko — avatars, server icons, banners, message attachments, custom emoji — are stored on Cloudinary's CDN. The backend generates cryptographic signatures (HMAC-SHA256) for direct uploads, so media files go straight from the mobile app to Cloudinary without passing through the Flicko backend. This reduces server load and provides global CDN delivery. The `cloudinaryService.ts` (12 KB) handles the client-side upload flow, and the `cloudinary.go` handler (4.3 KB) generates signatures.

**Free tier:** 25 monthly credits (roughly 25 GB storage + 25 GB bandwidth + 25,000 transformations).

**Setup steps:**

1. Go to [cloudinary.com](https://cloudinary.com) and create an account
2. Navigate to the **Dashboard** to find:
   - `CLOUDINARY_CLOUD_NAME` — Your cloud name (e.g., `dflicko`)
   - `CLOUDINARY_API_KEY` — API key (numeric)
   - `CLOUDINARY_API_SECRET` — API secret

```env
# Example Cloudinary configuration
CLOUDINARY_CLOUD_NAME=dflicko
CLOUDINARY_API_KEY=123456789012345
CLOUDINARY_API_SECRET=AbCdEfGhIjKlMnOpQrStUvWx
```

### LiveKit

**What it provides:** WebRTC Selective Forwarding Unit (SFU) for real-time voice and video communication.

**Why Flicko needs it:** LiveKit powers all voice and video features — voice channels, video calls, screen sharing, and DM voice/video calls. The SFU architecture means media streams are routed through LiveKit's servers rather than peer-to-peer, which scales to many participants without each client needing to send individual streams to every other participant.

**Free tier:** LiveKit Cloud offers a free tier with limited concurrent participants. Self-hosting is also an option for unlimited usage.

**Setup steps:**

1. Go to [livekit.io](https://livekit.io) and create an account
2. Create a new project
3. Copy the credentials:
   - `LIVEKIT_URL` — WebSocket URL (e.g., `wss://your-project.livekit.cloud`)
   - `LIVEKIT_API_KEY` — API key
   - `LIVEKIT_API_SECRET` — API secret

```env
# Example LiveKit configuration
LIVEKIT_URL=wss://flicko-dev.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key_here
LIVEKIT_API_SECRET=your_livekit_api_secret_here
```

---

## Tooling (Node.js)

**Required Version:** Node.js 18.0+
**Why Flicko needs it:** While the core app uses Flutter and Go, Node.js is required for our development tooling. The root `package.json` configures **Husky** pre-commit hooks and **Prettier** code formatting to maintain high code quality across the monorepo.

---

## Mobile Development Tools

### iOS Development (macOS only)

**Required:** Xcode 15+ with iOS Simulator
**Why:** To run and debug the Flicko mobile app on iOS. Xcode provides the build toolchain and simulators for iPhone testing.

```bash
# Install Xcode from the Mac App Store or:
xcode-select --install   # Installs command-line tools

# Verify
xcodebuild -version      # Expected: Xcode 15.x
```

### Android Development

**Required:** Android Studio with Android SDK, JDK 17+
**Why:** To run and debug the Flicko app on an Android emulator or physical device. Flutter requires the Android SDK for building and deploying.

## Optional Tools

These tools are not required but significantly improve the development experience:

| Tool | Purpose | Install |
|------|---------|---------|
| **jq** | Parse structured JSON logs from Go services | `brew install jq` / `apt install jq` |
| **psql** | Connect directly to Supabase PostgreSQL for debugging | `brew install postgresql` / `apt install postgresql-client` |
| **redis-cli** | Inspect Redis state, monitor Pub/Sub | `brew install redis` / `apt install redis-tools` |
| **Delve (dlv)** | Go debugger with breakpoints and step-through | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| **ngrok** | Flutterse local services for mobile testing on physical devices | Download from [ngrok.com](https://ngrok.com) |
| **Postman/Insomnia** | API testing with saved request collections | Download from respective websites |

### jq for Log Parsing

Flicko's Go services output structured JSON logs via Zap. `jq` makes these logs human-readable during development:

```bash
# Pretty-print all logs
go run ./cmd/server 2>&1 | jq .

# Filter for errors only
go run ./cmd/server 2>&1 | jq 'select(.level == "error")'

# Show only message and user_id fields
go run ./cmd/server 2>&1 | jq '{msg: .msg, user: .user_id}'
```

---

## Related Documentation

- [Getting Started: Installation](installation.md) — Step-by-step installation guide that assumes all prerequisites are met
- [Getting Started: Configuration](configuration.md) — Complete environment variable reference for all cloud services configured here
- [Getting Started: Troubleshooting](troubleshooting.md) — Solutions for common prerequisite-related errors
- [Development: Dev Environment](../development/dev-environment.md) — Advanced local development setup including IDE configuration and hot reload

## Quick Reference

| Prerequisite | Minimum Version | Free Tier Available |
|-------------|----------------|-------------------|
| Go | 1.22+ | Open source |
| Node.js | 18.0+ | Open source |
| Docker | 24.0+ | Docker Desktop free for personal use |
| Git | 2.30+ | Open source |
| Supabase | N/A | ✅ 2 projects, 500 MB |
| Upstash Redis | N/A | ✅ 10K commands/day |
| Cloudinary | N/A | ✅ 25 credits/month |
| LiveKit | N/A | ✅ Free tier |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
