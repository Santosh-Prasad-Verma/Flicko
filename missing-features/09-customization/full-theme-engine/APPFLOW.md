# Full Theme Engine — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile (Flutter)
    participant API as Go Backend
    participant DB as Supabase
    participant RT as Centrifugo
    participant CDN as Appwrite

    U->>M: Tap theme card
    M->>API: GET /api/v1/themes/:id
    API->>DB: select spec
    DB-->>API: spec JSON
    API-->>M: 200 spec
    M->>M: theme_engine.hydrate(spec)
    M-->>U: live preview (isolated subtree)
    U->>M: Tap Apply
    M->>API: POST /api/v1/themes/:id/apply
    API->>DB: upsert user_theme_overrides
    API->>RT: publish themes:user:<uid>
    RT-->>M: theme.applied (other devices)
    API-->>M: 200
    M->>M: appThemeProvider.notify
    M-->>U: crossfade 120ms; toast "Looks good on you"
```

## 2. State Machine

```
[browsing] -- pickCard --> [previewLoading]
[previewLoading] -- specOk --> [previewing]
[previewLoading] -- specErr --> [browsing+toast]
[previewing] -- apply --> [applying]
[previewing] -- back --> [browsing]
[applying] -- ok --> [applied]
[applying] -- err --> [previewing+toast]
[applied] -- clear --> [browsing]
```

## 3. User Journeys

### J1 — Happy path: discover, preview, apply
1. User opens Settings → Appearance → Themes.
2. Marketplace loads cached popular themes; fresh page streams in.
3. Taps "Tokyo Night" — detail loads in <300ms.
4. Hits Preview — isolated subtree shows mock chat with applied tokens.
5. Hits Apply — crossfade across the whole app, toast confirms.
6. Settings deep link returns to root with new theme everywhere.

### J2 — Server enforces theme
1. Owner of `#sage-garden` set the server theme to "Sage Gardens" with `enforced=true`.
2. User Mira has personal "Tokyo Night" override.
3. Mira navigates into the server — app renders Sage Gardens for the server scope only.
4. Returns to DMs — Tokyo Night.
5. Mira can opt out per-server in server settings overflow.

### J3 — Creator publishes a theme
1. Creator opens `flicko://themes/new` (Settings → Appearance → Create theme).
2. Picks 8 base colors via picker; the engine derives the rest.
3. Hits Publish — server validates schema + contrast; if a contrast pair fails, UI marks the offending swatch with a red ring and a fix button.
4. On success, theme enters marketplace as `status=published vetted=false`.
5. After 24h with no reports and ≥10 installs, vetted is upgraded by admin or by an auto-vet job.

### J4 — Reported theme
1. User taps Report → reason "contrast".
2. `theme_reports` row inserted; trigger increments `themes.report_count`.
3. At 5 reports the theme auto-flags (status='flagged') and is hidden from marketplace.
4. Admin reviews in queue; either restores or removes.
5. Removal cascades to `user_theme_overrides` — affected users fall back to default with toast "Theme was removed".

### J5 — First-time empty state
1. User opens Themes for the first time, network error.
2. Cached popular grid renders if available; otherwise the empty state with a "Create one" CTA.

## 4. Edge Cases

- **Offline:** marketplace reads from Hive cache (last 24 themes browsed). Apply queued; sent on reconnect.
- **Permission denied (server settings):** owner UI is the only entry point; non-owners never see it.
- **Stale spec:** if `spec_version` advances, client refuses to apply v2 specs and shows "Update Flicko to use this theme".
- **Concurrent device override:** Centrifugo push wins last-write; UI shows banner "Theme changed on another device" with undo.
- **Rate limit:** 30 applies per user/day. After: "You're switching themes a lot — try previewing instead." Soft block.
- **Server-default theme deleted:** members fall back to user override or app default; a banner explains.
- **Server enforce flips off mid-session:** crossfade back to user theme.

## 5. Background / Async

- **Auto-vet job:** cron `0 */2 * * *`. For each theme `published AND NOT vetted AND install_count >= 10 AND age >= 24h AND report_count = 0`, set vetted=true.
- **Cover image processing:** on upload, resize/encode to webp 256x144, attach to theme row.
- **Idempotency key:** `theme:apply:<user_id>:<theme_id>:<minute_bucket>`.
- **Failure policy:** retry 3× exp backoff, DLQ to `themes.dlq` topic.

## 6. Notifications

- **Theme applied on another device:** in-app silent banner, no push.
- **Theme you use was removed:** push + in-app: "Theme '<name>' was removed by Flicko. Reverted to default."
- **Your theme was vetted:** push, deep link `flicko://themes/<id>`.
- **Your theme was reported:** in-app inbox only, no push.
- Batching: max 1 vet/removal push per theme per user.
