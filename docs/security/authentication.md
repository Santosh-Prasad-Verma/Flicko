# Security: Authentication

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Authentication Architecture

Flicko uses **Supabase Auth** as the primary identity provider, with **JWT-based token authentication** for all API requests. The authentication flow involves three components working together:

1. **Supabase Auth** — Handles user registration, login, password hashing, and token issuance
2. **Go Backend** — Validates JWT tokens on every protected request
3. **Mobile App** — Manages session state, token storage, and automatic refresh

---

## Authentication Methods

### Email/Password
The primary auth method. Supabase handles:
- bcrypt password hashing (cost factor 10)
- Email verification (configurable)
- Password reset flow via email

### OAuth Providers
Configured via Supabase Dashboard:
- Google
- GitHub
- Discord
- Apple (Sign in with Apple, iOS)

### Biometric (Optional)
File: `mobile/services/biometrics.service.ts`

After initial password auth, users can enable Face ID / fingerprint unlock via `expo-local-authentication`. Biometric auth unlocks a locally stored session — it does not replace server-side JWT validation.

---

## JWT Token System

### Token Types
| Token | TTL | Purpose |
|-------|-----|---------|
| Access token | 15 minutes (`JWT_ACCESS_TTL`) | API authentication |
| Refresh token | 30 days (`JWT_REFRESH_TTL`) | Obtain new access tokens |

### Token Claims
```json
{
    "sub": "user-uuid",
    "iss": "flicko.dev",
    "aud": "authenticated",
    "exp": 1712000900,
    "iat": 1712000000,
    "email": "user@example.com",
    "role": "authenticated"
}
```

### Token Validation (Backend)
File: `backend/internal/services/auth.go` (5.2 KB)

The `AuthService.ValidateToken()` method:
1. Parses the JWT using `golang-jwt/jwt/v5`
2. Validates signature with HMAC-SHA256 using `JWT_SECRET`
3. Checks `exp` (expiration), `iss` (issuer), `aud` (audience) claims
4. If HMAC validation fails (e.g., after key rotation), falls back to Supabase API verification
5. Returns the user ID string on success, error on failure

### Token Refresh
The mobile app's `AuthGate` (`mobile/app/_layout.tsx`) listens for `TOKEN_REFRESHED` events from Supabase. If refresh fails:
1. Session is cleared
2. User is redirected to login
3. A warning is logged

---

## Session Management

### Mobile (Client-Side)
File: `shared/stores/authStore.ts` (6.5 KB)

The `authStore` manages:
- `user` — Current user object
- `session` — Supabase session (access + refresh tokens)
- `isAuthenticated` — Boolean auth state
- `initialized` — Whether initial session check completed
- `isSessionExpired()` — Checks token expiry

Tokens are persisted in Flutter SecureStore (encrypted device storage).

### Backend (Server-Side)
File: `backend/internal/services/session_service.go` (7.3 KB)

Server-side session tracking:
- Active sessions stored in Redis with TTL
- Multi-device support (multiple sessions per user)
- Session revocation on password change
- IP address and device info logging

---

## CSRF Protection
File: `backend/internal/middleware/security.go` (lines 18-51)

All state-changing requests (POST, PUT, DELETE, PATCH) must include a valid `X-CSRF-Token` header. The token must be ≥16 characters. This prevents cross-site request forgery attacks.

---

## Security Hardening

| Measure | Implementation |
|---------|---------------|
| **Password strength** | `password_validator.go` — length, complexity, entropy checks |
| **Rate limiting on auth** | NGINX: 5 req/min per IP on `/auth/*` |
| **Account lockout** | Supabase built-in brute-force protection |
| **Secure token storage** | Flutter SecureStore (iOS Keychain, Android Keystore) |
| **Token rotation** | Automatic refresh before expiry, fallback verification |

---

## Related Docs
- [Security Overview](overview.md)
- [Authorization](authorization.md)
- [Authentication Flow](../architecture/authentication-flow.md)
