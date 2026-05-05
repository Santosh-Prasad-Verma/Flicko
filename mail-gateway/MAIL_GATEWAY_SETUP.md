# Mail Gateway Deployment Guide

## ✅ What Was Added

1. **docker-compose.prod.yml**: Added `mail-gateway` service
2. **nginx/nginx.conf**: Added `mail_gateway` upstream
3. **nginx/conf.d/flicko.conf**: Added `/mail/` location route

---

## 🚀 Deployment Steps

### 1. Configure Environment Variables

Add to your `.env` file:

```bash
# SMTP Configuration (Brevo)
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USERNAME=your-brevo-username@smtp-brevo.com
SMTP_PASSWORD=xkeysib-your-long-api-key
SMTP_FROM=noreply@focko.tech   # Must be a verified domain in Brevo

# Webhook Secret (generate with: openssl rand -hex 32)
WEBHOOK_SECRET=your-random-secret-here

# Domain
DOMAIN=flicko.focko.tech
```

1. Go to: https://app.brevo.com/settings/keys/smtp
2. Create a new SMTP Key
3. Copy the key and use as `SMTP_PASSWORD`
4. Ensure your sender domain (`focko.tech`) is verified in Brevo

### 3. Generate Webhook Secret

```bash
openssl rand -hex 32
```

Copy the output and add to `.env` as `WEBHOOK_SECRET`

### 4. Deploy Mail Gateway

```bash
cd /home/tarun/Videos/Flicko

# Build and start mail-gateway
docker compose -f docker-compose.prod.yml up -d --build mail-gateway

# Restart NGINX to load new configuration
docker compose -f docker-compose.prod.yml restart nginx

# Check logs
docker compose -f docker-compose.prod.yml logs -f mail-gateway
```

### 5. Configure Supabase Auth Hook

1. Go to **Supabase Dashboard** → **Authentication** → **Hooks**
2. Click **"Create an auth hook"**
3. Configure:
   - **Name**: `flicko-mail-gateway`
   - **Hook type**: **Send Email**
   - **Enabled**: ✅ Toggle ON
   - **HTTP endpoint**: `https://flicko.focko.tech/mail/hooks/email`
   - **HTTP Headers**: `Content-Type: application/json`
   - **Secrets**:
     - Key: `webhook_secret`
     - Value: [same as WEBHOOK_SECRET from .env]
    - **Events to trigger**:
      - ✅ `auth.signup`
      - ✅ `auth.recovery` (Password Reset)
      - ✅ `auth.magiclink`
      - ✅ `auth.email_change`
      - ✅ `auth.invite`
      - ✅ `auth.reauthentication`
    - **Timeout**: `5000` ms
4. **Enable OTP Support**: In Supabase Auth Settings → Email Templates, ensure you use `{{ .Token }}` in your message bodies if you want 6-digit codes to appear.
5. Click **"Create hook"**

---

## 🧪 Testing

### 1. Check Service Health

```bash
# Check if mail-gateway is running
docker compose -f docker-compose.prod.yml ps mail-gateway

# Test health endpoint
curl https://flicko.focko.tech/mail/health
# Expected: {"status":"ok"}
```

### 2. Test Email Sending

1. Open your Flutter app
2. Sign up with a new email address
3. Check logs:
   ```bash
   docker compose -f docker-compose.prod.yml logs -f mail-gateway
   ```
4. Look for:
   ```
   webhook received type=signup email=user@example.com
   welcome email queued alongside verification
   email sent successfully
   ```

### 3. Check Inbox

You should receive **2 emails**:
1. **Verification email** (verify.html template)
2. **Welcome email** (welcome.html template) ✅

---

## 📧 Email Templates

Your mail-gateway includes beautiful Discord-style templates:

- `templates/verify.html` - Email verification
- `templates/welcome.html` - Welcome message (sent on signup)
- `templates/reset.html` - Password reset
- `templates/magic_link.html` - Magic link login
- `templates/confirm_email_change.html` - Email change confirmation

---

## 🐛 Troubleshooting

### Mail gateway not receiving webhooks

**Check NGINX routing**:
```bash
docker compose -f docker-compose.prod.yml logs nginx | grep mail
```

**Test webhook endpoint directly**:
```bash
curl -X POST https://flicko.focko.tech/mail/hooks/email \
  -H "Content-Type: application/json" \
  -H "x-supabase-signature: test" \
  -d '{"type":"signup","user":{"email":"test@example.com"}}'
```

### Emails not sending

**Check SMTP credentials**:
```bash
docker compose -f docker-compose.prod.yml exec mail-gateway env | grep SMTP
```

**Check mail-gateway logs**:
```bash
docker compose -f docker-compose.prod.yml logs mail-gateway | grep -i error
```

**Common issues**:
- ❌ Gmail App Password incorrect → Regenerate
- ❌ 2FA not enabled on Gmail → Enable it
- ❌ SMTP_PORT wrong → Use 587 for TLS
- ❌ Firewall blocking port 587 → Check VPS firewall

### Webhook signature verification fails

**Check webhook secret matches**:
1. In `.env`: `WEBHOOK_SECRET=abc123...`
2. In Supabase Hook: `webhook_secret` = `abc123...`

They must be **exactly the same**.

---

## 📊 Monitoring

### View Logs

```bash
# Real-time logs
docker compose -f docker-compose.prod.yml logs -f mail-gateway

# Last 100 lines
docker compose -f docker-compose.prod.yml logs --tail=100 mail-gateway

# Filter for errors
docker compose -f docker-compose.prod.yml logs mail-gateway | grep ERROR
```

### Check Queue Status

Mail-gateway uses an in-memory queue with 4 workers. Check logs for:
```
queue size: 5/1000
worker 1: sending email to user@example.com
email sent successfully in 1.2s
```

---

## 🎉 Success Indicators

✅ Mail-gateway container running  
✅ Health endpoint returns `{"status":"ok"}`  
✅ Supabase webhook shows "Success" status  
✅ Logs show "webhook received" and "email sent"  
✅ User receives verification + welcome emails  

---

## 📝 Notes

- **Welcome emails** are sent automatically on signup alongside verification emails
- **Email templates** are Discord-style with beautiful gradients and branding
- **Queue size**: 1000 emails max (configurable via `QUEUE_SIZE`)
- **Workers**: 4 concurrent senders (configurable via `WORKER_COUNT`)
- **Retry**: 3 attempts per email (configurable via `RETRY_MAX`)
- **Memory**: 256 MB limit (sufficient for 1000 queued emails)

---

## 🔗 Related Documentation

- [Mail Gateway Architecture](mail-gateway/docs/architecture.md)
- [Email Templates](mail-gateway/templates/)
- [Supabase Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)
