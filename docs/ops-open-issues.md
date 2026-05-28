# Production Ops — Open Issues

Two issues remain on the Azure VM (`Tarun@104.43.114.32`) after the bot
re-registration loop was fixed by rebuilding `flicko/backend` cleanly.

---

## 1. msg-service stale image (go-retryablehttp go.sum bug)

### Problem

`docker compose build msg-service` fails on the VM with:

```
/go/pkg/mod/github.com/livekit/protocol@v1.45.3/webhook/resource_url_notifier.go:30:2:
  missing go.sum entry for module providing package
  github.com/hashicorp/go-retryablehttp
  (imported by github.com/livekit/protocol/webhook); to add:
    go get github.com/livekit/protocol/webhook@v1.45.3
```

Because the build fails, compose silently keeps running the previously
cached `flicko/msg-service:latest` image. The deployed binary is stale and
won't pick up any code changes in `services/msg-service/` until the build
succeeds.

### Root cause

`services/msg-service/go.sum` is missing checksum entries for
`github.com/hashicorp/go-retryablehttp`, which is a transitive dependency
of `github.com/livekit/protocol/webhook@v1.45.3`. Go module integrity
checks reject the build.

### Why we fix on dev, not on the VM

The VM only runs Docker — no Go toolchain installed (`go: command not
found`). Updating `go.sum` requires running `go mod tidy`, so it has to
happen on a dev machine and be committed.

### Solution

**On the dev machine (Fedora):**

```bash
cd ~/Pictures/Flicko/services/msg-service
go get github.com/livekit/protocol/webhook@v1.45.3
go mod tidy

# Verify go.sum now has the entry
grep go-retryablehttp go.sum

git add go.mod go.sum
git commit -m "fix(msg-service): add missing go-retryablehttp go.sum entry"
git push origin main
```

**On the Azure VM:**

```bash
cd ~/Flicko
git pull origin main

# Rebuild only msg-service (no --no-cache needed; the go.mod change
# invalidates the relevant layer)
docker compose -f docker-compose.prod.yml build msg-service

# Recreate the container
docker compose -f docker-compose.prod.yml up -d --force-recreate msg-service

# Verify
docker image inspect flicko/msg-service:latest --format='Created={{.Created}}'
docker compose -f docker-compose.prod.yml logs --tail=20 msg-service
```

The new image timestamp should be today's date and the logs should show a
clean startup with no `missing go.sum` errors.

---

## 2. Orphan containers warning

### Problem

Every `docker compose -f docker-compose.prod.yml ...` invocation prints:

```
WARN[0000] Found orphan containers
  ([flicko-livekit-sfu flicko-redis-local])
  for this project. If you removed or renamed this service in your
  compose file, you can run this command with the --remove-orphans flag
  to clean it up.
```

### Root cause

`flicko-livekit-sfu` and `flicko-redis-local` were defined in the older
`docker-compose.yml` (dev-style) but are not part of
`docker-compose.prod.yml`. Compose still finds them under the same project
label and flags them as orphans.

They're also unused in production — prod uses Upstash Redis (cloud) and
no LiveKit SFU.

### Solution

**Confirm they're safe to remove first:**

```bash
# Are these containers in use? Check what's connecting to them.
docker ps --filter name=flicko-livekit-sfu --filter name=flicko-redis-local
docker network inspect flicko_default 2>/dev/null | grep -A2 flicko-

# Confirm prod uses Upstash, not local Redis
grep -E "REDIS_URL|UPSTASH" .env.prod
```

If `REDIS_URL` points at `*.upstash.io` (it does — confirmed in earlier
msg-service logs: `redis: connected addr=settling-grizzly-97370.upstash.io:6379`),
the local Redis container is unused and safe to drop.

**Remove the orphans:**

```bash
cd ~/Flicko
docker compose -f docker-compose.prod.yml up -d --remove-orphans
```

This stops and removes `flicko-livekit-sfu` and `flicko-redis-local` while
leaving every prod-defined service running.

The warning will stop appearing on subsequent compose commands.

### If you need LiveKit later

Don't bring back the old containers — add a `livekit:` service block to
`docker-compose.prod.yml` with proper resource limits, network attachment,
and `env_file: .env.prod` so it's part of the prod stack.

---

## Verification checklist (after both fixes)

```bash
cd ~/Flicko

# All services healthy, no orphans
docker compose -f docker-compose.prod.yml ps

# Fresh msg-service image
docker image inspect flicko/msg-service:latest --format='Created={{.Created}}'

# Health endpoint returns 200 (via nginx)
curl -sf http://localhost/api/v1/health && echo OK

# No leftover errors in logs
docker compose -f docker-compose.prod.yml logs --since=5m \
  | grep -iE "panic|fatal|error" \
  | grep -v "level\":\"info"
```
