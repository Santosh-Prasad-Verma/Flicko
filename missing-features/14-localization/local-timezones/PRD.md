# Local Timezones — Product Requirements

> **One-line:** Display every timestamp in the user's local timezone with relative-time UI and absolute-on-hover.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** S
> **Priority:** P0
> **Slug:** `local-timezones`

## 1. Problem

Flicko stores timestamps in UTC (correct) but currently renders them as either UTC or the server's TZ (wrong). When a user in Tokyo sees "scheduled 14:00 UTC" they have to mentally add 9 hours; when they see relative-time "5 minutes ago" without absolute-on-hover, they cannot verify when an event actually occurred. This is a 2-line fix from a code perspective but requires a system-wide audit because timestamp rendering is sprinkled across ~80 widgets.

Real evidence:
- 4 GitHub issues asking "show messages in my timezone".
- Stage / scheduled-event timestamps are particularly painful: a 22:00 UTC event is 7am the next day in Tokyo, and the current UI doesn't make that obvious.
- Voice channel "started 2h ago" is fine, but "Recording from 2026-05-29 14:00 UTC" is not.

## 2. Users & Use Cases

- **Primary persona:** "Hiroshi in Tokyo" — wants every timestamp in JST.
- **Secondary personas:** event organizers scheduling cross-region meetings; recording listeners trying to find a clip from "yesterday 8pm".
- **Top jobs-to-be-done:**
  1. As a global user, I want all times shown in my zone, so that I never miscalculate.
  2. As an event creator, I want to see how my time displays for invitees in their zone, so that "8pm my time" is clear to them.
  3. As an admin, I want audit logs in my TZ for forensic clarity.

## 3. Goals & Non-Goals

**Goals**
- All UI timestamps render in user's TZ (auto-detected from device, override-able).
- Relative time + absolute-on-tap (mobile) / on-hover (web) for every timestamp.
- Scheduled events display in viewer's TZ with creator's TZ in tooltip.
- Backend persists everything in UTC (no change).
- Date pickers honor locale's first-day-of-week (Sun/Mon).
- Export and CSV downloads include both UTC and viewer-TZ columns.

**Non-Goals (out of scope for v1)**
- Per-channel timezone (a server in Tokyo vs members in NYC — keep it user-scoped).
- Historical TZ-rule changes for very old events (we use IANA tzdata which Flutter ships with).
- Calendar invites (.ics export) — separate feature.

## 4. Scope (v1)

- [ ] `profile.timezone` column (IANA, e.g. `Asia/Tokyo`)
- [ ] Auto-detect TZ on signup from device (`DateTime.now().timeZoneName`)
- [ ] `Timestamp` widget: `<relative> · <absolute>` on tap
- [ ] `RelativeTime.format(dt, locale, tz)` helper using `intl`
- [ ] Replace all `DateFormat` usages outside the helper with the centralized one
- [ ] Settings → Timezone picker (search by city + UTC offset)
- [ ] Scheduled-event widget shows: "8:00 PM your time (5:00 AM creator time, JST)"
- [ ] CSV exports add `timestamp_local` column
- [ ] Pseudo-zone in dev menu (e.g. UTC-13 to expose any UTC-only assumptions)
- [ ] Mail-gateway: receipts and notifications include user's TZ-formatted time

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Users with non-UTC TZ set | 90% within 30d | profile field |
| TZ-related support tickets | <2/week post-GA | support tags |
| Mismatch reports | 0 | regression dashboard |
| Cost | $0 | n/a |

## 6. Open Questions / Risks

- Daylight Saving Time edge cases — handled by IANA tzdata which Flutter ships in `package:timezone`.
- Some users want UTC even though they live elsewhere (devops, analysts) — provide explicit "UTC" option.
- Half-hour and quarter-hour zones (IST UTC+5:30, NPT UTC+5:45, ACWST UTC+8:45) — ensure picker shows these correctly.
- When users travel: do we re-detect on each session? Default = yes, with toast on change.
- Event scheduling is deceptively hard: if creator says "every Monday 9am Tokyo", a viewer in NYC seeing "8pm Sunday" must understand DST shifts can desynchronize the two over the year. Solve in v2.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Local TZ only via Markdown timestamps `<t:1234567890:R>` | We make every timestamp work, no markdown |
| Slack | Solid local TZ; ID 1989-shipping | We match |
| Notion | Local TZ; absolute on hover | We match |
| Linear | Local TZ everywhere | We match |

## 8. Rollout

- Phase 1: Settings screen + auto-detect → silent rollout (already shows UTC, no regression).
- Phase 2: All `Text(date.toString())` replaced with `Timestamp` widget → 10% canary.
- Phase 3: Scheduled events show dual-TZ → 50%.
- Phase 4: GA.
- Kill switch: `feature.local_timezones.enabled` (default ON post-GA); off reverts to UTC display.
