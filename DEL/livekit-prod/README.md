# Production Deployment Guide: Self-Hosted LiveKit (Option B)

This directory contains the production-ready deployment bundle for self-hosting a LiveKit server using **Docker Compose**, **Redis**, and **Caddy** (for automatic Let's Encrypt SSL/TLS).

---

## 1. Prerequisites

Before starting, you must have:
1. **A Cloud VM** (AWS EC2, GCP Compute Engine, DigitalOcean Droplet, Linode, etc.) running Linux (Ubuntu/Debian/Rocky/AL2) with Docker and Docker Compose installed.
2. **A Public IP Address** for your Cloud VM.
3. **A Domain Name** with the following DNS records pointing to your VM's public IP address:
   - **`livekit.yourdomain.com`** (A Record) -> VM Public IP (For client API / WebSocket signaling)
   - **`turn.yourdomain.com`** (A Record) -> VM Public IP (For WebRTC TURN/TLS relay fallback)

---

## 2. Firewall Port Configuration

You **MUST** open the following ports on your cloud provider's firewall / Security Groups:

| Port | Protocol | Service | Description |
|---|---|---|---|
| **`80`** | TCP | HTTP | Let's Encrypt HTTP-01 challenge verification |
| **`443`** | TCP / UDP | HTTPS | Client signaling connections (HTTPS & WSS) |
| **`7881`** | TCP | WebRTC TCP | Fallback for clients behind strict firewalls |
| **`3478`** | UDP | TURN UDP | UDP media relay server |
| **`5349`** | TCP | TURN TLS | TLS-encrypted media relay server |
| **`50000 - 60000`** | UDP | WebRTC Media | Direct peer-to-peer audio/video streams |

---

## 3. Deployment Steps

### Step 1: Copy Configuration to the VM
Copy this entire folder (`livekit-prod/`) to your target cloud VM (e.g., to `/opt/livekit` or `~/livekit`).

```bash
scp -r livekit-prod/ user@your-vm-ip:~/livekit
```

### Step 2: Configure Your Domain Names
SSH into your cloud VM, navigate to the `livekit` directory, and update the domain placeholders:

1. **`Caddyfile`**: Replace `livekit.yourdomain.com` and `turn.yourdomain.com` with your subdomains.
2. **`livekit.yaml`**:
   - Update `turn.domain` with your TURN subdomain (e.g., `turn.yourdomain.com`).
   - Change the paths under `cert_file` and `key_file` to match your domain name.
   - Generate secure API keys/secrets and update the `keys:` block.

### Step 3: Run the Stack
Start the containers in detached (background) mode:

```bash
docker compose up -d
```

### Step 4: Verify Deployment
Verify that the services started successfully:

```bash
docker compose ps
docker compose logs -f
```

Look for a message in the Caddy logs indicating that the certificates were successfully obtained:
```text
certificate obtained successfully {"identifier": "livekit.yourdomain.com"}
certificate obtained successfully {"identifier": "turn.yourdomain.com"}
```

---

## 4. Connecting Your Flicko App

To connect your Flicko Flutter application or backend services to your new self-hosted LiveKit server, update your `.env` (or environment variables) config:

```env
# LiveKit Server Configuration
LIVEKIT_URL=wss://livekit.yourdomain.com
LIVEKIT_API_KEY=API_Flicko_LiveKit_Prod
LIVEKIT_API_SECRET=FS_LiveKit_Prod_Secure_Secret_Token_Change_Me_789456
```
