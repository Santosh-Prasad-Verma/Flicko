# ✅ Flicko Mail Gateway — Complete Implementation

A production-grade Go mail server that intercepts **Supabase Auth webhooks** and sends emails via **Gmail SMTP**. Replaces Supabase's 3/hr email limit with unlimited custom sending.

---

## File Structure

```
mail-gateway/
├── cmd/server/main.go               ✅ Entry point: wiring + graceful shutdown
├── internal/
│   ├── config/config.go             ✅ Env loading, fail-fast validation
│   ├── handler/
│   │   ├── hook_handler.go          ✅ HMAC-SHA256 webhook + routing + queue push
│   │   └── health_handler.go        ✅ GET /health — queue stats + uptime
│   ├── mailer/
│   │   ├── mailer.go                ✅ Mailer interface (swappable)
│   │   ├── smtp_mailer.go           ✅ Gmail SMTP via net/smtp, RFC 2822 MIME
│   │   └── mock_mailer.go           ✅ Test double with thread-safe recording
│   ├── models/
│   │   ├── hook_payload.go          ✅ Supabase webhook payload structs
│   │   ├── email_job.go             ✅ Queue job + EmailData structs
│   │   └── errors.go                ✅ Sentinel errors for validation
│   ├── middleware/ratelimit.go       ✅ 60 req/min per IP (httprate)
│   ├── queue/
│   │   ├── email_queue.go           ✅ Buffered chan — non-blocking enqueue
│   │   └── worker_pool.go           ✅ 3 workers, exponential backoff (1s/2s/4s)
│   └── templates/renderer.go        ✅ html/template loader (XSS-safe)
├── templates/
│   ├── verify.html                  ✅ Indigo — "Verify Email Address"
│   ├── reset.html                   ✅ Purple — "Reset Password"
│   └── magic_link.html              ✅ Green — "Log In Now"
├── tests/unit/
│   ├── handler_test.go              ✅ 9 handler test cases
│   └── queue_test.go                ✅ 9 queue test cases
├── .env.example                     ✅ All vars documented
├── Dockerfile                       ✅ Multi-stage Alpine build
├── Makefile                         ✅ run/build/test/docker targets
└── go.mod                           ✅ chi/v5, httprate, godotenv
```

---

## Verification Results

| Check | Result |
|---|---|
| `go build ./...` | ✅ Clean |
| `go vet ./...` | ✅ Clean |
| `go test ./tests/...` | ✅ All pass |
| Binary `bin/server` | ✅ Compiled |

---

## Key Features

| Feature | Details |
|---|---|
| **HMAC-SHA256 Auth** | Constant-time `hmac.Equal()` — timing-attack safe |
| **Email Queue** | Buffered `chan EmailJob` size=100, non-blocking enqueue |
| **Worker Pool** | 3 goroutines (configurable), `sync.WaitGroup` drain |
| **Retry + Backoff** | 3 attempts: 1s → 2s → 4s, log + discard on failure |
| **Graceful Shutdown** | SIGINT/SIGTERM → drain HTTP → close queue → wait workers |
| **Dev Mode** | `USE_MOCK_MAILER=true` logs emails without sending |
| **Rate Limit** | 60 req/min per IP on `/hooks/email` |
| **Health Check** | `GET /health` — queue depth, uptime, workers |

---

## Quick Start

```bash
# 1. Copy and fill env
cp .env.example .env
# Edit: SMTP_USERNAME, SMTP_PASSWORD, WEBHOOK_SECRET, SUPABASE_URL

# 2. Run server
GOTOOLCHAIN=local go run cmd/server/main.go

# 3. Expose with ngrok
ngrok http 8080

# 4. Set Supabase hook URL
# Supabase → Auth → Hooks → Add Hook → HTTP URL = https://xxx.ngrok.app/hooks/email

# 5. Test health
curl http://localhost:8080/health
```

---

## System Architecture

```mermaid
flowchart TD
    A(["👤 Client App\nReact / Flutter / Any"])
    B(["🔐 Supabase Auth\nauth.users · JWT · Sessions"])
    C(["🌐 Chi HTTP Router\nPORT 8080"])
    D(["🔏 Hook Handler\nHMAC-SHA256 verify"])
    E(["📥 Email Queue\nbuffered chan · size=100"])
    F1(["⚙️ Worker 1"])
    F2(["⚙️ Worker 2"])
    F3(["⚙️ Worker 3"])
    G(["🖼️ Template Renderer\nhtml/template XSS-safe"])
    H(["📤 SMTP Mailer\nnet/smtp · STARTTLS"])
    I(["📧 Gmail SMTP\nsmtp.gmail.com:587"])
    J(["📬 User Inbox"])

    A -- "signUp / resetPassword\n/ signInWithOtp" --> B
    B -- "POST /hooks/email\nHMAC-SHA256 signed" --> C
    C --> D
    D -- "✅ Valid signature" --> E
    D -- "❌ Bad signature" --> R401(["401 Unauthorized"])
    D -- "❌ Queue full" --> R503(["503 Retry Later"])
    E --> F1 & F2 & F3
    F1 & F2 & F3 --> G
    G --> H
    H -- "STARTTLS · Port 587" --> I
    I --> J

    style A fill:#6366f1,color:#fff
    style B fill:#3b82f6,color:#fff
    style C fill:#8b5cf6,color:#fff
    style D fill:#f59e0b,color:#fff
    style E fill:#10b981,color:#fff
    style F1 fill:#059669,color:#fff
    style F2 fill:#059669,color:#fff
    style F3 fill:#059669,color:#fff
    style G fill:#0ea5e9,color:#fff
    style H fill:#7c3aed,color:#fff
    style I fill:#dc2626,color:#fff
    style J fill:#16a34a,color:#fff
    style R401 fill:#ef4444,color:#fff
    style R503 fill:#f97316,color:#fff
```

---

## API Routes

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/hooks/email` | HMAC-SHA256 | Supabase webhook receiver |
| `GET` | `/health` | None | System health check |

---

## Email Flow Sequence

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Client App
    participant Supa as Supabase Auth
    participant GW as Go Mail Gateway
    participant Queue as Email Queue
    participant Worker as Worker Pool
    participant Gmail as Gmail SMTP

    Note over App,Supa: Flow 1 — Signup Verification
    User->>App: fills signup form
    App->>Supa: supabase.auth.signUp()
    Supa->>Supa: creates user (unverified)
    Supa->>GW: POST /hooks/email {type:signup}
    GW->>GW: verify HMAC-SHA256 signature
    GW->>Queue: Enqueue(EmailJob) ← non-blocking
    GW-->>Supa: 200 OK {message:email queued}
    Queue->>Worker: job dequeued
    Worker->>Worker: render verify.html template
    Worker->>Gmail: smtp.SendMail() STARTTLS:587
    Gmail-->>User: ✉️ Verify Email Address
    User->>Supa: clicks verify link
    Supa->>Supa: user verified ✅

    Note over App,Supa: Flow 2 — Password Reset
    User->>App: clicks Forgot Password
    App->>Supa: resetPasswordForEmail()
    Supa->>GW: POST /hooks/email {type:recovery}
    GW->>Queue: Enqueue(EmailJob)
    GW-->>Supa: 200 OK
    Queue->>Worker: job dequeued
    Worker->>Worker: render reset.html template
    Worker->>Gmail: smtp.SendMail()
    Gmail-->>User: ✉️ Reset Password

    Note over App,Supa: Flow 3 — Magic Link
    User->>App: enters email for magic link
    App->>Supa: signInWithOtp()
    Supa->>GW: POST /hooks/email {type:magiclink}
    GW->>Queue: Enqueue(EmailJob)
    GW-->>Supa: 200 OK
    Queue->>Worker: job dequeued
    Worker->>Worker: render magic_link.html template
    Worker->>Gmail: smtp.SendMail()
    Gmail-->>User: ✉️ Log In Now
    User->>Supa: clicks magic link → logged in ✅
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `SMTP_USERNAME` | ✅ Yes | Gmail address |
| `SMTP_PASSWORD` | ✅ Yes | Gmail App Password (not your login password) |
| `WEBHOOK_SECRET` | ✅ Prod | From Supabase Auth → Hooks dashboard |
| `SUPABASE_URL` | ✅ Yes | Your Supabase project URL |
| `APP_URL` | Yes | Your frontend URL for redirects |
| `PORT` | No | Default: `8080` |
| `EMAIL_WORKER_POOL` | No | Default: `3` |
| `EMAIL_QUEUE_SIZE` | No | Default: `100` |
| `USE_MOCK_MAILER` | No | Set `true` in dev to skip real sends |

---

## Gmail App Password Setup

1. Go to [myaccount.google.com](https://myaccount.google.com)
2. **Security** → **2-Step Verification** → Turn ON
3. **Security** → **App Passwords**
4. Select app: "Mail" → Device: "Other" → name it `mail-gateway`
5. Copy the 16-character password → paste as `SMTP_PASSWORD`

---

## Deployment

Deploy to Railway, Fly.io, or any Docker host. Set env vars and point Supabase hook to your public URL:

```
https://your-deployment.up.railway.app/hooks/email
```

<!-- -------------------------------------------------------------------- -->
<!-- -------------------------------------------------------------------- -->
# 1. Copy and fill env
cp .env.example .env
# Edit: SMTP_USERNAME, SMTP_PASSWORD, WEBHOOK_SECRET, SUPABASE_URL
# 2. Run server  
GOTOOLCHAIN=local go run cmd/server/main.go
# 3. Expose with ngrok
ngrok http 8080
# 4. Set Supabase hook URL
# Supabase → Auth → Hooks → Add Hook → HTTP URL = https://xxx.ngrok.app/hooks/email
# 5. Test health
curl http://localhost:8080/health