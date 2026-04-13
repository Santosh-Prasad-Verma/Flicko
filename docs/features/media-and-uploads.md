# Media & Uploads

> **Reading time:** ~10 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

This document covers how Flicko handles user-generated media efficiently without overwhelming the backend bandwidth. We utilize Cloudinary as an edge CDN and GIPHY for dynamic integrations.

---

## Table of Contents

- [The Direct Upload Architecture](#the-direct-upload-architecture)
- [Message Attachments](#message-attachments)
- [Image Transformations](#image-transformations)
- [GIF Integration](#gif-integration)

---

## The Direct Upload Architecture

If clients uploaded large videos directly to our Go `backend`, it would require vast bandwidth, massive RAM buffers, and slow down other API requests. Instead, we use Cloudinary's "Direct Upload" capability. The backend authorizes the upload without ever touching the actual file bytes.

### Step-by-Step Flow

1. **Client Request:** The React Native app requests a signature: `GET /api/v1/upload/signature?folder=avatars`
2. **Backend Signing:** The Go backend validates the user's JWT. It reads the server's Unix timestamp, appends the folder name, and generates an HMAC-SHA256 signature using the secret `CLOUDINARY_API_SECRET`.
3. **Response:** Backend returns `{ signature: "xyz", timestamp: 1712800000, api_key: "abc" }`.
4. **Direct POST:** The mobile app constructs a `multipart/form-data` request containing the physical image file and the signature, and POSTs it directly to `https://api.cloudinary.com/v1_1/<cloud_name>/image/upload`.
5. **CDN Storage:** Cloudinary verifies the signature, stores the file, and returns a secure `secure_url`.
6. **API Usage:** The mobile app takes that URL and includes it when making its next Flicko API request (e.g., `PATCH /api/v1/users/@me` to update their avatar).

---

## Message Attachments

Messages support an array of JSON objects representing attachments.

```json
{
  "content": "Look at my cat!",
  "attachments": [
    {
      "url": "https://res.cloudinary.com/.../cat.jpg",
      "type": "image/jpeg",
      "size": 1048576,
      "width": 1920,
      "height": 1080
    }
  ]
}
```

By storing the `width` and `height` alongside the URL, the React Native app can compute the correct aspect ratio and reserve UI space *before* the image finishes downloading, completely preventing layout shift in the chat timeline.

---

## Image Transformations

Cloudinary sits as an active transformation layer. We never serve raw user avatars to the chat interface.

When rendering an avatar, the mobile app modifies the base URL to request a transformed version:
```
Original: https://res.cloudinary.com/demo/image/upload/user_avatar.jpg
Requested: https://res.cloudinary.com/demo/image/upload/c_fill,w_128,h_128,f_avif/user_avatar.jpg
```

**Applied Optimizations:**
- `c_fill`: Center-crops non-square images perfectly.
- `w_128, h_128`: Downsides high-res images to exactly the pixel density needed for UI avatars.
- `f_avif` / `f_webp`: Transcodes older formats into modern, hyper-efficient codecs on the fly.

This saves terabytes of egress bandwidth and massively speeds up initial app loading times.

---

## GIF Integration

Flicko embeds the GIPHY API for searching and sending animated GIFs in chat.

To protect the GIPHY API keys from being extracted from the mobile binary or intercepted, the integration relies on a secure Supabase Edge Function (`supabase/functions/gif-search`).

### Execution Path
1. User types "Happy Birthday" into the GIF search bar.
2. Mobile app calls `GET https://project-ref.supabase.co/functions/v1/gif-search?q=Happy+Birthday` with their Supabase Auth Bearer token.
3. The Edge Function verifies the JWT.
4. The Edge Function injects the secure `GIPHY_API_KEY` (stored in Supabase Vault) and queries the official GIPHY API.
5. The Edge Function maps the complex GIPHY response into a simplified array of URLs, saving mobile bandwidth.
6. Mobile app displays the grid of GIFs. When tapped, it sends a standard message with the URL embedded.

---

## Related Documentation

- [Architecture: Third-Party Integrations](../architecture/third-party-integrations.md) — More details on Cloudinary
- [Backend: Security](../security/middleware.md) — How the upload signature endpoint enforces rate limits

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
