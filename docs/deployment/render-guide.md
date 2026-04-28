# Render.com Deployment Guide

> **Reading time:** ~5 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

If managing a Raw VPS with Docker Compose and NGINX (as outlined in [Docker Compose](docker-compose.md)) is too complex, Flicko can be deployed as 3 distinct "Web Services" on a fully managed PaaS like Render.com.

---

## Architecture Adjustments for PaaS

When deploying to Render, we **delete** NGINX. 
Render handles edge routing, DDoS projection, and SSL termination automatically. Every Web Service on Render gets its own public URL (e.g., `https://flicko-gateway.onrender.com`).

Because the services no longer sit behind a single `api.flicko.app` domain, you must update the Flutter frontend `Config.ts` to point to the three distinct URLs.

---

## 1. Blueprint Configuration (Infrastructure as Code)

Render reads a `render.yaml` file to automate infrastructure deployment. Simply push this file to the root of your GitHub repository, connect your Repo to the Render Dashboard, and click "Blueprint Sync".

```yaml
# render.yaml
services:
  # 1. The Monolith
  - type: web
    name: flicko-backend
    env: docker
    dockerfilePath: ./Dockerfile
    dockerBuildArgs:
      - SERVICE_NAME=api
    region: ohio
    plan: starter # $7/mo
    envVars:
      # Automatically syncs against main repo secrets
      - key: DATABASE_URL
        sync: false 
      - key: SUPABASE_URL
        sync: false
      # ... other env vars

  # 2. WebSockets Edge
  - type: web
    name: flicko-ws-gateway
    env: docker
    dockerfilePath: ./Dockerfile
    dockerBuildArgs:
      - SERVICE_NAME=ws-gateway
    region: ohio
    plan: starter # $7/mo

  # 3. Message Batcher
  - type: web
    name: flicko-msg-service
    env: docker
    dockerfilePath: ./Dockerfile
    dockerBuildArgs:
      - SERVICE_NAME=msg-service
    region: ohio
    plan: starter # $7/mo
```

## 2. Managing Environment Variables

Render allows you to create "Environment Groups". Instead of pasting the `UPSTASH_REDIS_URL` into 3 different service panels manually, create a single Environment Group called `flicko-secrets`, paste all your keys there, and link the group to all 3 web services.

## 3. Disadvantages of PaaS Deployment

While easier, deploying to Render has drawbacks:
- **Cost:** Running 3 `starter` instances is $21/mo vs $6/mo on a bare VPS.
- **Latency:** Because the 3 services no longer communicate over a dedicated high-speed Docker `bridge` network, inter-service HTTP calls now incur public internet latency routing.
- **Cold Starts:** If you use Render's "Free" tier (which is not recommended for WebSockets), the services will spin down to sleep after 15 minutes of inactivity, causing 30-second delays when the next user tries to post a message.
