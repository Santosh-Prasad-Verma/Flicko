# NGINX Configuration

> **Reading time:** ~5 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

Because Flicko is split into three microservices but presented externally as a single unified REST/WebSocket endpoint (`api.flicko.app`), NGINX is the critical edge router making this illusion possible.

---

## NGINX Docker Container

We run NGINX in its own lightweight Docker container defined within our `docker-compose.prod.yml`. It is the ONLY container with port mappings bridging the host network to the public internet.

```yaml
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/ssl/certs:ro
    depends_on:
      - backend
      - ws-gateway
      - msg-service
    networks:
      - flicko-internal
```

---

## 1. SSL/TLS Termination & Forwarding

The very first action NGINX performs is capturing HTTP traffic and permanently redirecting it to HTTPS.
The HTTPS Server Block handles SSL termination using Cloudflare Origin Certificates, after which all internal Docker network traffic between NGINX and the Go services occurs as unencrypted plaintext over the isolated Docker bridge network.

```nginx
server {
    listen 80;
    server_name api.flicko.app;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.flicko.app;

    ssl_certificate /etc/ssl/certs/cloudflare_origin.pem;
    ssl_certificate_key /etc/ssl/certs/cloudflare_origin.key;
    
    # Require strong cyphers required for Apple App Store compliance
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Standard proxy headers injected to inform Go of original client IP
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
```

---

## 2. Service Routing (The Split)

NGINX determines which Go container receives the traffic based on the URI path. 

### WebSocket Upgrades (`ws-gateway`)
NGINX correctly parses the HTTP Upgrade headers to establish the long-lived TCP connection needed for the Gateway.

```nginx
    location /api/v1/ws {
        proxy_pass http://ws-gateway:8081; # Uses Docker internal DNS name
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_read_timeout 86400s; # Prevent NGINX dropping long idle sockets
        proxy_send_timeout 86400s;
    }
```

### High-Throughput Routes (`msg-service`)
All POSTs to the message endpoint are intercepted and routed to the Batcher container.

```nginx
    location ~ ^/api/v1/channels/.*/messages/?$ {
        proxy_pass http://msg-service:8082;
        # Limits matching Go API logic to prevent buffer overflow attacks
        client_max_body_size 1M; 
    }
```

### The Fallback Monolith (`backend`)
Any route that does not match the WebSockets or Message path defaults to the monolith.

```nginx
    location /api/v1/ {
        proxy_pass http://backend:8080;
    }
}
```

---

## Security Headers

To further harden the API, NGINX injects strict browser security headers on all responses.

```nginx
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
```

With this configuration, your Flicko cluster is protected against basic DOS, ensures internal DNS resolution via Docker, and handles dynamic websocket upgrades perfectly.
