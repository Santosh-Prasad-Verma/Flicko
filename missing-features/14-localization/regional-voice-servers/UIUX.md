# Regional Voice Servers — UI/UX Design

## 1. Design Principles

- **Auto by default, override on demand:** users shouldn't have to think about regions.
- **Transparency without intrusion:** show the chosen region in fine print, not as a header.
- **Quality-first messaging:** if quality drops, offer a switch — never panic.
- **Server admin sovereignty:** admins can pin a region for a server's voice; users see and respect it.
- **Speed metrics legible:** RTT is shown in ms, prefixed by a quality dot (green/amber/red).

## 2. Information Architecture

- Voice settings: `Settings → Voice & Video → Region`
- Server voice settings: `Server Settings → Voice → Region`
- In-call status: bottom bar shows current region + RTT.
- Quality banner: appears in-call when quality drops.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | VoiceSettingsScreen | personal voice region prefs | content, picker, applied |
| 2 | ServerVoiceSettingsScreen | admin sets server-level pin | content, picker, applied |
| 3 | RegionPickerSheet | bottom sheet of all regions | scoring, applied |
| 4 | InCallRegionPill | bottom-bar status | normal, warning, error |
| 5 | QualityBanner | in-call switch prompt | warn, switching |
| 6 | RegionStatusPage (admin) | health dashboard | green, amber, red regions |

## 4. Wireframes (ASCII)

### Screen 1 — VoiceSettingsScreen

```
┌──────────────────────────────────────────┐
│ ← Voice & Video                          │
├──────────────────────────────────────────┤
│ Voice region                             │
│ ┌──────────────────────────────────────┐ │
│ │ Auto (recommended)                ✓  │ │
│ │ Currently: APAC SE · 42 ms · ●green  │ │
│ └──────────────────────────────────────┘ │
│  [ Pin a region… ]                       │
│                                          │
│ Cross-region quality                     │
│  ☑ Show region during calls              │
│  ☑ Allow federation across regions       │
│                                          │
│ ─────────────────────────────────────    │
│  Test connection now [ ▶ Run ]           │
└──────────────────────────────────────────┘
```

### Screen 3 — RegionPickerSheet

```
┌──────────────────────────────────────────┐
│ Pick a region                          ✕ │
├──────────────────────────────────────────┤
│ Auto (recommended)                       │
│ Best for global calls.                   │
│ ────────────────────────────────────     │
│ APAC SE       ● 42 ms     load 51%       │
│ APAC S        ● 89 ms     load 29%       │
│ NA West       ● 128 ms    load 18%       │
│ EU West       ● 215 ms    load 62%       │
│ NA East       ● 240 ms    load 34%       │
│ SA East       ⊘ unavailable               │
└──────────────────────────────────────────┘
```

### Screen 4 — InCallRegionPill

```
┌─────────────────────────────────┐
│  🎤  ✋  📞     APAC SE · 42ms ● │
└─────────────────────────────────┘
```
Tap pill → opens picker mid-call.

### Screen 5 — QualityBanner (in-call)

```
┌──────────────────────────────────────────┐
│ ⚠ Voice quality dropped                  │
│ Try APAC S (89 ms)?                      │
│ [ Switch ]   [ Stay ]                    │
└──────────────────────────────────────────┘
```

### Screen 6 — RegionStatusPage (admin web)

```
┌────────────────────────────────────────────────────┐
│ Voice Region Status                                │
├────────────────────────────────────────────────────┤
│ Region        Health  Load%  Sessions  p50  Action │
│ NA East       ●green     34       420   78  drain  │
│ NA West       ●green     18       310   65  drain  │
│ EU West       ●amber     62       980   95  drain  │
│ APAC SE       ●green     51       680   42  drain  │
│ APAC S        ●green     29       190   89  drain  │
│ SA East       ●red        0         0   --  enable │
└────────────────────────────────────────────────────┘
```

## 5. Component Specs

### `RegionPill` (in-call)
- Props: `String regionCode`, `int rttMs`, `Color qualityColor`
- States: green (RTT < 100), amber (100-200), red (> 200 or unhealthy)
- Tap → `RegionPickerSheet` (mid-call switch)

### `RegionPickerSheet`
- Props: `List<RegionWithScore>`, `String? currentRegion`
- Shows live ping scores, sorted ascending
- "Auto" pinned at top
- Disabled state for unavailable regions

### `QualityBanner`
- Triggered when sustained `rtt > 250 OR loss > 3%` for 30s
- Suggests next-best region; user accepts → reconnect
- Auto-dismisses after a switch

### `VoiceSettingsScreen`
- Pin / unpin
- Test connection button (runs ping test, shows results inline)

### `ServerVoiceSettingsScreen`
- Admin: choose default region for server
- Multi-select allowed regions (subset of all)
- Reset

## 6. Empty / Error / Loading

- **No regions configured:** "Voice service unavailable" full-page error with status link.
- **All regions unhealthy:** banner "Voice degraded — falling back to NA East" with status link.
- **Loading region list:** skeleton tiles for 6 rows.

## 7. Copy

| Surface | Copy (en source) |
|---------|------------------|
| Settings title | Voice & Video |
| Region label | Voice region |
| Auto subtitle | Best for global calls. We pick the lowest-latency region. |
| Pin button | Pin a region |
| Currently | Currently: {name} · {rtt} ms |
| Quality banner title | Voice quality dropped |
| Quality banner body | Try {region} ({rtt} ms)? |
| Switch CTA | Switch |
| Stay CTA | Stay |
| Test connection CTA | Run |
| Test running | Testing… |
| Test result | {n} regions reachable. Best: {name} ({rtt} ms). |
| Region full | This region is at capacity — try another. |
| Region draining | This region is undergoing maintenance. |

Voice: friendly, concise, second-person.

## 8. Motion

- Pill color transitions: 200ms ease.
- Quality banner: slide-down, persists until action.
- Picker sheet: bottom-sheet curve.
- Reduced-motion: instant transitions.

## 9. Accessibility

- Quality dot has Semantics label "good"/"fair"/"poor".
- Region pill announces "{name}, latency {rtt} milliseconds, quality good" via screen reader.
- Quality banner is announced via live region; "Switch" button auto-focused.
- All taps ≥44pt.

## 10. Responsive

- Phone: pill in bottom toolbar.
- Tablet: pill in voice control rail (right side).
- Web: in voice toolbar header.
- Foldable: identical to phone.

## 11. Theming

- Quality dots: `colorScheme.tertiary` (good), warning yellow, error red.
- Pill background: `colorScheme.surfaceContainerHighest`.
- Picker selected: `colorScheme.primaryContainer`.
- Dark/AMOLED: quality dots brighten for visibility.

## 12. Detail Views

### Test Connection result card

```
┌──────────────────────────────────────────┐
│ Connection test                       ●● │
├──────────────────────────────────────────┤
│ APAC SE       ● 42 ms     loss 0.0%      │
│ APAC S        ● 89 ms     loss 0.1%      │
│ NA West       ● 128 ms    loss 0.5%      │
│ EU West       ● 215 ms    loss 1.0%      │
│ NA East       ● 240 ms    loss 0.8%      │
│ SA East       ⊘ unreachable               │
│                                          │
│ Best: APAC SE — Auto will pick this.     │
└──────────────────────────────────────────┘
```

### Server Admin pin chip

```
┌──────────────────────────────────────────┐
│ Voice region: 📍 EU West (pinned by      │
│ admin). Members in other regions may     │
│ experience higher latency.               │
└──────────────────────────────────────────┘
```

## 13. Edge UX

- **Federation transparency:** when in a federated call, the pill shows your edge name; tooltip explains "{n} other regions are bridged to this call".
- **Privacy mode:** users with data-residency preferences see only compliant regions in the picker; backend enforces.
- **Mid-call switch:** if user accepts switch, audio briefly mutes (~1s) during reconnect; show "Reconnecting…" overlay; resume mute/deaf state.
