# Server Soundboard — Product Requirements

> **One-line:** Mods upload custom audio clips that members can trigger in voice channels with cooldowns and per-role permissions.
> **Status:** Missing — to build
> **Category:** 02-discord-parity-customization
> **Effort:** L
> **Priority:** P1

## 1. Problem

Discord shipped Soundboard in 2023; it's now a default expectation for any chat-with-voice product. Flicko has voice channels (Azure ACS-backed) and stickers, but no way for a member in voice to play a short audio clip the whole room hears. This is the single most-asked-about voice feature in our community Discord (147 references in 6 months).

The unlock isn't just parity. Custom community-uploaded clips are the *culture* of a server: in-jokes, hype clips, walk-on music, "ding" reactions. Without it, voice channels feel sterile compared to the rest of the platform.

Evidence:
- 147 Discord posts in our community channel ask for soundboard.
- 6 of 12 dogfood mods report manually playing audio through their mic ("ghetto soundboard"), which is laggy and breaks echo cancellation.
- Voice channel DAU is ~9% of total; soundboard adds the kind of sticky moment that grows that number on Discord (their published metric: +18% voice DAU after launch).

## 2. Users & Use Cases

- **Primary persona:** Priya, 19, member of a 2k esports server. Lurks in voice. Wants to hit a "GG" clip without unmuting.
- **Secondary personas:**
  - Mods curating a clean clip library; tagging clips by emoji.
  - Server owners worried about abuse (spam, NSFW audio).
  - Hearing-impaired members who want a visual indicator when a clip plays.

Top 3 jobs-to-be-done:
1. As a member in a voice channel, I want to play a short audio clip everyone hears, so that I can react without speaking.
2. As a mod, I want to upload, label, and emoji-tag clips, so that the library is searchable.
3. As a server owner, I want per-role permissions and cooldowns, so that the room doesn't become a wall of noise.

## 3. Goals & Non-Goals

**Goals**
- Mod uploads .mp3/.m4a/.ogg/.wav, ≤512 KB, ≤5 s, mono or stereo.
- Backend transcodes to opus 48kHz mono at 32 kbps; stores both original and opus on Appwrite.
- Library has 24 default clips on every server (Flicko-curated, free) and up to 48 custom slots (96 with Plus).
- Per-clip emoji label and name.
- Per-role permission: who can play, who can upload, who can manage.
- Per-user cooldown via Redis (default 5 s, mod-configurable 1–60 s).
- Playback fan-out via Azure ACS data tracks; clients render audio plus a visual chip.
- Recent-clips drawer per voice channel.

**Non-Goals (out of scope for v1)**
- TTS / generated clips.
- Clip volume mixing controls (use voice volume).
- Music streaming (covered by sonic_music feature).
- Per-clip cost / monetization.
- Premium-only sounds marketplace (post-GA).

## 4. Scope (v1)

- [x] `soundboard_clips` + `soundboard_default_clips` tables.
- [x] Appwrite bucket `soundboard-clips` with original + opus variants.
- [x] REST: list, upload, update, delete, play.
- [x] Azure ACS data-track event `soundboard.play` published by backend after permission + cooldown checks.
- [x] Redis cooldown key `sb:cd:{server_id}:{user_id}` (TTL = configured cooldown).
- [x] Flutter: clip grid sheet attached to voice room overflow; recent drawer; haptics on play.
- [x] Visual indicator for hearing-impaired members.
- [x] Audit log entry on upload, delete, play.
- [x] Report-clip flow.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Plays per voice-DAU | ≥4 / day | PostHog event `soundboard.play` |
| Custom clips per active server (median) | ≥6 in 30d | DB query |
| Voice DAU lift after launch | +12% within 60d | A/B with 5% holdout |
| Cooldown-hit rate | <8% of attempts (signals overload) | service log |
| Storage cost / server / month | <$0.005 | Appwrite |
| Playback latency (button tap → all peers hear) | p95 <250 ms | Azure ACS telemetry |
| Reports per 1k plays | <2 | moderation log |

## 6. Open Questions / Risks

- **Bandwidth:** opus at 32 kbps × N peers. With 30-peer rooms and 4 plays/min, that's negligible (Azure ACS handles SFU fan-out).
- **Echo / mix:** clip plays through *member's local audio output*, not microphone. Verified: Azure ACS data track + remote audio element pattern (no mic re-capture).
- **Abuse:** loud/jumpscare clips. Mitigation: server-side normalize loudness to -16 LUFS; mods can disable a clip server-wide; report flow.
- **Plus gating:** Discord locks Soundboard slots behind Nitro tiers. We give 48 free + 96 with Plus. Clear and generous.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Soundboard in voice; Nitro raises slot count to 48 | We give 48 free, 96 with Plus |
| Slack | None | Pure parity gain |
| Telegram | Voice chat reactions only | Full clip library |
| Revolt | Doesn't exist | First-class community soundboard |

## 8. Rollout

- Internal dogfood (3 servers, 1 week).
- 1% beta cohort, 7 days.
- 10% → 50% → 100% across 10 days.
- Kill switch: `feature.server_soundboard.enabled`.
- Per-server toggle in server-settings.

## 9. Dependencies

- Azure ACS (live; already used for voice).
- `services/voice_service.go` for room metadata.
- `services/permissions_service.go` for role checks.
- `services/audio_normalize_service.go` (new, ffmpeg).
- Appwrite storage (live).
- Redis (live; cooldown).
- Existing soundboard sheet skeleton at `mobile/lib/features/voice/presentation/soundboard_sheet.dart` — extend.
