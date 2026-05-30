# Channel Notes — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile (WebView)
    participant API as Backend
    participant DB as Postgres
    participant H as Hocuspocus

    U->>M: Tap channel header "Notes"
    M->>API: POST /channels/:cid/note/handshake
    API->>DB: SELECT or INSERT channel_notes ROW
    API-->>M: {ws_url, token, last_edited}
    M->>H: WS connect doc=cn:<channel_id>
    H->>DB: load yjs_state
    H-->>M: sync
    M-->>U: editor mounts; "Last edited by @priya 2m ago"

    U->>M: types
    M->>H: y-update
    H->>H: broadcast
    Note over H: every 100 updates / 2 min idle
    H->>DB: persist yjs_state, rev++
    H->>API: POST /internal/channel-notes/:cid/persisted

    Note over U,DB: Mod clears
    U->>M: overflow -> Clear notes
    M->>API: POST /channels/:cid/note/clear
    API->>DB: yjs_state = empty doc, rev++
    API->>H: force-broadcast new state
    H-->>M: clients show empty editor
```

## 2. State Machine

```
[absent] -- first edit --> [active]
[active] -- mod clear --> [active (empty)]
[active] -- channel deleted --> [purged]
```

## 3. User Journeys

### J1 — Create on first edit
1. New channel; member opens header "Notes" -> empty editor.
2. Types a checklist; auto-saves.
3. Channel header now shows "Notes (3 lines)".

### J2 — Live coediting
1. Two members open notes; cursors visible.
2. One adds heading; other adds bullet; merged via CRDT.

### J3 — Mod clears
1. Mod overflow -> Clear notes -> confirm.
2. Note replaced with empty; audit log entry.

### J4 — Bloat warning
1. Note approaches 64 KB -> banner "Long enough to be a Doc. Convert?"
2. Tap converts contents into a `collaborative-docs` doc.

### J5 — Empty state
1. Header "Notes" not visible until first creation OR shows "Add notes".

## 4. Edge Cases

- **Permission revoked while editing:** WebView switches to read-only on push.
- **Channel renamed/moved:** note follows channel.
- **Channel deleted:** note row cascade deleted.
- **Markdown injection:** sanitized server-side render endpoint.
- **Mobile offline:** show last cached markdown read-only.

## 5. Background / Async

- Persist on idle (2 min) or 100 updates
- Daily prune Yjs deltas older than latest snapshot
- No version history retained

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Note created | bot post once in channel | "@user started notes for #channel" | `flicko://channel/<cid>/note` | once per channel |
| Mention added in note | in-app | "@author mentioned you in #channel notes" | same | once per editor per 5m |
| Mod clear | bot post | "@mod cleared notes" | same | once |

Voice: short, neutral.
