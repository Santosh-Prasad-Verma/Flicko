# Security: Data Protection

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Encryption

### At Rest — AES-256-GCM
Sensitive data is encrypted before storage using AES-256-GCM authenticated encryption. The encryption key is configured via the `ENCRYPTION_KEY` environment variable (64 hex characters = 32 bytes).

**In production:** The key must be explicitly set. The backend will refuse to start without it.
**In development:** An ephemeral key is auto-generated on each startup with a warning log.

### In Transit — TLS Everywhere
| Connection | Encryption |
|-----------|-----------|
| Client ↔ Cloudflare | Cloudflare TLS (auto) |
| Cloudflare ↔ NGINX | Origin TLS (Cloudflare Origin Certificate) |
| NGINX ↔ Go services | Unencrypted (same-host Docker network) |
| Go services ↔ PostgreSQL | `sslmode=require` |
| Go services ↔ Redis | `rediss://` TLS (Upstash requirement) |

### Password Hashing
bcrypt with cost factor 10 (Supabase default). Server-side password validation ensures strength requirements are met before hashing.

---

## PII Data Handling

| Data Type | Storage | Protection |
|-----------|---------|-----------|
| Email addresses | PostgreSQL | RLS policies restrict access |
| Passwords | PostgreSQL | bcrypt hashed, never stored plaintext |
| IP addresses | Logs only | Redacted after 14 days (log rotation) |
| Message content | PostgreSQL | RLS policies, soft-delete support |
| Auth tokens | Redis | TTL-based auto-expiry |
| JWT private keys | Docker secrets | Never in container filesystem |

---

## Log Security

### Sensitive Header Redaction
File: `backend/internal/middleware/security.go` (lines 195-227)

Headers redacted from all log output:
- `Authorization` → `***REDACTED***`
- `X-API-Key` → `***REDACTED***`
- `X-Auth-Token` → `***REDACTED***`
- `Cookie` → `***REDACTED***`

### Log Retention
- Docker container logs: 14 days, max 100 MB per container
- NGINX access logs: 14 days, compressed
- Application logs: Forwarded to Loki, 30-day retention

---

## Related Docs
- [Security Overview](overview.md)
- [Deployment: Docker](../deployment/docker.md)
