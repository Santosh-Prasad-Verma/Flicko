# Private Vaults — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + crypto review | 4d | PM/Sec |
| 1 | DB migration 220 + quota trigger | 2d | Backend |
| 2 | libsodium Flutter binding hardening | 4d | Mobile |
| 3 | Argon2id KDF + tiers | 3d | Mobile |
| 4 | Encrypted manifest format + codec | 4d | Mobile |
| 5 | Vault setup + recovery seed UX | 4d | Mobile |
| 6 | Backend handler + presigned URLs | 3d | Backend |
| 7 | Upload/download flows | 4d | Mobile |
| 8 | Multi-device unlock | 3d | Mobile |
| 9 | QA + crypto audit + perf profiling | 7d | QA/Sec |
| 10 | Beta | 7d | All |
| 11 | GA | 1d | All |

Total: ~46 working days, two engineers + crypto consultant.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/220_private_vaults.up.sql` + down.
- [ ] Models `internal/models/vault.go`.
- [ ] Service `internal/services/privacy/private_vaults/service.go`.
  - [ ] `EnsureVault(ctx, userID, kdfParams)`.
  - [ ] `RequestUpload(ctx, userID, sealedSize, sha256) (objectID, presignedURL)`.
  - [ ] `RequestDownload(ctx, userID, objectID) (presignedURL)`.
  - [ ] `DeleteObject(ctx, userID, objectID)`.
  - [ ] `SaveManifest(ctx, userID, ciphertext, version)`.
- [ ] Quota enforcement in `RequestUpload`.
- [ ] Handler `internal/handlers/private_vaults_handler.go`.
- [ ] Wire routes in `cmd/server/main.go`.
- [ ] Audit-log entries (object id only, no content metadata).
- [ ] Quota-roll-up worker.
- [ ] Service tests + handler tests (≥85%).

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/private_vaults/`.
- [ ] Crypto layer:
  - [ ] `argon2_kdf.dart` with three tiers (high/mid/low).
  - [ ] `secretbox.dart` libsodium wrappers; per-file fresh nonce; AAD = file ID.
  - [ ] `manifest_codec.dart` — versioned format `{magic, version, files[], updated_at}`.
- [ ] Data: repositories + remote data source.
- [ ] Domain: entities + usecases.
- [ ] Application: providers for unlock state, quota, file list.
- [ ] Presentation:
  - [ ] `VaultHomeScreen`.
  - [ ] `VaultUnlockSheet` (passphrase + biometric option).
  - [ ] `RecoverySeedScreen` (BIP-39 24 words).
  - [ ] `FileItemTile`.
  - [ ] `UploadProgressTile`.
  - [ ] `QuotaBadge`.
- [ ] Auto-lock timer (default 5min).
- [ ] Optional biometric unlock (uses OS Keychain to wrap the passphrase-derived key locally).
- [ ] Routing: `flicko://vault`, `flicko://vault/setup`.
- [ ] L10n keys.
- [ ] Tests:
  - [ ] Unit: KDF determinism, encrypt-decrypt roundtrip, manifest codec.
  - [ ] Widget + provider tests.
  - [ ] Golden tests.
  - [ ] Integration with mock Appwrite.

## 4. AI / Infra Tasks

- [ ] Appwrite bucket `user-vault` with permissions config.
- [ ] CDN cache disabled for vault bucket (privacy + freshness).

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/private_vaults/service.go        (new)
  internal/services/privacy/private_vaults/quota_worker.go   (new)
  internal/handlers/private_vaults_handler.go                (new)
  internal/models/vault.go                                   (new)
  internal/repo/vault_repo.go                                (new)
  cmd/server/main.go                                         (edit)
mobile/
  lib/features/privacy/private_vaults/...                    (new tree)
  lib/core/router/app_router.dart                            (edit)
  pubspec.yaml                                               (edit)
supabase/
  migrations/220_private_vaults.up.sql                       (new)
  migrations/220_private_vaults.down.sql                     (new)
infra/
  appwrite/buckets/user-vault.json                           (new)
```

## 6. Test Plan

- **Unit:** crypto roundtrips; KDF tiers; manifest format upgrade path.
- **Integration:** mock Appwrite; upload-list-download cycle.
- **Crypto audit:** external review of KDF params, secretbox use, manifest format.
- **Perf:** Argon2id <1.5s on Pixel 6a, <2.5s on entry-level Android.
- **E2E:** Maestro — setup vault, upload file, log out, log in on second device, decrypt the file.
- **Security tests:**
  - Server cannot decrypt a sample blob even with full DB access.
  - Logs contain no plaintext file names or content.
  - Manifest changes do not leak file count via timing.

## 7. Rollout & Feature Flags

- Flag: `feature.private_vaults.enabled` (Doppler).
- Beta: 2% of DAU.
- Canary: 10% over 14d.

## 8. Rollback Plan

1. Disable flag — vault entry point hidden.
2. Existing vaults remain accessible to enrolled users.
3. Down migration only as last resort and only if zero objects exist.

## 9. Dependencies / Blockers

- libsodium Flutter binding stable on iOS + Android.
- Appwrite version supporting per-user-prefixed permissions.
- Argon2id KDF benchmarked across device classes.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Forgotten passphrase | Med | High UX | Recovery seed flow |
| KDF too heavy on cheap devices | Med | Med | Tiered presets |
| Manifest format upgrades break old clients | Low | High | Versioned codec; never break v1 readers |
| Appwrite outage | Low | High | Document; graceful degradation |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Appwrite storage (5 GB/user free quota) | self-hosted | hardware-bound |
| DB rows | small | $0 |
| **Total** | | **storage scaling-dependent** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] External crypto audit signed off.
- [ ] Privacy-policy update.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
- [ ] Zero P0/P1 in 14-day window.
