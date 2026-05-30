# Widget Builder — Technical Requirements

## 1. Architecture Overview

```
+----------------------+     +-----------------------+
| widget-builder web   |     | server's website      |
| (React/Vite SPA)     |     | <iframe src="...">    |
+----+-----------------+     +----+------------------+
     | save layout                | request
     v                            v
+----+-------------------+   +----+--------------------+
| widgets_handler.go     |   | edge renderer (CF Worker|
| /api/v1/widgets/...    |   | embed.flicko.app/<slug>)|
+----+-------------------+   +-----+-------------------+
     |                             |
     v                             v
+----+--------+                +---+----------+
| Postgres    | <------------- | Edge KV cache|
| embed_widgets|               +--------------+
+-------------+
```

## 2. Components

### Backend (Go)
- **Service:** `internal/services/widgets/service.go` — CRUD on `embed_widgets`, slug generation, snippet build.
- **Renderer:** static HTML render in `internal/services/widgets/renderer.go` (used by edge worker via fetch).
- **Handlers:** `internal/handlers/widgets_handler.go`.
- **Models:** `internal/models/embed_widget.go`.

### Web (React/Vite)
- **App:** `widget-builder/` directory or sub-route in `gaming-ui/`.
- **Routes:**
  - `/builder/:server_id` — drag canvas
  - `/preview/:slug` — iframe preview
  - `/snippet/:slug` — snippet generator
- **Libraries:** `@dnd-kit/core` for drag-drop, `zustand` for state.
- **Output spec:** layout JSON `{ blocks: [{type, props, x, y, w, h}] }`.

### Edge Renderer (CF Worker)
- Reads slug from URL.
- Hits Worker KV; if miss, fetches `https://api.flicko.app/v1/widgets/render/:slug`.
- Returns HTML with `Content-Security-Policy: default-src 'self' https://cdn.flicko.app; frame-ancestors <allowlist>;`.
- Cache 60s.

### Infra
- DB: `embed_widgets`.
- Cache: Cloudflare KV `widget:<slug>` TTL 60s.
- Realtime: not needed.

## 3. API Contracts

### REST
```
POST   /api/v1/servers/:sid/widgets        create
GET    /api/v1/servers/:sid/widgets        list
PATCH  /api/v1/widgets/:id                 update layout
DELETE /api/v1/widgets/:id                 delete
GET    /api/v1/widgets/render/:slug        edge worker fetches
```

### Payloads
```jsonc
// PATCH layout body
{
  "blocks": [
    { "type": "member_count", "x": 0, "y": 0, "w": 4, "h": 1, "props": {} },
    { "type": "recent_posts", "x": 0, "y": 1, "w": 4, "h": 3, "props": { "channel_id": "uuid", "limit": 3 } }
  ],
  "theme": { "primary": "#7AA2F7", "mode": "auto" },
  "frame_ancestors": ["mygame.com","www.mygame.com"]
}

// Render response (HTML)
"<!doctype html>..."
```

## 4. Permissions & Auth

- Owner / `manage_server` to edit.
- Public read by slug; edge worker enforces frame-ancestors.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Edge p95 first paint | <300ms |
| Origin render p99 | <800ms |
| Concurrency at edge | 5k RPS per region |
| CSP strict | always |
| Storage per widget | <8 KB layout |
| Cost per render | <$0.00001 |

## 6. Dependencies

- New libraries:
  - Web: `@dnd-kit/core: ^6.1.0`, `zustand: ^4.5.4`, `lucide-react: ^0.453.0`.
  - Edge: Cloudflare Workers runtime; KV namespace.
- External: Cloudflare account.

## 7. Observability

- Metrics: `flicko_widget_render_total{slug}`, `..._cache_hit_ratio`, `..._csp_violation_total`.
- Logs: edge access logs.
- Traces: backend render only.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Origin down | edge serves stale | KV stale-while-revalidate 24h |
| CSP misconfig | embed broken | dry-run preview tool |
| Frame busting | embed blocked | document allowed ancestors |
| Layout corrupt | blank widget | server-side schema validation |
