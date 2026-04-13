# Deployment: Cloud Options

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Recommended: Single VPS (Current Architecture)

The current architecture is optimized for deployment on a single VPS with Docker Compose. Recommended providers:

| Provider | Plans | Monthly Cost |
|----------|-------|-------------|
| **Hetzner** | CX31 (8 GB / 2 vCPU) | ~€8.50/mo |
| **DigitalOcean** | Droplet (8 GB / 2 vCPU) | ~$48/mo |
| **Linode** | Shared 8 GB | ~$48/mo |
| **Azure** | B2s (4 GB) with student credits | $0 with $100 credit |

## VPS Initial Setup

The `scripts/server-setup.sh` (36 KB) automates:
1. System updates and essential packages
2. Docker and Docker Compose installation
3. UFW firewall configuration (80, 443, SSH only)
4. fail2ban installation and configuration
5. SSH hardening (key-only auth, non-standard port)
6. Swap file creation (2 GB)
7. Kernel tuning for high-concurrency WebSocket
8. Log rotation setup

## Alternative: Azure

For Azure deployment with student credits ($100), see the [Azure Hosting Strategy](../../) conversation for detailed guidance on using Azure Container Instances or Azure App Service.

---

## Related Docs
- [Deployment Overview](overview.md)
- [Docker](docker.md)
