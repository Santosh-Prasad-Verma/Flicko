# Gaming Profiles Deep — APPFLOW

```mermaid
sequenceDiagram
    participant V as Viewer
    participant API as Backend
    participant C as Composer
    participant DB as Supabase
    participant CACHE as Redis
    participant SSR as Public Renderer

    V->>API: GET /users/<id>/gaming
    API->>CACHE: get gprofile:user:<id>
    alt cache miss
      API->>C: compose
      C->>DB: SELECT settings, stats, achievements, clips, codes
      C-->>API: JSON
      API->>CACHE: SET TTL 60s
    end
    API-->>V: JSON

    Note over V,SSR: public link
    V->>SSR: GET /public/@alice/gaming
    SSR->>CACHE: get gprofile:public:alice
    alt miss
      SSR->>API: compose
      SSR->>SSR: render HTML
      SSR->>CACHE: SET TTL 5m
    end
    SSR-->>V: HTML + OG tags
```

## State Machine
```
profile: [private] ⇄ [public]
section visible/hidden per section
```

## Edge Cases
- Slug already taken: suggest variants.
- User deletes account: public page returns 404 immediately (cache purge).
- Section provider disconnected: omit section gracefully.
- Image export fails: serve last successful card or generic.

## Background
- Cache invalidation on settings PATCH.
- Recent games refresher hooks into stats worker.

## Notifications
- None.
