# Security Overview

> **Reading time:** ~5 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

Security in Flicko is modeled using a "Defense in Depth" strategy. We do not trust any single layer of the stack to prevent an attack. Instead, every boundary explicitly checks and limits what it passes down.

---

## The 4-Layer Perimeter

An incoming malicious request attempting an SQL Injection on the Flicko API must survive four distinct perimeters before reaching the database.

1. **The Edge (Cloudflare)**: Cloudflare WAF drops payloads violating known OWASP signatures, enforcing SSL negotiation, and blocking known botnet IPs immediately.
2. **The Reverse Proxy (NGINX)**: NGINX enforces hard limits on maximum body size (`client_max_body_size`) preventing payload allocation attacks, strips arbitrary headers to prevent IP spoofing, and enforces the Redis rate-limiting keys.
3. **The Application Layer (Go Middleware)**: The Go API rejects undocumented URL fields, verifies the cryptographic signature of the JWT, and fails fast if CSRF headers are missing.
4. **The Database Layer (PostgreSQL)**: Because the Go backend utilizes `pgx` with strictly parameterized queries (`$1`, `$2`), the malicious string is evaluated entirely as data, never as executable SQL.

---

## Attack Vector Mitigations

### 1. Cross-Site Scripting (XSS)
- **Prevention:** Flutter handles text safely natively (there is no DOM). 
- **Prevention:** Any web interfaces receive `X-XSS-Protection: 1; mode=block` headers.

### 2. Denial of Service (DoS/DDoS)
- **Prevention:** Cloudflare `Under Attack` mode. 
- **Prevention:** Distributed Sliding-Window Rate limiting via Upstash Redis.
- **Prevention:** The Batch Insertion Engine in `msg-service` acts as a shock absorber. Even if 10,000 requests hit it, it only triggers one massive SQL constraint, protecting database connections from pool exhaustion.

### 3. Enumeration Attacks
- **Prevention:** Generic errors. If an attacker attempts to guess a hidden channel UUID, the API returns `404 Not Found` rather than `403 Forbidden` (`403` implies the channel exists, allowing them to map invisible layouts).
- **Prevention:** Postgres UUIDv4 identifiers are cryptographically random and cannot be brute-forced or iterated sequentially like auto-incrementing integer IDs (`/user/1`, `/user/2`).

### 4. Cross-Site Request Forgery (CSRF)
- **Prevention:** All API mutations (`POST`, `PUT`, `PATCH`, `DELETE`) strictly require a custom `X-CSRF-Token` header. Because browsers cannot attach custom headers to cross-site `<form>` submissions, the middleware ensures the request intentionally originated from our code.

---

Explore deeply into specific security subsystems:
- [Authorization & RBAC](authorization.md)
- [Middleware Defense Pipeline](middleware.md)
- [Rate Limiting](rate-limiting.md)
- [Data Privacy & GDPR](data-privacy.md)
