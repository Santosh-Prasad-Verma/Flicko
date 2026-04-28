# Deployment Infrastructure Diagram

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Production Infrastructure

```mermaid
graph TB
    subgraph Internet["🌐 Internet"]
        USERS["👤 Mobile Users<br/>(iOS + Android)"]
        CLDFL["☁️ Cloudflare<br/>CDN + WAF + DDoS<br/>DNS: flicko.dev<br/>Origin TLS Certificates"]
    end

    subgraph VPS["🖥️ VPS (8 GB RAM, 2 vCPU)"]
        subgraph Docker["🐳 Docker Host"]

            subgraph NET1["📡 flicko_edge<br/>172.20.0.0/24"]
                NGX["🔀 NGINX 1.25<br/>Ports: 80, 443<br/>RAM: 128 MB<br/>CPU: 0.25"]
            end

            subgraph NET2["🔒 flicko_internal<br/>172.20.1.0/24<br/>(internal: true)"]
                WSG["⚡ ws-gateway<br/>Port: 8080<br/>RAM: 1 GB<br/>CPU: 1.0<br/>Max: 6K conns"]
                MSGS["📨 msg-service<br/>Port: 8081<br/>RAM: 512 MB<br/>CPU: 0.5<br/>Batch: 50 msg"]
                BACK["🤖 backend<br/>Port: 8080<br/>RAM: 512 MB<br/>CPU: 0.5<br/>8 bots"]
            end

            subgraph NET3["📊 flicko_monitor<br/>172.20.2.0/24<br/>(internal: true)"]
                PROM["📊 Prometheus<br/>RAM: 512 MB"]
                GRAF["📈 Grafana<br/>RAM: 256 MB"]
                LOKI["📋 Loki<br/>RAM: 512 MB"]
                NEXP["📡 Node Flutterrter<br/>RAM: 64 MB"]
                XEXP["📡 NGINX Flutterrter<br/>RAM: 32 MB"]
            end
        end

        F2B["🛡️ fail2ban<br/>SSH Protection"]
        UFW["🔥 UFW Firewall<br/>Allow: 80, 443, SSH"]
        SWAP["💾 2 GB Swap"]
    end

    subgraph Managed["☁️ Managed Services"]
        SUPA["🐘 Supabase<br/>PostgreSQL + Auth<br/>65 Migrations<br/>RLS Policies<br/>Edge Functions"]
        UPST["🔴 Upstash Redis<br/>TLS Encrypted<br/>Pub/Sub + Cache"]
        CLDY["☁️ Cloudinary<br/>Media CDN<br/>Signed Uploads"]
        LVKT["🎙️ LiveKit Cloud<br/>Voice/Video SFU<br/>Screen Sharing"]
    end

    USERS --> CLDFL
    CLDFL --> NGX

    NGX --> WSG
    NGX --> MSGS
    NGX --> BACK
    NGX --> GRAF

    WSG --> SUPA
    WSG --> UPST
    MSGS --> SUPA
    MSGS --> UPST
    MSGS --> CLDY
    BACK --> SUPA
    BACK --> UPST

    PROM --> WSG
    PROM --> MSGS
    PROM --> NEXP
    PROM --> XEXP
    GRAF --> PROM
    GRAF --> LOKI
```

## Resource Budget

```
Total VPS RAM: 8,192 MB
────────────────────────────────────────
Container Allocation:
  NGINX .............. 128 MB
  ws-gateway ........ 1,024 MB
  msg-service ....... 512 MB
  backend ........... 512 MB
  Prometheus ........ 512 MB
  Grafana ........... 256 MB
  Loki .............. 512 MB
  Node Flutterrter ..... 64 MB
  NGINX Flutterrter .... 32 MB
────────────────────────────────────────
  Total Containers: 3,552 MB (~3.5 GB)
  OS + Buffers:     4,640 MB (~4.5 GB)
────────────────────────────────────────
```
