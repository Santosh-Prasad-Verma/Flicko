# Collaborative Docs — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile (WebView)
    participant API as Go Backend
    participant DB as Postgres
    participant H as Hocuspocus
    participant W as SnapshotWorker
    participant RT as Centrifugo

    Note over U,RT: Open doc
    U->>M: Tap doc in channel
    M->>API: GET /docs/:id/handshake
    API->>DB: validate channel membership + ACL
    API-->>M: 200 {ws_url, token, rev, default_tier}
    M->>H: WS connect ?token=<jwt>
    H->>API: validate token (cached 30s)
    H->>DB: load yjs_state where doc.id=<id>
    H-->>M: send Yjs sync step 1
    M-->>U: editor mounts; presence avatars appear

    Note over U,RT: Co-editing
    U->>M: types
    M->>H: y-protocol update bytes
    H->>H: merge update, broadcast to other clients
    Note over H: every 200 updates OR 5 min idle
    H->>DB: UPDATE docs SET yjs_state, rev=rev+1
    H->>API: POST /internal/docs/:id/persisted {rev}
    API->>RT: publish docs:server:<sid> "doc.rev"

    Note over U,RT: Snapshot
    W->>DB: SELECT docs WHERE updated_at < now()-5m AND rev > last_snap_rev
    W->>DB: INSERT doc_revisions (...)
    W->>DB: prune deltas older than snapshot

    Note over U,RT: Comment
    U->>M: select text -> Comment
    M->>API: POST /docs/:id/comments {anchor_from, anchor_to, body}
    API->>DB: INSERT doc_comments
    API->>RT: publish doc:<id>:comments
    API-->>M: 201
```

## 2. State Machine

```
doc lifecycle:
  [draft] -- save --> [active]
  [active] -- archive --> [archived]
  [archived] -- restore --> [active]
  [active] -- 90d archived --> [purged]

connection state (per client):
  [connecting] -- handshake ok --> [synced]
  [synced] -- network drop --> [reconnecting]
  [reconnecting] -- 3 failed --> [offline_readonly]
  [offline_readonly] -- network back --> [reconnecting]
  any -- token expired --> [refreshing]
  [refreshing] -- ok --> [synced]
```

## 3. User Journeys

### J1 — Mod team writes a playbook together
1. Owner opens #mod-room channel header -> "+ New doc".
2. Picks template "Playbook"; doc created; bot posts "New doc: Onboarding".
3. Two other mods open the doc; cursors appear in unique colors.
4. They edit simultaneously; presence shows three avatars top-right.
5. After 5 min idle, snapshot worker creates rev 1 with auto-label.

### J2 — Comment thread anchored to a paragraph
1. Mod selects a sentence in the doc.
2. Floating menu shows "Comment".
3. Sheet appears; types "should we mention rate limits?".
4. Comment pin appears in margin; reply chain on tap.
5. Author resolves -> pin grayed.

### J3 — First-time empty state
1. Member opens channel that has no docs -> Docs section in header empty.
2. Channel header says "No doc yet"; mods see "+ New doc".
3. Members see no CTA but a tooltip "Mods can pin shared docs here."

### J4 — Restore a snapshot
1. Owner opens doc -> Version history.
2. Picks "rev 12 - before launch" -> Preview side-by-side.
3. Taps Restore -> system creates rev N+1 with content from rev 12, trigger=restore.
4. Other editors see toast "@owner restored rev 12".

### J5 — Permission downgrade mid-edit
1. Owner downgrades user from editor to viewer.
2. Hocuspocus pushes `acl.changed`; client puts editor read-only.
3. Banner: "Your edit access was changed. Read-only now."
4. Last in-flight edits flushed before downgrade applied.

## 4. Edge Cases

- **Offline:** WebView surface shows last cached markdown; edits disabled; banner "Offline. Changes from others will appear when you reconnect."
- **Permission denied:** clicking doc shows "You don't have access. Ask a mod."
- **Concurrent restore vs edit:** restore creates new rev; in-flight edits applied as deltas on top.
- **Image upload fails:** placeholder block with retry.
- **Massive paste (50k+ tokens):** client warns; backend caps `markdown_export` at 256 KB; doc still functions but search excerpt truncated.
- **WS connection limit hit (>25 editors):** 26th gets read-only banner "Doc full".
- **JWT expired:** transparent refresh; if refresh fails, show "Reconnect" button.
- **Hocuspocus restart:** clients reconnect with backoff (1s, 2s, 5s, 15s, 30s); state replayed from last snapshot.

## 5. Background / Async

- **Snapshot worker:** every 5 min (cron) and on `200 updates since last snapshot`
  - Idempotency: by `(doc_id, rev)`
  - Failure: retry once; on failure, log + Sentry; doc still usable from in-memory Yjs
- **Token cleanup:** hourly cron purges expired handshake tokens
- **Markdown export:** on each snapshot, render Yjs to markdown server-side via Tiptap-server (Node sidecar) and store in `markdown_export`
- **Archive purge:** daily, delete archived > 90d

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Mentioned in doc | in-app + push | "@{author} mentioned you in {doc title}" | `flicko://doc/<id>` | 1 per doc per 5m |
| New comment on resolved thread | in-app | "{author} reopened a thread in {doc}" | same | once |
| ACL granted | in-app | "You can now edit '{doc}'" | same | once |
| Snapshot named | in-app | "{author} marked rev {n}: {label}" | same | once |
| Doc archived | in-app | "'{doc}' was archived" | channel link | once |

Voice: friendly, concise, second-person.
