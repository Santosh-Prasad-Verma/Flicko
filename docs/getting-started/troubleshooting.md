# Troubleshooting Guide

> **Reading time:** ~15 minutes · **Audience:** All Developers · **Last Updated:** 2026-04-11

This guide covers every known issue you may encounter while developing, building, or deploying Flicko, organized by category. Each issue includes the exact error message, root cause analysis, solution steps, and prevention tips. If your issue isn't covered here, open a GitHub Discussion with the full error output and relevant log context.

---

## Table of Contents

- [Database Issues](#database-issues)
- [Redis Issues](#redis-issues)
- [Authentication Issues](#authentication-issues)
- [Backend Service Issues](#backend-service-issues)
- [Mobile App Issues](#mobile-app-issues)
- [WebSocket Issues](#websocket-issues)
- [Media Upload Issues](#media-upload-issues)
- [Docker Issues](#docker-issues)
- [Build Issues](#build-issues)
- [Performance Issues](#performance-issues)

---

## Database Issues

### Error: `password authentication failed for user "postgres"`

**Full error:**
```
pq: password authentication failed for user "postgres.abcdefgh"
```

**Root cause:** The password in `DATABASE_URL` is incorrect or contains special characters that aren't URL-encoded. Supabase database passwords are set when you create the project and can contain characters like `@`, `#`, `%` that have special meaning in URIs.

**Solution:**
1. Go to Supabase Dashboard → Settings → Database → Reset Database Password
2. Set a new password that only uses alphanumeric characters and basic symbols (`!`, `_`, `-`)
3. Update `DATABASE_URL` in your `.env` file with the new password
4. Restart all three Go services

**Prevention:** When creating a Supabase project, use a password without URI-special characters (`@`, `:`, `/`, `?`, `#`, `[`, `]`). If you must use special characters, URL-encode them (e.g., `@` → `%40`).

### Error: `too many connections for role "postgres"`

**Full error:**
```
pq: remaining connection slots are reserved for non-replication superuser connections
```

**Root cause:** You're connecting directly to PostgreSQL (port 5432) instead of through the Supavisor connection pooler (port 6543). With all 3 Go services opening default pools of 10 connections each, plus Supabase's internal connections, the 60-connection limit is quickly exhausted.

**Solution:**
1. Change `DATABASE_URL` port from `5432` to `6543`
2. Ensure the URL uses the pooler hostname (contains `pooler.supabase.com`)
3. Restart all services

**Correct URL format:**
```env
# ❌ Direct connection (will exhaust connection limit)
DATABASE_URL=postgresql://postgres:pass@db.abcdefgh.supabase.co:5432/postgres

# ✅ Supavisor connection pooler (manages pools efficiently)
DATABASE_URL=postgresql://postgres.abcdefgh:pass@aws-0-us-east-1.pooler.supabase.com:6543/postgres
```

### Error: `relation "servers" does not exist`

**Root cause:** Database migrations haven't been applied. The Go services expect the schema to exist before they can run queries.

**Solution:**
```bash
cd supabase
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

If `db push` fails, try resetting the database completely:
```bash
npx supabase db reset
```

> **Warning:** `db reset` deletes all data. Only use this in development.

### Error: `SSL is not enabled on the server`

**Root cause:** Missing `sslmode=require` parameter in `DATABASE_URL`. Supabase requires TLS for all connections.

**Solution:** Append `?sslmode=require` to your `DATABASE_URL`:
```env
DATABASE_URL=postgresql://...@host:6543/postgres?sslmode=require
```

---

## Redis Issues

### Error: `redis: connection refused`

**Full error:**
```
dial tcp: connect: connection refused
```

**Root cause:** The `REDIS_URL` is incorrect, the Upstash database is paused/deleted, or the URL uses `redis://` instead of `rediss://` (missing TLS).

**Solution:**
1. Log in to Upstash Console and verify your database is active
2. Copy the Redis URL from the dashboard (it should start with `rediss://`)
3. Update `REDIS_URL` in your `.env` file
4. Restart the affected service

### Error: `x509: certificate signed by unknown authority`

**Root cause:** TLS certificate verification failure when connecting to Upstash Redis. This typically occurs on Linux systems with outdated CA certificates.

**Solution:**
```bash
# Update CA certificates (Ubuntu/Debian)
sudo apt update && sudo apt install -y ca-certificates
sudo update-ca-certificates

# macOS (rarely needed — certificates come with the system)
brew install ca-certificates
```

### Redis Pub/Sub Not Working (Messages Not Delivered in Real-Time)

**Symptoms:** Messages save to the database (you can see them after refresh) but don't appear in real-time on other clients.

**Root cause:** The Redis Pub/Sub connection between `msg-service` (publisher) and `ws-gateway` (subscriber) is broken. This can happen if:
- `REDIS_URL` differs between the two services
- The Upstash database was restarted
- A network partition disconnected the subscriber

**Solution:**
1. Verify both services use the same `REDIS_URL` (they share the root `.env`)
2. Restart `ws-gateway` first (it re-subscribes to all channels on startup)
3. Then restart `msg-service` (it reconnects its publish client)
4. Check logs for `redis connected` confirmation in both services

---

## Authentication Issues

### Error: `401 Unauthorized` on All Requests

**Root cause:** The `JWT_SECRET` in your `.env` doesn't match the JWT secret in your Supabase project. The Go middleware verifies JWT signatures using this secret, and a mismatch means every token verification fails.

**Solution:**
1. Go to Supabase Dashboard → Settings → API → JWT Secret
2. Copy the exact JWT secret (it's a long base64-encoded string)
3. Paste it as the `JWT_SECRET` value in your `.env` (no quotes needed)
4. Restart all three Go services

**Verification:**
```bash
# The JWT secret should be the same as what Supabase uses to sign tokens
echo $JWT_SECRET | wc -c    # Should be 100+ characters
```

### Error: `token is expired`

**Root cause:** The JWT token's `exp` (expiration) claim is in the past. Supabase tokens expire after 1 hour by default. The mobile app should automatically refresh tokens using the refresh token, but bugs in the refresh logic or clock skew can cause this.

**Solution:**
1. Log out and log back in on the mobile app (forces a fresh token)
2. If persistent, check that the device's clock is accurate
3. Verify the token refresh logic in `shared/services/auth.service.ts`

### Error: `invalid token format`

**Root cause:** The `Authorization` header is malformed. Common causes: missing `Bearer ` prefix, extra whitespace, or truncated token.

**Expected format:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOi...
```

---

## Backend Service Issues

### Error: `address already in use`

**Full error:**
```
listen tcp :8080: bind: address already in use
```

**Root cause:** Another process (or another instance of the same service) is already listening on the port.

**Solution:**
```bash
# Find the process using the port
lsof -ti:8080

# Kill it
lsof -ti:8080 | xargs kill -9

# Or change the port in .env
PORT=8082
```

### Error: `too many open files`

**Full error:**
```
accept tcp [::]:8080: accept4: too many open files
```

**Root cause:** The OS file descriptor limit is too low for the number of WebSocket connections the ws-gateway is handling. Each WebSocket connection uses 2 file descriptors (one for the TCP socket, one for the TLS layer).

**Solution:**
```bash
# Check current limit
ulimit -n     # Default is often 1024

# Increase for current session
ulimit -n 65536

# Make permanent (Linux) — add to /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
```

### All 8 Bots Not Starting

**Symptoms:** Backend service starts but bot count is less than 8 or bot commands don't work.

**Root cause:** A bot's service dependency (database table, Redis prefix) is missing. Usually caused by incomplete migrations.

**Solution:**
1. Check the backend startup logs for specific bot registration errors
2. Verify migration 002 (`bot_system_tables.sql`, 291 lines) was applied:
   ```bash
   psql "$DATABASE_URL" -c "SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%settings%'"
   ```
3. Expected tables: `mod_settings`, `automod_settings`, `welcome_settings`, `level_settings`, `ticket_settings`, `starboard_settings`
4. If missing, re-run migrations: `npx supabase db push`

---

## Mobile App Issues

### White / Blank Screen on Launch

**Root cause (most common):** Metro bundler crashed or has stale cache. The app loads but JavaScript failed to execute.

**Solution:**
```bash
cd mobile

# Clear Metro cache and restart
npx expo start -c

# If that doesn't work, clear all caches
rm -rf node_modules/.cache
rm -rf .expo
npm install
npx expo start -c
```

### Error: `Network Request Failed`

**Root cause:** The mobile app can't reach the backend services. The most common cause is using `localhost` in `EXPO_PUBLIC_API_URL` instead of the machine's LAN IP.

**Solution:**
1. Find your LAN IP:
   ```bash
   hostname -I           # Linux
   ifconfig | grep "inet " # macOS
   ```
2. Update `mobile/.env`:
   ```env
   EXPO_PUBLIC_API_URL=http://192.168.1.100:8081
   EXPO_PUBLIC_WS_URL=ws://192.168.1.100:8080/ws
   ```
3. Restart Metro bundler (env changes require restart)

**Other causes:**
- Backend service isn't running
- Firewall blocking the port
- Phone and computer on different networks (if using physical device)

### Error: `Unable to resolve module`

**Root cause:** Missing npm dependency or incorrect import path.

**Solution:**
```bash
cd mobile
rm -rf node_modules
npm install
npx expo start -c
```

### Error: `Invariant Violation: "main" has not been registered`

**Root cause:** The app entry point is misconfigured. In Expo Router, the entry point is defined by the `"main"` field in `package.json` pointing to `expo-router/entry`.

**Solution:** Verify `mobile/package.json` contains:
```json
{
  "main": "expo-router/entry"
}
```

---

## WebSocket Issues

### Connection Drops Every 30 Seconds

**Root cause:** The heartbeat mechanism is working correctly — the client must respond to `OpHeartbeat` frames within the 30-second interval. If the client doesn't send a `OpHeartbeatAck`, the server considers the connection dead after 3 missed heartbeats (90 seconds) and closes it.

**What to check:**
1. The mobile app's WebSocket handler must process `OpHeartbeat` and respond with `OpHeartbeatAck`
2. If running through a proxy (e.g., Cloudflare), ensure WebSocket connections are allowed and the idle timeout is set to ≥120 seconds

### Messages Received by Wrong User

**Root cause:** The ws-gateway hub is subscribing a connection to the wrong channel. This is a rare bug — check that the user's server membership is correct in the database and that the `OpIdentify` handshake sends the correct JWT token.

---

## Media Upload Issues

### Error: `Invalid signature` on Cloudinary Upload

**Root cause:** The HMAC-SHA256 signature generated by the backend doesn't match what Cloudinary expects. This happens when:
- `CLOUDINARY_API_SECRET` is incorrect
- The timestamp used in the signature has drifted more than 1 hour from Cloudinary's server time
- The upload parameters (folder, eager transforms) don't match what was signed

**Solution:**
1. Verify `CLOUDINARY_API_SECRET` in your `.env` matches the value in Cloudinary Dashboard
2. Check that the system clock is accurate: `date -u` should be within a few seconds of real time
3. Restart the `backend` service to reload credentials

### Upload Size Limit Exceeded

**Error:** `413 Request Entity Too Large` or `file too large`

**Root cause:** Three independent size limits can trigger this error:
1. **NGINX** — `client_max_body_size 25m` in `nginx.conf` (25 MB)
2. **Go middleware** — 10 MB body limit in the middleware stack
3. **Cloudinary** — Plan-dependent limits (free: 10 MB images, 100 MB videos)

**Solution:** The Go middleware limit takes precedence for direct backend uploads, and NGINX takes precedence for proxied requests. For Cloudinary direct uploads, the limit is set by your Cloudinary plan.

---

## Docker Issues

### Error: `port is already allocated`

**Root cause:** Another Docker container or host process is using the same port.

**Solution:**
```bash
# Find what's using the port
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 8080
lsof -ti:8080

# Stop conflicting containers
docker compose down

# Remove all stopped containers and restart
docker compose -f docker-compose.prod.yml down -v
docker compose -f docker-compose.prod.yml up -d
```

### Error: `no space left on device`

**Root cause:** Docker images, containers, and volumes have consumed all disk space.

**Solution:**
```bash
# See disk usage
docker system df

# Remove unused data (images, containers, volumes, build cache)
docker system prune -a --volumes

# Check host disk space
df -h
```

### Container Keeps Restarting

**Symptoms:** `docker ps` shows container status cycling between `Up` and `Restarting`.

**Solution:**
```bash
# Check container logs for the crash reason
docker logs flicko-ws-gateway --tail 50

# Common causes:
# 1. Missing env vars → add to env_file or environment section
# 2. DB not ready → check depends_on and healthcheck configuration
# 3. OOM killed → increase memory limit in docker-compose.prod.yml
```

---

## Build Issues

### Go Build: `package X is not in std`

**Root cause:** Using a Go standard library package that doesn't exist in your Go version. Flicko requires Go 1.22+.

**Solution:** Upgrade Go to the latest version (see [Prerequisites](prerequisites.md#go)).

### npm install: `ERESOLVE unable to resolve dependency tree`

**Root cause:** Peer dependency conflict between packages. This sometimes happens when Expo SDK and React Native version constraints conflict.

**Solution:**
```bash
# Force install (resolves most peer dependency conflicts)
npm install --legacy-peer-deps

# Or use the exact lockfile
npm ci
```

---

## Performance Issues

### Slow Message Delivery (>500ms Latency)

**Possible causes:**
1. **Redis high latency** — Check Upstash dashboard for p99 latency. If >50ms, consider upgrading to a regional endpoint.
2. **Database connection pool exhaustion** — Check `msg-service` logs for connection wait times. Solution: switch to Supavisor (port 6543).
3. **WebSocket buffer overload** — Check `ws-gateway` memory usage. If near 1 GB limit, some connections may be queuing.

### High Memory Usage on ws-gateway

**Expected:** ~130 KB per connected WebSocket client. 5,000 connections ≈ 650 MB.

**If higher than expected:** Check for goroutine leaks using Go's pprof:
```bash
# If pprof endpoint is enabled
go tool pprof http://localhost:6060/debug/pprof/goroutine

# Expected goroutines: ~2 per connection (read + write) + base goroutines
# If significantly higher, there may be a goroutine leak
```

---

## Related Documentation

- [Getting Started: Installation](installation.md) — Step-by-step setup that prevents most of these issues
- [Getting Started: Configuration](configuration.md) — Environment variable reference for verifying your config
- [Deployment: Docker](../deployment/docker.md) — Docker-specific deployment and debugging
- [Security: Middleware Pipeline](../security/middleware-pipeline.md) — Debugging 401/403 errors

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
