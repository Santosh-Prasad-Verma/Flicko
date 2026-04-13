# Development: Local Environment

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Quick Setup

```bash
# 1. Clone
git clone https://github.com/Santosh-Prasad-Verma/Flicko.git && cd Flicko

# 2. Root dependencies (Husky, Prettier)
npm install

# 3. Environment files
cp .env.example .env
cp mobile/.env.example mobile/.env
# Fill in your Supabase, Redis, Cloudinary credentials

# 4. Start infrastructure (optional local Redis)
./scripts/dev-start.sh

# 5. Start backend (Terminal 1)
cd services && go run ./msg-service/cmd/server

# 6. Start WebSocket gateway (Terminal 2)
cd services && go run ./ws-gateway/cmd/gateway

# 7. Start mobile (Terminal 3)
cd mobile && npm install && npx expo start
```

## IDE Configuration

### VS Code (Recommended)
Install these extensions:
- **Go** — Go language support
- **ES7+ React/Redux/React-Native** — React snippets
- **Prettier** — Auto-formatting
- **ESLint** — TypeScript linting
- **Docker** — Container management

### GoLand / IntelliJ
- Import `backend/` as Go module
- Set GOPATH appropriately
- Enable Go workspace mode for `services/go.work`

## Hot Reload

| Service | Hot Reload | How |
|---------|-----------|-----|
| Mobile app | ✅ Yes | Expo fast refresh (automatic) |
| Go backend | ❌ Manual | Stop → `go run` again. Or use `air` for Go hot reload |
| NGINX | ❌ Manual | `docker compose restart nginx` |

## Useful Development Commands

```bash
# Format all Go code
gofmt -w backend/ services/

# Format all TypeScript
npx prettier --write "shared/**/*.ts" "mobile/**/*.tsx"

# Run Go tests
cd backend && go test -v ./...

# Check for lint errors
cd mobile && npx eslint . --ext .ts,.tsx

# View Docker logs
docker compose logs -f --tail=50

# Reset Supabase database
node supabase/reset.js
```

---

## Related Docs
- [Prerequisites](../getting-started/prerequisites.md)
- [Installation](../getting-started/installation.md)
- [Configuration](../getting-started/configuration.md)
