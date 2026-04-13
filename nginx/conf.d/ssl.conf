# =============================================================================
# Flicko — SSL/TLS Settings
# =============================================================================
#
# Included by the HTTPS server block in flicko.conf:
#   include /etc/nginx/conf.d/ssl.conf;
#
# This config is designed for Cloudflare Full (Strict) mode:
#   Browser ──[public TLS]──▶ Cloudflare edge ──[origin TLS]──▶ NGINX
#
# The certificate is a Cloudflare Origin Certificate (15-year validity,
# trusted only by CF edge, NOT by browsers directly).
#
# If you switch to Let's Encrypt (browser-trusted), enable the OCSP
# stapling directives at the bottom.
# =============================================================================

# ── Certificate Paths ───────────────────────────────────────────────────────
# Mounted read-only in docker-compose.yml:
#   ./nginx/ssl/origin.pem     → /etc/nginx/ssl/origin.pem
#   ./nginx/ssl/origin-key.pem → /etc/nginx/ssl/origin-key.pem
#
# Generate via: Cloudflare Dashboard → SSL/TLS → Origin Server → Create Certificate
# Choose: ECDSA P-256 (smaller, faster) or RSA 2048. Validity: 15 years.
ssl_certificate      /etc/nginx/ssl/origin.pem;
ssl_certificate_key  /etc/nginx/ssl/origin-key.pem;

# ── Protocol Versions ───────────────────────────────────────────────────────
# TLSv1.0 and TLSv1.1 are deprecated (RFC 8996). Only allow:
#   TLSv1.2 — broad client compatibility (Android 5+, iOS 9+)
#   TLSv1.3 — zero-RTT, perfect forward secrecy by design
ssl_protocols  TLSv1.2 TLSv1.3;

# ── Cipher Suite ────────────────────────────────────────────────────────────
# Modern cipher list prioritizing:
#   1. ECDHE key exchange (perfect forward secrecy)
#   2. AES-GCM authenticated encryption (hardware-accelerated on most CPUs)
#   3. ChaCha20-Poly1305 (fast on mobile ARM without AES-NI)
#   4. SHA-256/384 for PRF
#
# TLSv1.3 ciphers are not configurable via ssl_ciphers (they're fixed in
# the spec: AES-128-GCM-SHA256, AES-256-GCM-SHA384, ChaCha20-Poly1305).
# This list controls TLSv1.2 cipher negotiation only.
ssl_ciphers  ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;

# Let the server choose the cipher, not the client. Prevents downgrade
# attacks where a client requests a weak cipher the server also supports.
ssl_prefer_server_ciphers  on;

# ── ECDH Curve ──────────────────────────────────────────────────────────────
# Use X25519 (fastest, smallest) as primary, P-256 as fallback.
# secp384r1 is included for compliance environments that require it.
ssl_ecdh_curve  X25519:prime256v1:secp384r1;

# ── Session Cache ───────────────────────────────────────────────────────────
# Shared session cache across all workers. Avoids a full TLS handshake on
# reconnection — the client presents a session ID and the server looks it up.
#
# 10 MB ≈ 40,000 sessions (each ~256 bytes). At 5k CCU with ~15 min
# reconnection interval this is more than enough.
ssl_session_cache    shared:SSL:10m;

# Sessions are valid for 4 hours. Longer than the default 5 min, but shorter
# than 24 h to limit the window if a session key is compromised.
ssl_session_timeout  4h;

# ── Session Tickets ─────────────────────────────────────────────────────────
# Session tickets encrypt the session state into a ticket sent to the client.
# The problem: the ticket encryption key is shared across workers and does NOT
# rotate automatically, which breaks Perfect Forward Secrecy (PFS).
#
# Disabled. We rely on the session cache (above) for resumption instead.
# This is the recommended setting for PFS compliance.
ssl_session_tickets  off;

# ── Diffie-Hellman Parameters ───────────────────────────────────────────────
# Only needed if using DHE ciphers (we prefer ECDHE, but this is defense
# in depth). Generate with: openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
# Uncomment if the file exists.
# ssl_dhparam  /etc/nginx/ssl/dhparam.pem;

# ── OCSP Stapling ──────────────────────────────────────────────────────────
# OCSP stapling attaches the certificate's revocation status to the TLS
# handshake, so the client doesn't need to query the CA's OCSP responder.
#
# NOTE: Cloudflare Origin Certificates do NOT support OCSP stapling because
# they're signed by a private CA (Cloudflare Origin CA) that doesn't publish
# OCSP responders. These directives are commented out.
#
# If you switch to Let's Encrypt or another public CA, uncomment these:
#
# ssl_stapling         on;
# ssl_stapling_verify  on;
# ssl_trusted_certificate /etc/nginx/ssl/origin-ca.pem;   # CA chain
# resolver  1.1.1.1 1.0.0.1 [2606:4700:4700::1111] [2606:4700:4700::1001]
#           valid=300s;
# resolver_timeout  5s;
