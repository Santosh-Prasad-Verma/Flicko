# API Error Codes

> **Reading time:** ~10 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

The Flicko API embraces predictable error handling. Whenever an API request fails (HTTP Status `>= 400`), it returns a standardized JSON object. This document maps HTTP Status codes to internal algorithmic error codes.

---

## Standard Error Response Schema

```json
{
  "error": {
    "code": "STRING_ENUM",
    "message": "Human readable explanation",
    "details": [{"field": "string", "error": "string"}],
    "request_id": "REQ_UUID"
  }
}
```

---

## 400 Bad Request

These errors indicate that your client sent a malformed request, invalid JSON, or failed input validation.

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `invalid_json` | The request body could not be parsed as JSON. | Check syntax, trailing commas, quoting. |
| `validation_failed` | One or more fields failed struct validation (e.g., username too short). | Check the `details` array in the response for specific fields. |
| `invalid_uuid` | A path parameter UUID was malformed. | Ensure IDs include hyphens and are 36 chars. |
| `parameter_missing` | A required query parameter (`?limit=`) is missing. | Provide the parameter. |

---

## 401 Unauthorized

These errors relate to Identity verification (JWT integrity).

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `missing_auth_header` | The `Authorization` header is entirely missing. | Pass `Authorization: Bearer <token>`. |
| `invalid_token` | The JWT signature is invalid or tampered with. | Obtain a new token via login. |
| `token_expired` | The JWT's `exp` claim is in the past. | Execute the Refresh Token flow. |

---

## 403 Forbidden

These errors confirm you are securely logged in, but you lack the Role-Based Access Control (RBAC) permissions to perform the action.

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `missing_permission` | Your role lacks the required bitfield flag (e.g., `SEND_MESSAGES`). | Contact a server admin to upgrade your role. |
| `feature_locked` | The feature requires Flicko Plus subscription. | Upgrade account billing. |
| `interaction_blocked` | You cannot DM this user because they blocked you. | None. Target user must unblock. |
| `csrf_failed` | Missing or invalid `X-CSRF-Token` header on a mutation. | Append header to POST/PUT/PATCH/DELETE. |

---

## 404 Not Found

The requested resource doesn't exist, OR you do not have permission to view that it exists (to prevent enumeration).

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `resource_not_found` | The UUID does not exist in the database. | Verify the ID. |
| `route_not_found` | The URL path is definitively wrong. | Verify spelling and API version (`/v1/`). |

---

## 429 Too Many Requests

The Edge or internal Redis limiter has flagged the client.

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `rate_limited` | Exceeded typical sliding window quota. | Read `X-RateLimit-Reset` and delay requests. |
| `brute_force_lock` | Targeted lockout due to rapid repetition of auth/admin endpoints. | Wait typically 15-60 minutes. |

---

## 500 Internal Server Error

The backend experienced a crash, timeout, or database connectivity failure. These trigger PagerDuty alerts for our engineers.

| `code` | Description | Typical Fix |
|--------|-------------|-------------|
| `internal_server_error` | Generic unhandled panic or SQL error. | Check statuspage; retry later. |
| `dependency_timeout` | Timed out waiting for Supabase Database or Upstash Redis. | Retry with exponential backoff. |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
