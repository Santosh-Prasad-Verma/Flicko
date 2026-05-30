# Private Vaults — Product Requirements

> **One-line:** Personal encrypted file storage with a key only the user holds.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** L
> **Priority:** P1

## 1. Problem

Discord users routinely use the platform to host their own files — backup drafts, screenshots, source files, snippets. The "personal upload archive" pattern works because it's convenient, but every byte sits decrypted on Discord's CDN, indexable, scannable, and one breach away from public. There is no first-party "store this for me, but only I can read it" surface.

Real evidence:
- Reddit/r/DataHoarder threads on "best free encrypted personal storage" cycle every month.
- Mega.nz, Tresorit, and Cryptomator have a market because mainstream cloud storage (iCloud, Dropbox, Google Drive) has the keys.
- Communities working with sensitive media (legal evidence, source materials, recovery photos) ask for encrypted "Saved" surfaces inside chat apps.

The pain: convenient storage is not private; private storage is not convenient.

## 2. Users & Use Cases

- **Primary persona:** Power users who already use Flicko's "saved messages" surface for personal scratch storage and want a private equivalent.
- **Secondary personas:** Journalists keeping interview audio safe; designers backing up drafts; activists holding evidence.
- **Top 3 jobs-to-be-done:**
  1. As a power user, I want a personal vault inside Flicko, so that I do not have to juggle a separate cloud service.
  2. As a privacy-conscious user, I want Flicko to never be able to read my files, so that even a server breach yields ciphertext.
  3. As a user, I want to recover my vault on a new device, so that losing my phone does not lose my files.

## 3. Goals & Non-Goals

**Goals**
- Personal vault per user; files encrypted client-side with a user-only key before upload.
- Server stores ciphertext + metadata; no key material on the server.
- libsodium secretbox (xchacha20-poly1305) for files; Argon2id key derivation from passphrase.
- Cross-device sync: same passphrase derives the same key.
- Recovery: if user forgets passphrase, files are lost (zero-knowledge guarantee). 24-word recovery seed offered as alternative.
- Per-file metadata (filename, size, mime) is itself encrypted; only opaque length and a salted hash are visible to the server.

**Non-Goals (out of scope for v1)**
- Sharing files from the vault (would require key exchange; v2).
- Streaming media playback in-place (encrypted-at-rest blobs require download-decrypt-play; for v1, download-then-open).
- Full-text search across vault contents (would require server-side indexing of plaintext, defeating zero-knowledge).

## 4. Scope (v1)

- [ ] Vault setup flow with passphrase + recovery seed.
- [ ] Argon2id KDF parameters tuned for mobile (memory-hard, ≥ 256MB, 3 iterations).
- [ ] File upload: client encrypts → uploads ciphertext to Appwrite vault bucket.
- [ ] File listing: encrypted manifest stored separately.
- [ ] File download + decryption.
- [ ] File rename / delete (manifest update).
- [ ] Recovery seed export (one-time, displayed in-app).
- [ ] Multi-device sync via passphrase or recovery seed.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| % of DAU who set up a vault | ≥3% within 90d | event |
| Storage / user (encrypted) | <500MB median | infra |
| Decryption failures | <0.01% per download | event |
| Recovery seed activations | ≥30% of vault setups complete recovery flow | event |
| Support tickets re lost passphrase | tracked, not dropped to 0 (impossible by design) | tag |

## 6. Open Questions / Risks

- **Risk: lost passphrase = lost files.** This is by design but is a UX cliff. Mitigation: recovery seed; multi-device sync helps; upfront warning.
- **Risk: KDF parameters too heavy on low-end Android.** Mitigation: profile, allow per-device tier (256MB / 128MB / 64MB).
- **Open: file-size cap?** v1 caps at 250MB per file to keep memory profile sane on mobile.
- **Open: legal-hold policy?** Documented: subpoenas yield ciphertext only; no rubber-stamp decryption.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord saved messages | server-readable | Zero-knowledge equivalent |
| iCloud Drive | provider key | E2EE always |
| Cryptomator | DIY | Native UX inside Flicko |
| Mega.nz | E2EE but standalone | Inside chat app |

## 8. Rollout

- Internal dogfood → 2% beta → 10% → GA.
- Kill switch: `feature.private_vaults.enabled`.
- Per-user opt-in (no auto-creation; vault setup is explicit).
