# Cloudinary Signing Endpoint
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## GET /api/v1/cloudinary/sign
**Description:** Generate signed upload parameters for direct Cloudinary upload.
**Authentication:** Bearer JWT required.

**Success Response (200):**
```json
{
  "cloud_name": "your_cloud",
  "api_key": "123456",
  "signature": "abc123def",
  "timestamp": 1712000000,
  "upload_preset": "flickochat_media"
}
```

The client then uploads directly to `https://api.cloudinary.com/v1_1/{cloud_name}/auto/upload` with these signed parameters. No file data passes through the Flicko backend.

**File:** `backend/internal/handlers/cloudinary.go`
