# Rate Limiting
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Three-Tier Rate Limiting

### Layer 0: Cloudflare (Edge)
- DDoS protection at the network edge
- WAF rules for known attack patterns
- Browser challenges for suspicious traffic

### Layer 1: NGINX (Per-IP)
Defined in `nginx/nginx.conf`:

| Zone | Rate | Burst | Scope |
|------|------|-------|-------|
| `api_limit` | 30 req/s | Default | General API endpoints |
| `ws_limit` | 5 req/s | Default | WebSocket upgrade requests |
| `upload_limit` | 2 req/s | Default | Upload presign requests |
| `auth_limit` | 5 req/min | Default | Login/register/refresh |
| `conn_limit` | Per config | — | Per-IP connection limit |

### Layer 2: Redis (Per-User, Distributed)
Defined in `backend/internal/middleware/distributed_ratelimit.go`:

| Limiter | Rate | Scope |
|---------|------|-------|
| API limiter | 50 req/s per IP | All API routes |
| WebSocket | 10 msg/s + burst 20 | Per-connection message rate |

### Response
When rate limited, the server returns:
```
HTTP/1.1 429 Too Many Requests
Retry-After: <seconds>
```

## Related Docs
- [API Overview](api-overview.md)
- [NGINX Configuration](../deployment/docker.md)
