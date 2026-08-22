# Installation Guide

> **Reading time:** ~25 minutes · **Audience:** New Developers · **Last Updated:** 2026-04-11

This guide walks you through the complete installation of Flicko from cloning the repository to running all three backend services and the mobile app simultaneously. Every step includes an explanation of what it does and why it's needed, so you understand the system as you set it up. Before starting, ensure you've completed all prerequisites in [prerequisites.md](prerequisites.md).

---

## Table of Contents

- [Step 1: Repository Setup](#step-1-repository-setup)
- [Step 2: Environment Configuration](#step-2-environment-configuration)
- [Step 3: Database Setup](#step-3-database-setup)
- [Step 4: Redis Verification](#step-4-redis-verification)
- [Step 5: Backend Services Setup](#step-5-backend-services-setup)
- [Step 6: Mobile App Setup](#step-6-mobile-app-setup)
- [Step 7: Verification Checklist](#step-7-verification-checklist)
- [Step 8: Development Data](#step-8-development-data)

---

## Step 1: Repository Setup

### Clone the Repository

```bash
git clone https://github.com/Santosh-Prasad-Verma/Flicko.git
cd Flicko
```

After cloning, you'll have the complete monorepo with the following top-level structure. Understanding this structure is critical for knowing where to find and place code:

```
Flicko/
├── backend/           # Go monolith — Bot framework (8 bots), slash commands, 95 services
├── services/          # Go microservices — ws-gateway + msg-service + shared packages
├── mobile/            # Flutter app — 80+ screens, Riverpod state, feature-first structure
├── shared/            # Shared packages and logic
├── supabase/          # Supabase config — 65 SQL migrations, Edge Functions
├── mail-gateway/      # Go email service
├── nginx/             # NGINX reverse proxy configuration (232 lines)
├── monitoring/        # Prometheus, Grafana, Loki configs
├── scripts/           # Deployment, setup, and health check scripts
├── docs/              # 87 documentation files across 12 categories
├── docker-compose.prod.yml  # Production: 9 containers, 3 networks (455 lines)
├── docker-compose.dev.yml   # Development stack
├── .env.example       # Environment variable template
├── package.json       # Root: Husky, Prettier, lint-staged
├── setup.sh           # Interactive setup wizard (9.7 KB)
└── README.md          # Project README
```

# This project doesn't require root npm install for core functionality, 
# although linting/hooks may use it.

This installs three root-level packages and sets up the development toolchain:

1. **Husky** — Git hooks manager. After `npm install`, Husky configures a `pre-commit` hook in `.husky/` that runs automatically before every `git commit`. This hook triggers lint-staged to format your changes, preventing unformatted code from entering the repository.

2. **Prettier** — Code formatter for TypeScript, JSON, YAML, and Markdown files. The configuration in `.prettierrc` defines Flicko's formatting rules (single quotes, trailing commas, 2-space indent). Prettier runs automatically on staged files via the pre-commit hook.

3. **lint-staged** — Runs formatters only on staged files (files added with `git add`), not the entire codebase. This keeps commits fast. The configuration in `package.json` maps file extensions to their formatters: `*.{ts,tsx}` → Prettier, `*.go` → gofmt.

If you skip this step, your commits won't be automatically formatted, and you may encounter CI failures due to formatting differences.

---

## Step 2: Environment Configuration

Flicko requires environment variables for database connections, Redis, authentication secrets, and cloud service credentials. There are two `.env` files to configure:

### Root .env (Backend Services)

```bash
cp .env.example .env
```

Open `.env` in your editor and fill in the following values. Each variable is explained in detail:

```env
# ═══════════════════════════════════════════
# DATABASE (Supabase PostgreSQL)
# ═══════════════════════════════════════════
# Connection string to your Supabase PostgreSQL database.
# IMPORTANT: Use port 6543 (Supavisor pooler), NOT 5432 (direct).
# Supavisor manages connection pools across all 3 Go services,
# preventing the "too many connections" error that occurs when
# 3 services each open their own connection pools to port 5432.
# Find this in: Supabase Dashboard → Settings → Database → Connection String → URI
DATABASE_URL=postgresql://postgres.XXXXX:YOUR_PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres?sslmode=require

# ═══════════════════════════════════════════
# SUPABASE
# ═══════════════════════════════════════════
# Project URL — used for Supabase Auth API calls and Edge Functions.
# Find this in: Supabase Dashboard → Settings → API → Project URL
SUPABASE_URL=https://XXXXX.supabase.co

# Anonymous key — safe for client-side use, subject to RLS policies.
# Find this in: Supabase Dashboard → Settings → API → Project API Keys → anon
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Service role key — BACKEND ONLY, bypasses RLS. Never expose in client code.
# Find this in: Supabase Dashboard → Settings → API → Project API Keys → service_role
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# ═══════════════════════════════════════════
# REDIS (Upstash)
# ═══════════════════════════════════════════
# TLS-encrypted Redis URL. The "rediss://" protocol indicates TLS.
# Find this in: Upstash Console → Your Database → Connect → Redis URL
REDIS_URL=rediss://default:TOKEN@HOST.upstash.io:6379

# ═══════════════════════════════════════════
# AUTHENTICATION
# ═══════════════════════════════════════════
# JWT signing secret — minimum 32 characters.
# Used by all 3 services to validate JWT tokens.
# Must match the JWT secret in your Supabase project settings.
# Find this in: Supabase Dashboard → Settings → API → JWT Secret
JWT_SECRET=your-supabase-jwt-secret-minimum-32-characters

# ═══════════════════════════════════════════
# ENCRYPTION
# ═══════════════════════════════════════════
# AES-256-GCM encryption key — 64 hex characters (32 bytes).
# Used to encrypt sensitive data at rest (DM content, etc.).
# Generate with: openssl rand -hex 32
# If omitted in development, an ephemeral key is auto-generated with a warning.
ENCRYPTION_KEY=

# ═══════════════════════════════════════════
# CLOUDINARY (Media CDN)
# ═══════════════════════════════════════════
# Find all three in: Cloudinary Dashboard → Getting Started
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=123456789012345
CLOUDINARY_API_SECRET=your_api_secret

# ═══════════════════════════════════════════
# LIVEKIT (Voice/Video)
# ═══════════════════════════════════════════
# Find in: LiveKit Cloud → Your Project → Settings
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=APIxxxxxxxx
LIVEKIT_API_SECRET=your_livekit_secret
```

### Mobile .env

```bash
cp mobile/.env.example mobile/.env
```

```env
# Mobile app environment variables
# These are loaded by the Flutter app using Azure Key Vault or local .env fallback

# API base URL — points to msg-service REST API
# For local dev: use your machine's LAN IP, NOT localhost
FLICKO_API_URL=https://192.168.1.100:8081

# WebSocket URL — points to ws-gateway
FLICKO_WS_URL=wss://192.168.1.100:8080/ws

# Supabase credentials (same as root .env)
FLICKO_SUPABASE_URL=https://XXXXX.supabase.co
FLICKO_SUPABASE_ANON_KEY=eyJhbGci...
```

> **Finding your local IP:** Run `ifconfig | grep "inet "` on macOS, `hostname -I` on Linux, or `ipconfig` on Windows. Use your LAN IP (usually 192.168.x.x or 10.x.x.x), not 127.0.0.1.

---

## Step 3: Database Setup

The database schema is defined by 65 SQL migration files in `supabase/migrations/` plus 3 backend migrations in `backend/migrations/`. These migrations create all tables, indexes, RLS policies, and stored functions.

### Running Supabase Migrations

```bash
# Install Supabase CLI if you haven't already
npm install -g supabase

# Link to your Supabase project
cd supabase
npx supabase link --project-ref YOUR_PROJECT_REF

# Run all 65 migrations
npx supabase db push
```

The `db push` command applies all migration files in sequential order. Here's what the key migration groups create:

| Migration Range | What It Creates |
|----------------|-----------------|
| `001` | Core tables: `users`, `servers`, `channels`, `messages`, `members`, `roles`, `member_roles`, `invites` |
| `002` | Bot system: `bots`, `bot_guilds`, `mod_settings`, `automod_settings`, `welcome_settings`, `level_settings`, `user_xp`, `ticket_settings`, `tickets`, `starboard_settings`, `starboard_entries`, `warnings` (291 lines) |
| `003–020` | Feature tables: `reactions`, `friends`, `dm_conversations`, `dm_messages`, `dm_participants`, `voice_states`, `threads`, `read_states`, `pins` |
| `021–033` | Indexes, constraints, column additions, enum types |
| `034` | Comprehensive Row-Level Security policies for all tables (13.3 KB) — enforces data access rules at the database level |
| `035` | Permission calculation SQL functions: `calculate_permissions()`, `has_permission()`, `check_channel_permission()` (6.9 KB) |
| `036–065` | Additional features, performance indexes, schema refinements |

### Verifying Migrations

After running migrations, verify the schema was created correctly:

```bash
# Using psql (if installed)
psql "$DATABASE_URL" -c "\dt public.*"

# Expected output: 20+ tables including servers, channels, messages, etc.
```

You can also verify in the Supabase Dashboard: navigate to **Table Editor** and confirm that tables like `servers`, `channels`, `messages`, `members`, `roles`, `bots`, `mod_settings`, etc. exist and have the expected columns.

### Rollback Procedure

If a migration fails partway through:

```bash
# Reset the database to a clean state (WARNING: deletes all data)
npx supabase db reset

# Or rollback the last migration
npx supabase migration repair --status reverted MIGRATION_VERSION
```

---

## Step 4: Redis Verification

Upstash Redis should already be configured via `REDIS_URL` in your `.env`. Verify the connection:

```bash
# Using redis-cli (if installed)
redis-cli -u "$REDIS_URL" PING
# Expected: PONG

# Or test from Go
cd services/shared
go test -run TestRedisConnection -v ./redis/
```

Flicko uses Redis for four purposes. If any of these fail, the related features will break:

| Purpose | What Breaks If Redis Is Down |
|---------|------------------------------|
| **Pub/Sub** | Real-time message delivery stops (messages still get saved to DB) |
| **Session Cache** | Slightly slower auth — falls back to DB lookup |
| **Rate Limiting** | Rate limits don't apply — all requests pass through |
| **Dead Letter Queue** | Failed messages can't be queued for retry (they're dropped) |

---

## Step 5: Backend Services Setup

Each of the three Go services needs to be built and started independently. Open **three separate terminal windows/tabs** for this step.

### Terminal 1: msg-service (REST API)

```bash
cd services/msg-service

# Download all Go module dependencies
go mod download

# Run the service
go run ./cmd/server
```

**Expected startup output:**
```json
{"level":"info","msg":"starting msg-service","port":8081,"version":"1.0.0"}
{"level":"info","msg":"database connected","host":"pooler.supabase.com","port":6543}
{"level":"info","msg":"redis connected","host":"upstash.io"}
{"level":"info","msg":"server listening","addr":":8081"}
```

**Verify it's running:**
```bash
curl http://localhost:8081/api/v1/health
# Expected: {"status":"ok","service":"msg-service"}
```

### Terminal 2: ws-gateway (WebSocket)

```bash
cd services/ws-gateway

go mod download
go run ./cmd/gateway
```

**Expected startup output:**
```json
{"level":"info","msg":"starting ws-gateway","port":8080}
{"level":"info","msg":"redis connected","host":"upstash.io"}
{"level":"info","msg":"gateway listening","addr":":8080"}
```

### Terminal 3: backend (Bot Framework)

```bash
cd backend

go mod download
go run ./cmd/server
```

**Expected startup output:**
```json
{"level":"info","msg":"starting backend service","port":8080}
{"level":"info","msg":"database connected"}
{"level":"info","msg":"redis connected"}
{"level":"info","msg":"bot registered","bot":"moderation"}
{"level":"info","msg":"bot registered","bot":"automod"}
{"level":"info","msg":"bot registered","bot":"welcome"}
{"level":"info","msg":"bot registered","bot":"leveling"}
{"level":"info","msg":"bot registered","bot":"music"}
{"level":"info","msg":"bot registered","bot":"ticket"}
{"level":"info","msg":"bot registered","bot":"poll"}
{"level":"info","msg":"bot registered","bot":"starboard"}
{"level":"info","msg":"all bots started","count":8}
{"level":"info","msg":"server listening","addr":":8080"}
```

The `backend` service initialization sequence (defined in `cmd/server/main.go`, 321 lines) performs these steps in order:

1. Load and validate configuration via `config.Load()`
2. Initialize Zap structured logger
3. Connect to PostgreSQL with connection pooling
4. Connect to Redis with TLS
5. Create all service instances with dependency injection
6. Register all 8 bots with the BotRegistry
7. Start all bots (subscribe to events, register commands)
8. Apply the 10-layer middleware stack to the HTTP router
9. Start the HTTP server on the configured port
10. Set up graceful shutdown handler (listens for SIGTERM/SIGINT)

### Common Build Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `missing go.sum entry` | Dependencies not downloaded | Run `go mod download` in the service directory |
| `cannot find module` | Wrong working directory | Ensure you're in the correct service directory |
| `connection refused` (DB) | Wrong DATABASE_URL | Check port (should be 6543 for Supavisor), password, and hostname |
| `connection refused` (Redis) | Wrong REDIS_URL or TLS issue | Ensure URL starts with `rediss://`, check Upstash credentials |
| `too many open files` | OS file descriptor limit | `ulimit -n 65536` (add to shell profile for persistence) |
| `address already in use` | Port conflict | Kill the process using that port: `lsof -ti:8080 | xargs kill` |

---

### Install Dependencies

```bash
cd mobile
flutter pub get
```

This installs all Flutter and Dart dependencies defined in `pubspec.yaml`. Key packages include:

- **flutter_riverpod** — Reactive state management and dependency injection
- **go_router** — Declarative routing system for all 80+ screens
- **supabase_flutter** — Official Supabase client for Auth and Database
- **livekit_client** — Real-time voice and video WebRTC client
- **flutter_secure_storage** — Encrypted local state (auth tokens)
- **cached_network_image** — High-performance image caching
- **shimmer** — Modern loading states
- **flutter_local_notifications** — Push and local notification engine
- **custom_lint** — Project-specific linting rules for Riverpod

### Generate Code

Many parts of the Flicko mobile app (Riverpod and Freezed models) rely on code generation.

```bash
# Run one-time generation
flutter pub run build_runner build --delete-conflicting-outputs

# Or watch for changes during development
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Start the Application

```bash
flutter run
```

This compiles the app for your targets. You have several options for running the app:

| Method | Command | Requirements |
|--------|---------|-------------|
| **iOS Simulator** | `flutter run -d iOS` | macOS + Xcode + Booted Simulator |
| **Android Emulator** | `flutter run -d android` | Android Studio + AVD running |
| **Physical Device** | `flutter run -d <DEVICE_ID>` | Physical device connected via USB/Wi-Fi |
| **Release Build** | `flutter build apk` / `ios` | Production signing configured |

The mobile app needs to connect to your local backend services. Ensure `mobile/.env` has the correct IP:

```env
# ❌ WRONG — simulators can't resolve localhost to the host machine
FLICKO_API_URL=https://localhost:8081

# ✅ CORRECT — use your machine's LAN IP
FLICKO_API_URL=https://192.168.1.100:8081
FLICKO_WS_URL=wss://192.168.1.100:8080/ws
```

### First Run Expectations

When the app first loads, you should see:

1. **Splash screen** — Flicko icon on blurple (#5865F2) background
2. **Login screen** — Email and password fields with "Create Account" link
3. **Create an account** — Fill in username, email, and password
4. **Home screen** — Empty server list with a "Create Server" button

If you see a white/blank screen or an error, check the console output and refer to the [Troubleshooting Guide](troubleshooting.md).

---

## Step 7: Verification Checklist

After completing all steps, verify that everything is working correctly by going through this checklist:

### Backend Services

- [ ] **msg-service** is running on port 8081
  - `curl http://localhost:8081/api/v1/health` returns `{"status":"ok"}`
- [ ] **ws-gateway** is running on port 8080
  - No error logs in terminal
- [ ] **backend** is running with all 8 bots registered
  - Log shows "all bots started, count: 8"
- [ ] Database is connected
  - No `connection refused` errors in any service log
- [ ] Redis is connected
  - No `redis: connection refused` errors

### Mobile App

- [ ] Flutter dependencies are installed (`flutter pub get`)
- [ ] Code generation is complete (`build_runner`)
- [ ] App loads on simulator/device (shows login or home screen)
- [ ] Registration works (create a new account)
- [ ] Login works (sign in with the account you just created)
- [ ] Server creation works (create a test server)
- [ ] Message sending works (send a message in the test server)

### End-to-End Test

- [ ] Create a server with a name and icon
- [ ] Create a text channel and a voice channel
- [ ] Send a message in the text channel
- [ ] The message appears in real-time (WebSocket delivery working)
- [ ] Create an invite link and copy it
- [ ] React to a message with an emoji

---

## Step 8: Development Data

For testing features like moderation, leveling, and social features, you'll want seed data in your local database.

### Creating Test Accounts

Create 2-3 test accounts through the mobile app's registration screen:
- **Admin user:** `admin@flicko.dev` (will be the server owner)
- **Regular user:** `user@flicko.dev` (for testing permission restrictions)
- **Bot test user:** `test@flicko.dev` (for testing bot commands on)

### Setting Up a Test Server

1. Log in as the admin user
2. Create a server called "Flicko Dev Test"
3. Create channels: `#general`, `#bot-testing`, `#mod-log`, `#welcome`
4. Create roles: "Admin" (all permissions), "Moderator" (moderate + manage messages), "Member" (basic read/write)
5. Assign the "Moderator" role to the regular user
6. Enable bots: Moderation, AutoMod, Welcome, Leveling
7. Configure the Welcome bot to send messages in `#welcome`
8. Configure the Moderation bot to log in `#mod-log`

This setup gives you a complete testing environment for all major features.

---

## Related Documentation

- [Getting Started: Prerequisites](prerequisites.md) — All required tools and cloud accounts (must complete before this guide)
- [Getting Started: Configuration](configuration.md) — Complete environment variable reference with all 169 variables explained
- [Getting Started: Quick Start](quick-start.md) — The fast path for experienced developers who don't need step-by-step explanations
- [Getting Started: Troubleshooting](troubleshooting.md) — Solutions for every common installation error
- [Development: Dev Environment](../development/dev-environment.md) — IDE setup, hot reload configuration, and useful development tools

## Quick Reference

| Step | Time Estimate | What It Sets Up |
|------|-------------- |-----------------|
| Repository setup | 2 min | Clone + npm install (Husky hooks) |
| Environment config | 10 min | .env files for all services |
| Database setup | 5 min | 65 migrations applied |
| Redis verification | 1 min | Pub/Sub + cache + rate limiting |
| Backend services | 5 min | 3 Go services running |
| Mobile app | 5 min | Flutter app on simulator |
| Verification | 5 min | End-to-end feature check |
| **Total** | **~35 min** | **Full local development environment** |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
