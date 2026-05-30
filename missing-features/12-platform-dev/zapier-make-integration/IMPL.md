# IMPL: Zapier and Make Integration

## Backend Layout
```
backend/internal/oauth/
├── module.go
├── handler/
│   ├── authorize.go        -- consent screen, code issue
│   ├── token.go            -- token + refresh
│   └── revoke.go
├── service/
│   ├── client.go
│   ├── token.go            -- hashing, rotation
│   └── consent.go
└── repository/
    ├── clients.go
    └── tokens.go

backend/internal/zapier/
├── module.go
├── handler/
│   ├── subscribe.go
│   ├── actions/
│   │   ├── messages.go
│   │   ├── members.go
│   │   ├── channels.go
│   │   └── events.go
│   ├── searches.go
│   └── samples.go
├── triggers/
│   ├── dispatcher.go
│   ├── filter.go
│   ├── delivery.go         -- POST + retry
│   ├── signer.go           -- HMAC
│   └── loop_detect.go
├── service/
│   ├── subscription.go
│   ├── action_runner.go
│   └── idempotency.go
└── repository/
    ├── subscriptions.go
    ├── actions.go
    └── deliveries.go
```

## Key Interfaces

```go
// Token verifies and exposes scopes/server allowlist.
type Token struct {
    ID        uuid.UUID
    UserID    uuid.UUID
    ClientID  string
    Scopes    []string
    Servers   []uuid.UUID
    ExpiresAt time.Time
}

func (t *Token) Allows(scope string, serverID uuid.UUID) bool { ... }

// Action handlers all share this signature.
type ActionFunc func(ctx context.Context, tok *Token, body json.RawMessage) (any, error)

// Subscription dispatch
type Delivery struct {
    SubscriptionID uuid.UUID
    Payload        []byte
    Attempt        int
}
```

## Delivery Worker

```go
func (w *Worker) Run(ctx context.Context, d Delivery) error {
    sub, err := w.repo.Get(ctx, d.SubscriptionID)
    if err != nil { return err }

    sig := w.signer.Sign(d.Payload, sub.Secret)
    req, _ := http.NewRequestWithContext(ctx, "POST", sub.TargetURL, bytes.NewReader(d.Payload))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Flicko-Signature", sig)
    req.Header.Set("X-Flicko-Event", sub.EventType)

    start := time.Now()
    resp, err := w.client.Do(req)
    dur := time.Since(start)

    w.repo.RecordAttempt(ctx, sub.ID, d.Attempt, resp, err, dur)
    if err != nil || resp.StatusCode >= 500 {
        return w.scheduleRetry(ctx, d, sub)
    }
    if resp.StatusCode == 410 {
        return w.repo.MarkRevoked(ctx, sub.ID)
    }
    w.repo.RecordSuccess(ctx, sub.ID)
    return nil
}
```

## Zapier App (Node)
```
integrations/zapier/
├── package.json            -- zapier-platform-core ^15
├── index.js                -- App definition
├── authentication.js       -- OAuth 2.0 config
├── triggers/
│   ├── messageCreated.js
│   ├── memberJoined.js
│   ├── reactionAdded.js
│   └── ... (10 files)
├── creates/
│   ├── sendMessage.js
│   ├── sendDm.js
│   ├── addRole.js
│   └── ... (10 files)
├── searches/
│   ├── findUser.js
│   └── findChannel.js
├── helpers/
│   ├── dynamic.js          -- channel/role pickers
│   └── sample.js
└── test/                   -- jest unit tests
```

`authentication.js` snippet:
```js
module.exports = {
  type: 'oauth2',
  oauth2Config: {
    authorizeUrl: { url: 'https://auth.flicko.app/oauth/authorize',
      params: { client_id: '{{process.env.CLIENT_ID}}',
                state: '{{bundle.inputData.state}}',
                redirect_uri: '{{bundle.inputData.redirect_uri}}',
                response_type: 'code' } },
    getAccessToken: { url: 'https://api.flicko.app/oauth/token', method: 'POST', ... },
    refreshAccessToken: { ... },
    autoRefresh: true,
    scope: 'messages.send messages.read members.read channels.read'
  },
  test: { url: 'https://api.flicko.app/api/v1/me' }
};
```

## Make App
```
integrations/make/
├── app.json                -- top-level metadata
├── connections/
│   └── oauth2.imljson
├── modules/
│   ├── trigger-message-created.imljson
│   ├── action-send-message.imljson
│   └── ... (one per module)
└── functions/
    └── helpers.iml
```

## Tests
- Backend unit: `oauth/service_test.go`, `zapier/triggers/dispatcher_test.go` with mocked HTTP server using `httptest.NewServer`.
- Backend integration: spin up Postgres test container, register a fake OAuth client, simulate trigger and outbound delivery, assert counters.
- Zapier app: jest tests using `zapier test`. Mocked HTTP client recordings.
- Make app: validated via Make's CLI lint plus manual scenario test in dev workspace.

## Rollout
1. Migration 244 deployed behind flag `zapier_integration_enabled`.
2. Submit Zapier app for "Beta" review, share invite link with 50 power users.
3. Submit Make app for review.
4. Approved Zapier app moves to "Public" after 100 active users and 4.0+ rating.
5. Marketing launch: blog post, template gallery, in-app banner for Pro tier admins.

## Telemetry to Watch
- Successful auth completion rate from consent screen.
- Outbound delivery success rate per partner.
- Distribution of trigger types used.
- Dead-letter rate and time-to-resolution.
- Action API rate-limit hit rate per token.

## Open Tickets at Ship
- IFTTT app definition.
- Per-Zap analytics inside Flicko (we currently rely on partner analytics).
- Granular per-channel scopes (current scopes are server-wide).
- Webhook signing key rotation UI.
