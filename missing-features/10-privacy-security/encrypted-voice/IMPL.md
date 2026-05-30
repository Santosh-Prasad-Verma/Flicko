# Encrypted Voice — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + threat-model + crypto review | 5d | PM/Sec/Crypto |
| 1 | DB migration 217 + epoch trigger | 2d | Backend |
| 2 | Key-rotation worker | 5d | Backend |
| 3 | Token-issuance handler with E2EE claim | 3d | Backend |
| 4 | LiveKit cluster config + per-room E2EE flag | 3d | DevOps |
| 5 | Mobile LiveKit insertable-streams hookup | 7d | Mobile |
| 6 | Mobile sealing/unsealing + epoch tracking | 5d | Mobile |
| 7 | Mobile E2EE badge + fingerprint UI | 4d | Mobile |
| 8 | QA + crypto audit + chaos testing | 7d | QA/Sec |
| 9 | Beta in security-team servers | 7d | All |
| 10 | GA | 1d | All |

Total: ~49 working days, two backend + one mobile + one DevOps.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/217_encrypted_voice.up.sql`.
- [ ] Down migration.
- [ ] Model `internal/models/encrypted_voice.go`.
- [ ] Service `internal/services/privacy/encrypted_voice/service.go`.
  - [ ] `IssueTokenForE2EERoom(ctx, channelID, userID) (token, sealedEnv, fingerprints, error)`.
  - [ ] `ForceRotate(ctx, channelID, adminID) error`.
- [ ] Worker `internal/services/privacy/encrypted_voice/key_rotation_worker.go`.
  - [ ] Listens on `e2ee_voice_rotate` PG NOTIFY.
  - [ ] For each member, fetches their identity public key.
  - [ ] Picks a fresh group key (libsodium secretstream key, 32 bytes), seals once per recipient via `crypto_box_seal`.
  - [ ] Inserts envelope rows.
  - [ ] **Critical:** the unsealed group key never leaves the worker process; goroutine-local; explicit `runtime.KeepAlive` then `crypto/subtle.ConstantTimeCompare`-backed wipe.
- [ ] LiveKit token issuance: token must claim `e2ee: true` and the room name; backend never has the key.
- [ ] Handler `internal/handlers/encrypted_voice_handler.go`.
- [ ] Wire routes in `cmd/server/main.go`.
- [ ] Permission middleware: ensure user has identity key set up.
- [ ] Audit-log entries: epoch number + reason; never key material.
- [ ] Metrics counters.
- [ ] OpenAPI doc update.
- [ ] Service tests (≥85%).
- [ ] Crypto unit tests using libsodium test vectors.
- [ ] Worker tests: rotation under concurrent member-change.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/encrypted_voice/`.
- [ ] LiveKit Flutter SDK upgrade to ≥2.0.
- [ ] Wrapper around LiveKit `Room` enabling insertable streams + group-key callback.
- [ ] `EncryptedVoiceRepository` to fetch token + sealed envelope from backend.
- [ ] Open envelope locally with libsodium `crypto_box_seal_open`.
- [ ] Set group key on LiveKit `KeyProvider` for the current epoch.
- [ ] On `voice.e2ee.epoch_changed` Centrifugo event: re-fetch envelope, swap key on `KeyProvider` for new epoch.
- [ ] Domain: `GroupKeyEpoch`, `EncryptedVoiceChannel`, `Fingerprint`.
- [ ] Application: `e2eeVoiceJoinProvider`, `e2eeIndicatorProvider`, `fingerprintsProvider`.
- [ ] Presentation: `EncryptedVoiceChannelScreen`, `E2EEBadge`, `FingerprintVerifySheet`.
- [ ] Routing: same voice-channel route, just E2EE-aware.
- [ ] L10n keys (~20 new).
- [ ] Tests: unit (sealing/unsealing roundtrip), widget (badge + sheet), integration with mock LiveKit room.
- [ ] Force-upgrade banner if `client_version < e2ee_min_client_version`.
- [ ] Pre-send assertion: never start publishing audio if `KeyProvider` is unset.

## 4. AI / Infra Tasks

- [ ] LiveKit cluster: enable E2EE flag globally; configure DTX off (forward secrecy concerns w/ silence frames).
- [ ] Disable any recording / transcription / VAD / AI-moderation hook on E2EE rooms at the SFU layer.
- [ ] Document operator runbook: "what to do if subpoenaed for an E2EE call."

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/encrypted_voice/service.go              (new)
  internal/services/privacy/encrypted_voice/key_rotation_worker.go  (new)
  internal/services/privacy/encrypted_voice/sealer.go               (new)
  internal/services/e2ee/key_manager.go                             (edit)
  internal/handlers/encrypted_voice_handler.go                      (new)
  internal/models/encrypted_voice.go                                (new)
  internal/repo/encrypted_voice_repo.go                             (new)
  cmd/server/main.go                                                (edit)
mobile/
  lib/features/privacy/encrypted_voice/...                          (new tree)
  lib/features/voice/presentation/voice_channel_screen.dart         (edit)
  lib/features/e2ee/data/identity_key_store.dart                    (edit)
  lib/core/router/app_router.dart                                   (edit)
supabase/
  migrations/217_encrypted_voice.up.sql                             (new)
  migrations/217_encrypted_voice.down.sql                           (new)
infra/
  livekit/server.yaml                                               (edit)
```

## 6. Test Plan

- **Unit:** sealing/unsealing roundtrip; epoch monotonicity; rotation reason classification.
- **Integration:** mock LiveKit room; member joins, key rotates, old key cannot decrypt new frames.
- **Crypto audit:** external review of sealing flow + envelope format.
- **Chaos:** member churn (join+leave 1 Hz) for 5 minutes; verify no decryption gaps lasting >1s.
- **E2E:** Maestro flow — two devices join, exchange audio, third joins → epoch bumps → all hear each other; one leaves → epoch bumps → leaver cannot decrypt.
- **Perf:** 30-participant room, 30 minutes, p99 frame-encrypt overhead <2%.
- **Security tests:**
  - Server with full DB read cannot decrypt sample envelopes (cryptographic; verify via external auditor).
  - Logs scan for any 32-byte hex blob = group-key length → must yield zero hits.

## 7. Rollout & Feature Flags

- Flag: `feature.encrypted_voice.enabled` (Doppler).
- Per-channel flag: `voice_channels.e2ee_enabled`.
- Beta: security team + 10 invited servers.
- Canary: 0.5% → 5% → 25% → 100% over 21d.

## 8. Rollback Plan

1. Disable global flag — no new E2EE channels can be created.
2. Existing E2EE rooms continue (we cannot retroactively decrypt; rolling back doesn't help).
3. If a P0 crypto bug: stop issuing tokens for E2EE rooms; force end calls; rotate flag to OFF; post incident.
4. Down migration only as last resort and only if no E2EE channels exist.

## 9. Dependencies / Blockers

- Existing `services/e2ee/` identity-key infrastructure must be rolled out to all clients before this feature.
- LiveKit cluster upgrade.
- LiveKit Flutter SDK upgrade.
- libsodium binding stable in Flutter target platforms.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Group key leaks via logs | Low | Critical | log-redactor + grep test in CI |
| Old client sees E2EE badge but doesn't encrypt | Med | Critical | min-client-version enforcement |
| Key-rotation race during fast churn | Med | Med | per-channel mutex in worker |
| LiveKit upstream regression | Low | High | pin known-good version; verify in staging on every upgrade |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| LiveKit SFU (self-hosted) | n/a | $400/mo |
| Compute (rotation worker) | Railway free | $0 |
| DB rows | small | $0 |
| **Total** | | **~$400/mo at 100k DAU** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] External crypto audit signed off.
- [ ] Privacy-policy + threat-model docs merged.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
- [ ] Zero P0/P1 in 21-day window.
- [ ] Operator runbook published.
