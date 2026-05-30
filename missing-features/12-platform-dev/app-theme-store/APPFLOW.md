# APPFLOW: App & Theme Store

## Submit -> Review -> Publish
```mermaid
sequenceDiagram
    participant Dev as Developer
    participant API as store-api
    participant Q as Review Queue
    participant Rev as Reviewer
    participant Reg as plugin-registry
    Dev->>API: POST /listings draft
    Dev->>API: upload assets
    Dev->>API: POST /listings/:id/submit
    API->>Q: enqueue with priority
    Rev->>Q: pull next
    Rev->>API: GET /listings/:id (incl. diff)
    Rev->>API: POST decision=approve
    API->>Reg: publish version
    API->>Dev: notify approved
    API->>API: flip status=published
```

## Purchase Flow (Paid)
```mermaid
sequenceDiagram
    participant U as User
    participant App as Mobile App
    participant API as store-api
    participant Pay as flicko-pay
    participant WH as Webhook
    U->>App: tap Buy
    App->>API: POST /listings/:id/purchase
    API->>Pay: create checkout session
    Pay-->>API: session url
    API-->>App: redirect url
    App->>Pay: WebView checkout
    U->>Pay: enter card / wallet
    Pay->>WH: payment.succeeded (HMAC)
    WH->>API: state=paid
    API->>Reg: install on server
    API->>App: push "Welcomer Pro is ready"
```

## State Machines

### Listing
```
draft -> submitted -> in_review -> [approved -> published] | [changes_requested -> draft] | [rejected -> draft]
published -> taken_down (manual)
published -> deprecated (creator)
```

### Purchase
```
pending -> [paid -> installed] | [failed -> retry|abandoned]
paid -> refund_requested -> refunded
installed -> uninstalled (does not refund)
```

### Subscription
```
trialing -> active -> [canceled at period end -> ended] | [past_due -> active|canceled]
```

## Edge Cases
- Listing approved but plugin-registry install fails: purchase stays `paid`, retried 5 times with backoff, then auto-refunded.
- Currency mismatch between user wallet and listing: convert at Stripe FX, shown clearly before confirm.
- Refund after 7 days: self-serve disabled, contact support flow opens with prefilled order id.
- Subscription card expires: 3 attempts over 7 days, grace period continues plugin, then disables and emails owner.
- Reviewer assigned but inactive: SLA timer triggers reassignment after 4 h.
- Capability escalation in update: 2-reviewer rule, both must approve, audit row stores both ids.
- Asset takedown after publish: status flips `taken_down`, existing installs continue with last good version, no new buyers.

## Reviewer Workflow
```mermaid
sequenceDiagram
    participant R as Reviewer
    participant API
    R->>API: claim ticket
    API-->>R: ticket + 30min lock
    R->>API: comment thread
    alt approve
        R->>API: decision=approve
    else changes
        R->>API: decision=changes
    else reject
        R->>API: decision=reject
    end
    API->>API: write audit row
```

## Refund Flow
```mermaid
sequenceDiagram
    participant U
    participant API
    participant Pay
    U->>API: POST /listings/:id/refund
    API->>API: check 7-day window
    API->>Pay: refund(charge_id)
    Pay-->>API: refunded
    API->>API: state=refunded, uninstall
    API-->>U: confirmation email
```
