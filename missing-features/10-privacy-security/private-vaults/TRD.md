# Private Vaults — Technical Requirements

## 1. Architecture Overview

```
   ┌──────────────────────────────────────────────────┐
   │ Mobile (Flutter)                                 │
   │                                                  │
   │  passphrase →  Argon2id  →  master_key (32B)     │
   │                              │                   │
   │                              ▼                   │
   │  file ──xchacha20-poly1305(master_key, nonce)──▶ │
   │  manifest entry encrypted similarly              │
   └──────────────┬───────────────────────────────────┘
                  │ ciphertext blobs + encrypted manifest
                  ▼
        ┌──────────────────┐
        │ Backend handler  │  enforces auth, quotas
        │ (services/       │
        │  privacy/        │
        │  private_vaults) │
        └────────┬─────────┘
                 │
       ┌─────────┴────────────┐
       ▼                      ▼
   ┌───────────┐    ┌───────────────────────┐
   │ Appwrite  │    │ Postgres              │
   │ vault-    │    │ vault_objects (meta)  │
   │ bucket/<u>│    │ vault_manifests (enc) │
   └───────────┘    │ vault_keys (NEVER stored)│
                    └───────────────────────┘
```

The backend never touches plaintext. The only server-readable fields are storage-side: blob length, file count, opaque ID, account ownership.

## 2. Components

### Backend (Go) — extends `services/e2ee/`

- **Service:** `internal/services/privacy/private_vaults/service.go`
  - Issue Appwrite presigned URLs scoped to `user-vault/<user_id>/`.
  - Track vault metadata (size, file-count) for quota.
  - Reject any operation revealing key material (no key-storage endpoint exists).
- **Handler:** `internal/handlers/private_vaults_handler.go`
- **Models:** `internal/models/vault.go`
- **Quota worker:** `internal/services/privacy/private_vaults/quota_worker.go` (rolls usage from object-list)

### Mobile (Flutter) — extends `features/e2ee/`

- **Feature folder:** `mobile/lib/features/privacy/private_vaults/`
  - `crypto/`: `argon2_kdf.dart`, `secretbox.dart` (libsodium bindings), `manifest_codec.dart`
  - `data/`: `VaultRepository`, `VaultRemoteDataSource`, `ManifestStorage`
  - `domain/`: `VaultFile`, `Manifest`, `VaultKey`
  - `application/`: `vaultUnlockProvider`, `vaultFilesProvider`, `vaultUploadProvider`
  - `presentation/`: `VaultHomeScreen`, `VaultUnlockSheet`, `RecoverySeedScreen`, `FileItemTile`

### Infra
- Storage: Appwrite bucket `user-vault`; per-user prefix; permission `read("user:{uid}")`, `write("user:{uid}")`.
- DB: `vault_objects` (per-blob metadata, ciphertext-only references), `vault_manifests` (encrypted manifest blob).
- Cache: minimal — server doesn't cache vault data because it can't.
- Quota: Postgres column `users.vault_quota_bytes` (default 5 GB).

## 3. API Contracts

### REST
```
POST   /api/v1/vault/setup-marker     mark account as vault-enabled
POST   /api/v1/vault/objects          { sealed_size, ciphertext_sha256 } → presigned upload URL
GET    /api/v1/vault/objects/:id/url  presigned download URL
DELETE /api/v1/vault/objects/:id      remove object
POST   /api/v1/vault/manifest         { ciphertext_blob } → store latest manifest version
GET    /api/v1/vault/manifest         → latest ciphertext_blob
```

The backend API is intentionally narrow. It cannot interrogate vault contents.

### Payloads
```jsonc
// upload init
{
  "ciphertext_size": 1234567,
  "ciphertext_sha256": "hex...",
  "kdf_params_version": 1
}

// response
{ "object_id": "uuid", "upload_url": "https://...", "headers": {...} }
```

## 4. Permissions & Auth

- All endpoints require auth.
- A user can only ever read/write their own vault.
- RLS strict: `user_id = auth.uid()` on all vault tables.
- No mod/admin override. Period.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Argon2id derivation time | 700-1500 ms on midrange mobile |
| Encryption throughput | ≥30 MB/s on midrange mobile |
| Upload throughput | network-limited |
| Free quota | 5 GB |
| Availability | 99.9% |
| Server-side knowledge | zero plaintext, ever |

## 6. Dependencies

- libsodium binding for Flutter (e.g., `cryptography` package or platform channel to native libsodium).
- Appwrite Storage with per-user bucket prefixes.
- Argon2id parameters chosen to be Postgres-side validatable (we send params, server checks lower bound).

## 7. Observability

- Metrics: `flicko_vault_uploads_total`, `flicko_vault_bytes_stored{user_tier}`, `flicko_vault_decrypt_failures_total` (client-reported), `flicko_vault_quota_breaches_total`.
- Logs: object-id and size only. No filenames (encrypted by client). No content.
- Traces: span on each metadata operation; no body inspection.
- Alerts: decrypt-failure rate >0.1% triggers investigation.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| User forgets passphrase + no recovery seed | files lost | upfront warning + recovery-seed flow during setup |
| Argon2 OOM on low-end device | unlock fails | tiered KDF presets per device class |
| Quota exhausted | upload blocked | UI shows usage; can delete to free space |
| Appwrite bucket compromised | ciphertext leaked, content still safe | rotate user's Appwrite signing scope; user notified |
| Manifest corruption | catalog gone, blobs orphaned | nightly orphan-scan; user can rebuild manifest by listing blobs |

## 9. Threat Model

**Attackers**
- A1: Flicko employee with full DB + Appwrite access. Sees ciphertext only. Cannot derive plaintext.
- A2: Network adversary on TLS path. TLS protects in transit; ciphertext is also opaque.
- A3: Subpoena. We hand over ciphertext. Plaintext recovery requires the user's passphrase or seed, which we do not have.
- A4: Compromised user device. Adversary on the device sees plaintext while the vault is unlocked. Mitigation: auto-lock after 5 minutes of inactivity; biometric re-unlock optional.
- A5: Quantum attacker (future). xchacha20 is symmetric and considered safe; Argon2id derives from passphrase entropy. Mitigation: recovery-seed BIP-39 24-word provides high entropy.

**Assets**
- Master key (in-memory only, on the user's device).
- Recovery seed (shown once during setup; user stores externally).
- Per-file content keys (derived from master + per-file salt; transient).

**Limitations (in user-facing copy)**
- Forgetting the passphrase or seed loses the files. We genuinely cannot recover them.
- Content scanning for CSAM or other illegal material is impossible by design (zero-knowledge). We document this as a tradeoff and explain that uploaded content is the user's sole responsibility.
