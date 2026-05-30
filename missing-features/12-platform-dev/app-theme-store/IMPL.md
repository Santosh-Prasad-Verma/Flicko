# IMPL: App & Theme Store

## Phases
- P0 (week 1): migration 241, listing CRUD, draft/submit only, no payments.
- P1 (week 2-3): reviewer console (web), queue logic, decisions, audit.
- P2 (week 4-5): publish path wires plugin-registry; theme + sticker pack handlers.
- P3 (week 6-7): payments via flicko-pay, paid one-time, webhook.
- P4 (week 8): subscriptions monthly/yearly, payout ledger.
- P5 (week 9): reviews + ratings, featured slots admin.
- P6 (week 10): refund self-serve, takedown, deprecation.
- P7 (week 11-12): mobile UI polish, search, GA.

## Backend Tasks
- `backend/internal/store/listings/handlers.go` CRUD, submit, list.
- `backend/internal/store/listings/search.go` FTS + trigram + ranking.
- `backend/internal/store/review/queue.go` priority, SLA, lock.
- `backend/internal/store/review/decisions.go` approve/reject/changes.
- `backend/internal/store/purchases/orchestrator.go` start checkout, persist row.
- `backend/internal/store/purchases/webhook.go` HMAC, idempotency, state machine.
- `backend/internal/store/purchases/refunds.go` 7-day self-serve.
- `backend/internal/store/subs/manager.go` subscription lifecycle.
- `backend/internal/store/payouts/ledger.go` creator earnings, payout schedule.
- `backend/internal/store/reviews/handlers.go` write rating, helpful.
- `backend/internal/store/featured/admin.go` curated slot management.
- `backend/internal/store/assets/scanner.go` ClamAV gateway.
- `backend/db/migrations/241_store.sql`.

## Reviewer Console (Web)
- `web/apps/reviewer/src/routes/queue.tsx`.
- `web/apps/reviewer/src/routes/listing/[id].tsx` with diff view.
- `web/apps/reviewer/src/components/CapabilityDiff.tsx`.
- `web/apps/reviewer/src/lib/realtime.ts` Supabase channel.
- Auth guard on `auth.jwt().role == reviewer`.

## Mobile Tasks
- `mobile/lib/features/store/data/store_repository.dart`.
- `mobile/lib/features/store/presentation/screens/store_home_screen.dart`.
- `mobile/lib/features/store/presentation/screens/listing_detail_screen.dart`.
- `mobile/lib/features/store/presentation/screens/orders_screen.dart`.
- `mobile/lib/features/store/presentation/widgets/install_or_buy_button.dart`.
- `mobile/lib/features/store/providers/store_provider.dart`.
- Hook into existing `flicko-pay` Flutter SDK for checkout WebView.
- `mobile/lib/core/router/app_router.dart` routes `/store`, `/store/:id`, `/store/orders`.

## Test Plan
- Unit: search ranking determinism, idempotency-key dedup, refund window logic, review aggregate trigger.
- Integration: end-to-end purchase happy path with Stripe test mode; refund; subscription renewal; webhook replay.
- Reviewer flow: claim, comment, approve, audit row written; capability escalation requires 2 approvals; SLA reassign after 4 h.
- Load: 100 k listings indexed, search p95 under 250 ms; webhook 100 rps sustained without dupes.
- Security: forged webhook rejected, RLS prevents cross-buyer order leak, asset upload with malware blocked.
- Mobile: checkout WebView returns to app on success/cancel/error; deep link install completes within 10 s.
- Localization: 12 currencies, FX displayed; tax line shown when Stripe Tax responds.

## Cost: $0
- Reuses Supabase Postgres + Storage and existing flicko-pay (Stripe). No new infra.
- ClamAV runs in same Go service as a sidecar process, freedef, OSS.
- Reviewer console deployed as static SPA in existing Vercel free tier.
- Stripe fees pass-through, not counted as our cost.
- Featured curation done in admin DB by ops team, no third-party CMS.

## Rollout
- Internal-only (`store.enabled` flag) for first 2 weeks.
- Free items public, paid items gated behind invite code list for 4 weeks.
- Public GA with curated bundle of 30 free + 20 paid items.

## Open Tickets
- FLK-STR-201 listings CRUD
- FLK-STR-202 reviewer console
- FLK-STR-203 payments
- FLK-STR-204 subscriptions
- FLK-STR-205 reviews
- FLK-STR-206 refunds
- FLK-STR-210 mobile store
