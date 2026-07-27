# Flicko Audit Report

**Date:** 2026-07-26
**Branch:** `main` @ `49b3d9d`
**Scope covered:** 400,919 LOC (467 Go, 643 Dart, 930 TS/TSX), 180 SQL migrations, 5 Go modules, nginx + Docker + coturn/LiveKit config.

> **Remediation status (2026-07-26):** CRITICAL-1, CRITICAL-2, HIGH-2, MEDIUM-1, MEDIUM-3 (TTL half), and MEDIUM-4 are **fixed and verified** — all 5 Go modules build, all test suites pass, 105 new test cases added. HIGH-1 requires operator action (credential rotation + history rewrite). HIGH-3, MEDIUM-2, MEDIUM-5, MEDIUM-6 remain open. Per-finding detail below.

A note on coverage before the findings: the security modules (2.1–2.5, 3.x) were verified directly against source. Module 1 asks for a per-feature tier classification across 30 mobile feature domains plus web — that was not exhaustively verified in this pass, and only confirmed findings are reported rather than a speculative matrix. What is missing is called out explicitly in §2.

---

## 1. Executive Summary

| Domain | Score | Basis |
|---|---|---|
| Injection defense (SQLi) | **A** | Parameterized throughout; only one dynamic builder, correctly done |
| XSS / client rendering | **A−** | No `dangerouslySetInnerHTML`, no `eval` in web src |
| Secrets hygiene | **C** | One live credential committed to git history (HIGH-1 still open) |
| Network egress (SSRF) | **F → A** | Was unfiltered; now resolve-then-validate dialer + redirect cap |
| File upload security | **D → B+** | Was extension-only; now magic-byte enforced + filenames sanitized |
| AuthN (JWT) | **B−** | Modern EdDSA path is solid; a legacy HS256 path coexists |
| AuthZ (RLS) | **A−** | 195/195 tables have RLS enabled; policy logic not line-audited |
| AuthZ (RBAC middleware) | **C** | Middleware defined but appears wired to very few routes |
| Real-time engine | **B+ → A−** | Correct ping/pong reaping, `sync.Map`; origin check now fails closed |
| Async workers | **C+** | msg-service has a real DLQ; backend asynq has retries but no DLQ |

**Remaining top priority:** the committed coturn credential (HIGH-1) — the only finding that needs operator action rather than a code change.

---

## 2. Feature Implementation — Verified Subset Only

### Tier C: UI-only / disconnected (confirmed by reading the code)

| Feature | Location | Evidence |
|---|---|---|
| Group DM chat | `mobile/lib/features/direct_messages/presentation/screens/group_dm_list_screen.dart:114` | Renders `Text('Group DM Chat - Coming Soon')` |
| Create group DM | same file `:124` | SnackBar stub |
| Server invite link | `mobile/lib/features/server/presentation/server_options_screen.dart:246` | SnackBar stub |
| Forum thread view | `mobile/lib/features/server_channels/forum/presentation/screens/forum_channel_screen.dart:633` | `Text('Thread View - Coming Soon')` |
| User reporting | `mobile/lib/features/profile/presentation/public_profile_screen.dart:684` | "Reporting functionality coming soon." |
| Privacy settings (subset) | `mobile/lib/features/settings/presentation/privacy_settings_screen.dart:87` | "Coming soon" |
| Gifting | `mobile/lib/features/store/presentation/store_screen.dart:2007`, `inventory_screen.dart:418,422` | 3 stub sites |
| Stripe checkout | `mobile/lib/features/subscription/presentation/subscription_screen.dart:151` | "Stripe checkout coming soon!" — note Razorpay appears to be the live path |
| Generic feature gate | `mobile/lib/features/server_channels/chat/presentation/widgets/message_input.dart:79` | `'$feature coming soon!'` — parameterized stub |

53 total stub/TODO/mock markers across `mobile/lib`.

### Tier C: backend dead code

`FileUploadValidationMiddleware` (`backend/internal/middleware/security.go:131`) implements magic-byte MIME detection but does not appear in `main.go`'s middleware chain. Written, never applied — see CRITICAL-2.

`services/ws-gateway/internal/{ratelimit,middleware,auth}/.gitkeep.go` are 2–3 line package declarations only. Their doc comments describe functionality ("Redis-backed sliding-window rate limiter", "JWT validation and key rotation") that does not exist in those packages.

### Not verified

End-to-end wiring for the remaining ~25 mobile feature domains, the Next.js web routes, and the cross-reference of the 14 `missing-features/` spec directories against implementation (Tier D) were not confirmed. A credible matrix there needs per-feature tracing.

---

## 3. Vulnerability Findings

### CRITICAL-1 — SSRF in embed service (unauthenticated internal network access) — ✅ FIXED

`backend/internal/services/embed_service.go:113-120`

URLs are regex-extracted from user message content and fetched server-side with no destination filtering.

```go
urls := s.urlRegex.FindAllString(content, 5)
// ...
req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
resp, err := s.httpClient.Do(req)
```

No blocklist for loopback, RFC1918, link-local, or `.internal`. Verified absent: the only `169.254`/`127.0.0.1` matches in the whole Go tree are in a test file. A message containing `http://169.254.169.254/latest/meta-data/iam/security-credentials/` triggers a cloud metadata fetch; response metadata lands in the `embeds` table and is rendered to the attacker. Redirects are also unrestricted, so an allowlist alone would be bypassable via 302.

Mitigations present: 5s timeout, 1MB `io.LimitReader`, rate limiter. None address destination.

```diff
+var privateNets = func() []*net.IPNet {
+	cidrs := []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
+		"127.0.0.0/8", "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"}
+	out := make([]*net.IPNet, 0, len(cidrs))
+	for _, c := range cidrs {
+		_, n, _ := net.ParseCIDR(c)
+		out = append(out, n)
+	}
+	return out
+}()
+
+// safeDial rejects connections to private/loopback IPs after DNS resolution,
+// closing the DNS-rebinding window that a pre-flight URL check would leave open.
+func safeDial(ctx context.Context, network, addr string) (net.Conn, error) {
+	host, port, err := net.SplitHostPort(addr)
+	if err != nil {
+		return nil, err
+	}
+	ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
+	if err != nil {
+		return nil, err
+	}
+	for _, ip := range ips {
+		for _, n := range privateNets {
+			if n.Contains(ip.IP) {
+				return nil, fmt.Errorf("blocked destination %s", ip.IP)
+			}
+		}
+	}
+	return (&net.Dialer{Timeout: 3 * time.Second}).DialContext(ctx, network, net.JoinHostPort(ips[0].IP.String(), port))
+}
```

Wire into the client and cap redirects:

```diff
 httpClient: &http.Client{
 	Timeout: 5 * time.Second,
+	Transport: &http.Transport{DialContext: safeDial},
+	CheckRedirect: func(r *http.Request, via []*http.Request) error {
+		if len(via) >= 3 {
+			return errors.New("too many redirects")
+		}
+		if r.URL.Scheme != "http" && r.URL.Scheme != "https" {
+			return errors.New("disallowed scheme")
+		}
+		return nil
+	},
 },
```

Also reject non-HTTP schemes at extraction time (`file://`, `gopher://`).

**What was implemented.** The guard lives in a dedicated `backend/internal/services/ssrf_guard.go` rather than inline, so it is unit-testable and reusable by the other outbound-fetch sites (`webhook_service.go`, `bots/webhook.go`) when those are hardened:

- `isBlockedIP` uses the stdlib predicates (`IsLoopback`, `IsPrivate`, `IsLinkLocalUnicast`, `IsMulticast`, …) plus an explicit CIDR list for ranges they miss: CGNAT `100.64/10`, `192.0.0.0/24`, TEST-NET 1–3, benchmarking `198.18/15`, reserved `240/4`, NAT64, and IPv6 documentation. IPv6 unique-local (`fc00::/7`) is checked by prefix since no stdlib predicate covers it.
- IPv4-in-IPv6 is normalized via `To4()` first, so `::ffff:127.0.0.1` and `::ffff:169.254.169.254` cannot smuggle a blocked address past the v4 checks. Both are regression-tested.
- `ssrfSafeDialContext` resolves the host, rejects the connection if **any** returned address is non-public, then dials one of those already-vetted addresses rather than re-resolving — this is what closes the DNS-rebinding window. A hostname resolving to both a public and a private address is refused rather than partially allowed.
- `Proxy: nil` is set explicitly: a configured proxy would connect to the proxy instead of the vetted address, bypassing the dialer entirely.
- `ValidateOutboundURL` runs before the cache lookup and rate-limit slot, so hostile input is cheap to reject.

Verified end-to-end: the guarded client refuses a real `httptest` server (which binds loopback), and refuses a redirect chain into one. 51 test cases in `ssrf_guard_test.go`.

---

### CRITICAL-2 — Upload validation bypass: extension-only checks, magic-byte middleware unwired — ✅ FIXED

`backend/internal/handlers/soundboard_handler.go:106-114`

```go
filename := header.Filename
if !strings.HasSuffix(strings.ToLower(filename), ".mp3") && ... ".wav" ... ".ogg" {
```

The only check is the client-controlled filename suffix. `payload.html` renamed to `payload.mp3` uploads cleanly into a public Supabase bucket, and the response returns a public URL (`:120`). Combined with the nginx CSP at `flicko.conf:379` allowing `'unsafe-inline' 'unsafe-eval'`, stored-XSS is reachable if the bucket serves attacker-controlled content types.

The correct implementation already exists at `security.go:131-200` using `http.DetectContentType`, but it is not in the chain — `main.go` applies `RequestID`, `SecurityHeaders`, `Tracing`, `CORS`, `Timeout`, `RequestBodyLimit`, `InputSanitization`, `CSRF`, `RequestFilter`, rate limiters, `Auth`, `Validation`. `FileUploadValidationMiddleware` is absent.

**Correction to the original remediation advice.** The obvious fix — reusing the existing middleware with an audio allowlist — does not work, and the audit's first draft recommended it in error:

```diff
-// BROKEN: rejects most legitimate audio uploads.
-audioUpload := middleware.FileUploadValidationMiddleware(
-	5*1024*1024, []string{"audio/mpeg", "audio/wav", "audio/ogg"}, logger)
```

Go's `http.DetectContentType` cannot classify audio. Measured behavior:

| Input | `DetectContentType` returns |
|---|---|
| MP3 with ID3v2 tag | `audio/mpeg` ✅ |
| MP3 bare frame (no ID3) | `application/octet-stream` ❌ |
| WAV | `audio/wave` — note, **not** `audio/wav` ❌ |
| OGG | `application/ogg` ❌ |
| JPEG / PNG / WebP | correct ✅ |

So the allowlist above would reject bare MP3s, all WAVs, and all OGGs while still admitting anything it failed to sniff.

**What was implemented instead:**

- `backend/internal/middleware/upload_validation.go` — a new `SniffAudioType` that checks container signatures directly (ID3, MPEG sync bits `0xFF 0xE0`, `RIFF....WAVE`, `OggS`), wrapped in `AudioUploadValidationMiddleware`. The MPEG sync check is deliberately narrower than `buf[1] & 0xE0` alone would suggest at a glance — JPEG also starts `0xFF`, and there's a regression test asserting JPEG does not sniff as audio.
- Soundboard route (`soundboard_handler.go:RegisterRoutes`) now wraps `UploadSound` in that middleware; the extension check is retained and demoted to a convenience filter in a comment.
- Channel-background route now wraps `UploadBackground` in the pre-existing `FileUploadValidationMiddleware` with `AllowedImageUploadTypes` — safe here because image sniffing *is* reliable.
- Size limits are now shared constants (`maxSoundUploadBytes`, `maxBackgroundUploadBytes`) so the middleware and handler cannot drift apart.

Both handlers call `ParseMultipartForm` again after the middleware already did; verified against `$GOROOT/src/net/http/request.go:1380` that the second call returns early, and there's a test asserting the handler still reads the full file body.

Only two upload routes needed wiring, not three — see item 17 in the roadmap.

---

### HIGH-1 — Live TURN credential committed to git — ⚠️ REQUIRES OPERATOR ACTION

`setup_coturn.sh:41-47`

```
lt-cred-mech
user=flicko:flickoSecretSecurePassword2026!
```

Confirmed tracked and present in history (commit `b6fa4f0`). A static long-term credential in a public-facing relay config allows anyone with repo read access to relay arbitrary traffic through the Azure VPS — bandwidth theft and attack laundering attributed to your IP.

Two separate defects: the credential is committed, and static `lt-cred-mech` is the wrong mechanism. Use `use-auth-secret` with time-limited HMAC credentials minted server-side.

```diff
-lt-cred-mech
-user=flicko:flickoSecretSecurePassword2026!
+use-auth-secret
+static-auth-secret=${TURN_STATIC_SECRET}
```

Rotate the credential regardless of the config change — it is in history and must be treated as compromised. `.gitleaksignore` does not currently cover this pattern, so consider whether the secret scanner should have caught it.

---

### HIGH-2 — Path traversal in storage keys from unsanitized filenames — ✅ FIXED

`backend/internal/services/attachment_service.go:61`, `backend/internal/services/channel_background_service.go:109`, `backend/internal/handlers/soundboard_handler.go:109`

```go
filePath := fmt.Sprintf("%s/%s_%s", userID, hashStr, header.Filename)
```

`header.Filename` is client-controlled and interpolated without `filepath.Base()`. A filename of `../../other-user/avatar.png` manipulates the storage key. Whether Supabase's storage API normalizes this before writing was not verified, hence HIGH rather than CRITICAL — but the sanitization is unambiguously missing.

The codebase already does this correctly elsewhere: `services/msg-service/internal/service/media_service.go:155` calls `name = filepath.Base(name)`. The three sites above are inconsistent with it.

```diff
-filePath := fmt.Sprintf("%s/%s_%s", userID, hashStr, header.Filename)
+safeName := filepath.Base(header.Filename)
+if safeName == "." || safeName == string(filepath.Separator) {
+	return nil, errors.New("invalid filename")
+}
+filePath := fmt.Sprintf("%s/%s_%s", userID, hashStr, safeName)
```

**What was implemented.** One shared `services.SanitizeUploadFilename` (`backend/internal/services/upload_filename.go`) applied at all three sites, rather than the fix repeated three times.

Beyond `filepath.Base()`, it handles two cases the one-line fix misses:

- **Windows-style traversal.** `filepath.Base` does not treat `\` as a separator on Linux, so `..\..\etc\passwd` survives it untouched. An explicit `[^A-Za-z0-9._-]` replacement neutralizes it.
- **Leading dots.** `.hidden` creates a hidden object and `..config` keeps traversal-adjacent text in the key; both are stripped.

Names that reduce to nothing usable (`.`, `..`, `/`, whitespace, all-unsafe-bytes) return `""`, and every caller treats that as a validation failure. Length is capped at 128 chars preserving the extension. 23 test cases including an invariant test asserting the output never contains a separator across adversarial inputs.

---

### HIGH-3 — Two divergent JWT systems; legacy path is weak

`backend/internal/services/auth.go:58-88` vs `services/shared/auth/jwt.go`

`services/shared/auth` is well built: Ed25519/EdDSA, `kid`-based rotation via SHA-256 key derivation, 15-minute access TTL, server-side refresh in Redis for revocation.

`backend/internal/services/auth.go` is the opposite: HS256 shared secret, **7-day** access token expiry, no `kid`, no revocation path. Comments at `:52-55` and `:86-88` show Supabase/ES256 fallback was deliberately stripped, leaving "unified HS256 validation only." A third validator (`services/shared/auth/validator.go`) is also HS256 and hardcodes `expected HS256` in its error string.

A 7-day non-revocable token means logout, password change, and account compromise all leave a valid credential live for a week. Consolidate on the EdDSA path and delete the HS256 validators.

**Positive:** algorithm confusion is correctly defended at all three sites — each verifies `token.Method.(*jwt.SigningMethodHMAC)` (or `SigningMethodEdDSA`) inside the keyfunc. The `alg: none` exploit class is **not** present. `exp` validation is handled by `jwt/v5` defaults.

---

### MEDIUM-1 — Wildcard CORS hardcoded in msg-service — ✅ FIXED

`services/msg-service/internal/middleware/cors.go:18` + `services/msg-service/internal/handler/router.go:49`

`DefaultCORSConfig()` returns `AllowedOrigins: []string{"*"}`, and the router calls it unconditionally — there is no environment-driven override path, so the "sensible defaults for development" comment describes what ships to production.

Severity is MEDIUM rather than HIGH because `Access-Control-Allow-Credentials` is never set and auth is `Authorization`-header based, so a browser will not attach victim credentials cross-origin. It still exposes any IP-authenticated or unauthenticated endpoint to arbitrary origins.

Separately, `:29` is broken by design: `origins = cfg.AllowedOrigins[0] // simplified: first origin`. With multiple configured origins, only the first ever works. Correct approach is echoing the request `Origin` when it matches the allowlist, plus `Vary: Origin`.

**What was implemented.**

- `NewCORSConfig(originsCSV, isProd)` replaces the hardcoded wildcard. The middleware now echoes the request's own `Origin` when it matches the allowlist, so every configured origin works — fixing the first-origin-only bug.
- `Vary: Origin` is always emitted, including on rejection, since that outcome is origin-dependent too and a shared cache must not reuse it.
- Wired through `CORSOrigins` + `IsProd` on `RouterDeps` from `cfg` in `main.go`. A new `CORSOrigins` field was added to `MsgServiceConfig`, which previously had none.
- `DefaultCORSConfig` is kept but marked deprecated so any other caller still compiles.
- **Fails closed at startup, not just at request time:** `validateGateway` and `validateMsgService` now refuse to boot when `ENVIRONMENT=production` and `CORS_ORIGINS` is unset. This turns a silent security downgrade into a loud startup failure.

Note this changes deploy requirements: **both services now require `CORS_ORIGINS` to be set in production or they will not start.** That is intentional, but it needs to land in Doppler before the next production deploy.

One existing test (`TestLoadGatewayConfig_CustomValues`) set `ENVIRONMENT=production` only to exercise `IsProd()` and started failing against the new validation; it was given a `CORS_ORIGINS` value rather than weakening the check. Four new config test cases cover the prod-required and dev-permissive paths.

---

### MEDIUM-2 — RBAC middleware defined but scarcely applied

`backend/internal/middleware/authorization.go:72,148,212`

`RequirePermission`, `RequireServerPermission`, and `RequireChannelPermission` all exist. Across `backend/internal`, references to these names appear in only 3 files (`role.go`, `authorization.go` itself, `bots/helpers.go`), and none appear in the `main.go` route registrations. `main.go` registers ~143 routes.

This does not prove routes are unprotected — handlers or services may perform inline checks, and RLS provides a second layer. But permission enforcement is not consistently applied at the middleware boundary where it is auditable. This needs per-route verification; treat it as an open question, not a confirmed bypass.

Related: `main.go:279` has `// protected.Use(middleware.Auth)` commented out. Which router that refers to, and whether auth is re-applied downstream, was not traced. Worth a look.

---

### MEDIUM-3 — Long-lived LiveKit tokens; room grant not tied to verified membership — ✅ TTL FIXED

`backend/internal/services/livekit_service.go:41-45`, `services/msg-service/internal/service/voice_service.go:63-65`

Tokens are minted server-side with identity binding — correct. But TTLs are 8 hours and 2 hours respectively. A leaked token grants room access for that whole window with no revocation.

`voice_service.go:65` grants `RoomJoin` to `"voice-" + in.ChannelID` from request input. Recommend 5–15 minute TTLs and an explicit membership assertion at mint time.

**What was implemented.** Both TTLs are now `15 * time.Minute`, expressed as named constants (`services.TokenTTL`, `service.tokenTTL`) with a comment explaining why they are short: LiveKit has no server-side revocation, so a leaked token is valid for its whole window.

The safe-by-construction detail worth knowing: LiveKit only checks the token at join/reconnect, so a 15-minute TTL does **not** drop participants from calls longer than 15 minutes. The constraint it does impose is that clients must request a fresh token when reconnecting after a network drop rather than replaying the original — noted in both constant comments. Worth confirming the mobile client does this before deploying.

**On the membership half (7b):** reading `voice_service.go:46-53` resolved the open question from the first pass. The production voice-token issuer is the Supabase edge function `supabase/functions/voice-token`, which the mobile client calls via `voice_repository.dart` and which already enforces membership, channel type, user limits, and screen-share slots. The msg-service route is registered but has **no client caller**, and it uses a different room-name convention (`voice-{id}` vs the edge function's `channel_{id}`). So the membership gap is latent, not live — but if that route is ever put on the hot path, both the membership check and the room-name mismatch must be resolved together or participants will be split across two rooms.

---

### MEDIUM-4 — WS origin check fails open when unconfigured — ✅ FIXED

`services/ws-gateway/internal/handler/websocket.go:83-85`

```go
if len(h.allowedOrigins) == 0 {
	return true // dev mode: allow all
}
```

If the origins env var is unset or misparsed in production, origin checking silently disables. Fail closed in production builds. The empty-Origin allowance at `:79-81` is a reasonable native-client accommodation and JWT auth still applies, so that part is acceptable.

**What was implemented.** `WSHandler` now carries an `isProd` flag (threaded from `cfg.IsProd()` in `cmd/gateway/main.go`), and the allow-all branch is gated on `!h.isProd`. In production an empty allowlist rejects all browser origins instead of accepting them.

Defense in depth, since a runtime check alone still leaves the service running misconfigured: `validateGateway` now refuses to start when `ENVIRONMENT=production` and `CORS_ORIGINS` is empty, so this state is unreachable in production rather than merely handled. In development a warning is logged once at startup that permissive mode is active.

Left as-is deliberately: the empty-`Origin` native-client allowance (JWT auth still applies) and the hardcoded `.flicko.tech` / `.flicko.dev` suffix match at `:92`. The latter is a latent footgun — it grants access to any subdomain of those domains regardless of configuration, so a subdomain takeover would bypass the allowlist — but removing it could break currently-working clients, so it should be a deliberate follow-up rather than folded into a security fix.

---

### MEDIUM-5 — Weak CSP on the web vhost

`nginx/conf.d/flicko.conf:379`

```
default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data: blob:;
script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:;
```

`'unsafe-inline'` plus `'unsafe-eval'` removes most of CSP's XSS value. This is the amplifier for CRITICAL-2. Move to nonce- or hash-based script policy; Next.js 15 supports nonce injection via middleware.

The API-side policy is correct by contrast — `backend/internal/middleware/security_headers.go:11` sets `default-src 'none'; frame-ancestors 'none'`, and HSTS is 2 years with `includeSubDomains; preload`.

---

### MEDIUM-6 — Backend async jobs have retries but no dead-letter path

`backend/internal/bots/asynq_coordinator.go:81-86`

```go
asynq.ProcessIn(delay), asynq.MaxRetry(3), asynq.Timeout(10*time.Second)
```

Retries exist (asynq applies exponential backoff by default), but there is no DLQ handling or alerting, and this is the only asynq task type found. `backend/internal/workers/` contains a single file (`vector_sync_worker.go`). After 3 failures a task is archived silently.

msg-service does this properly — `batcher.NewDeadLetterQueue` with a disk-backed queue, depth metrics (`services/msg-service/internal/batcher/metrics.go:52`), and lifecycle management in `main.go:128-130,265`. Port that pattern, and alert on `DeadLetterDepth`.

---

### LOW-1 — Secrets present in the working tree

`livekit.yaml:11` contains a live-looking API key/secret pair (`APIwjcPRMuEXh63` / `fs41gp...`). Confirmed **untracked**, with no git history hits — so this is not a repo leak, just local-disk exposure. Same for `doppler_secrets.json` (12KB), `.env`, `.env.prod`, `nginx/ssl/origin-key.pem`, and `secrets/` — all verified gitignored.

Only the coturn credential (HIGH-1) is actually in version control.

---

## 4. What Passed

Checked and genuinely solid — recorded so they do not get "fixed" into regressions:

- **SQL injection: clean.** Across 467 Go files, no query is built with `fmt.Sprintf` string interpolation of user data. The four `Sprintf` hits near DB code are header-name and TOTP-label construction, not SQL. The one dynamic query builder (`services/msg-service/internal/repository/channel_repo.go:153-158`) generates `$N` placeholders and passes args separately — textbook correct.
- **RLS: complete coverage.** 195 `ENABLE ROW LEVEL SECURITY` statements across 143 migrations, covering every `CREATE TABLE`. An initial automated pass flagged 10 tables (`ai_summaries`, `mod_queue_items`, `translations_cache`, et al.) as missing RLS — that was a regex artifact from multiline statements in migrations 138–140. All 10 have both RLS enabled and policies. Policy *logic* (correct `auth.uid()` scoping, no overly broad `USING (true)`) was not line-audited and remains the main open RLS question.
- **XSS: no injection sinks.** Zero `dangerouslySetInnerHTML`, `innerHTML =`, `eval(`, or `new Function(` in `Flicko-Web/src`. React's default escaping is doing the work; no sanitizer dependency is needed because no raw HTML path exists.
- **WebSocket lifecycle: correct.** `PongWait = 60s` / `PingPeriod = 54s` with the required `PingPeriod < PongWait` ordering (`services/ws-gateway/internal/conn/client.go:27-28`), read deadline refreshed in the pong handler (`:114-116`), ping ticker writing `websocket.PingMessage` (`:175,212`). Zombie connections are reaped. Concurrency uses `sync.Map` for the hot client/channel/session maps plus `sync.RWMutex` on per-channel sets — no unguarded map access found. An `IdentifyTimeout` read deadline (`handler/websocket.go:125`) blocks pre-auth connection squatting, cleared at `:193` after identify.
- **E2EE key storage.** `flutter_secure_storage ^10.0.0` (Android Keystore / iOS Keychain) backs `mobile/lib/features/e2ee/data/secure_keystore.dart`, with `cryptography ^2.7.0` + `cryptography_flutter` for primitives. A ratchet WAL store and per-device envelope schema exist (`migrations/075_dm_envelopes_per_device`), and legacy plaintext columns were dropped (`076_drop_legacy_dm_ciphertext_columns`) — good hygiene. The X3DH/Double Ratchet math itself was not audited; that warrants dedicated cryptographic review.
- **Rate limiting on the main backend is thorough.** Redis-backed distributed limiter at 50 rps general, plus strict tiers on the right endpoints: MFA 5/min, account deletion 3/10min, per-action creator limits (5 create, 20 delete, 30 engagement, 60 follow). CSRF, input sanitization, 10MB body cap, and 30s timeout middleware are all wired. msg-service layers per-route tiers (message create, upload, guild join) over a 50 rps base with idempotency keys on POSTs.

---

## 5. Remediation Roadmap

**Immediately (exploitable now)**

- [x] 1. Patch SSRF in `embed_service.go` — resolve-then-validate dialer, redirect cap, scheme allowlist. (CRITICAL-1)
- [x] 2. Wire magic-byte validation onto the live upload routes. (CRITICAL-2)
- [ ] 3. Rotate the coturn credential, switch to `use-auth-secret`, purge from history, add a scanner rule. (HIGH-1) — **operator action required**

**This week**

- [x] 4. Sanitize client filenames before they reach a storage key. (HIGH-2)
- [x] 5. Make msg-service CORS config-driven; fix the multi-origin bug and add `Vary: Origin`. (MEDIUM-1)
- [ ] 6. Audit the ~143 routes for actual permission enforcement; resolve `main.go:279`. (MEDIUM-2)
- [x] 7a. Drop LiveKit token TTLs to 15 min. (MEDIUM-3)
- [ ] 7b. Assert channel membership at mint time — see the MEDIUM-3 note: the production issuer is the Supabase edge function, which already enforces membership, so this applies only if the msg-service route is put on the hot path.

**This month**

- [ ] 8. Retire the HS256 auth path; consolidate on EdDSA + Redis refresh revocation. (HIGH-3)
- [x] 9. Fail-closed WS origin checking in production. (MEDIUM-4)
- [ ] 10. Nonce-based CSP for the web vhost. (MEDIUM-5)
- [ ] 11. DLQ + depth alerting for backend asynq, modeled on msg-service's batcher. (MEDIUM-6)
- [ ] 12. Either implement the three stub ws-gateway packages or delete them so the doc comments stop describing absent behavior.
- [ ] 17. Decide the fate of `internal/services/attachment_service.go` — it is never constructed or routed (dead code), so its upload path is unreachable. It was hardened anyway, but it should be wired up or removed rather than left ambiguous.

**Follow-up audits not completed here**

- [ ] 13. Line-by-line RLS *policy* review — the highest-value remaining security work, since coverage is complete but correctness is unverified.
- [ ] 14. Per-column FK index analysis. Raw counts (424 `REFERENCES` vs 348 `CREATE INDEX` vs 325 `ON DELETE CASCADE`) cannot distinguish covered from uncovered without column-level comparison; the high cascade count makes missing FK indexes a real risk on delete.
- [ ] 15. Complete Tier A/B/D feature matrix against `missing-features/`.
- [ ] 16. Cryptographic review of the X3DH/Double Ratchet implementation.
