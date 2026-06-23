<p align="center">
  <img src="assets/branding/Flicko-for-black-background.png" alt="Flicko Logo" width="140" height="140" />
</p>

<h1 align="center">⚡ Flicko</h1>

<p align="center">
  <strong>The open-source, self-hostable Discord alternative featuring secure real-time messaging, LiveKit voice/video, BlackHole-powered music, built-in bots, and end-to-end encryption.</strong>
</p>

<p align="center">
  <a href="#-quick-start"><strong>Quick Start</strong></a> •
  <a href="#-architecture"><strong>Architecture</strong></a> •
  <a href="#-key-features"><strong>Features</strong></a> •
  <a href="#-self-hosting"><strong>Self-Hosting</strong></a> •
  <a href="docs/README.md"><strong>Full Documentation</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.26-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go" />
  <img src="https://img.shields.io/badge/Flutter-3.22+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Supabase-Postgres+RLS-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/LiveKit-WebRTC-5AC8FA?style=for-the-badge&logo=livekit&logoColor=white" alt="LiveKit" />
  <img src="https://img.shields.io/badge/Firebase-FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Razorpay-Payments-3395FF?style=for-the-badge&logo=razorpay&logoColor=white" alt="Razorpay" />
  <img src="https://img.shields.io/badge/Appwrite-Storage-FD366E?style=for-the-badge&logo=appwrite&logoColor=white" alt="Appwrite" />
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</p>

---

<p align="center">
  <img src="assets/branding/Flicko-new-banner.png" alt="Flicko App Banner" width="100%" />
</p>

---

## 📖 Table of Contents

- [🌟 What is Flicko?](#-what-is-flicko)
- [🏗️ Architecture](#️-architecture)
- [✨ Key Features](#-key-features)
- [💻 Tech Stack](#-tech-stack)
- [📁 Repository Layout](#-repository-layout)
- [🚀 Quick Start](#-quick-start)
- [🌐 Self-Hosting](#-self-hosting)
- [⚙️ Configuration](#️-configuration)
- [🔔 Push Notifications](#-push-notifications)
- [🎙️ Voice & Video Setup](#️-voice--video-setup)
- [🎵 Music System (Sonic Drip)](#-music-system-sonic-drip)
- [🔒 End-to-End Encryption](#-end-to-end-encryption)
- [🗄️ Database & Migrations](#️-database--migrations)
- [🛡️ Security Checklist](#️-security-checklist)
- [📣 Marketing Website](#-marketing-website)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🌟 What is Flicko?

Flicko is a modern, privacy-focused, and robust real-time communication platform designed to be a viable open-source alternative to Discord. Built with a modular microservices architecture, Flicko is fully self-hostable and scales easily from a single VPS to distributed cloud environments.

### The Four Pillars of Flicko:
* **💬 Real-Time Messaging** — Text channels, threads, nested replies, emoji reactions, media attachments, custom emojis, polls, mentions, and typing status.
* **🎥 Crystal Clear Voice & Video** — WebRTC-powered voice rooms, high-definition video calls, screen sharing, integrated soundboards, stage channels, and collaborative whiteboards.
* **🎵 Sonic Drip Music** — Seamless JioSaavn and YouTube integration providing direct music search and streaming directly within your client.
* **🛡️ End-to-End Security** — Private DMs protected by the Signal protocol (X3DH key agreement and Double Ratchet), backed by local secure storage.

---

## 🏗️ Architecture

Flicko leverages a specialized Go-based microservices layer behind an NGINX reverse proxy. Real-time notifications and state management are orchestrated via Redis Pub/Sub, while persistent data is secured within Supabase Postgres using strict Row-Level Security (RLS).

```mermaid
graph TB
    subgraph Client["Client Devices"]
        APP["Flutter App<br/>(iOS / Android)"]
    end

    subgraph Edge["Gateway & Routing"]
        CF["Cloudflare<br/>WAF & CDN"]
        NGX["NGINX Proxy<br/>SSL / WebSockets / Rate Limits"]
    end

    subgraph Backend["Go Microservices"]
        BE["backend-service<br/>Core APIs & Bots"]
        WS["ws-gateway<br/>WebSocket Broker"]
        MSG["msg-service<br/>Message Pipeline"]
        MAIL["mail-gateway<br/>Branded SMTP Relay"]
        SD["sonic-drip<br/>Music Server (Python)"]
    end

    subgraph Cloud["Data & Media Infrastructure"]
        DB["Supabase Postgres<br/>Storage + RLS Rules"]
        REDIS["Redis Cache<br/>Queues / Pub-Sub"]
        AW["Appwrite Storage<br/>Asset CDN"]
        LK["LiveKit SFU<br/>WebRTC Audio/Video"]
        FCM["Firebase FCM<br/>Push Services"]
        RP["Razorpay<br/>Subscription Billing"]
    end

    APP -->|HTTPS/WSS| CF --> NGX
    APP -->|WebRTC| LK
    APP -->|Push Tokens| FCM
    NGX --> BE & WS & MSG & MAIL
    BE & MSG --> DB & REDIS
    WS --> REDIS
    BE --> AW & LK & RP
    SD --> DB
    DB -->|Db Hook on Message| FCM
```

---

## ✨ Key Features

### 💬 Rich Messaging
* **Modern Channel Formats:** Standard Text channels, Voice channels, Announcement feeds, and Forum channels with threads.
* **Rich Interactions:** In-line replies, markdown formatting, Giphy integration, polls, pins, custom stickers, and mentions.
* **E2EE Direct Messages:** X3DH key agreement and Double Ratchet (XChaCha20-Poly1305 + HKDF-SHA256) for unbreakable 1:1 chats.
* **Reliable Delivery:** Read receipts, typing indicators, and full-text channel search using Postgres `tsvector`.

### 🎙️ Immersive Voice & Video
* **LiveKit WebRTC Integration:** Ultra-low latency voice/video with auto-adaptive bitrate and noise suppression.
* **Stage Channels:** Speaker queues, moderator controls, and audience "raise hand" requests.
* **Screen Sharing & Camera:** HD stream broadcasting directly from mobile devices.
* **Collaborative Whiteboard:** Synced in real-time, allowing users to draw and brainstorm together.

### 🎵 Sonic Drip Music
* **Direct Integration:** BlackHole-inspired search & streaming utilizing JioSaavn and YouTube.
* **Spotify Integration:** Local capture for Spotify metadata throughWebView (no Premium required).
* **System Integration:** Dynamic lock-screen media controls on iOS and Android via `audio_service`.
* **Visualizer:** Pulsing "Gava" equalizer visualizer integrated into user profiles when streaming.

### 🎮 Gaming Hub
* **Play In-App:** Full Chess and Ludo engines with real-time multiplayer matchmaking.
* **Matchmaking & Stats:** Leaderboards, match history, and Elo scoring tracked in Redis + Postgres.

### 🤖 Built-in Bot Framework
Flicko ships with a complete, built-in asynchronous bot framework managed by `asynq_coordinator.go`:
* **AutoMod Bot:** Real-time spam, link, and profanity filtering.
* **Leveling Bot:** User XP progression system with custom role unlocks.
* **Ticket Bot:** Support queue system with private ticket channels.
* **Music Bot, Starboard Bot, Poll Bot, Welcome Bot, and Moderation Bot.**

---

## 💻 Tech Stack

| Layer | Technologies |
|---|---|
| **Mobile Client** | Flutter 3.22+, Dart 3.4+, Riverpod 3, GoRouter 17, Freezed |
| **Backend API** | Go 1.26, Chi Router, pgx/v5, Asynq, LiveKit Go SDK, Zap Logger |
| **Real-time Gateway** | Custom Go WebSocket Broker (`ws-gateway`), Redis Pub/Sub |
| **Database** | Postgres 15 (Supabase) with Row-Level Security (RLS) on all tables |
| **File Storage** | Appwrite Object Storage |
| **WebRTC Media** | LiveKit SFU (WebRTC), just_audio, audio_service |
| **Music Services** | Python FastAPI, spotapi 1.2.7, JioSaavn & YouTube API |
| **Push Notifications** | Firebase Cloud Messaging (FCM HTTP v1) |
| **Payments & Billing** | Razorpay SDK (subscriptions, boosts, catalog transactions) |
| **E2EE Core** | X3DH (Curve25519), Double Ratchet (XChaCha20-Poly1305), Argon2id |

---

## 📁 Repository Layout

```
.
├── mobile/              # Flutter Client Application (iOS + Android)
├── backend/             # Primary Go Backend API (Auth, Servers, Bots, Billing)
├── services/            # Core Infrastructure Services (ws-gateway, msg-service, shared)
├── sonic-drip/          # Music Stream Engine (Go + Python spotapi integration)
├── mail-gateway/        # Branded HTML Transactional Email Relay (Go)
├── supabase/            # Database configurations & migrations
│   ├── migrations/      # 131+ production-ready SQL database migrations
│   └── functions/       # Edge Functions (voice-token, push-notify, etc.)
├── nginx/               # NGINX configuration templates
├── monitoring/          # Prometheus, Grafana, and Loki configs
├── web/                 # Marketing Site & Web Portal (Next.js 15 + Bun)
└── docs/                # Extended architectural and deployment guides
```

---

## 🚀 Quick Start

### 1. Clone & Initialize Env
```bash
git clone git@github.com:Santosh-Prasad-Verma/Flicko.git
cd Flicko
cp .env.example .env
cp .env.mail-gateway.example mail-gateway/.env
```
*(Review and populate the `.env` files with your local/staging configuration)*

### 2. Launch Local Services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### 3. Run the Mobile App
```bash
cd mobile
flutter pub get
flutter run
```

---

## 🌐 Self-Hosting

For production hosting, Flicko uses `docker-compose.prod.yml` to spin up a fully isolated, secure network structure.

| Service Container | Port | Description |
|---|---|---|
| `flicko-nginx` | `80` / `443` | Reverse proxy, SSL termination, WebSocket upgrade handling |
| `flicko-backend` | `8090` | Primary Go REST API and Asynq Bot Worker |
| `flicko-ws-gateway` | `8091` | High-throughput WebSocket connection broker |
| `flicko-msg-service` | `8092` | REST ingestion layer for chat and media |
| `flicko-sonic-drip` | `8001` | Music streaming metadata service |
| `flicko-livekit-sfu` | `7880` - `7882` | LiveKit SFU media server (TCP/UDP WebRTC ports) |
| `flicko-redis` | `6379` | Cache, key-value store, and pub/sub broker |
| `flicko-prometheus` | `9090` | System metrics harvester |
| `flicko-grafana` | `3000` | Real-time performance dashboards |

> [!TIP]
> For small server configurations (e.g. 8GB RAM single VPS), use `docker-compose.zero.yml` to launch without the heavy Prometheus/Grafana monitoring suite.

---

## ⚙️ Configuration

Secrets and configuration tokens are located across three locations:
1. **`.env`** (Root): Handles database configuration, Redis strings, JWT credentials, Razorpay IDs, and LiveKit keys.
2. **`mail-gateway/.env`**: Handles Brevo SMTP keys and database webhook verification tokens.
3. **`mobile/.env`**: Envs for Flutter client (Supabase URL, anon key, Appwrite API keys, LiveKit server address, Giphy tokens).

---

## 🔔 Push Notifications

Flicko manages notifications with high reliability:
1. **Token Registration:** The Flutter client registers its FCM token to the `public.user_devices` table.
2. **Database Trigger:** An `INSERT` trigger on `messages` posts a payload to the Supabase `push-notify` Edge function.
3. **FCM Gateway:** The Edge function generates a secure Firebase Admin payload and dispatches it over FCM HTTP v1.
4. **Local Alert:** When received in the foreground, `flutter_local_notifications` displays a beautiful, custom in-app banner.

---

## 🎙️ Voice & Video Setup

LiveKit runs as a container within the stack. Configure `livekit.yaml` to specify key-secret pairs:
```yaml
keys:
  my_api_key_id: my_api_secret_hash_key
```
Generate random keys for production:
```bash
KEY=$(openssl rand -hex 16)
SECRET=$(openssl rand -hex 32)
echo "$KEY: $SECRET"
```
Ensure `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` are correctly configured in both the backend `.env` and `livekit.yaml`.

---

## 🎵 Music System (Sonic Drip)

Sonic Drip compiles music metadata from JioSaavn and YouTube. A WebView captures required cookies when a user authenticates, sending them to the backend to proxy search/stream requests. Lock screen controls interface with iOS/Android audio systems seamlessly.

---

## 🔒 End-to-End Encryption

Secure conversations are fully decentralized. Key exchanges are handled via X3DH, while ongoing encryption utilizes a Double Ratchet chain. Plaintext is never sent to or visible by the server; it remains strictly inside local secure keychains on the sender and receiver devices.

---

## 🗄️ Database & Migrations

Our Postgres instance contains 131+ structured migrations. Key migrations:
* `001-027`: Base tables (servers, channels, roles, voice state).
* `034`: Strict Row-Level Security (RLS) policies.
* `035`: DB functions to calculate 26-bit role permissions.
* `056-061`: WebRTC voice, video, screen share, and whiteboard states.
* `099`: Strict privacy filters (presence hiding, friend requirements).
* `131`: SQL optimizations for active channel participant tracking.

Run migrations against a live database:
```bash
supabase link --project-ref <your-ref>
supabase db push
```

---

## 🛡️ Security Checklist

Before taking your Flicko stack live:
- [ ] Rotate the default `flicko_livekit_key` and `flicko_livekit_secret` values.
- [ ] Generate a secure, 256-bit JWT secret.
- [ ] Verify that every user-facing table has Row-Level Security (RLS) enabled.
- [ ] Verify SSL certificates are active (Cloudflare Origin certs are recommended).
- [ ] Setup `fail2ban` for automated rate limit blocklisting.
- [ ] Confirm Razorpay webhook signature verification is enabled in `.env`.

---

## 📣 Marketing Website

Flicko includes a public-facing corporate website built with Next.js 15, Vercel ready, located inside `/web`.
To run locally:
```bash
cd web
bun install
bun run dev
```

---

## 🤝 Contributing

Contributions make the open-source community an amazing place. We welcome bug fixes, documentation improvements, and feature PRs.
* Ensure `flutter analyze` runs without errors before making mobile PRs.
* Make sure `go vet ./...` and `go test ./...` pass for backend modifications.
* Follow the [Conventional Commits](https://www.conventionalcommits.org/) standard.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  <img src="assets/branding/Flicko-for-black-background.png" alt="Flicko" width="48" height="48" />
  <br />
  <sub>Built with passion using Flutter, Go, Supabase, and LiveKit.</sub>
</p>
