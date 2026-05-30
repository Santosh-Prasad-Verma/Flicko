# APPFLOW - Reward System

## Sequence: Event ingest -> grant
```mermaid
sequenceDiagram
  participant Mod as Source Module
  participant N as NATS
  participant W as IngestWorker
  participant R as RuleEngine
  participant Budget as BudgetSvc
  participant DB as Postgres
  participant Deliv as Delivery
  participant U as User

  Mod->>N: emit event_id=E1, type=daily_login
  N->>W: deliver
  W->>DB: INSERT processed_events (event_id) ON CONFLICT DO NOTHING
  alt new event
    W->>R: evaluate active rules for type
    R-->>W: matched rules: [streak]
    loop each matched rule
      W->>Budget: TRY_DEC budget by reward_value (Lua)
      Budget-->>W: ok=true remaining=...
      W->>DB: BEGIN; INSERT reward_grants; ledger; outbox; COMMIT
      W->>Deliv: deliver(grant)
      Deliv->>U: coins credited, badge granted, notification sent
    end
  end
```

## State Machine: rule_version
```
   draft -> dry_run -> active -> archived
                    -> paused (budget exhausted) -> active (next reset)
```

## State Machine: reward_grant
```
   computed -> delivered -> archived
            -> reversed (admin) -> archived_reversed
   delivery_failed -> retrying -> delivered | dead_letter
```

## Edge Cases
- **Event redelivered by NATS**: `processed_events.event_id` PK acts as dedupe ledger; second delivery becomes no-op.
- **Rule edited mid-stream**: events carry timestamp; engine looks up rule version active at event time.
- **Budget exhausted between evaluate and grant**: Lua atomic DEC returns failure, rule paused, grant not written, user not promised.
- **Worker crash after ledger write but before delivery**: delivery is idempotent on `grant_id`; on restart, reconcile worker picks up `grant.status=computed` rows older than 60 s and retries delivery.
- **User account deleted between ingest and grant**: grant writes succeed (ledger preserved); delivery is skipped, status=skipped_user_deleted.
- **A/B variant assignment**: deterministic hash(user_id, rule_id) % 100; user always falls into the same bucket for a rule.
- **Cash reward without KYC**: grant computed but delivery routed to escrow until KYC complete; user notified to verify.
- **Race - two events for same milestone**: dedup by `(rule_id, user_id, milestone_key)`; second grant writes with status=duplicate.
- **Reverse fraud grant**: admin endpoint writes negative ledger entry with `reverses_grant_id`; coins debited; if user balance insufficient, account flagged for collection.
- **Backfill historical grants**: replay events via dry-run mode + force-grant flag; rate-limited to protect downstream notifications.
- **Rule predicate references missing field**: predicate evaluator returns false safely, logs WARN, no crash.
