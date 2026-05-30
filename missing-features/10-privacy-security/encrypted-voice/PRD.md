# Encrypted Voice — Product Requirements

> **One-line:** End-to-end encrypted voice channels using LiveKit insertable streams + group keys.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** XL
> **Priority:** P1

## 1. Problem

Discord voice is fully decryptable on Discord's servers. Even though the network is TLS-secured, Discord has the key, can MITM, can record, can transcribe with AI. For most casual voice chat that does not matter. For activists, lawyers and journalists, sensitive interviewees, or anyone running a private support call, it is a non-starter.

Real evidence:
- Multiple high-profile leaks of Discord voice content extracted by court order (2023-2025).
- Activist communities have shifted entirely off Discord voice to Mumble or Jitsi for sensitive calls.
- LiveKit released production-grade insertable-streams E2EE in late 2024; the building block exists, the UX hasn't been democratized.

The pain: there is no mainstream gamer-friendly voice product with true E2EE, where the server provider cannot decrypt the audio.

## 2. Users & Use Cases

- **Primary persona:** Members of small-to-medium private groups (5-30 participants) who want server-side guarantees that nobody at Flicko can hear them.
- **Secondary personas:** Journalists with sources; legal teams; activists; therapists running peer-support calls.
- **Top 3 jobs-to-be-done:**
  1. As a community member, I want a voice channel where Flicko cannot decrypt the audio, so that a subpoena yields ciphertext only.
  2. As a server admin, I want to mark certain voice channels as E2EE, so that members joining know what they get.
  3. As a member, I want a clear visual indicator that the call is end-to-end encrypted, so that I can trust it.

## 3. Goals & Non-Goals

**Goals**
- LiveKit insertable streams with AES-GCM frame encryption.
- Group key derivation per-channel; rotation on member-join and member-leave (forward + post-compromise security).
- Key distribution rides the existing E2EE messaging service (Signal-like double-ratchet between members; new joiners receive the current group key sealed).
- Visible "E2EE" badge with a tap-to-verify-fingerprints flow.
- Recording disabled at the server protocol level for E2EE channels (we cannot prevent client-side recording).

**Non-Goals (out of scope for v1)**
- Video E2EE (audio only in v1).
- E2EE for >30 participants (key-distribution cost grows; punt).
- Recording / transcription features for E2EE channels (those features exist for non-E2EE channels).
- Hardware-attestation of clients.

## 4. Scope (v1)

- [ ] Toggle "End-to-end encrypted" on voice-channel creation.
- [ ] LiveKit deployment with `e2eeEnabled: true` per-room.
- [ ] Group key generation + rotation worker.
- [ ] Per-member sealed-envelope key delivery via existing `services/e2ee/`.
- [ ] Visual indicator + fingerprint verification UI.
- [ ] Block server-side recording, transcription, AI moderation, VAD on E2EE channels.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers using E2EE voice | 2% of voice-active servers within 90d | server_settings query |
| Median call quality (MOS) | ≥4.0 | LiveKit telemetry |
| Key-rotation latency on member change | <500ms p99 | metric |
| Fingerprint verifications per call | ≥1 in P1 servers | event |
| E2EE indicator visible at all times | 100% | UI test |

## 6. Open Questions / Risks

- **Risk: LiveKit version skew** — old client cannot decrypt new key. Mitigation: client-version gate; force-upgrade banner for E2EE rooms.
- **Risk: silent failure to encrypt** — bug ships unencrypted audio with E2EE badge shown. Mitigation: client-side assertion that frame is opaque before sending; never display badge unless verified.
- **Risk: subpoena UX** — government asks "decrypt this." Answer: technically impossible by design; document this clearly.
- **Open: TURN server visibility** — we relay encrypted media but never have keys. Document.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Server-decryptable | True E2EE |
| Signal | E2EE 1:1 + small groups | We do server-channel groups w/ moderation |
| Mumble (self-host) | Encrypted but DIY | We provide hosted UX |
| Jitsi E2EE | Available but clunky | Native mobile UX |

## 8. Rollout

- Internal dogfood (security team) → 0.5% beta → 5% → GA.
- Kill switch: `feature.encrypted_voice.enabled`.
- Per-server flag: `server_voice_settings.e2ee_available`.
- Privacy-policy + threat-model doc must ship simultaneously.
