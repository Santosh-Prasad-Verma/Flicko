# Authentication Endpoints

> **Reading time:** ~5 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

Because Flicko delegates core identity provision to Supabase Auth, you do not POST credentials directly to the Flicko Go backend. Instead, you interact with the Supabase GoTrue API to obtain JWTs, and then secure your Flicko API requests with those tokens.

---

## 1. Register a New Account
Registers a new user with Supabase Auth.

**POST** `https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co/auth/v1/signup`

**Headers:**
```http
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
```

**Body:**
```json
{
  "email": "user@example.com",
  "password": "strongPassword123!",
  "data": {
    "username": "new_user"
  }
}
```

*Note: The `data.username` field is intercepted by a Postgres trigger to populate the `public.users` table instantly.*

---

## 2. Login (Exchange Email/Password for Token)
Authenticates a user and issues Access/Refresh tokens.

**POST** `https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co/auth/v1/token?grant_type=password`

**Headers:**
```http
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
```

**Body:**
```json
{
  "email": "user@example.com",
  "password": "strongPassword123!"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUz...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "fLqYz...",
  "user": {
    "id": "db3a2b10...",
    "email": "user@example.com"
  }
}
```

---

## 3. Using the Access Token
Once you possess the `access_token`, include it in the `Authorization` header for all requests to the Flicko Go backend.

**GET** `https://api.flicko.app/api/v1/users/@me`

**Headers:**
```http
Authorization: Bearer eyJhbGciOiJIUz...
Content-Type: application/json
```

---

## 4. Refreshing an Expired Token
When the Go backend begins returning `401 Unauthorized` (after ~1 hour), you must exchange your persistent `refresh_token` for a new pair.

**POST** `https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co/auth/v1/token?grant_type=refresh_token`

**Headers:**
```http
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
```

**Body:**
```json
{
  "refresh_token": "fLqYz..."
}
```

---

For deeper architectural context, read the [Authentication Architecture](../architecture/authentication-flow.md) document.
