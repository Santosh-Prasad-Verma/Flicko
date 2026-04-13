# Development: Scripts Reference

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

All operational scripts are in the `scripts/` directory. Each serves a specific purpose in the development, deployment, or maintenance lifecycle.

---

## Script Inventory

| Script | Size | Purpose | Usage |
|--------|------|---------|-------|
| `setup.sh` | 9.7 KB | Interactive setup wizard. Displays Flicko logo, checks prerequisites (Node.js, npm, Go, Docker, Git), shows getting started instructions. | `./setup.sh` |
| `dev-start.sh` | — | Starts local development infrastructure (Redis, monitoring) via Docker Compose. | `./scripts/dev-start.sh` |
| `deploy.sh` | — | Production deployment script. Pulls latest code, builds Docker images, restarts services with zero-downtime. | `./scripts/deploy.sh` |
| `server-setup.sh` | 36 KB | Full VPS initial setup. Installs Docker, configures firewall (UFW), sets up fail2ban, hardens SSH, tunes kernel, creates swap. Run once on a fresh server. | `sudo ./scripts/server-setup.sh` |
| `run-backend.sh` | — | Backend runner with automatic restart on crash. Wraps `go run` with retry logic. | `./scripts/run-backend.sh` |
| `check-health.sh` | — | Checks health of all running services by hitting health endpoints. | `./scripts/check-health.sh` |
| `generate-jwt-keys.sh` | — | Generates Ed25519 JWT key pair. Creates `secrets/jwt_public.pem` and `secrets/jwt_private.pem`. | `./scripts/generate-jwt-keys.sh` |
| `generate-icons.sh` | — | Generates app icons from source image in multiple sizes for iOS and Android. | `./scripts/generate-icons.sh` |
| `update-cloudflare-ips.sh` | — | Fetches latest Cloudflare IP ranges and updates NGINX `set_real_ip_from` directives. | `./scripts/update-cloudflare-ips.sh` |
| `zero-start.sh` | — | Zero-dependency minimal start script. | `./scripts/zero-start.sh` |
| `logrotate-flicko.conf` | — | Logrotate configuration for NGINX and Docker logs. Install to `/etc/logrotate.d/`. | `sudo cp scripts/logrotate-flicko.conf /etc/logrotate.d/flicko` |

---

## npm Scripts (package.json)

```json
{
  "scripts": {
    "prepare": "husky",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

| Script | Command | Purpose |
|--------|---------|---------|
| `npm run prepare` | Install Husky git hooks | Auto-runs after `npm install` |
| `npm run format` | Prettier format all files | Format entire project |
| `npm run format:check` | Prettier check only | CI-safe format verification |

---

## Related Docs
- [Dev Environment](dev-environment.md)
- [Deployment](../deployment/overview.md)
