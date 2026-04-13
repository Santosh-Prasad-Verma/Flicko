# Security: Known Vulnerabilities & Mitigations

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Known Limitations

### 1. No End-to-End Encryption
**Status:** Not implemented
**Impact:** Server operators can read message content in the database.
**Mitigation:** TLS encrypts data in transit, AES-256-GCM encrypts sensitive data at rest. Full E2E encryption would require significant client-side key management.

### 2. CSRF Token Validation is Basic
**Status:** Implemented but simplified
**Impact:** The current CSRF implementation validates token presence and minimum length (≥16 chars) but does not bind tokens to server-side sessions.
**Mitigation:** All state-changing requests require the token, preventing the most common CSRF attack vectors. Full session-bound CSRF tokens are recommended for production hardening.

### 3. Rate Limiting is Per-IP
**Status:** Implemented at all layers
**Impact:** Shared IP addresses (corporate NAT, VPN) may hit rate limits collectively.
**Mitigation:** Generous limits (30 req/s API, 5 req/min auth) should accommodate shared IPs. Per-user rate limiting via Redis provides additional granularity.

### 4. Some RLS Policies Need Edge Case Review
**Status:** Identified in audit
**Impact:** Certain complex permission scenarios (deeply nested channel overwrites) may not be fully covered by RLS policies.
**Mitigation:** Application-layer authorization middleware provides a second layer of defense.

### 5. Development Mode Security
**Status:** By design
**Impact:** In development, the `ENCRYPTION_KEY` is auto-generated (ephemeral), and some security middleware is relaxed.
**Mitigation:** Production mode enforces all security requirements and will refuse to start with missing secrets.

---

## Dependency Vulnerability Management

**Go dependencies:** Managed via `go.mod` with checksums in `go.sum`. All direct dependencies are pinned to specific versions.

**npm dependencies:** `package-lock.json` ensures reproducible installs. Regular `npm audit` is recommended.

**Docker base images:** Alpine-based images are minimal by default. Regular base image updates are recommended.

---

## Related Docs
- [Security Overview](overview.md)
- [Authentication](authentication.md)
- [Authorization](authorization.md)
