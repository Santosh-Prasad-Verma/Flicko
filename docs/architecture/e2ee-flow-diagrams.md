# Flicko E2EE — Flow Diagrams

> Concrete sequence and state diagrams for every flow that runs in
> production. ASCII so it renders in any viewer (terminal, GitHub, IDE).
> Pair this with `e2ee-production-readiness.md` for the gap analysis.

---

## 1. System architecture (who lives where)

```
   ┌─────────────────────────────────────────────────────────────────┐
   │                         FLICKO BACKEND                          │
   │   (Go — server NEVER sees plaintext, private keys, or backups)  │
   ├─────────────────────────────────────────────────────────────────┤
   │  e2ee_identity_keys      │ device pubs (X25519 + Ed25519)       │
   │  e2ee_signed_prekeys     │ medium-lived signed prekeys          │
   │  e2ee_one_time_prekeys   │ single-use OTKs (atomic consumption) │
   │  e2ee_message_envelopes  │ relay queue (per-device ciphertext)  │
   │  e2ee_envelope_dedup     │ replay window (7d, sha256 hash)      │
   │  e2ee_identity_attest…   │ rotation attestations                │
   │  dm_message_envelopes    │ per-device DM ciphertext (post-075)  │
   └─────────────────────────────────────────────────────────────────┘
                              ▲   │
                       HTTPS  │   │  HTTPS
                              │   ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │                      FLICKO MOBILE (Dart)                       │
   ├─────────────────────────────────────────────────────────────────┤
   │  E2EESession            │ X3DH + Double Ratchet (per-pair)      │
   │  GroupChatSession       │ Sender keys + distribution            │
   │  EncryptedChannelRepo   │ Channel send/receive over GroupChat   │
   │  SecureKeystore         │ iOS Keychain / Android Keystore       │
   │  RatchetWalStore        │ SQLCipher WAL of ratchet state        │
   │  IdentityChangeBanner   │ UI for rotation alerts                │
   └─────────────────────────────────────────────────────────────────┘
```

---

## 2. First-launch bootstrap

What `E2EESession.ensureBootstrapped()` does on a brand-new device.

```
   APP FIRST RUN
        │
        ▼
   ┌─────────────────────────────────────┐
   │ SecureKeystore.getOrCreateDeviceId  │ ──── 16-byte hex, persisted
   └─────────────────┬───────────────────┘
                     │
                     ▼
   ┌─────────────────────────────────────┐
   │ generate X25519 identity keypair    │
   │ generate Ed25519 signing keypair    │ ──── private parts NEVER leave
   │ store in flutter_secure_storage      │     OS keystore
   └─────────────────┬───────────────────┘
                     │
                     ▼
   ┌─────────────────────────────────────┐         PUT /e2ee/identity
   │ POST identity pubs + fingerprint    │  ─────► (device_id, identity_pub,
   └─────────────────┬───────────────────┘         signing_pub, fingerprint)
                     │
                     ▼
   ┌─────────────────────────────────────┐
   │ generate signed prekey (X25519)     │
   │ sign SPK pub with Ed25519 signing key│         PUT /e2ee/signed-prekey
   └─────────────────┬───────────────────┘  ─────► (key_id, public_key,
                     │                              signature)
                     ▼
   ┌─────────────────────────────────────┐
   │ generate 25 one-time prekeys        │         PUT /e2ee/one-time-prekeys
   │ persist private parts locally       │  ─────► [{key_id, public_key} × 25]
   └─────────────────────────────────────┘
```

---

## 3. First message — X3DH session bootstrap

```
   ALICE (sender)                                BACKEND                                 BOB (receiver)
   ──────────────                                ───────                                 ──────────────

   encryptV2('hi bob')
        │
        │ GET /e2ee/devices/bob          ─────────►
        │                                              ◄──── [bob.phone, bob.laptop]
        │
        │ for each device:
        │   GET /e2ee/bundle/bob?device_id=phone ────►
        │                                              ◄──── { identity, signed_prekey,
        │                                                       one_time_prekey }
        │                                              [server atomically consumes 1 OTK]
        │
        │ verify signed_prekey signature
        │ under bob's signing pub
        │      │
        │      ▼
        │ X3DHEngine.initiatorStart:
        │   EK = new ephemeral X25519 keypair
        │   DH1 = DH(IK_alice, SPK_bob)
        │   DH2 = DH(EK,        IK_bob)
        │   DH3 = DH(EK,        SPK_bob)
        │   DH4 = DH(EK,        OTK_bob)        (4-DH if OTK present, else 3-DH)
        │   SK  = HKDF(DH1||DH2||DH3||DH4, "flicko-x3dh-v2")
        │      │
        │      ▼
        │ DoubleRatchet.initSender(sharedKey=SK, recipientDhPub=SPK_bob)
        │   • DHs = new X25519 (sending)
        │   • RK, CKs = HKDF(SK, DH(DHs, SPK_bob), "flicko-ratchet-root-v2")
        │      │
        │      ▼
        │ DoubleRatchet.encrypt(state, "hi bob", AAD = IK_alice || IK_bob)
        │   • MK = HKDF(CKs, "flicko-ratchet-msg-v2-mk")
        │   • CKs' = HKDF(CKs, "flicko-ratchet-msg-v2-ck")
        │   • header = (DHs.pub, pn=0, n=0)            (40 bytes on wire)
        │   • nonce = random(24)
        │   • ct = XChaCha20-Poly1305(MK, plaintext, nonce, AAD = header || sender_IK || recipient_IK)
        │      │
        │      ▼
        │ envelope = {
        │    is_initial: true,
        │    sender_identity_pub: IK_alice,
        │    sender_ephemeral_pub: EK.pub,
        │    prekey_id, signed_prekey_id,
        │    ratchet_header: header,
        │    ciphertext: nonce || ct
        │ }
        │
        │ POST /e2ee/envelopes  ─────────────────────►
        │                                              [dedup: sha256(header||ct) NOT in window]
        │                                              [INSERT into e2ee_message_envelopes]
        │                                              ◄──── 200 OK
        │                                                                    decryptV2(envelope, sender='alice')
        │                                                                       │
        │                                                                       │ envelope.is_initial = true
        │                                                                       │ no cached state → run X3DH responder
        │                                                                       │
        │                                                                       │ X3DHEngine.responderAccept:
        │                                                                       │   DH1 = DH(SPK_bob, IK_alice)
        │                                                                       │   DH2 = DH(IK_bob,  EK)
        │                                                                       │   DH3 = DH(SPK_bob, EK)
        │                                                                       │   DH4 = DH(OTK_bob, EK)  if OTK was used
        │                                                                       │   SK' = HKDF(DH1||DH2||DH3||DH4, ...)
        │                                                                       │   ASSERT SK' == SK    ✓
        │                                                                       │
        │                                                                       │ DoubleRatchet.initRecipient(SK')
        │                                                                       │ DoubleRatchet.decrypt(state, header, ct, AAD)
        │                                                                       │   • derive MK from CKr
        │                                                                       │   • ct → "hi bob"          ✓
        │                                                                       │
        │                                                                       │ persist new ratchet state to WAL
        │
        │ persist new ratchet state to WAL
```

---

## 4. Subsequent messages — Double Ratchet (per-pair)

Once the X3DH bootstrap is done, every subsequent message advances the
ratchet on both sides. Forward secrecy: each message key is discarded
after one use. Post-compromise security: a stolen ratchet state can be
recovered from after the next DH ratchet step.

```
   ALICE                           BOB
   ──────                          ──────

   encryptV2('msg #2')
        │
        │ recover ratchet from WAL
        │ advance sending chain:
        │   MK_2 = HKDF(CKs_1, "msg-mk")
        │   CKs_2 = HKDF(CKs_1, "msg-ck")
        │   forget CKs_1, MK_2 used once
        │
        │ encrypt with MK_2
        │ header = (DHs, pn=0, n=1)
        │
        │ POST envelope  ────────► relay  ──► decryptV2
        │                                       │
        │                                       │ recover ratchet from WAL
        │                                       │ no DH change → stay on receiving chain
        │                                       │ advance to n=1 → MK_2'
        │                                       │ decrypt → 'msg #2'  ✓
        │
        │ persist state                                       persist state

   ──────────────────────────────────────────────────────────────────
   Bob replies — DH RATCHET STEP fires on Alice's side when she sees
   a NEW DHr.pub in Bob's header.
   ──────────────────────────────────────────────────────────────────

   BOB encryptV2('reply')
        │
        │ his sending chain is null until he generates one:
        │   DHs_bob = new X25519
        │   RK', CKs_bob = HKDF(RK, DH(DHs_bob, DHr=DHs_alice), root-info)
        │   MK = derive from CKs_bob
        │
        │ header carries DHs_bob.pub
        │
        │ POST envelope  ────────► relay  ──► ALICE decryptV2
        │                                       │
        │                                       │ header.DH ≠ DHr (cached)
        │                                       │ → DH RATCHET STEP:
        │                                       │   skip leftovers on old chain
        │                                       │   derive new RK, CKr from
        │                                       │   DH(DHs_alice, header.DH)
        │                                       │   generate new DHs_alice
        │                                       │   derive new CKs_alice
        │                                       │ now decrypt 'reply'  ✓
```

---

## 5. Out-of-order delivery — skipped-key cache

```
   Sender chain:   M0 ─── M1 ─── M2 ─── M3 ─── M4
                   ↓                          ↓
   Receiver sees:  M0 ──────────────────────► M4
                   │                          │
                   │ M0: in order             │ M4: skip M1, M2, M3
                   │ derive MK_0              │ derive MK_1, MK_2, MK_3
                   │ decrypt                  │ cache them as
                   │                          │   skipped[(DHr, 1)] = MK_1
                   │                          │   skipped[(DHr, 2)] = MK_2
                   │                          │   skipped[(DHr, 3)] = MK_3
                   │                          │ derive MK_4 → decrypt M4  ✓

   Later, M2 arrives:
                                              │ skipped[(DHr, 2)] hit
                                              │ pop MK_2 → decrypt M2  ✓

   CAP: kMaxSkip = 1000.
   If header.n - state.nr > 1000: throw RatchetSkipExceededError.
   Conversation can recover after the next DH ratchet step.
```

---

## 6. Multi-device fan-out (DM)

```
                     ALICE encryptV2ToAllDevices("yo")
                                │
                                │ GET /e2ee/devices/bob ────► [phone, laptop]
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
   encryptV2 (peerDevice=phone)    encryptV2 (peerDevice=laptop)
        independent X3DH                independent X3DH
        independent ratchet              independent ratchet
   ─── envelope_phone ────────       ─── envelope_laptop ────────
                │                               │
                └─────────────┬─────────────────┘
                              ▼
   INSERT INTO direct_messages (id, sender, recipient, is_encrypted=true,
                                  e2ee_protocol_version='v2',  ...)
   INSERT INTO dm_message_envelopes (rows × 2)
                              │
                              ▼
                     each device pulls DM row + joins envelopes;
                     filters by recipient_device_id = ME;
                     decryptV2 on the row addressed to it.
```

---

## 7. Group messaging — sender keys

Per-pair X3DH/DR scales as O(N²) per channel. Sender keys collapse it to
O(N) once distribution has happened.

```
   ┌── Phase 1: distribution ── (per-pair, ONCE per chain) ──────────────┐
   │                                                                     │
   │   ALICE.GroupChatSession:                                           │
   │     SK_alice = generate sender key for groupId                      │
   │     payload  = {kind:'group-sender-key', payload: SK_alice.toJson}  │
   │                                                                     │
   │   for each member device:                                           │
   │     E2EESession.encryptV2(payload) → per-pair ratchet envelope      │
   │     POST → e2ee_message_envelopes / dm_message_envelopes            │
   │                                                                     │
   │   each receiver:                                                    │
   │     decryptV2 → tryAcceptControlPayload                             │
   │     cache SK_alice keyed by (groupId, alice.userId, alice.device)   │
   └─────────────────────────────────────────────────────────────────────┘

   ┌── Phase 2: broadcast ── (one ciphertext, many readers) ─────────────┐
   │                                                                     │
   │   ALICE.sendGroupMessage("ship it"):                                │
   │     advance SK_alice → MK                                           │
   │     ct  = XChaCha20-Poly1305(MK, "ship it")                         │
   │     sig = Ed25519(alice.signing, "flicko-sender-key-sig-v2" ||      │
   │                   groupId || alice.device || chainId || ct)         │
   │     envelope = (groupId, sender_device, chainId, ct, sig)           │
   │                                                                     │
   │   ──── ONE envelope ───────────────────────────────────────────►    │
   │                                                                     │
   │   each receiver.receiveGroupMessage(envelope):                      │
   │     verify sig under cached SK_alice.signingPub  ← reject if bad    │
   │     advance their cached SK_alice → MK'                             │
   │     decrypt ct with MK'                                             │
   └─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Identity change detection — TOFU + rotation + attestation

```
   on chat_screen.open(peer='bob'):
        │
        ▼
   E2EESession.checkPeerIdentityChange('bob')
        │
        │ GET /e2ee/identity/bob  ──► newFp = sha256(IK_bob_now)
        │
        │ oldFp = SecureKeystore.getLastSeenPeerFingerprint('bob')
        │
        ├─── oldFp == newFp ────► return null            ──► no banner
        │
        ├─── oldFp == null   ────► return Alert(old='', new=newFp)
        │                          provider auto-acks (TOFU)  ──► no banner
        │
        └─── oldFp != newFp  ────► ROTATION
                                      │
                                      │ GET /e2ee/identity/attestation/bob?new_pub=…
                                      │
                                      ├── 404 → hasAttestation=false
                                      │
                                      └── 200 → att = (oldPub, newPub, sig)
                                          oldSigningPub = SecureKeystore
                                              .getLastSeenPeerSigningPub('bob')
                                          msg = "rotate:" + att.oldPub + ":" + att.newPub
                                          ok = Ed25519.verify(oldSigningPub, sig, msg)
                                          hasAttestation = ok

                                      return Alert(old=oldFp, new=newFp, hasAttestation)
                                                ▼
                                      IdentityChangeBanner renders:
                                        ─────────────────────────────────
                                        │ ⚠ Their security code changed │
                                        │   Previously: aa…             │
                                        │   Now:        bb…             │
                                        │   [Verify]  [Trust]           │
                                        ─────────────────────────────────
                                      Trust → acknowledgePeerIdentity()
                                            → store newFp + newSigningPub
```

---

## 9. Replay rejection — server-side dedup

```
   ALICE                                  BACKEND
   ──────                                 ───────
   POST envelope (header, ct)  ────►  hash = sha256(header || ct)
                                       BEGIN TX
                                         INSERT e2ee_envelope_dedup
                                            (recipient, recipient_device, hash)
                                            ON CONFLICT DO NOTHING
                                         ─── tag.RowsAffected() ───
                                            == 0 → already seen
                                                    ROLLBACK
                                                    409 Conflict        ◄── ErrEnvelopeReplay
                                            == 1 → fresh
                                                    INSERT envelope
                                                    COMMIT
                                                    200 OK

   Window: 7 days (matches signed-prekey validity).
   GC: e2ee_envelope_dedup rows older than the window are purged by
       a periodic job (EnvelopeStore.GCDedup).
```

---

## 10. Sender-key rotation (member removal)

```
   ── BEFORE rotation: SK_alice is shared with [bob, mallory] ──

   ALICE                          MALLORY (will be removed)
   ──────                         ──────────────────────────
   sendGroupMessage("a")  ─────►  receiveGroupMessage  ──► "a"  ✓

   ── Mallory is removed from the channel ──

   ALICE.rotateOwnSenderKey(channelId)
        │
        │ generate fresh SK_alice'
        │ overwrite SecureKeystore.writeOwnSenderKey
        │
        ▼
   distributeSenderKey(recipients=[bob])      ← Mallory NOT in the list
        │
        │ encryptV2(payload, peer=bob)
        ▼
   ── BOB caches SK_alice'; MALLORY still has SK_alice ──

   ALICE.sendGroupMessage("locked-out")
        │ advances SK_alice' → chainId=1
        ▼
   envelope = (chainId=1, sig = Ed25519(alice.signing, …))
        ▼
   BOB:    cached SK_alice' → ✓ decrypts
   MALLORY: cached SK_alice  → ✗ chain mismatch → throw

   The forward secrecy of the OLD sender key means even if Mallory
   later leaks her cached SK_alice, no future messages decrypt under it.
```

---

## 11. Storage layout

```
   ┌─────────────────────── ON DEVICE ──────────────────────────┐
   │                                                            │
   │  iOS Keychain / Android Keystore (flutter_secure_storage)  │
   │     identity_priv (X25519)                                 │
   │     signing_priv  (Ed25519)                                │
   │     signed_prekey_priv                                     │
   │     otk_priv.<keyId>  (deleted on use)                     │
   │     peer_fp.<userId>          ← TOFU baseline              │
   │     peer_signing.<userId>     ← for attestation verify     │
   │     group.own_sk.<groupId>                                 │
   │     group.peer_sk.<gid>|<uid>|<dev>                        │
   │     wal.master                ← random 32-byte SQLCipher key│
   │                                                            │
   │  SQLCipher (ratchet_wal.db) — encrypted with wal.master    │
   │     ratchet_wal: append-only snapshots of RatchetState     │
   │     hash chain over (snapshot, prev_hash)                  │
   │     compaction every 10 entries / 7 days                   │
   │                                                            │
   └────────────────────────────────────────────────────────────┘

   ┌──────────────────────── ON SERVER ─────────────────────────┐
   │                                                            │
   │  Postgres (Supabase + Go API):                             │
   │     PUBLIC KEYS only — never private bytes                 │
   │     identity_pub, signing_pub, prekeys, signatures         │
   │     ciphertexts (cannot be decrypted server-side)          │
   │     verification audit log (immutable)                     │
   │     replay dedup window (7d)                               │
   │     escrow registry (off by default, opt-in)               │
   │                                                            │
   └────────────────────────────────────────────────────────────┘
```

---

## 12. Trust boundary cheat sheet

| Crosses the trust boundary?      | Direction               | Encryption       |
| -------------------------------- | ----------------------- | ---------------- |
| Identity public keys             | device → server → peer  | TLS only (pubs)  |
| Signed prekeys + signatures      | device → server → peer  | TLS only (pubs)  |
| One-time prekeys                 | device → server → peer  | TLS only (pubs)  |
| **Plaintext message content**    | NEVER leaves device     | n/a              |
| Message ciphertext               | sender → server → recv  | E2EE (XChaCha20) |
| Sender keys (group)              | inside per-pair ratchet | E2EE             |
| Backup chunks                    | device → server         | Argon2id + AEAD  |
| Identity attestations            | device → server → peer  | TLS (sig is E2E) |
| Private keys / chain keys        | NEVER leave device      | n/a              |

If anything in the "NEVER" rows ever shows up in a network capture or
server log, that is an incident — investigate immediately.
