# Encrypted Voice — Technical Requirements

## 1. Architecture Overview

```
              ┌──────────────────────────────────────────────┐
              │     existing E2EE service (key delivery)     │
              │     services/e2ee/key_manager.go             │
              └─────────┬────────────────────┬───────────────┘
                        │ sealed envelope    │ sealed envelope
                        ▼                    ▼
   ┌────────────┐                                  ┌────────────┐
   │ Member A   │                                  │ Member B   │
   │  Mobile    │                                  │  Mobile    │
   │            │  ◄── group key (derived) ──►     │            │
   │  LiveKit   │                                  │  LiveKit   │
   │  client    │  insertable streams encrypt/dec  │  client    │
   └─────┬──────┘                                  └──────┬─────┘
         │ ciphertext frames (SFU never decrypts)         │
         ▼                                                ▼
              ┌──────────────────────────────────────┐
              │       LiveKit SFU (relay only)       │
              │       sees opaque RTP payloads       │
              └──────────────────────────────────────┘
                            │
              ┌──────────────────────────────────────┐
              │  Voice key-rotation worker (Go)      │
              │  watches member-change events,       │
              │  triggers new group key + redistrib  │
              └──────────────────────────────────────┘
```

## 2. Components

### Backend (Go) — extends `services/e2ee/`

- **Service:** `internal/services/privacy/encrypted_voice/service.go`
- **Worker:** `internal/services/privacy/encrypted_voice/key_rotation_worker.go`
- **Handler:** `internal/handlers/encrypted_voice_handler.go` (issue LiveKit token w/ E2EE-required claim)
- **Model:** `internal/models/encrypted_voice.go` (`E2EEVoiceChannel`, `GroupKeyEpoch`)
- **Repo:** `internal/repo/encrypted_voice_repo.go`
- **Sealing helper:** delegates to `services/e2ee/key_manager.go::SealForRecipient(envelope)`

### Mobile (Flutter) — extends `features/e2ee/`

- **Feature folder:** `mobile/lib/features/privacy/encrypted_voice/`
  - `data/`: LiveKit room wrapper, group-key store
  - `domain/`: `GroupKeyEpoch`, `EncryptedVoiceChannel`, `EnsureKeyMaterialUsecase`
  - `application/`: `e2eeVoiceJoinProvider`, `e2eeIndicatorProvider`
  - `presentation/`: `EncryptedVoiceChannelScreen`, `E2EEBadge`, `FingerprintVerifySheet`

### Infra

- LiveKit cluster (self-hosted): per-room `enabledE2EE: true`, no recording add-ons attached.
- Realtime: LiveKit's own signaling for media; key-rotation events via Centrifugo `voice:e2ee:<channel_id>`.
- Cache: Redis ephemeral `e2ee:voice:epoch:<channel_id>` (TTL 1h) — current epoch number, never the key.
- Storage: none. The key never reaches the server.

## 3. API Contracts

### REST
```
POST /api/v1/voice/e2ee/channels                  create E2EE voice channel
POST /api/v1/voice/e2ee/channels/:id/token        get LiveKit token + sealed group key envelope
POST /api/v1/voice/e2ee/channels/:id/rotate       force key rotation (admin)
GET  /api/v1/voice/e2ee/channels/:id/fingerprints get participant fingerprint list
```

### WebSocket / Centrifugo
- Channel: `voice:e2ee:<channel_id>`
- Events: `voice.e2ee.epoch_changed` (new epoch n), `voice.e2ee.member_joined` (envelope sealed for current set)

### Payloads
```jsonc
// POST /api/v1/voice/e2ee/channels/:id/token
// response
{
  "livekit_token": "eyJhbGciOi...",
  "livekit_url": "wss://lk.flicko.io",
  "epoch": 14,
  "sealed_envelope": "base64-of-libsodium-sealed-box-containing-group-key",
  "participant_fingerprints": [
    { "user_id": "uuid", "fingerprint": "9c4f-3e8a-..." }
  ]
}
```

## 4. Permissions & Auth

- Required scope: `voice.e2ee.join`.
- Server admin can mark channel as E2EE; members must have a published E2EE identity key (`services/e2ee/identity_keys` table) before joining; if missing, prompt to set up E2EE first.
- LiveKit token issued only after server verifies member is in `channel_members` AND has a valid identity key.
- RLS denies non-members from reading sealed envelopes.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Voice MOS (audio quality) | ≥4.0 |
| Encryption frame overhead | <2% bandwidth |
| Key-rotation latency | <500ms p99 |
| Group size cap | 30 participants |
| Availability | 99.9% |
| Backend cost per E2EE-minute | <$0.0001 (relay only) |

## 6. Dependencies

- LiveKit server v1.7+ with E2EE flag.
- LiveKit Flutter SDK ≥2.0 with insertable-streams support.
- Existing `services/e2ee/` for double-ratchet identity keys.
- libsodium (Flutter `cryptography` package or native binding) for sealed-box envelopes.

## 7. Observability

- Metrics: `flicko_e2ee_voice_joins_total{channel_type}`, `flicko_e2ee_voice_rotations_total{trigger}`, `flicko_e2ee_voice_decrypt_failures_total` (client-reported).
- Logs: server side never sees keys; logs limited to membership and epoch numbers. **Logging a group key would be a P0 incident.**
- Traces: span on token issuance + envelope sealing.
- Alerts: decrypt-failure rate > 1% triggers PagerDuty.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| LiveKit SFU goes down | call drops | LiveKit cluster failover; reconnect logic |
| Identity key missing for joiner | join blocked | Force user through E2EE setup flow |
| Group-size > 30 | join refused | UI explains limit; suggest splitting |
| Old client cannot decrypt new epoch | one user silent | banner "update required for E2EE" |
| Forwards-secrecy gap (key reused after leave) | privacy regression | Auto-rotate on every leave; tested in CI |

## 9. Threat Model

**Attackers**
- A1: Flicko employee with DB / SFU access. Cannot decrypt; never has the group key.
- A2: Network adversary on TLS path. TLS protects metadata; payload also encrypted by group key.
- A3: Compromised participant. Has access while in room; once removed and key rotated, has no access to subsequent audio (PCS).
- A4: Government subpoena. We can hand over membership and ciphertext only. Document this clearly in transparency report.
- A5: Side-channel: traffic-analysis of voice-activity patterns. Mitigation: LiveKit's RTP padding and constant-bitrate codecs. Documented as residual risk.

**Assets**
- Group keys (live in client memory only).
- Per-member identity keys (in `services/e2ee/`; public part in DB, private part on device).
- Sealed envelopes (in DB briefly, useless without recipient's identity private key).

**Limitations (documented for users)**
- Client-side recording (other participant's OS) cannot be prevented.
- Endpoint compromise (malware on a participant's device) defeats E2EE on that device.
- Metadata (who joined, when, channel name, duration) is visible to Flicko.
