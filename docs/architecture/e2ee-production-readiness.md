# Flicko E2EE — Production Readiness Plan

> **Status as of 2026-05-29.** This file tracks every gap between the
> current shipped E2EE and "production-grade enterprise messaging." Each
> item lists scope, blast radius, acceptance criteria, and rough cost.
> Items are checked off as they land in code; deferred items list the
> exact reason they cannot be closed in a single coding session.

## What's already shipped

```
                    ┌─────────────────────────┐
                    │   E2EE shipped today    │
                    └─────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ┌────▼──────┐         ┌───────▼────────┐       ┌───────▼────────┐
   │ Per-pair  │         │ Per-device     │       │ Group sender   │
   │  X3DH +   │         │  fan-out       │       │   keys + dist  │
   │   DR      │         │ (envelopes)    │       │  (3-party OK)  │
   └────┬──────┘         └────────┬───────┘       └───────┬────────┘
        │                         │                       │
        └─────────────┬───────────┴───────────────────────┘
                      │
            ┌─────────▼──────────┐
            │ Storage / control  │
            │  • Argon2id backup │
            │  • SQLCipher WAL   │
            │  • Replay window   │
            │  • Identity alerts │
            │  • CI gating       │
            └────────────────────┘
```

49 mobile + Go protocol-info tests pass on every PR via
`.github/workflows/e2ee-tests.yml`.

## Gap matrix — what "production-grade enterprise" still needs

```
  category       │ status  │ ships in code? │ this session?
 ────────────────┼─────────┼────────────────┼───────────────
  Wire-up        │ partial │ yes            │ YES
  Crypto core    │ partial │ yes (mostly)   │ partial
  Compliance     │ none    │ no             │ no
  Audits         │ none    │ no             │ no
  Operational    │ partial │ no             │ no
```

## Implementation plan — graph view

```
   #A wire banner ──┐
                    │
   #B wire group ───┼──> #G member-removal rotation
                    │       │
   #C attestation ──┘       │
                            │
                            ▼
   #D kMaxSkip boundary ──> #E backend replay tests ──> ✅ regression-safe
                            │
                            ▼
   #F cleanup (dead code, lint quirks)

   ──── DEFERRED (need external work or weeks) ─────
   #X1 PQ hybrid (Kyber-768)         — needs FFI
   #X2 Key transparency / CONIKS     — server work + UX
   #X3 FIPS 140-3 module             — BoringSSL/CC FFI build
   #X4 Memory hygiene (mlock+zeroize) — Rust shim
   #X5 Third-party crypto audit       — external vendor
   #X6 SOC 2 / HIPAA paperwork        — non-engineering
   #X7 Migration 076 deploy           — needs telemetry-driven cutover
```

---

## In-code work items

### #A Wire `IdentityChangeBanner` into the DM chat screen

**What.** When the user opens a DM, call
`E2EESession.checkPeerIdentityChange(peerUserId)`. If the result is non-null
and `oldFingerprint` is non-empty, render the banner above the message
list. First-contact (TOFU) is silently auto-acknowledged on first send so
we don't pester users opening every brand-new conversation.

**Acceptance.**
- DM chat screen subscribes to a Riverpod provider that exposes the alert.
- Banner appears for true rotations only.
- Trust dismisses; subsequent opens stay silent until next rotation.
- Widget test for the controller wiring.

---

### #B Wire `GroupChatSession` into a server-channel repository

**What.** A new `GroupChannelRepository` that:
- Lazy-distributes the device's sender key to every other channel member
  device on first send.
- Persists incoming sender-key distributions under the right `(groupId,
  peer, peerDevice)` key.
- Encrypts outbound channel messages once via `sendGroupMessage`.
- Decrypts inbound messages, falling back to a "request distribution"
  marker when no peer key is cached.

**Acceptance.**
- Repo + provider exist alongside existing channel chat code.
- Existing `chat_notifier` can opt-in via a flag (does not break any
  unencrypted channels).
- Integration test mirroring `group_chat_session_test.dart` covering a
  channel of three members with two devices each.

---

### #C Use `IdentityAttestation` in `checkPeerIdentityChange`

**What.** Today `hasAttestation` is hard-coded false. When a user rotates
identity, their old key signs an attestation of the new pub. Wire the
session to check for an attestation and surface `hasAttestation: true`
when one verifies. Banner softens its tone in that case (still warn,
but not red-alert).

**Acceptance.**
- `IdentityAttestation` lookup added to `checkPeerIdentityChange` (server
  side: a new `e2ee_identity_attestations` table; client side: fetch
  endpoint).
- Banner uses `hasAttestation` to pick warning vs. info tone.
- Tests for attested-rotation, non-attested-rotation, attestation-with-bad-
  signature.

---

### #D Cover the `kMaxSkip=1000` boundary

**What.** Three integration tests against the real ratchet:
- 999 skipped messages: still decrypts the catch-up.
- 1000 skipped: still decrypts (boundary inclusive).
- 1001 skipped: throws `RatchetSkipExceededError` cleanly without
  corrupting state for later messages.

**Acceptance.**
- Tests live in `test/e2ee/` and run in CI.
- Cap behaviour is the tested behaviour; if implementation diverges we
  notice immediately.

---

### #E Backend Go test for envelope replay rejection

**What.** A unit test for `EnvelopeStore.Push` using a real Postgres test
container OR a `pgxmock` that asserts a duplicate `(recipient_user_id,
recipient_device_id, message_hash)` push returns `ErrEnvelopeReplay`.

**Acceptance.**
- Test added to `backend/internal/services/e2ee/`.
- Runs in the existing backend CI workflow.

---

### #F Cleanup

- Remove the `_keepSimpleKeyPairImport` workaround in
  `group_chat_session.dart` and drop the unused `cryptography` import.
- Audit `crypto_service.dart` v1 callers — once nothing is left, delete
  the class entirely (deprecation has had its run).

---

## Sender-key rotation on member removal — #G

This is its own work item because of correctness implications.

**The problem.** Today, when Bob leaves a channel, every remaining member
keeps using the same sender keys. Bob can still receive (and decrypt) any
new messages whose sender keys he already has. The Signal protocol's
prescribed mitigation: every remaining member rotates their sender key
and re-distributes only to the post-removal member set.

**Implementation.**
- `GroupChatSession.rotateOwnSenderKey(groupId)` — discard the cached own
  sender key, call `_ensureOwnSenderKey` (which generates a fresh chain).
- New control kind: `'group-rotate'` is just a fresh sender-key
  distribution; receivers replace the cached peer sender key.
- Caller (channel admin tooling) hooks into "member removed" events and
  invokes rotation on every remaining device.

**Acceptance.**
- `rotateOwnSenderKey` + tests covering: rotation invalidates pre-rotation
  envelopes for the removed device, post-rotation envelopes only decrypt
  with the new key.

---

## Deferred — out of scope for a single coding session

These each need either weeks of work, a native dependency build, or an
external vendor. Listed with the unblocking action so they're trackable.

| ID | Item | Unblocked by |
| --- | --- | --- |
| **X1** | Post-quantum hybrid (X25519 + Kyber-768 in X3DH) | Native FFI dep (libsodium-pq or pqclean) integrated into mobile build |
| **X2** | Key transparency / verifiable directory | Backend Merkle log + gossip protocol; client-side CT proof verification; UX for CT failure |
| **X3** | FIPS 140-3 validated primitives | BoringSSL FFI on Android, CommonCrypto on iOS, plumbed in front of `cryptography` |
| **X4** | Memory hygiene (mlock + explicit zeroize) | Rust/Go shim that owns sensitive buffers behind FFI |
| **X5** | Third-party crypto audit | Engagement with NCC / Trail of Bits / Cure53 |
| **X6** | SOC 2 Type II + HIPAA DPA | Non-engineering, compliance team |
| **X7** | Migration 076 deploy (drop legacy DM columns) | Telemetry showing 100% of clients on per-device-envelope read path |

---

## What "production-ready" means after #A–#G land

Everything that an enterprise CISO inspecting *the code path itself*
would want:
- All ciphertext per-device, every chain audited end-to-end
- User-visible warnings on rotation, attested where possible
- Group messaging hardened against post-departure access
- Replay protection on relay
- Test coverage at protocol boundary (max-skip, replay)
- CI gating on every PR

Anything beyond that — PQ, key transparency, FIPS, audits, paperwork —
is in the deferred section, with clear unblocking criteria. Those are not
"things we forgot," they are "things we cannot finish in code alone."
