# Deployment Overview

> **Reading time:** ~5 minutes · **Audience:** DevOps, SysAdmins · **Last Updated:** 2026-04-11

Flicko is specifically designed to be extremely cost-effective to host while maintaining enterprise-grade security and reliability. This section covers how we package, orchestrate, and route traffic to the Flicko backend.

---

## The Infrastructure Philosophy

Most modern platforms push heavily towards Kubernetes (k8s) or complex serverless meshes. 
While Flicko's 3-service split *can* be deployed to Kubernetes, our primary architectural mandate is: **Run on a single VPS.**

By utilizing Go (compiled, statically linked binaries with tiny memory footprints) and a highly optimized NGINX reverse-proxy, the entire Flicko tech stack can handle tens of thousands of active WebSockets on a single $24/mo Ubuntu VPS (e.g., 4 vCPU, 8GB RAM on DigitalOcean or Azure).

To achieve this, we rely heavily on **Docker Compose** for orchestration.

---

## Production Footprint

A typical production node runs these exact Docker containers:

1. **`nginx`** — The edge router taking ports 80/443.
2. **`flicko-backend`** — The main monolith (REST API & Bot Engine).
3. **`flicko-msg-service`** — The high-throughput message batcher.
4. **`flicko-ws-gateway`** — The WebSocket handler.
5. **`prometheus`** — Time-series metrics scraper.
6. **`grafana`** — Visual dashboarding for the metrics.

*Note: We do NOT host PostgreSQL or Redis on the VPS. For reliability and data durability, those are delegated to Supabase and Upstash respectively.*

---

## Cloudflare Integration

The VPS IP address should never be exposed directly to DNS. We enforce the use of **Cloudflare**.

1. **DNS Routing:** `api.flicko.app` points to the VPS IP via an `A` record (Proxied).
2. **WAF:** Cloudflare automatically drops known malicious bots before they ever use our VPS CPU cycles.
3. **Strict SSL:** We generate a Cloudflare Origin Certificate (Valid for 15 years) and mount it inside the NGINX Docker container. This ensures traffic between Cloudflare's Edge and our single VPS is fully encrypted, mathematically neutralizing Man-in-the-Middle attacks.

---

## Deployment Options

Flicko officially supports several deployment topologies. Depending on your team size and budget, choose the guide that fits your needs:

- [Standard Docker Compose Deployment](docker-compose.md) (Recommended)
- [Render.com PaaS Deployment](render-guide.md) (Fully Managed)
- [Azure Migration Strategy](azure-guide.md) (Free Credit Optimization)

If you are just trying to run the app on your local MacBook or Windows machine, please refer to the [Getting Started: Installation](../getting-started/installation.md) guide instead.

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
