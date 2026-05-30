# Multi-Language 50+ — UI/UX Design

## 1. Design Principles

- **Native-first:** display language names in their native script (`日本語`, `العربية`, not `Japanese`, `Arabic`).
- **Discoverable but not pushy:** language picker lives in Settings; we do not launch a modal at first run.
- **Auto-detect, then trust:** device locale wins on first launch; user override is sticky.
- **No mid-flow language flicker:** locale changes are atomic — full tree rebuild from `MaterialApp.locale`.
- **Token use only:** all copy comes from ARB; zero hardcoded user-facing strings (lint enforced).
- **Reduced motion safe:** locale change uses crossfade, not slide.

## 2. Information Architecture

Where this feature lives:
- Entry points (3 max):
  1. `Settings → Language & Region → Language` (primary)
  2. Onboarding step 2 (one-tap if device locale already supported, else picker)
  3. Profile menu shortcut (long-press globe icon)
- Parent navigation: Settings tab in main bottom nav
- Deep links: `flicko://settings/language`
- App-bundle behavior: install ships with `en` + auto-detected device locale; all 48 others fetched on demand

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | LanguageSettingsScreen | pick UI language | loading, content, search, applied, error |
| 2 | LanguagePickerSheet | bottom-sheet variant from onboarding | content, applied |
| 3 | TranslatorsAboutScreen | credit translators per locale | loading, list, empty (no credits yet) |
| 4 | LanguageBannerWidget (overlay) | "this locale is at 60% — help translate" | dismissable, persistent for low-coverage |

## 4. Wireframes (ASCII)

### Screen 1 — LanguageSettingsScreen

```
┌────────────────────────────────────────┐
│ ← Language & Region                    │
├────────────────────────────────────────┤
│ Search                                 │
│ ┌────────────────────────────────────┐ │
│ │ 🔍  Search 50+ languages           │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Suggested                              │
│ ┌────────────────────────────────────┐ │
│ │ 🇯🇵  日本語   (device)            ✓ │ │
│ │ 🇺🇸  English (default)             │ │
│ └────────────────────────────────────┘ │
│                                        │
│ All languages                          │
│ ┌────────────────────────────────────┐ │
│ │ 🇸🇦  العربية              87%      │ │
│ │ 🇦🇲  Հայերեն              52%      │ │
│ │ 🇧🇩  বাংলা               74%      │ │
│ │ 🇧🇬  Български            68%      │ │
│ │ ...                                │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ─────────────────────────────────────  │
│ Help translate Flicko                  │
│ Join Crowdin →                         │
└────────────────────────────────────────┘
```

### Screen 2 — LanguagePickerSheet (onboarding)

```
┌────────────────────────────────────────┐
│                                        │
│           Pick your language           │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 🇧🇷  Português (BR)             ✓  │ │
│ │ 🇺🇸  English                       │ │
│ │ 🇪🇸  Español                       │ │
│ │ 🇫🇷  Français                      │ │
│ │ 🇩🇪  Deutsch                       │ │
│ │ See all 50 languages →             │ │
│ └────────────────────────────────────┘ │
│                                        │
│         [   Continue in pt-BR   ]      │
└────────────────────────────────────────┘
```

### Screen 3 — TranslatorsAboutScreen

```
┌────────────────────────────────────────┐
│ ← Translators                          │
├────────────────────────────────────────┤
│ Português (BR)                  124 ↓  │
│ ┌────────────────────────────────────┐ │
│ │ Camila Souza         3,240 strings │ │
│ │ Lucas Pereira        1,890 strings │ │
│ │ ...                                │ │
│ └────────────────────────────────────┘ │
│                                        │
│ 日本語                          78 ↓   │
│ ┌────────────────────────────────────┐ │
│ │ Yuki Tanaka          2,110 strings │ │
│ │ ...                                │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Help translate Flicko →                │
└────────────────────────────────────────┘
```

### Screen 4 — Low-coverage banner

```
┌──────────────────────────────────────────┐
│ ⓘ Some text shows in English             │
│ Bahasa Indonesia is 62% translated.      │
│ [ Help translate ]      [ Dismiss ]      │
└──────────────────────────────────────────┘
```

## 5. Component Specs

### `LocaleTile`
- Props: `Locale locale`, `bool selected`, `double coveragePct`, `VoidCallback onTap`
- States: idle, hover (web), pressed, selected, disabled (coverage<20%)
- Layout: `[flag] [native_name][english_name secondary][coverage_pct][checkmark]`
- Token usage: `colorScheme.surfaceContainerHighest`, `textTheme.titleMedium`
- 56pt tap target, 16pt horizontal padding
- Coverage indicator: thin progress bar under the tile, color-coded `green ≥90`, `amber 60-90`, `red <60`

### `LanguagePickerSheet`
- Bottom sheet with snap points 50%, 100%
- Search bar pinned to top once expanded
- Used in onboarding and as alternate access in settings on tablets

### `LocaleProvider` (Riverpod)
- `state: Locale`
- Methods: `setLocale(Locale)`, `resetToDevice()`
- Side effects: persists to `shared_preferences` (key `flicko.locale`) AND `PATCH /profile/me`
- On change: notifies `MaterialApp.locale`; `intl.DateFormat` uses new locale automatically

### `LowCoverageBanner`
- Shown when current locale's `coverage_pct < 80`
- Dismissable per-session; persistent flag in settings
- CTA opens external Crowdin URL with `?lang=<code>` deep link

## 6. Empty / Error / Loading

- **Empty (no translators yet for a locale):** illustration of an open notebook + line "Be the first to translate to <native_name>" + CTA "Open Crowdin".
- **Error (locales API unreachable):** inline banner "Couldn't refresh languages — using cached list." Allow user to retry; never block the screen.
- **Loading:** skeleton tiles (8 shimmer rows) for the All Languages section; Suggested renders immediately from cache.

## 7. Copy

| Surface | Copy (en source) |
|---------|------------------|
| Screen title | Language & Region |
| Search placeholder | Search 50+ languages |
| Section header (suggested) | Suggested |
| Section header (all) | All languages |
| Coverage label (≥90%) | Fully translated |
| Coverage label (60-90%) | {pct}% translated |
| Coverage label (<60%) | {pct}% — partial |
| Confirm dialog title | Switch to {language}? |
| Confirm dialog body | The app will reload in {language}. |
| CTA: confirm | Switch language |
| CTA: cancel | Keep {current} |
| Banner: low coverage | Some text shows in English. {language} is {pct}% translated. |
| Banner CTA | Help translate |
| Translators screen title | Translators |
| Help-translate footer | Help translate Flicko → |

Voice: friendly, concise, second-person. No jargon (avoid "i18n", "locale", "BCP-47" in user copy — say "language").

## 8. Motion

- Locale switch: `MaterialApp` rebuilds with crossfade 200ms (we wrap in `AnimatedSwitcher`)
- Tile selection: scale 0.98 → 1.0 over 100ms
- Picker sheet: standard Material bottom-sheet curve
- Reduced-motion: instant swap, no fade

## 9. Accessibility

- Every `LocaleTile` exposes Semantics: label = native_name + english_name + coverage_pct
- Selected state announced "<lang> selected"
- Screen reader pronounces native names correctly only if the OS has the speech engine — otherwise we add `Semantics(attributedLabel)` with explicit phonetic when known
- Color contrast ≥4.5:1 against `surfaceContainerHighest`
- Keyboard: full tab order; arrow-keys navigate the list; Space/Enter selects
- Reduced motion respected
- Pseudo-locale `xq-XQ` available in dev menu for QA expansion testing

## 10. Responsive

- Phone (360-599): full-screen list
- Foldable / 600-839: two columns (suggested left, all right)
- Tablet / 840-1199: three columns
- Web / ≥1200: master-detail (list left, preview screenshot right)
- iPad split-view: behaves like tablet

## 11. Theming

- Light + Dark + AMOLED variants — uses standard tokens, no special handling needed
- Honor server accent color for the selected-tile checkmark
- Native scripts: ensure font fallback chain includes Noto Sans (covers all 50 locales' scripts) — bundled in `mobile/fonts/NotoSans*.ttf`
- Emoji flags rendered via system emoji font; on Windows web (no emoji flags), substitute ISO code badge

## 12. Pseudo-Locale (xq-XQ)

- Wraps every translated string with `[‹ ... ›]` markers
- Expands length by ~30% with Cyrillic-looking Latin (`Ξжpäήdedٍ`) — exposes layout overflow and missing translations
- Dev menu toggle: `Settings → Developer → Pseudo-locale`
- CI: pseudo-locale screen captures uploaded as PR artifacts

## 13. Translator UX (out-of-app, Crowdin)

Although the user-facing UX is in the app, the translator experience is a *first-class part* of the design:

- Each ARB key has a screenshot showing it in context
- Glossary tooltip shows term + locked translations (Aura, Server, Channel)
- DeepL MT auto-fills as a *gray suggestion* — translator either accepts or overwrites
- Reviewer queue: 2-eyes principle, second translator approves before string ships
- Achievement badges in Crowdin (we configure: First 100 strings, Bug spotter, Voice of <lang>)
