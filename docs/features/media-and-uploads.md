# Media & Uploads

> **Reading time:** ~12 minutes · **Audience:** Frontend Developers, Backend Developers · **Last Updated:** 2026-04-24

This document covers how Flicko handles user-generated media efficiently without overwhelming the backend bandwidth. We utilize Cloudinary as an edge CDN and GIPHY for dynamic integrations.

---

## Table of Contents

- [The Direct Upload Architecture](#the-direct-upload-architecture)
- [Message Attachments](#message-attachments)
- [Image Transformations](#image-transformations)
- [GIF Integration](#gif-integration)

---

## The Direct Upload Architecture

## The Core Principle: SDK-Direct Uploads
Flicko uses **SDK-Direct Uploads** via **Appwrite Storage**. This means the mobile client uploads media files directly to Appwrite's S3-compatible buckets using the Appwrite Flutter SDK.

### Why this approach?
- **Reduced Backend Load:** The Go backend doesn't handle binary file streams.
- **Scalability:** Managed storage scales horizontally without infrastructure work.
- **Security:** Appwrite provides fine-grained permissions for individual buckets and files.
- **Performance:** Multi-part uploads and chunked processing are handled natively by the Appwrite SDK.

## Technical Flow: Appwrite Migration

The system uses `AppwriteStorageService` in the mobile app to handle all interactions.

### 1. Initialization
The `AppwriteStorageService` is initialized with the project ID and endpoint configured via `AppConfig`.

### 2. Upload Flow
The client performs the following steps:
1.  Initialize `Storage` object from the Appwrite SDK.
2.  Use `storage.createFile()` with the appropriate `bucketId`.
3.  Store the returned `fileId` in the backend database via a message or profile update request.

```dart
// Example Upload Snippet
final file = await storage.createFile(
  bucketId: AppConfig.appwriteMessageBucketId,
  fileId: ID.unique(),
  file: InputFile.fromPath(path: filePath),
);
```

### 3. Fetching Content
Media is served using the Appwrite file preview or download URLs.
- **Avatars:** `appwrite/storage/buckets/[AVATAR_BUCKET]/files/[FILE_ID]/view`
- **Messages:** `appwrite/storage/buckets/[MESSAGE_BUCKET]/files/[FILE_ID]/view`

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

By storing the `width` and `height` alongside the URL, the Flutter app can compute the correct aspect ratio and reserve UI space *before* the image finishes downloading, completely preventing layout shift in the chat timeline.

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

*Last Updated: 2026-04-24 | Version: 1.1.0 | Maintained by: Media Infrastructure Team*
