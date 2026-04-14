# Discord Parity Execution Tickets (Audit-Mapped)

This backlog decomposes the audit implementation plan into **Epic → Story → API/Schema tasks**.

## Phase 0 — Program Setup & Foundations

### Epic P0-E1 — Delivery Framework (Audit: Program governance gap)

- **Story P0-E1-S1 — Define parity baseline and done criteria**
  - **Task P0-E1-S1-T1 (Schema):** Add `feature_parity_status` table (`feature_key`, `status`, `owner`, `target_phase`, `updated_at`).
  - **Task P0-E1-S1-T2 (API):** Add internal `GET /api/v1/parity/status`.
- **Story P0-E1-S2 — Cross-service contract governance**
  - **Task P0-E1-S2-T1 (Docs):** Create versioned WS event schema docs for `MESSAGE_*`, `VOICE_*`, `ACTIVITY_*`, `MOD_*`.
  - **Task P0-E1-S2-T2 (Schema):** Add `schema_versions` table.

## Phase 1 — Activities Parity Core

### Epic P1-E1 — Embedded Activities Runtime (Audit: Activities runtime parity gap)

- **Story P1-E1-S1 — Server-authoritative activity lifecycle**
  - **Task P1-E1-S1-T1 (API):** `POST /api/v1/activities/launch`
  - **Task P1-E1-S1-T2 (API):** `POST /api/v1/activities/{sessionId}/join`
  - **Task P1-E1-S1-T3 (API):** `POST /api/v1/activities/{sessionId}/leave`
  - **Task P1-E1-S1-T4 (API):** `POST /api/v1/activities/{sessionId}/end`
  - **Task P1-E1-S1-T5 (API):** `GET /api/v1/activities/{sessionId}`
  - **Task P1-E1-S1-T6 (Schema):** Harden `activity_sessions` with host transfer fields, `ended_reason`, `last_heartbeat_at`.
  - **Task P1-E1-S1-T7 (Schema):** Extend `activity_participants` with role (`host|participant|spectator`) and `left_at`.
- **Story P1-E1-S2 — Versioned Embedded App SDK bridge**
  - **Task P1-E1-S2-T1 (WS):** Add `ACTIVITY_SESSION_UPDATE`.
  - **Task P1-E1-S2-T2 (WS):** Add `ACTIVITY_PARTICIPANT_UPDATE`.
  - **Task P1-E1-S2-T3 (WS):** Add `ACTIVITY_STATE_PATCH`.
  - **Task P1-E1-S2-T4 (Schema):** Add `activity_state_snapshots` (`session_id`, `version`, `state_json`, `created_at`).

### Epic P1-E2 — Synchronized Media & Join Flows (Audit: Activity sync/join UX parity gap)

- **Story P1-E2-S1 — Synchronized media control**
  - **Task P1-E2-S1-T1 (API):** `POST /api/v1/activities/{sessionId}/sync/play`
  - **Task P1-E2-S1-T2 (API):** `POST /api/v1/activities/{sessionId}/sync/pause`
  - **Task P1-E2-S1-T3 (API):** `POST /api/v1/activities/{sessionId}/sync/seek`
  - **Task P1-E2-S1-T4 (Schema):** Add `activity_sync_state` (`leader_user_id`, `playhead_ms`, `is_playing`, `updated_at`).
- **Story P1-E2-S2 — Join activity entry points**
  - **Task P1-E2-S2-T1 (API):** `GET /api/v1/users/{id}/active-activity`
  - **Task P1-E2-S2-T2 (API):** `GET /api/v1/channels/{id}/active-activity`
  - **Task P1-E2-S2-T3 (Schema):** Add materialized view for active session counts per channel.

### Epic P1-E3 — Activity Catalog Completion (Audit: Placeholder activity integration gap)

- **Story P1-E3-S1 — Real integrations for required activities**
  - **Task P1-E3-S1-T1 (API):** `GET /api/v1/activities/catalog`
  - **Task P1-E3-S1-T2 (API):** `POST /api/v1/activities/catalog/{id}/validate`
  - **Task P1-E3-S1-T3 (Schema):** Add `activities_catalog` (`slug`, `provider`, `capabilities`, `mobile_supported`, `enabled`).
- **Story P1-E3-S2 — Third-party/custom provider pipeline**
  - **Task P1-E3-S2-T1 (API):** `POST /api/v1/activities/providers/register`
  - **Task P1-E3-S2-T2 (API):** `POST /api/v1/activities/providers/{id}/publish`
  - **Task P1-E3-S2-T3 (Schema):** Add `activity_providers`, `activity_provider_secrets`, `activity_review_queue`.

## Phase 2 — Security, Identity & Privacy Hardening

### Epic P2-E1 — 2FA + Trusted Devices (Audit: account security parity gap)

- **Story P2-E1-S1 — TOTP enrollment/challenge**
  - **Task P2-E1-S1-T1 (API):** `POST /api/v1/auth/mfa/enroll`
  - **Task P2-E1-S1-T2 (API):** `POST /api/v1/auth/mfa/verify`
  - **Task P2-E1-S1-T3 (API):** `POST /api/v1/auth/mfa/disable`
  - **Task P2-E1-S1-T4 (Schema):** Add `mfa_factors`, `mfa_recovery_codes`.
- **Story P2-E1-S2 — Trusted devices and suspicious login detection**
  - **Task P2-E1-S2-T1 (API):** `GET /api/v1/auth/devices`
  - **Task P2-E1-S2-T2 (API):** `DELETE /api/v1/auth/devices/{id}`
  - **Task P2-E1-S2-T3 (API):** `GET /api/v1/auth/login-events`
  - **Task P2-E1-S2-T4 (Schema):** Add `trusted_devices`, `login_events`, `security_alerts`.

### Epic P2-E2 — GDPR Export & Deletion (Audit: privacy compliance parity gap)

- **Story P2-E2-S1 — Async account export**
  - **Task P2-E2-S1-T1 (API):** `POST /api/v1/privacy/export`
  - **Task P2-E2-S1-T2 (API):** `GET /api/v1/privacy/export/{jobId}`
  - **Task P2-E2-S1-T3 (Schema):** Add `data_export_jobs`, `data_export_artifacts`.
- **Story P2-E2-S2 — Irreversible account deletion workflow**
  - **Task P2-E2-S2-T1 (API):** `POST /api/v1/privacy/delete-account`
  - **Task P2-E2-S2-T2 (API):** `GET /api/v1/privacy/delete-account/{jobId}`
  - **Task P2-E2-S2-T3 (Schema):** Add `account_deletion_jobs`, `deletion_audit_log`.

## Phase 3 — Moderation & Roles Parity

### Epic P3-E1 — Reaction Roles + Screening (Audit: moderation automation parity gap)

- **Story P3-E1-S1 — Reaction-role mapping automation**
  - **Task P3-E1-S1-T1 (API):** `POST /api/v1/servers/{id}/reaction-roles`
  - **Task P3-E1-S1-T2 (API):** `DELETE /api/v1/servers/{id}/reaction-roles/{mappingId}`
  - **Task P3-E1-S1-T3 (Schema):** Add `reaction_roles` (`server_id`, `channel_id`, `message_id`, `emoji`, `role_id`).
- **Story P3-E1-S2 — Member screening enforcement**
  - **Task P3-E1-S2-T1 (API):** `GET /api/v1/servers/{id}/screening`
  - **Task P3-E1-S2-T2 (API):** `POST /api/v1/servers/{id}/screening/accept`
  - **Task P3-E1-S2-T3 (Schema):** Add `member_screening_status`, `screening_rules`.

### Epic P3-E2 — Moderation Operations Completeness (Audit: moderation controls parity gap)

- **Story P3-E2-S1 — Backend-first purge/bulk-delete**
  - **Task P3-E2-S1-T1 (API):** `POST /api/v1/channels/{id}/messages/purge`
  - **Task P3-E2-S1-T2 (Schema):** Add `purge_jobs` and purge audit metadata.
- **Story P3-E2-S2 — Timeout/kick/ban consistency**
  - **Task P3-E2-S2-T1 (API):** `POST /api/v1/servers/{id}/members/{userId}/timeout`
  - **Task P3-E2-S2-T2 (API):** `POST /api/v1/servers/{id}/members/{userId}/ban` (`duration` optional)
  - **Task P3-E2-S2-T3 (Schema):** Extend `bans` with `expires_at`, `revoked_at`.

## Phase 4 — Voice/Video Parity Gaps

### Epic P4-E1 — Stage & Voice Admin Controls (Audit: voice admin parity gap)

- **Story P4-E1-S1 — Stage queue and raise-hand enforcement**
  - **Task P4-E1-S1-T1 (API):** `POST /api/v1/stage/{channelId}/raise-hand`
  - **Task P4-E1-S1-T2 (API):** `POST /api/v1/stage/{channelId}/speaker/{userId}`
  - **Task P4-E1-S1-T3 (Schema):** Add `stage_speaker_queue`, `stage_sessions`.
- **Story P4-E1-S2 — Move users and voice moderation controls**
  - **Task P4-E1-S2-T1 (API):** `POST /api/v1/voice/channels/{id}/move-user`
  - **Task P4-E1-S2-T2 (API):** `PATCH /api/v1/voice/channels/{id}` (`user_limit`)
  - **Task P4-E1-S2-T3 (Schema):** Add `user_limit` to channels if absent; add `voice_admin_actions`.

### Epic P4-E2 — Advanced Audio Features (Audit: spatial audio parity gap)

- **Story P4-E2-S1 — Spatial audio path**
  - **Task P4-E2-S1-T1 (Schema):** Add `voice_spatial_settings`.

## Phase 5 — Nitro/Premium Productization

### Epic P5-E1 — Gifting, Credits, Cosmetics (Audit: premium monetization parity gap)

- **Story P5-E1-S1 — Subscription gifting purchase/redeem**
  - **Task P5-E1-S1-T1 (API):** `POST /api/v1/premium/gifts`
  - **Task P5-E1-S1-T2 (API):** `POST /api/v1/premium/redeem`
  - **Task P5-E1-S1-T3 (Schema):** Add `gift_transactions`, `gift_redemptions`.
- **Story P5-E1-S2 — Monthly boost credits**
  - **Task P5-E1-S2-T1 (API):** `GET /api/v1/premium/boost-credits`
  - **Task P5-E1-S2-T2 (API):** `POST /api/v1/premium/boost-credits/apply`
  - **Task P5-E1-S2-T3 (Schema):** Add `boost_credits` (`issued_at`, `expires_at`, `consumed_at`).
- **Story P5-E1-S3 — Nitro cosmetics inventory**
  - **Task P5-E1-S3-T1 (API):** `GET /api/v1/premium/cosmetics`
  - **Task P5-E1-S3-T2 (API):** `POST /api/v1/profile/cosmetics/apply`
  - **Task P5-E1-S3-T3 (Schema):** Add `cosmetic_catalog`, `user_cosmetics`.

## Phase 6 — Bot Platform & App Ecosystem

### Epic P6-E1 — Bot OAuth2 Install + Permissions (Audit: app ecosystem parity gap)

- **Story P6-E1-S1 — OAuth2 install flow**
  - **Task P6-E1-S1-T1 (API):** `GET /api/v1/apps/{id}/oauth/authorize`
  - **Task P6-E1-S1-T2 (API):** `POST /api/v1/apps/{id}/install/callback`
  - **Task P6-E1-S1-T3 (Schema):** Add `applications`, `application_installs`, `application_scopes`.
- **Story P6-E1-S2 — Permission scoping and revocation**
  - **Task P6-E1-S2-T1 (API):** `PATCH /api/v1/apps/{id}/installs/{installId}/permissions`
  - **Task P6-E1-S2-T2 (Schema):** Add `application_permissions`.

### Epic P6-E2 — Interaction Components Parity (Audit: interaction surface gap)

- **Story P6-E2-S1 — Select menus, modals, context commands, file upload interactions**
  - **Task P6-E2-S1-T1 (API):** `POST /api/v1/interactions/components`
  - **Task P6-E2-S1-T2 (API):** `POST /api/v1/interactions/modals`
  - **Task P6-E2-S1-T3 (Schema):** Extend `interactions` with component payload metadata.

### Epic P6-E3 — App Directory (Audit: app discoverability gap)

- **Story P6-E3-S1 — Searchable app marketplace**
  - **Task P6-E3-S1-T1 (API):** `GET /api/v1/app-directory`
  - **Task P6-E3-S1-T2 (Schema):** Add `app_directory_entries`, `app_reviews`.

## Phase 7 — Client Surface Parity

### Epic P7-E1 — Web/Desktop Product Surfaces (Audit: platform surface parity gap)

- **Story P7-E1-S1 — Production web parity for core messaging/voice/social**
  - **Task P7-E1-S1-T1 (Implementation):** Reuse existing services; no new API/schema required initially.
- **Story P7-E1-S2 — Desktop shell notifications and shortcuts**
  - **Task P7-E1-S2-T1 (Schema/API):** Add desktop sound-pack notification preference fields if needed.

### Epic P7-E2 — UX Parity Enhancements (Audit: workflow ergonomics parity gap)

- **Story P7-E2-S1 — Full shortcut map and power-user navigation**
  - **Task P7-E2-S1-T1 (Implementation):** Client UX implementation; no new API/schema required.

## Phase 8 — Discovery, Intelligence & Reporting

### Epic P8-E1 — Discovery Quality (Audit: discovery/ranking parity gap)

- **Story P8-E1-S1 — Trending ranking and category taxonomy**
  - **Task P8-E1-S1-T1 (API):** `GET /api/v1/servers/discover/trending`
  - **Task P8-E1-S1-T2 (Schema):** Add `server_discovery_scores`, `server_categories`, `server_tags`.
- **Story P8-E1-S2 — Forum upvotes and ranking**
  - **Task P8-E1-S2-T1 (API):** `POST /api/v1/forum/posts/{id}/vote`
  - **Task P8-E1-S2-T2 (Schema):** Add `forum_post_votes`.

### Epic P8-E2 — Admin Insights (Audit: server analytics parity gap)

- **Story P8-E2-S1 — Server insights dashboards**
  - **Task P8-E2-S1-T1 (API):** `GET /api/v1/servers/{id}/insights`
  - **Task P8-E2-S1-T2 (Schema):** Add `server_daily_metrics` rollup table/materialized views.

## Cross-Phase Technical Tickets

- **X1:** Contract tests for WS + REST compatibility across services.
- **X2:** Security review gates for auth, activities, bot installs.
- **X3:** Performance budgets for high-fanout channels and activity sessions.
- **X4:** Migration safety pack (idempotent SQL + rollback docs).
- **X5:** Observability pack (metrics, tracing, SLOs per epic).

## Execution Cadence

1. Phase 1 + Phase 2
2. Phase 3 + Phase 4
3. Phase 5 + Phase 6
4. Phase 7 + Phase 8
