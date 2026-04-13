# API Overview

> **Reading time:** ~5 minutes · **Audience:** API Consumers, Frontend Developers · **Last Updated:** 2026-04-11

Welcome to the Flicko REST API Reference. Our API is organized around standard REST principles and features predictable, resource-oriented URLs.

---

## The Base URL

All API requests MUST be made over HTTPS. Plain HTTP requests are rejected by Cloudflare and NGINX.

```text
https://api.flicko.app/api/v1/
```

If testing locally via Docker Compose, the base URL is:
```text
http://localhost:8080/api/v1/
```

---

## Authentication Required

Nearly all API endpoints require authentication via a Bearer JWT issued by Supabase Auth.

```http
Authorization: Bearer <your-jwt-token>
```

All mutating endpoints (POST, PUT, PATCH, DELETE) also require CSRF protection headers if originating from a web client.

See [Authentication Header Specs](authentication.md) for deeper implementation details.

---

## Data Formats

1. **JSON Validation:** The API strictly adheres to `application/json` for both request payloads and responses. You must ensure your `Content-Type` and `Accept` headers are correctly set.
2. **Dates:** Timestamps are strictly formatted as ISO 8601 strings in UTC (`Zulu`) time. Example: `2026-04-11T12:00:00Z`.
3. **Identifiers:** All resource IDs are UUIDv4. Supplying malformed IDs will result in a fast-path 400 Bad Request error.
4. **Snowflakes:** Unlike Discord which uses Integer Snowflakes, Flicko relies entirely on Postgres UUIDs for global uniqueness and unguessability.

---

## Rate Limiting

The Flicko API utilizes a Redis-backed sliding window rate limiter to protect infrastructure stability.

### Default Quotas
- **Global Read Limit:** 100 requests per 10 seconds per IP/Token.
- **Global Write Limit:** 20 requests per 10 seconds per IP/Token.
- **Authentication Routes:** 5 requests per minute.

### Response Headers
Every API response includes diagnostic headers indicating your current rate limit standing:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1712850000
```
If you exceed a quota, the API will immediately return HTTP `429 Too Many Requests`.

---

## Navigating the Reference

The API documentation is divided logically by Resource. Select a resource below to view specific endpoints, schemas, and examples.

- [Authentication & Identity](authentication.md)
- [User Profiles & Social](users.md)
- [Servers (Guilds)](servers.md)
- [Channels](channels.md)
- [Messages & History](messages.md)
- [Bots & Webhooks](bots-and-webhooks.md)

If you encounter an error, consult the [Global Error Codes Reference](error-codes.md) to understand mapping between `HTTP Status Codes` and our internal `error_code` strings.

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
