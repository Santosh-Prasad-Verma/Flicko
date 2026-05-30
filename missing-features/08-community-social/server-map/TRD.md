# Server Map — Technical Requirements

## 1. Architecture Overview

```
+------------------+   POST /map/opt-in   +-------------------+
|  Mobile (Flutter)| -------------------> |  Go Backend       |
|  + MapLibre GL   |                      |  map_service      |
+------------------+                      +---------+---------+
        ^                                           |
        |  GET /map/clusters                         v
        +-------------------------------+   +-----------------+
                                        +---|  Postgres       |
                                            |  member_locs    |
                                            |  + clusters MV  |
                                            +--------+--------+
                                                     |
                                                     v
                                            cron rebuild MV
                                            cron expire rows
```

Locations stored as geohash, never lat/lon. Cluster materialized view enforces k-anonymity floor of 5. Reads go via security-definer function `get_server_clusters(server_id)` which checks server membership.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/server-map/service.go`
- **Geohash utils:** `backend/internal/services/social/server-map/geohash.go`
- **K-anon:** `backend/internal/services/social/server-map/kanon.go`
- **Handlers:** `backend/internal/handlers/social/map_handler.go`
- **Models:** `backend/internal/models/social/member_location.go`
- **Repo:** `backend/internal/repo/social/map_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/server-map/`
  - `data/`: dto, repo, datasource
  - `domain/`: location, precision enum, consent state
  - `application/`: providers
  - `presentation/`: map_screen, consent_sheet, privacy_controls_screen, list_view

### Infra
- DB: tables in migration 196
- Map tiles: MapLibre GL with OSM raster fallback; cached locally
- Cache: Redis cluster cache TTL 5m
- Cron: nightly expire, 30-min cluster rebuild

## 3. API Contracts

### REST
```
POST   /api/v1/me/map/opt-in              { server_id, precision, geohash, label }
PATCH  /api/v1/me/map/:server_id          { precision }
DELETE /api/v1/me/map/:server_id          revoke
DELETE /api/v1/me/map                     revoke all
GET    /api/v1/servers/:id/map/clusters
GET    /api/v1/servers/:id/map/heatmap    (owner only)
```

### WebSocket / Centrifugo

None needed. Map data refreshes on-demand and via TTL.

### Payloads
```jsonc
// Opt-in (client computes geohash from device location with consent)
{
  "server_id": "uuid",
  "precision": 5,
  "geohash": "9q9hv",
  "country_code": "US",
  "label": "Berkeley area"
}

// Cluster
{
  "geohash": "9q9hv",
  "precision": 5,
  "member_count": 12,
  "country_code": "US",
  "label": "Berkeley area"
}
```

## 4. Permissions & Auth

- Opt-in only by self
- Read clusters by server members
- Heatmap by `MANAGE_SERVER`
- Minor users (<18): server enforces precision = 2 regardless of input
- Raw `member_locations` rows never exposed beyond owner via RLS

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Cluster fetch p50 | <120 ms |
| Map tile cache hit ratio | >=90% |
| Storage | <$0.0005 per opted-in user/mo |

## 6. Dependencies

- MapLibre GL Flutter package
- Geohash encoder (no external API needed)
- IP-based country fallback for precision=2 (free GeoLite2 db)

## 7. Observability

- Metrics: `flicko_map_optin_total`, `flicko_map_revoke_total`, `flicko_map_clusters_seconds`
- Logs: structured, no raw geohash logged
- Traces: OTel
- Dashboards: `social-map`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Tile provider down | broken map | switch to fallback tiles, list view available |
| Inference attack | privacy | k-anon=5, jitter, never expose raw row |
| Stale clusters | wrong density | 30-min rebuild + on-demand refresh |
