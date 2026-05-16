# FLICKO TECHNICAL AUDIT REPORT

**Date:** January 15, 2025  
**Auditor:** Cascade AI  
**Project:** Flicko - Discord-like Chat Application  
**Version:** 1.0.0

---

## SECTION 1 — CODE QUALITY AUDIT

### Feature Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Backend (Bot Framework)** | ⚠️ Partially Broken | Bot auth middleware uses hardcoded mock values |
| **Message Service** | ✅ Working | REST API handlers functional, batch insertion implemented |
| **WebSocket Gateway** | ✅ Working | Connection management, pub/sub, presence tracking functional |
| **Mobile App** | ⚠️ Partially Broken | Many TODO comments, spike screens in production, incomplete features |
| **Database Schema** | ✅ Working | Comprehensive RLS policies, permission functions |
| **Authentication** | ✅ Working | Ed25519 JWT with key rotation, but bot auth is mocked |

### Code Logic Correctness

**🔴 Critical Issues:**

1. **Bot Authentication Mock Implementation** (`backend/internal/handlers/middleware.go` lines 37-39)
   - **Problem:** Hardcoded mock values instead of database lookup
   - **Root Cause:** Commented pseudo-code at lines 34-35, actual implementation uses static values
   - **Recommended Fix:** Implement actual database query to validate bot API keys
   - **Priority:** 🔴 Critical - Security vulnerability

2. **No Test Coverage**
   - **Problem:** Zero `_test.go` files found in backend and services despite documentation claiming "45 Go unit test suites"
   - **Root Cause:** Tests not implemented or removed
   - **Recommended Fix:** Implement comprehensive test suite for all critical paths
   - **Priority:** 🔴 Critical - Production risk

**🟡 Medium Issues:**

3. **AutoMod Permission Check** (`backend/internal/bots/automod.go` lines 333-341)
   - **Problem:** N+1 query pattern in exemption check
   - **Root Cause:** Loops through roles array and executes query for each
   - **Recommended Fix:** Use `ANY($3::uuid[])` with single query (already partially done)
   - **Priority:** 🟡 Medium - Performance under load

4. **Mobile TODO Comments** (Multiple files)
   - **Problem:** 20+ TODO comments indicating incomplete features
   - **Root Cause:** Features marked as implemented but not completed
   - **Recommended Fix:** Complete features or remove TODO comments
   - **Priority:** 🟡 Medium - Feature parity gap

### Code Reusability

**Good Patterns:**
- Shared auth package (`services/shared/auth`) with JWT validation used across services
- Common middleware patterns in backend
- Repository pattern in msg-service

**Missing Abstractions:**
- No shared error handling utilities across services
- Duplicate rate limiting implementations (NGINX layer + Go middleware + Redis)
- No shared logging configuration patterns

### Code Quality

**Anti-Patterns Found:**
1. **Hardcoded mock values** in production code (middleware.go)
2. **Development spike screens** in mobile app production build (`features/spike/`)
3. **Commented-out pseudo-code** left in production files (middleware.go lines 34-35)
4. **Mixed concerns** - AutoMod bot directly executes SQL without service layer

**Naming Issues:**
- Generally good naming conventions
- Some inconsistent use of `server_id` vs `guild_id` in database vs code

**Nesting:**
- Acceptable depth in most handlers
- Some deeply nested conditional logic in permission calculation functions

**SOLID/DRY Violations:**
- AutoMod bot violates Single Responsibility (handles UI commands + moderation logic + SQL)
- Duplicate rate limiting logic across layers

### Test Coverage

| Component | Test Files | Coverage | Risk Level |
|-----------|------------|----------|------------|
| Backend (Go) | 0 | 0% | 🔴 Critical |
| Msg Service (Go) | 0 | 0% | 🔴 Critical |
| WS Gateway (Go) | 0 | 0% | 🔴 Critical |
| Mobile (Flutter) | 0 | 0% | 🔴 Critical |
| Shared Services (Go) | 0 | 0% | 🔴 Critical |

**Highest-Risk Untested Paths:**
1. JWT validation and key rotation
2. Permission calculation (complex bitwise operations)
3. Rate limiting logic
4. WebSocket connection lifecycle
5. Message batching and dead letter queue
6. Bot authentication (currently mocked - would fail if implemented)

---

## SECTION 2 — PRODUCTION READINESS ASSESSMENT

### Overall Production Readiness Score: **3/10**

**Justification:** While infrastructure is well-designed, critical security vulnerabilities, zero test coverage, and incomplete features make this unsuitable for production deployment.

### Features That WILL Break in Production

| Feature | Failure Mode | Root Cause |
|---------|--------------|------------|
| **Bot API Authentication** | All bot requests will fail or accept invalid tokens | Hardcoded mock values in middleware.go |
| **Mobile Premium Features** | Stripe payments will fail | Hardcoded test secret in spike screen |
| **AutoMod Exemptions** | Performance degradation under load | N+1 query pattern with many roles |
| **Any Code Changes** | No regression testing | Zero test coverage across entire codebase |
| **Server Discovery** | Pagination issues | TODO comment in discovery_handler.go line 44 |
| **Server Insights** | Performance issues | TODO comment in discovery_handler.go line 73 |

### Single Points of Failure

1. **Single VPS Architecture** - All services on one 8GB VPS
   - **Mitigation:** Documented horizontal scaling paths, but not implemented
   - **Priority:** 🟡 Medium - Acceptable for MVP

2. **Upstash Redis** - Single point for pub/sub, rate limiting, presence
   - **Mitigation:** Upstash provides high availability, but no fallback
   - **Priority:** 🟡 Medium - Cloud provider reliability

3. **Supabase PostgreSQL** - Single database instance
   - **Mitigation:** Supabase handles backups, but no read replica
   - **Priority:** 🟡 Medium - Acceptable for MVP

### Missing Error Handling

1. **Unhandled Promise Rejections** - Mobile app async operations lack try-catch in several places
2. **Missing Error Context** - Some error responses don't include request IDs for debugging
3. **No Circuit Breakers** - Services will retry failing requests indefinitely
4. **Missing Timeout Context** - Some database queries lack explicit timeouts

### Load Behavior Assessment

| Metric | Current Capacity | Expected Behavior | Risk |
|--------|------------------|-------------------|------|
| **Concurrent Users** | 3,000-5,000 (designed) | WebSocket connections may exhaust file descriptors | 🟡 Medium |
| **Message Volume** | Unknown (no load testing) | Batch insertion should handle moderate load | 🔴 Critical - untested |
| **File Uploads** | Cloudinary (external) | Should scale, but presigned URL generation not rate-limited per-user | 🟡 Medium |
| **Database Queries** | Connection pool: 20 | May exhaust under high concurrency with N+1 queries | 🟠 High |

### Memory Leaks & Blocking Operations

**Potential Issues:**
1. **WebSocket Connection Cleanup** - No evidence of goroutine leaks, but untested
2. **Message Batcher** - Has drain timeout, but memory growth under backpressure untested
3. **AutoMod Regex Compilation** - Compiled at package init (good), but many regexes could slow cold start
4. **Mobile Image Handling** - No evidence of memory cleanup in image picker code

### Prioritized Fix List

**Must Fix Before Go-Live (🔴 Critical):**
1. Implement actual bot authentication with database lookup
2. Remove hardcoded Stripe test secret
3. Implement comprehensive test suite (minimum: auth, permissions, message flow)
4. Remove development spike screens from mobile production build
5. Fix N+1 query in AutoMod exemption check

**Should Fix Soon (🟠 High):**
6. Add request IDs to all error responses
7. Implement circuit breakers for external service calls
8. Add database query timeouts
9. Complete mobile TODO features or remove from UI
10. Add integration tests for WebSocket message flow

**Can Wait (🟡 Medium):**
11. Implement read replicas for database
12. Add distributed tracing
13. Optimize AutoMod regex compilation
14. Add per-user rate limiting for file upload presigned URLs

---

## SECTION 3 — SCALABILITY & INFRASTRUCTURE

### Estimated Max Concurrent Users

| Component | Current Limit | Bottleneck | Scaling Path |
|-----------|---------------|------------|--------------|
| **WebSocket Connections** | ~5,000 | File descriptors (65536 limit) | Add more gateway instances with load balancer |
| **HTTP API** | ~10,000 req/s | NGINX + Go workers | Horizontal scaling of msg-service |
| **Database** | ~2,000 active connections | Connection pool (20) | Increase pool size, add read replicas |
| **Redis Pub/Sub** | Unknown | Upstash limits | Upgrade to higher tier |

### Bottlenecks

1. **Database Connection Pool** (20 connections)
   - **Impact:** Will exhaust under high concurrent user load
   - **Fix:** Increase to 50-100, implement connection pooling per service

2. **Single WebSocket Gateway Instance**
   - **Impact:** File descriptor limit at ~5,000 connections
   - **Fix:** Horizontal scaling with sticky sessions (ip_hash already configured in nginx)

3. **N+1 Queries in Permission System**
   - **Impact:** Every permission check may trigger multiple queries
   - **Fix:** Materialized views for member roles, caching of permission results

4. **No CDN for Static Assets**
   - **Impact:** Mobile app downloads directly from Appwrite/Cloudinary
   - **Fix:** Add Cloudflare CDN in front of storage

### Horizontal Scaling Strategy

**Current State:** Single 8GB VPS with Docker Compose

**Recommended Scaling Path:**

1. **WebSocket Gateway** (Stateful)
   - Use `ip_hash` in NGINX (already configured)
   - Add Redis for cross-gateway presence synchronization
   - Each gateway instance handles subset of users

2. **Message Service** (Stateless)
   - Use `least_conn` load balancing (already configured)
   - Scale horizontally behind NGINX
   - Shared database and Redis

3. **Backend Service** (Stateless)
   - Scale horizontally behind NGINX
   - Shared database and Redis

4. **Database**
   - Add read replicas for read-heavy operations
   - Use connection pooling (PgBouncer) if needed

5. **Session Management**
   - JWT tokens are stateless (good)
   - Presence stored in Redis (shared across gateways)

### Caching Strategy

**Current Implementation:**
- Redis for rate limiting
- Redis for pub/sub
- Redis for presence tracking
- No application-level caching

**Recommended Additions:**

| Cache Type | Use Case | TTL | Implementation |
|------------|----------|-----|----------------|
| **User Profile Cache** | Frequent profile lookups | 5 min | Redis hash |
| **Permission Cache** | Permission checks | 10 min | Redis, invalidate on role change |
| **Channel Metadata Cache** | Channel info lookups | 15 min | Redis |
| **Message Cache** | Recent messages (hot channels) | 1 min | Redis sorted sets |
| **CDN** | Static assets, app downloads | N/A | Cloudflare |

### Message Queue Implementation

**Current State:** No message queue - direct Redis pub/sub

**Recommended Implementation:**

**Option 1: Redis Streams (Simplest)**
- Use Redis Streams for async workloads
- Consumer groups for reliability
- Pros: No new infrastructure, already using Redis
- Cons: Limited features compared to dedicated MQ

**Option 2: RabbitMQ (Recommended for Production)**
- Use for: Email sending, notifications, audit log processing
- Pros: Mature, reliable, good tooling
- Cons: Additional infrastructure to manage

**Option 3: Cloud-Managed (Zero-Cost Alternative)**
- AWS SQS (free tier: 1M requests/month)
- Google Cloud Pub/Sub (free tier: 10GB/month)
- Pros: Managed, scales automatically
- Cons: Vendor lock-in

### Discord-Like Infrastructure Roadmap

**Phase 1: Current (MVP)**
- Single 8GB VPS
- Docker Compose deployment
- Upstash Redis
- Supabase PostgreSQL
- Cloudinary storage
- LiveKit Cloud for voice

**Phase 2: Horizontal Scaling (1,000-10,000 users)**
- Add second gateway instance
- Increase database connection pools
- Implement Redis caching layer
- Add Cloudflare CDN
- Estimated cost: $20-50/month

**Phase 3: Multi-Region (10,000-100,000 users)**
- Multiple VPS instances per region
- Database read replicas
- Dedicated message queue (RabbitMQ)
- Load balancer (HAProxy or cloud LB)
- Estimated cost: $200-500/month

**Phase 4: Cloud-Native (100,000+ users)**
- Kubernetes cluster
- Managed databases (Supabase Pro or RDS)
- Managed Redis (ElastiCache or Upstash Pro)
- CDN with edge computing
- Estimated cost: $1,000+/month

---

## SECTION 4 — SECURITY AUDIT

### Current Security Posture: **4/10**

**Specific Vulnerabilities:**

🔴 **Critical:**
1. **Bot Authentication Bypass** - Hardcoded mock values allow any token with "flicko_bot_" prefix
2. **Exposed Test Secret** - Stripe test secret in mobile app code
3. **Zero Test Coverage** - No security tests, unable to verify auth flows

🟠 **High:**
4. **No Input Validation** - AutoMod regexes but no general input sanitization in some handlers
5. **Missing Rate Limiting** - Some endpoints lack per-user rate limiting (only IP-based)
6. **No CSRF Protection** - Documented but implementation unclear in mobile app

🟡 **Medium:**
7. **Error Information Leakage** - Some error messages may leak internal details
8. **No API Key Rotation** - Bot API keys have no rotation mechanism
9. **No Request Signing** - Webhooks lack signature verification (HMAC code exists but not integrated)

### SQL/NoSQL Injection

**Assessment:** ✅ Low Risk

- Using parameterized queries with pgx (Go)
- Supabase RLS policies provide additional protection
- No raw SQL string concatenation found in reviewed code

**Recommendation:** Add automated SQL injection testing to CI/CD

### XSS (Cross-Site Scripting)

**Assessment:** ✅ Low Risk

- Flutter's native text rendering prevents XSS
- NGINX has X-XSS-Protection headers
- Input sanitization middleware documented but implementation unclear

**Recommendation:** Verify input sanitization middleware is applied to all user content endpoints

### CSRF (Cross-Site Request Forgery)

**Assessment:** ⚠️ Medium Risk

- CSRF middleware documented in backend
- X-CSRF-Token header required for mutations
- **Ambiguity:** Mobile app usage unclear - does it implement CSRF tokens?

**Recommendation:** Verify mobile app implements CSRF token flow, document exemption for native apps

### Broken Authentication

**Assessment:** 🟠 High Risk

**Issues:**
1. **Bot authentication completely broken** (mock implementation)
2. **No account lockout** for failed login attempts visible in code
3. **No password complexity enforcement** in backend (only 6-char minimum in mobile)

**Strengths:**
1. **Ed25519 JWT** with key rotation support
2. **15-minute access token TTL** (good)
3. **30-day refresh token TTL** stored in Redis (good)
4. **Device ID tracking** for session management

### Insecure Direct Object References (IDOR)

**Assessment:** ✅ Low Risk

- UUIDv4 IDs prevent enumeration
- RLS policies enforce row-level access
- Permission checks before resource access

**Recommendation:** Add automated IDOR testing

### Exposed Secrets

**🔴 Critical Findings:**
1. **Stripe test secret** in `mobile/lib/features/spike/stripe_spike_screen.dart:51`
   - `pi_test_123456_secret_123456`
   - Should be in environment variables

2. **Bot auth mock values** in `backend/internal/handlers/middleware.go:37-39`
   - Hardcoded bcrypt hash and prefix
   - Should query database

**Recommendation:** Scan codebase with `trufflehog` or `gitleaks` before every commit

### Authentication & Authorization Audit

**JWT Implementation:** ✅ Solid
- Ed25519 (EdDSA) signing method
- Key rotation support with KeySet
- kid header for key selection
- Proper expiration enforcement

**Authorization:** ⚠️ Partial
- Bitwise permission system implemented
- RLS policies in database
- **Gap:** Some handlers lack explicit permission checks
- **Gap:** Bot auth completely bypassed

**Rate Limiting:** ⚠️ Partial
- NGINX IP-based rate limits (good)
- Redis-backed distributed rate limiter in Go (good)
- **Gap:** Not all endpoints have rate limiting applied
- **Gap:** No per-user rate limiting (only per-IP)

### API Endpoint Security Review

| Endpoint | Auth | Rate Limit | Input Validation | Error Exposure |
|----------|------|------------|------------------|----------------|
| `POST /api/v1/channels/{id}/messages` | ✅ JWT | ✅ Redis | ⚠️ Basic | ⚠️ May leak details |
| `GET /api/v1/servers/discover` | ✅ JWT | ✅ Redis | ✅ | ✅ Generic |
| `POST /api/v1/bots` | ⚠️ Bot Auth (BROKEN) | ✅ Redis | ⚠️ Basic | ⚠️ May leak details |
| `POST /bot-api/messages/{id}` | ⚠️ Bot Auth (BROKEN) | ✅ Redis | ⚠️ Basic | ⚠️ May leak details |

### Step-by-Step Security Hardening Plan

**🔴 Critical (Fix Immediately):**
1. **Implement actual bot authentication**
   - Remove hardcoded values from middleware.go
   - Add database query to validate bot API keys
   - Add bcrypt comparison for secret verification
   - Add scope checking
   - **Time estimate:** 4 hours

2. **Remove hardcoded Stripe secret**
   - Move to environment variables
   - Add to .env.example
   - Rotate the leaked secret
   - **Time estimate:** 1 hour

3. **Add security testing to CI/CD**
   - Add `trufflehog` scan
   - Add basic auth flow tests
   - Add permission check tests
   - **Time estimate:** 8 hours

**🟠 High (Fix This Week):**
4. **Implement account lockout**
   - Add failed attempt tracking in Redis
   - Lock account after 5 failed attempts (15 min)
   - Add unlock via email
   - **Time estimate:** 6 hours

5. **Add comprehensive rate limiting**
   - Ensure all endpoints have rate limiting
   - Add per-user rate limiting for sensitive operations
   - Add rate limiting for presigned URL generation
   - **Time estimate:** 4 hours

6. **Implement webhook signature verification**
   - HMAC code already exists in `backend/internal/bots/auth/hmac.go`
   - Integrate into webhook handlers
   - **Time estimate:** 3 hours

**🟡 Medium (Fix This Month):**
7. **Add password complexity requirements**
   - Minimum 12 characters
   - Require uppercase, lowercase, number, special char
   - Implement in backend validation
   - **Time estimate:** 2 hours

8. **Add API key rotation for bots**
   - Add rotation endpoint
   - Support multiple active keys during rotation
   - **Time estimate:** 6 hours

9. **Implement security headers**
   - Content-Security-Policy
   - X-Frame-Options
   - Strict-Transport-Security
   - **Time estimate:** 2 hours

**🟢 Low (Fix Next Quarter):**
10. **Add security audit logging**
    - Log all auth failures
    - Log permission denials
    - Log suspicious patterns
    - **Time estimate:** 8 hours

### End-to-End Encryption (E2EE) Implementation

**Recommended Approach: Signal Protocol**

**Library:** `libsignal-protocol-java` (via FFI) or `double-ratchet-ffi` for Dart

**Protocol:** Signal Protocol (Double Ratchet + X3DH)

**Implementation Steps:**

1. **Key Management**
   - Generate long-term identity keys per user
   - Generate signed prekeys
   - Upload to server (encrypted at rest)
   - **Time estimate:** 16 hours

2. **X3DH Key Exchange**
   - Implement initial key exchange for DM sessions
   - Server only acts as key directory
   - **Time estimate:** 12 hours

3. **Double Ratchet**
   - Implement message encryption/decryption
   - Handle ratchet updates
   - **Time estimate:** 24 hours

4. **Integration**
   - Add encryption toggle to DM UI
   - Encrypt message content before sending
   - Decrypt on receive
   - Store encrypted content in database
   - **Time estimate:** 16 hours

5. **Testing & Validation**
   - Test key rotation
   - Test session recovery
   - Test multi-device sync
   - **Time estimate:** 16 hours

**Total Time Estimate:** ~84 hours (2-3 weeks)

**Alternative:** Use Matrix's Olm library (simpler but less audited)

**Breaking Changes:**
- Existing DMs would remain unencrypted
- New encrypted DMs would require both participants to support E2EE
- Message search would need to be client-side only for encrypted messages

---

## SECTION 5 — DISCORD FEATURE PARITY ANALYSIS

### Core Discord Features Status

| Feature | Status | Complexity | Recommended Approach |
|---------|--------|------------|----------------------|
| **Text Channels** | ✅ Implemented | - | - |
| **Voice Channels** | ✅ Implemented | - | - |
| **Server/Guild Creation** | ✅ Implemented | - | - |
| **Roles & Permissions** | ✅ Implemented | - | - |
| **Direct Messages** | ✅ Implemented | - | - |
| **Message Reactions** | ✅ Implemented | - | - |
| **Message Editing** | ✅ Implemented | - | - |
| **Message Deletion** | ✅ Implemented | - | - |
| **File Attachments** | ✅ Implemented | - | - |
| **User Profiles** | ✅ Implemented | - | - |
| **Friend System** | ✅ Implemented | - | - |
| **Server Invites** | ✅ Implemented | - | - |
| **Read Receipts** | ✅ Implemented | - | - |
| **Typing Indicators** | ✅ Implemented | - | - |
| **Presence Status** | ✅ Implemented | - | - |
| **Slash Commands** | ✅ Implemented | - | - |
| **Bot Framework** | ⚠️ Partial | Medium | Fix bot auth, add webhook support |
| **AutoMod** | ✅ Implemented | - | - |
| **Welcome Bot** | ✅ Implemented | - | - |
| **Leveling System** | ✅ Implemented | - | - |
| **Music Bot** | ✅ Implemented | - | - |
| **Ticket System** | ✅ Implemented | - | - |
| **Polls** | ✅ Implemented | - | - |
| **Starboard** | ✅ Implemented | - | - |
| **Threads** | ⚠️ Partial | Medium | Complete UI, add thread-specific permissions |
| **Pinned Messages** | ✅ Implemented | - | - |
| **Message Search** | ❌ Missing | Hard | Implement full-text search (PostgreSQL FTS or external) |
| **Screen Sharing** | ⚠️ Partial | Medium | Complete mobile implementation |
| **Video Calls** | ✅ Implemented | - | - |
| **Go Live** | ⚠️ Partial | Medium | Complete activity integration |
| **Stage Channels** | ⚠️ Partial | Medium | Complete raise-hand, speaker management |
| **Voice Activity Detection** | ❌ Missing | Hard | Integrate with LiveKit or WebRTC VAD |
| **Server Boosting** | ⚠️ Partial | Medium | Complete premium integration |
| **Nitro/Premium** | ⚠️ Partial | Medium | Complete payment flow, feature gating |
| **Custom Emojis** | ⚠️ Partial | Easy | Complete UI, add emoji picker |
| **Stickers** | ⚠️ Partial | Easy | Complete UI, add sticker picker |
| **Server Discovery** | ✅ Implemented | - | - |
| **Trending Servers** | ✅ Implemented | - | - |
| **Server Templates** | ⚠️ Partial | Medium | Complete template creation/import |
| **Audit Logs** | ✅ Implemented | - | - |
| **Mod Actions (Ban/Kick/Timeout)** | ✅ Implemented | - | - |
| **Message Purge** | ✅ Implemented | - | - |
| **2FA/MFA** | ✅ Implemented | - | - |
| **Trusted Devices** | ⚠️ Partial | Medium | Complete device management UI |
| **Login History** | ✅ Implemented | - | - |
| **Account Export (GDPR)** | ⚠️ Partial | Medium | Complete async export job |
| **Account Deletion** | ⚠️ Partial | Medium | Complete async deletion job |
| **Reaction Roles** | ✅ Implemented | - | - |
| **Member Screening** | ✅ Implemented | - | - |
| **Forum Channels** | ⚠️ Partial | Medium | Complete forum-specific features |
| **Announcements** | ⚠️ Partial | Easy | Complete announcement channel type |
| **Community Features** | ⚠️ Partial | Medium | Complete community onboarding |
| **App Directory/Bot Market** | ⚠️ Partial | Hard | Complete OAuth flow, app reviews |
| **Bot OAuth2 Install** | ⚠️ Partial | Hard | Complete OAuth2 implementation |
| **Slash Command Interactions** | ⚠️ Partial | Medium | Add buttons, select menus, modals |
| **Context Commands** | ❌ Missing | Medium | Add context menu support |
| **Embedded Activities** | ⚠️ Partial | Hard | Complete activity runtime, SDK bridge |
| **Activity Sync** | ⚠️ Partial | Medium | Complete media sync APIs |
| **Spatial Audio** | ❌ Missing | Hard | Implement spatial positioning |
| **Soundboard** | ❌ Missing | Easy | Add soundboard UI and audio playback |
| **Clips** | ❌ Missing | Hard | Implement clip recording (LiveKit) |
| **Webhooks** | ⚠️ Partial | Medium | Complete webhook delivery, signature verification |
| **Server Insights/Analytics** | ✅ Implemented | - | - |
| **Member Roles** | ✅ Implemented | - | - |
| **Role Icons** | ❌ Missing | Easy | Add role icon upload/display |
| **Role Colors** | ✅ Implemented | - | - |
| **Channel Categories** | ✅ Implemented | - | - |
| **Slow Mode** | ❌ Missing | Easy | Add per-channel slow mode |
| **NSFW Channels** | ⚠️ Partial | Easy | Add NSFW flag and age gate |
| **Age Gates** | ❌ Missing | Medium | Implement age verification |
| **Verified Bots** | ❌ Missing | Medium | Add bot verification system |
| **Application Commands** | ⚠️ Partial | Medium | Complete command registration |
| **Message Embeds** | ✅ Implemented | - | - |
| **Rich Presence** | ❌ Missing | Medium | Implement activity display |
| **Custom Status** | ✅ Implemented | - | - |
| **Streamer Mode** | ❌ Missing | Easy | Add streamer mode toggle |
| **Overlay** | ❌ Missing | Hard | Implement in-game overlay (desktop only) |
| **Keybinds** | ❌ Missing | Medium | Implement custom keybinds (desktop only) |
| **Shortcuts** | ❌ Missing | Medium | Implement keyboard shortcuts |
| **Themes** | ❌ Missing | Easy | Add custom themes |
| **Accessibility Features** | ❌ Missing | Medium | Add screen reader support, reduced motion |
| **Internationalization** | ⚠️ Partial | Hard | Complete translations for all UI strings |

### Top 5 Features for MVP

1. **Fix Bot Authentication** (🔴 Critical)
   - **Complexity:** Medium
   - **Time:** 4 hours
   - **Impact:** Enables third-party bot ecosystem

2. **Complete Message Search**
   - **Complexity:** Hard
   - **Time:** 16 hours
   - **Approach:** PostgreSQL full-text search with GIN indexes
   - **Impact:** Critical user experience feature

3. **Complete Custom Emojis & Stickers**
   - **Complexity:** Easy
   - **Time:** 8 hours
   - **Impact:** High engagement, differentiation opportunity

4. **Complete Premium/Nitro Flow**
   - **Complexity:** Medium
   - **Time:** 12 hours
   - **Impact:** Revenue generation, feature gating

5. **Complete Embedded Activities**
   - **Complexity:** Hard
   - **Time:** 24 hours
   - **Approach:** Integrate YouTube Together, Watch Together, etc.
   - **Impact:** Major differentiation from Discord

---

## SECTION 6 — DIFFERENTIATION STRATEGY

### Unique Features Discord Does NOT Have

| Feature | Value Proposition | Implementation Approach | Complexity |
|---------|------------------|------------------------|------------|
| **1. AI-Powered AutoMod** | Proactive moderation using ML to detect toxicity, harassment, spam before posting | Integrate OpenAI/Cohere API for content analysis, add confidence scores, configurable thresholds | Medium |
| **2. Built-in Translation** | Real-time message translation for global servers | Integrate DeepL or Google Translate API, add language detection, auto-translate toggle | Medium |
| **3. Voice-to-Text Transcription** | Automatic transcription of voice channels for accessibility and search | Integrate Whisper (OpenAI) or AssemblyAI, store transcripts, make searchable | Hard |
| **4. Decentralized Identity** | Users own their identity across servers using blockchain/DID | Implement DID wallets, verifiable credentials, portable reputation | Hard |
| **5. Time-Shifted Messaging** | Send messages that appear at specific times (scheduled delivery) | Add cron-based message scheduler, timezone support, delivery confirmations | Easy |
| **6. Collaborative Whiteboard** | Real-time drawing in channels (like Miro but built-in) | Integrate Fabric.js or similar, sync via WebSocket, save as attachments | Medium |
| **7. Gamification Marketplace** | Server-specific currencies, shops, rewards for engagement | Extend leveling system, add economy, marketplace for custom items | Medium |
| **8. Privacy-First DMs** | Optional E2EE for DMs with forward secrecy | Implement Signal protocol as described in Section 4 | Hard |
| **9. Cross-Server Communities** | Users can belong to communities across multiple servers with shared channels | Implement federation protocol, shared channel subscriptions, cross-server chat | Very Hard |
| **10. Built-in Code Review** | PR-style code discussions directly in channels with diff view | Integrate Git, add syntax highlighting, inline comments, approval workflow | Hard |

### Recommended Platform/API Integrations

**AI & ML:**
- **OpenAI API** - GPT-4 for AutoMod, content generation
- **AssemblyAI** - Speech-to-text transcription
- **Cohere** - Content moderation, text generation

**Translation:**
- **DeepL API** - Higher quality than Google Translate
- **Google Cloud Translation** - Fallback, more languages

**Voice & Video:**
- **LiveKit Cloud** (already using) - WebRTC SFU
- **Agora** - Alternative for global voice routing

**Storage & CDN:**
- **Cloudflare R2** - S3-compatible storage (zero egress fees)
- **Cloudflare CDN** (already using via WAF)

**Payments:**
- **Stripe** (already using) - Keep for premium
- **Coinbase Commerce** - Accept crypto payments

**Authentication:**
- **Supabase Auth** (already using) - Keep
- **Auth0** - Alternative for enterprise SSO

**Monitoring & Analytics:**
- **Sentry** - Error tracking (add to current stack)
- **PostHog** - Product analytics
- **LogDNA** - Log aggregation (alternative to Loki)

**Email:**
- **Resend** - Modern email API (alternative to mail-gateway)
- **SendGrid** - Reliable transactional email

**Search:**
- **Algolia** - Fast, typeahead search for messages
- **Meilisearch** - Open-source alternative (self-hosted)

---

## SECTION 7 — ZERO-COST INFRASTRUCTURE PLAN

### Free-Tier Service Stack

| Service | Free Tier Provider | Limits | Upgrade Threshold |
|---------|-------------------|--------|-------------------|
| **Hosting (VPS)** | Oracle Cloud Always Free | 4 ARM CPUs, 24GB RAM, 200GB SSD | > 2,000 CCU |
| **Database** | Supabase Free | 500MB DB, 1GB bandwidth, 2 concurrent connections | > 500 active users |
| **Redis** | Upstash Free | 10K commands/day, 256MB storage | > 1,000 CCU |
| **File Storage** | Cloudinary Free | 25GB storage, 25GB bandwidth/month | > 10GB files |
| **CDN** | Cloudflare Free | Unlimited bandwidth, DDoS protection | Never (keep free) |
| **Email** | Resend Free | 3,000 emails/month | > 1,000 users |
| **Auth** | Supabase Auth Free | Included with database | > 500 active users |
| **Voice/Video** | LiveKit Cloud Free | 50K minutes/month | > 500 active voice users |
| **Monitoring** | Grafana Cloud Free | 10K metrics, 50GB logs | > 1,000 CCU |
| **Error Tracking** | Sentry Free | 5K errors/month | Production launch |

### Architecture Diagram (Free Tier)

```
┌─────────────────────────────────────────────────────────────┐
│                     Cloudflare (Free)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   WAF/DDoS   │  │     CDN      │  │   DNS/SSL    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│  Oracle Cloud Free Tier VPS │                                │
│  ┌─────────────────────────┴────────────────────────────┐   │
│  │              NGINX (Reverse Proxy)                   │   │
│  └─────────────────────────┬────────────────────────────┘   │
│                            │                                │
│  ┌───────────┬─────────────┼─────────────┬──────────────┐  │
│  │ WS Gateway│ Msg Service │   Backend   │ Mail Gateway │  │
│  │  (Go)     │   (Go)      │   (Go)      │    (Go)      │  │
│  └─────┬─────┴──────┬──────┴──────┬──────┴──────┬───────┘  │
└────────┼─────────────┼─────────────┼─────────────┼──────────┘
         │             │             │             │
         └─────────────┼─────────────┼─────────────┘
                       │             │
┌──────────────────────┼─────────────┼─────────────────────────┐
│                      │             │                         │
│  ┌───────────────────┴─────┐  ┌────┴─────────────────────┐  │
│  │   Supabase (Free)       │  │   Upstash Redis (Free)   │  │
│  │  - PostgreSQL 500MB     │  │  - 256MB storage         │  │
│  │  - Auth                 │  │  - 10K commands/day      │  │
│  │  - RLS Policies         │  │  - Pub/Sub               │  │
│  └─────────────────────────┘  └──────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Cloudinary (Free)                                   │   │
│  │  - 25GB storage                                      │   │
│  │  - 25GB bandwidth/month                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  LiveKit Cloud (Free)                                │   │
│  │  - 50K minutes/month                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Exact Free Tier Limits

**Oracle Cloud Always Free:**
- 2 AMD VMs with 1/8 OCPU, 1GB RAM each (use for monitoring)
- 4 ARM Ampere A1 cores, 24GB RAM (main VPS)
- 200GB block volume storage
- 10TB/month outbound traffic (US regions)
- **Upgrade when:** > 2,000 CCU or CPU > 80% sustained

**Supabase Free:**
- 500MB database storage
- 1GB bandwidth/month
- 2 concurrent database connections
- 10,000 API requests/month
- **Upgrade when:** > 500 active users or > 10K API requests/day

**Upstash Redis Free:**
- 10K commands/day
- 256MB storage
- 128K max keys
- **Upgrade when:** > 1,000 CCU or frequent rate limiting

**Cloudinary Free:**
- 25GB storage
- 25GB bandwidth/month
- 25 transformations/month
- **Upgrade when:** > 10GB total files or > 25GB/month transfer

**LiveKit Cloud Free:**
- 50K minutes/month
- 500 concurrent participants
- **Upgrade when:** > 500 active voice users or > 1.6K minutes/day

**Resend Free:**
- 3,000 emails/month
- 100 emails/day
- **Upgrade when:** > 1,000 users or frequent email notifications

**Grafana Cloud Free:**
- 10K metrics series
- 50GB logs ingestion
- 14-day retention
- **Upgrade when:** > 1,000 CCU or need longer retention

### Open-Source Self-Hosted Alternatives

| Service | Self-Hosted Alternative | Pros | Cons |
|---------|----------------------|------|------|
| **Database** | PostgreSQL (direct) | Full control, no limits | Need to manage backups, scaling |
| **Redis** | Redis (direct) | Full control, no command limits | Need to manage persistence |
| **File Storage** | MinIO | S3-compatible, self-hosted | Need to manage storage, backups |
| **CDN** | None (use Cloudflare) | N/A | N/A |
| **Email** | Postfix + Dovecot | Full control, free | Complex setup, deliverability issues |
| **Auth** | Keycloak | Full-featured IAM | Complex setup, resource-heavy |
| **Voice/Video** | Jitsi Meet | Fully self-hosted | Higher resource usage |
| **Monitoring** | Prometheus + Grafana | Full control, no limits | Need to manage storage, alerts |
| **Error Tracking** | Sentry (self-hosted) | Full control, no limits | Resource-heavy |

**Recommended Self-Hosted Stack (for > 1,000 users):**
- PostgreSQL (managed via repmgr for HA)
- Redis (with Redis Sentinel for HA)
- MinIO (with distributed setup)
- Jitsi Meet (for voice/video)
- Prometheus + Grafana + AlertManager
- Postfix for email (or use Resend for deliverability)

---

## SECTION 8 — HIGH-LEVEL DOCUMENTATION

### Architecture Overview

**Component Diagram Description:**

Flicko uses a microservices architecture with three core Go services:

1. **WebSocket Gateway** (`ws-gateway`)
   - Manages persistent WebSocket connections
   - Handles real-time event delivery via Redis Pub/Sub
   - Tracks user presence
   - Rate-limits inbound frames
   - Forwards messages to msg-service for persistence

2. **Message Service** (`msg-service`)
   - REST API for message CRUD operations
   - Batch insertion engine for high-throughput writes
   - Idempotency store for duplicate prevention
   - Abuse detection and enforcement
   - Redis caching for frequently accessed data

3. **Backend Service** (`backend`)
   - Bot framework with 8 built-in bots
   - Slash command execution
   - Premium payment processing
   - Activity lifecycle management
   - Moderation actions

**External Dependencies:**
- **Supabase** - PostgreSQL database, authentication, RLS policies
- **Upstash Redis** - Pub/Sub, rate limiting, presence, caching
- **Cloudinary** - File storage and CDN
- **LiveKit Cloud** - WebRTC SFU for voice/video
- **Stripe** - Payment processing
- **Cloudflare** - WAF, DDoS protection, CDN, DNS

**Data Flow:**
1. Client connects to WS Gateway via WebSocket
2. Gateway authenticates via JWT
3. Messages sent via WebSocket are forwarded to msg-service
4. msg-service persists to PostgreSQL and publishes to Redis
5. Gateway receives Redis pub/sub messages and fans out to connected clients
6. NGINX reverse-proxies HTTP requests to appropriate services

### API Endpoint Reference

**Authentication:** Bearer JWT token in `Authorization` header

#### Message Service (`:8081`)

| Method | Route | Auth | Request | Response |
|--------|-------|------|---------|----------|
| POST | `/v1/channels/{channelID}/messages` | ✅ | `{content, nonce, type, reference_id}` | Message object |
| GET | `/v1/channels/{channelID}/messages` | ✅ | `?before={cursor}&limit={n}` | Message array + cursor |
| PATCH | `/v1/messages/{messageID}` | ✅ | `{content}` | 204 No Content |
| DELETE | `/v1/messages/{messageID}` | ✅ | - | 204 No Content |

#### Backend Service (`:8080`)

| Method | Route | Auth | Request | Response |
|--------|-------|------|---------|----------|
| GET | `/api/v1/commands` | ✅ | - | Command list |
| POST | `/api/v1/commands/invoke` | ✅ | `{name, options}` | Command response |
| GET | `/api/v1/servers/{serverId}/bots/{botName}/settings` | ✅ | - | Bot settings |
| PUT | `/api/v1/servers/{serverId}/bots/{botName}/settings` | ✅ | Settings object | Updated settings |
| GET | `/api/v1/servers/{serverId}/leaderboard` | ✅ | - | Leaderboard |
| POST | `/api/v1/activities/launch` | ✅ | `{activity_id, channel_id}` | Session object |
| POST | `/api/v1/premium/orders` | ✅ | `{plan_id}` | Order object |
| POST | `/api/v1/premium/verify` | ✅ | `{payment_id}` | Verification result |

#### Bot API (`:8080/bot-api`)

| Method | Route | Auth | Request | Response |
|--------|-------|------|---------|----------|
| POST | `/bot-api/messages/{channelID}` | 🔴 Bot Token | Message object | `{status: "delivered"}` |

**Note:** Bot authentication is currently broken (see Section 4).

#### Health Endpoints

| Method | Route | Auth | Response |
|--------|-------|------|----------|
| GET | `/health` | ❌ | Service health |
| GET | `/healthz/live` | ❌ | Liveness probe |
| GET | `/healthz/ready` | ❌ | Readiness probe |

### Database Schema Summary

**Core Tables:**

| Table | Key Fields | Relationships |
|-------|------------|---------------|
| `profiles` | id, username, discriminator, email, avatar, status | FK to auth.users |
| `servers` | id, name, owner_id, icon, banner | - |
| `channels` | id, server_id, name, type, position | FK to servers |
| `messages` | id, channel_id, author_id, content, created_at | FK to channels, profiles |
| `roles` | id, server_id, name, permissions, color | FK to servers |
| `members` | server_id, user_id, joined_at | FK to servers, profiles |
| `member_roles` | server_id, user_id, role_id | FK to members, roles |
| `invites` | id, server_id, code, created_at, expires_at | FK to servers |
| `voice_states` | user_id, server_id, channel_id | FK to profiles, servers, channels |
| `reactions` | message_id, user_id, emoji | FK to messages, profiles |

**Permission System:**
- Bitwise permissions (64-bit integers)
- Role-based with channel overwrites
- Calculated via `has_permission()` function
- RLS policies enforce access at database level

### Environment Variables Reference

**Backend (`.env`):**
```bash
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET=...
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
LIVEKIT_API_KEY=...
LIVEKIT_API_SECRET=...
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
RAZORPAY_KEY_ID=...
RAZORPAY_KEY_SECRET=...
MAIL_GATEWAY_URL=...
INTERNAL_TOKEN=...
PORT_HTTP=8080
ENVIRONMENT=production
```

**Message Service:**
```bash
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWTPUBLIC_KEY_PATH=/path/to/jwt_public.pem
HTTP_PORT=8081
METRICS_PORT=9101
DATABASE_POOL_MAX=20
DATABASE_POOL_MIN=5
IDEMPOTENCY_TTL=300
ENVIRONMENT=production
```

**WebSocket Gateway:**
```bash
REDIS_URL=redis://...
JWTPUBLIC_KEY_PATH=/path/to/jwt_public.pem
WS_PORT=8080
METRICS_PORT=9100
MAX_CONNECTIONS=5000
RATE_LIMIT_MSG_PER_SEC=50
RATE_LIMIT_BURST=100
READ_BUFFER_SIZE=4096
WRITE_BUFFER_SIZE=4096
MSG_SERVICE_URL=http://msg-service:8081
INSTANCE_ID=
ENVIRONMENT=production
```

**Mobile (`.env`):**
```bash
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
API_BASE_URL=...
STRIPE_PUBLISHABLE_KEY=...
LIVEKIT_URL=...
```

### Deployment Guide (Zero-Cost Setup)

#### Prerequisites
- Oracle Cloud account (Always Free tier)
- Supabase account (Free tier)
- Upstash account (Free tier)
- Cloudinary account (Free tier)
- LiveKit Cloud account (Free tier)
- Resend account (Free tier)
- Cloudflare account (Free tier)
- Domain name

#### Step 1: Set up Cloudflare
1. Add your domain to Cloudflare
2. Configure DNS records pointing to Oracle Cloud VPS IP
3. Enable SSL/TLS (Full mode)
4. Configure WAF rules (use Cloudflare managed rules)
5. Set up Page Rules for caching static assets

#### Step 2: Create Oracle Cloud VPS
1. Create Always Free ARM instance (4 cores, 24GB RAM)
2. Install Docker and Docker Compose
3. Configure firewall (allow 80, 443, 22)
4. Set up SSH keys

#### Step 3: Set up External Services
1. **Supabase:**
   - Create project
   - Run migrations from `supabase/migrations/`
   - Enable RLS
   - Get connection string and service key

2. **Upstash Redis:**
   - Create database
   - Get Redis URL
   - Note command limits

3. **Cloudinary:**
   - Create account
   - Get cloud name, API key, secret
   - Configure upload presets

4. **LiveKit:**
   - Create project
   - Get API key and secret
   - Configure webhook URL

5. **Resend:**
   - Create account
   - Get API key
   - Verify sender domain

#### Step 4: Deploy Application
```bash
# Clone repository
git clone https://github.com/your-org/flicko.git
cd flicko

# Configure environment
cp .env.production.example .env
# Edit .env with actual values

# Generate JWT keys
ssh-keygen -t ed25519 -f secrets/jwt_private.pem
openssl pkey -in secrets/jwt_private.pem -pubout -out secrets/jwt_public.pem

# Deploy with Docker Compose
docker-compose -f docker-compose.prod.yml up -d

# Check health
curl http://localhost/health
```

#### Step 5: Configure Monitoring
```bash
# Access Grafana
http://your-domain:3000
# Default credentials: admin/admin (change immediately)

# Import dashboards from monitoring/grafana/dashboards/
```

#### Step 6: Set up SSL
1. Generate Cloudflare Origin Certificate
2. Add to `nginx/ssl/` directory
3. Restart nginx container

### Developer Onboarding Guide

#### Local Development Setup

**Prerequisites:**
- Go 1.25.7+
- Flutter SDK 3.22+
- Docker 24.0+
- Node.js 18+ (for some tools)

**Backend Development:**
```bash
cd backend
go mod download
go run cmd/server/main.go
```

**Services Development:**
```bash
cd services/msg-service
go mod download
go run cmd/server/main.go

cd ../ws-gateway
go mod download
go run cmd/gateway/main.go
```

**Mobile Development:**
```bash
cd mobile
flutter pub get
flutter run
```

**Development Database:**
```bash
# Use docker-compose for local services
docker-compose up -d redis livekit
# Use Supabase local or remote for database
```

#### Folder Structure

```
flicko/
├── backend/              # Bot framework and admin APIs
│   ├── cmd/server/      # Main entry point
│   ├── internal/
│   │   ├── bots/        # Built-in bots
│   │   ├── handlers/    # HTTP handlers
│   │   ├── middleware/  # Auth, rate limiting, etc.
│   │   └── services/    # Business logic
│   └── go.mod
├── services/
│   ├── msg-service/     # Message REST API
│   │   ├── cmd/server/
│   │   ├── internal/
│   │   │   ├── handler/
│   │   │   ├── service/
│   │   │   └── repository/
│   │   └── go.mod
│   ├── ws-gateway/      # WebSocket service
│   │   ├── cmd/gateway/
│   │   └── internal/
│   │       ├── conn/
│   │       ├── pubsub/
│   │       └── handler/
│   └── shared/          # Shared code
│       └── auth/        # JWT utilities
├── mobile/              # Flutter app
│   ├── lib/
│   │   ├── core/        # Config, router, theme
│   │   ├── data/        # Repositories, models
│   │   └── features/    # Feature modules
│   └── pubspec.yaml
├── supabase/
│   └── migrations/      # SQL migrations
├── nginx/               # NGINX configuration
├── monitoring/          # Prometheus, Grafana, Loki
└── docker-compose.prod.yml
```

#### Key Conventions

**Go:**
- Use `go.uber.org/zap` for structured logging
- Use `context.Context` for all operations
- Use pgx for database operations
- Follow standard Go project layout
- Use dependency injection for services

**Flutter:**
- Use `flutter_riverpod` for state management
- Use `go_router` for navigation
- Use `dio` for HTTP requests
- Follow feature-based folder structure
- Use `supabase_flutter` for backend integration

**Database:**
- Use UUIDv4 for all IDs
- Use `snake_case` for column names
- Use `TIMESTAMPTZ` for timestamps
- Use RLS policies for row-level security
- Use migrations for all schema changes

### Known Issues & Technical Debt Log

| ID | Issue | Severity | Status | Created |
|----|-------|----------|--------|---------|
| BUG-001 | Bot auth uses hardcoded mock values | 🔴 Critical | Open | 2025-01-15 |
| BUG-002 | Zero test coverage across entire codebase | 🔴 Critical | Open | 2025-01-15 |
| BUG-003 | Hardcoded Stripe test secret in mobile app | 🔴 Critical | Open | 2025-01-15 |
| BUG-022 | Pagination issues in server discovery | 🟡 Medium | Open | 2025-01-15 |
| BUG-023 | Performance issues in correlated subqueries | 🟡 Medium | Open | 2025-01-15 |
| TD-001 | N+1 query in AutoMod exemption check | 🟡 Medium | Open | 2025-01-15 |
| TD-002 | Development spike screens in production build | 🟡 Medium | Open | 2025-01-15 |
| TD-003 | 20+ TODO comments in mobile app | 🟡 Medium | Open | 2025-01-15 |
| TD-004 | No circuit breakers for external service calls | 🟡 Medium | Open | 2025-01-15 |
| TD-005 | Missing database query timeouts | 🟡 Medium | Open | 2025-01-15 |

### Roadmap

**Priority 1 - Critical Security & Stability (Week 1-2)**
- [ ] Fix bot authentication (4h)
- [ ] Remove hardcoded secrets (1h)
- [ ] Add basic test coverage (16h)
- [ ] Remove spike screens from production (2h)
- [ ] Fix N+1 query in AutoMod (2h)
- **Total:** ~25 hours (3-4 days)

**Priority 2 - Production Readiness (Week 3-4)**
- [ ] Add circuit breakers (8h)
- [ ] Add database query timeouts (4h)
- [ ] Implement account lockout (6h)
- [ ] Add comprehensive rate limiting (4h)
- [ ] Add request IDs to errors (4h)
- [ ] Complete mobile TODO features (16h)
- **Total:** ~42 hours (1 week)

**Priority 3 - Core Features (Month 2)**
- [ ] Implement message search (16h)
- [ ] Complete custom emojis (8h)
- [ ] Complete stickers (8h)
- [ ] Complete premium flow (12h)
- [ ] Add webhook signature verification (3h)
- [ ] Add API key rotation (6h)
- **Total:** ~53 hours (1.5 weeks)

**Priority 4 - Advanced Features (Month 3)**
- [ ] Complete embedded activities (24h)
- [ ] Complete threads UI (8h)
- [ ] Complete forum features (12h)
- [ ] Add soundboard (8h)
- [ ] Add slow mode (4h)
- **Total:** ~56 hours (1.5 weeks)

**Priority 5 - Differentiation (Month 4)**
- [ ] AI AutoMod integration (16h)
- [ ] Translation integration (12h)
- [ ] Voice transcription (24h)
- [ ] Collaborative whiteboard (16h)
- [ ] Gamification marketplace (16h)
- **Total:** ~84 hours (2-3 weeks)

**Priority 6 - Scaling & Performance (Month 5)**
- [ ] Add Redis caching layer (16h)
- [ ] Implement database read replicas (8h)
- [ ] Add CDN for static assets (4h)
- [ ] Optimize permission calculations (12h)
- [ ] Add distributed tracing (8h)
- **Total:** ~48 hours (1.5 weeks)

**Estimated Time to Production-Ready MVP:** 8-10 weeks

---

## SUMMARY

This audit has identified critical security vulnerabilities, zero test coverage, and incomplete features that prevent production deployment. The architecture is well-designed with good separation of concerns, but implementation gaps must be addressed before go-live.

**Critical Path to Production:**
1. Fix bot authentication (🔴 4 hours)
2. Remove hardcoded secrets (🔴 1 hour)
3. Implement basic test suite (🔴 16 hours)
4. Remove development artifacts (🔴 2 hours)

**Estimated Time to Production-Ready:** 8-10 weeks with dedicated development effort.

**Recommendation:** Do not deploy to production until critical security issues are resolved and basic test coverage is implemented.
