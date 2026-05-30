# Local Timezones — Technical Requirements

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Mobile (Flutter)                       │
│                                                                 │
│  Platform.localeName + DateTime.now().timeZoneName              │
│          │                                                      │
│          ▼                                                      │
│  TzProvider (Riverpod)                                          │
│          │                                                      │
│          ▼                                                      │
│  Timestamp widget ──▶ RelativeTime.format(dt, locale, tz)       │
│                                                                 │
│  uses package:timezone (IANA tzdata bundled, no API)            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ PATCH /profile { timezone }
┌─────────────────────────────────────────────────────────────────┐
│                        Go Backend                               │
│                                                                 │
│  Validate IANA via golang.org/x/text/language + regex            │
│  Persist to profiles.timezone                                   │
│                                                                 │
│  notification_builder reads recipient.timezone                  │
│  mail-gateway template helper formats per recipient             │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/local-timezones/service.go`
  - `FormatLocal(t time.Time, tz, locale string) string`
  - `IsValidTZ(tz string) bool`
  - `LoadIANA() error` — calls `time.LoadLocation` once at boot
- **Handlers:** `profile_handler.go` validates TZ on PATCH
- **Notification builder:** uses `recipient.timezone` to format date strings before sending
- **CSV export handler:** appends `timestamp_local`, `tz` columns

### Mobile (Flutter)
- **Cross-cutting folder:** `mobile/lib/core/datetime/`
  - `data/tz_repository.dart`
  - `application/tz_provider.dart`
  - `presentation/timestamp.dart`
  - `relative_time.dart` helper
- **Init:** `tz.initializeTimeZones()` called in `main.dart`

### Infra
- DB: `profiles.timezone` (TEXT, IANA name)
- Cache: not needed
- AI: not used
- External: none (IANA db bundled with `timezone` Dart pkg + Go's `time/tzdata`)

## 3. API Contracts

### REST

```
PATCH /api/v1/profile/me { timezone: "Asia/Tokyo" }
GET   /api/v1/i18n/timezones                          list common IANA zones with friendly names
```

### Payloads

```jsonc
// GET /api/v1/i18n/timezones
{
  "zones": [
    { "iana": "Asia/Tokyo",        "city": "Tokyo",        "offset_minutes": 540, "country": "JP" },
    { "iana": "Asia/Kolkata",      "city": "Kolkata",      "offset_minutes": 330, "country": "IN" },
    { "iana": "Pacific/Chatham",   "city": "Chatham",      "offset_minutes": 765, "country": "NZ" },
    { "iana": "UTC",               "city": "UTC",          "offset_minutes": 0,   "country": null },
    { "iana": "America/New_York",  "city": "New York",     "offset_minutes": -300, "country": "US" }
  ]
}

// PATCH /api/v1/profile/me
{ "timezone": "Asia/Tokyo" }
```

## 4. Permissions & Auth

- `/i18n/timezones` is public.
- `PATCH /profile/me` requires user JWT.
- No new permission scopes.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| `Timestamp` widget render | < 1ms |
| `RelativeTime.format` | < 0.5ms |
| TZ validation server-side | < 0.1ms |
| Bundle size delta | < 200KB (timezone IANA db) |
| Per-render CPU | negligible |

## 6. Dependencies

### Existing
- `multi-language-50` (locale)
- `profiles` table

### New libraries
- Flutter: `timezone: ^0.9.4` (IANA tzdata)
- Go: `time/tzdata` import (embeds tzdata in binary)
- Flutter: `intl: ^0.19.0` (already pinned)

### External
- None — IANA db ships in-process.

## 7. Observability

- Metrics:
  - `flicko_tz_users_with_tz_total` — gauge (% with non-null TZ)
  - `flicko_tz_distinct_zones` — gauge
  - `flicko_tz_invalid_attempted_total` — counter (PATCH rejected)
- Logs: WARN on invalid TZ submitted; INFO on TZ change
- Traces: not necessary

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| `profile.timezone` corrupt | bad UI render | server validation; client falls back to UTC |
| IANA db doesn't recognize zone | render error | safe-fallback to UTC + Sentry breadcrumb |
| User sends TZ in IETF form (UTC+09:00) | invalid | accept and remap to known IANA via offset |
| `intl` lacks weekday name in locale | English fallback | acceptable degradation |

## 9. Implementation Notes

### Backend: validate
```go
var ianaRe = regexp.MustCompile(`^[A-Za-z_]+/[A-Za-z_]+(/[A-Za-z_]+)?$|^UTC$|^Etc/GMT[+-]?\d+$`)

func IsValidTZ(tz string) bool {
    if !ianaRe.MatchString(tz) { return false }
    _, err := time.LoadLocation(tz)
    return err == nil
}
```

### Backend: format for notifications
```go
func FormatForRecipient(t time.Time, recipient User) string {
    loc, err := time.LoadLocation(recipient.Timezone)
    if err != nil { loc = time.UTC }
    p := message.NewPrinter(language.MustParse(recipient.Locale))
    return p.Sprintf("%s", t.In(loc).Format("Jan 2, 3:04 PM MST"))
}
```

### Mobile: Timestamp widget
```dart
class Timestamp extends ConsumerWidget {
  final DateTime utc;
  const Timestamp(this.utc);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tzName = ref.watch(tzProvider).valueOrNull ?? 'UTC';
    final loc = ref.watch(localeProvider).valueOrNull ?? const Locale('en');
    final tzInstance = tz.getLocation(tzName);
    final local = tz.TZDateTime.from(utc, tzInstance);
    final relative = RelativeTime.format(local, loc);

    return Tooltip(
      message: DateFormat.yMMMd(loc.toString()).add_Hm().format(local) + ' $tzName',
      child: GestureDetector(
        onLongPress: () => _showAbsoluteSheet(context, local, tzName, loc),
        child: Text(relative),
      ),
    );
  }
}
```

### Mobile: RelativeTime
- Wraps `intl_pkg` for locale-aware "5 minutes ago" style strings.
- Fallback: if `intl` doesn't support locale, format as "May 29 14:00".

## 10. Testing Strategy

- Unit (Go): table-driven validity (positive: 100 zones; negative: 50 invalid strings).
- Unit (Dart): `RelativeTime.format` table tests across locales (en, ja, ar, pt-BR, fr).
- Property: round-trip — UTC → tz → UTC produces same instant.
- Golden: `Timestamp` × 5 zones × 3 ages.
- E2E: change TZ; observe re-render in <300ms.
- DST transition: assert correct rendering on the day of DST shift in `America/New_York`, `Europe/London`, `Australia/Sydney`.
