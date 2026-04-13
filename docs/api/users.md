# Users API

> **Reading time:** ~5 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

The Users API allows fetching and mutating profile information. Users cannot mutate the profiles of others.

---

## 1. Get Current User

Returns the profile belonging to the active JWT.

**GET** `/api/v1/users/@me`

**Response (200 OK):**
```json
{
  "id": "db3a2b10-67cc-44a1-b847-19fc2ef3a774",
  "username": "tarun",
  "display_name": "Tarun",
  "avatar_url": "https://res.cloudinary.com/...",
  "banner_url": null,
  "bio": "Building Flicko",
  "status_text": "Coding...",
  "status_emoji": "👨‍💻",
  "is_premium": true,
  "created_at": "2026-01-01T00:00:00Z"
}
```

---

## 2. Get User Profile

Fetches the public profile of another user by their UUID. Does not return private fields like billing status.

**GET** `/api/v1/users/{user_id}`

**Response (200 OK):**
```json
{
  "id": "uuid-here",
  "username": "alex",
  "display_name": "Alex",
  "avatar_url": "https://res.cloudinary.com/...",
  "bio": "Hello there",
  "badges": ["early_supporter"]
}
```

---

## 3. Update Current User Profile

Mutates the current user's profile. All fields are optional; only provided fields will be updated.

**PATCH** `/api/v1/users/@me`

**Body:**
```json
{
  "display_name": "Tarun V2",
  "bio": "New bio!",
  "status_text": "Online but busy"
}
```

**Response (200 OK):** Returns the fully hydrated, updated User object.

*Note: To update an `avatar_url`, you must first run the Image via the Direct Upload endpoint to Cloudinary, and pass the resulting secure URL to this PATCH endpoint.*
