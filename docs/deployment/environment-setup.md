# Deployment: Environment Setup

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Production Environment Configuration

### Step 1: Create .env file
```bash
cp .env.production.example .env
```

### Step 2: Fill in required values

**Database (Supabase):**
```env
DATABASE_URL=postgresql://postgres.XXXX:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres?sslmode=require
```
- Use port **6543** (Supavisor connection pooler), NOT 5432
- Use `sslmode=require` for encrypted connections

**Redis (Upstash):**
```env
REDIS_URL=rediss://default:TOKEN@HOST.upstash.io:6379
```
- Must use `rediss://` (with double s) for TLS

**Cloudinary:**
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

**Grafana:**
```env
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
```

### Step 3: Generate JWT Keys
```bash
./scripts/generate-jwt-keys.sh
```
This creates `secrets/jwt_public.pem` and `secrets/jwt_private.pem`.

### Step 4: Obtain Cloudflare Origin Certificates
1. Go to Cloudflare Dashboard → SSL/TLS → Origin Server
2. Create certificate for `*.flicko.dev` and `flicko.dev`
3. Save as `secrets/origin.pem` and `secrets/origin-key.pem`

---

## Related Docs
- [Configuration](../getting-started/configuration.md) — Complete env var reference
- [Docker](docker.md) — Container configuration
