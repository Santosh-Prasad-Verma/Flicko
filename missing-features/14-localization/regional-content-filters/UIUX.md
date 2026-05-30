# Regional Content Filters — UI/UX Design

## 1. Design Principles

- **Transparent over invisible:** users *see* something is hidden and can find out why.
- **Calm copy, no shaming:** matter-of-fact tone — "Hidden in your region under {rule}".
- **No false sense of security for posters:** writers see clear pre-send warnings.
- **Appealable, not appellate:** appeals go to a queue; we never auto-restore.
- **Accessible explanation:** explainer modal in user's locale, links to legal text in original language.

## 2. Information Architecture

- Hidden placeholder appears inline wherever the original item would have appeared.
- Region settings: `Settings → Language & Region → Region`
- Age attestation prompt: triggered on first interaction with age-gated content.
- Admin rules editor: web-only at `/admin/regional-rules`.
- Deep link: `flicko://settings/region`, `flicko://hidden-explainer/<audit_id>`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | RegionSettingsScreen | view/override region | content, override, confirm |
| 2 | HiddenPlaceholder | inline indicator | message-hidden, channel-hidden, server-hidden |
| 3 | HiddenExplainerSheet | reveals rule details | content, error |
| 4 | AgeAttestationDialog | confirm age before content | prompt, confirmed, denied |
| 5 | PreSendWarning | author-side soft warning | warn, dismissed |
| 6 | AppealForm | user submits appeal | form, submitted, error |
| 7 | AdminRulesEditor (web) | manage rules | list, edit, audit log |

## 4. Wireframes (ASCII)

### Screen 2 — HiddenPlaceholder (message)

```
┌─────────────────────────────────────────┐
│ 🇩🇪  This message is hidden in your     │
│ region under StGB §86a.                 │
│ [ Why? ]   [ Appeal ]                   │
└─────────────────────────────────────────┘
```

### Screen 3 — HiddenExplainerSheet

```
┌─────────────────────────────────────────┐
│ Why was this hidden?                  ✕ │
├─────────────────────────────────────────┤
│ Region: Germany (DE)                    │
│ Rule:   de.symbols.nazi                 │
│ Reason: Hides Nazi-related symbols      │
│         and slogans for German users.   │
│ Legal:  StGB §86a (read more →)         │
│                                         │
│ This was hidden automatically. The      │
│ original poster's view is unaffected.   │
│                                         │
│ [ Submit appeal ]                       │
└─────────────────────────────────────────┘
```

### Screen 4 — AgeAttestationDialog

```
┌─────────────────────────────────────────┐
│ Age confirmation required               │
├─────────────────────────────────────────┤
│ Are you 19 or older?                    │
│                                         │
│ This is required by Korean law to       │
│ access the channel "#mature-talk".      │
│                                         │
│ We don't store your date of birth —     │
│ only your confirmation.                 │
│                                         │
│ [ I am 19+ ]   [ I am under 19 ]        │
└─────────────────────────────────────────┘
```

### Screen 5 — PreSendWarning

```
┌─────────────────────────────────────────┐
│ ⚠ This message will be hidden for       │
│ users in Germany (rule: de.symbols.nazi)│
│                                         │
│ [ Edit ]      [ Post anyway ]           │
└─────────────────────────────────────────┘
```

### Screen 6 — AppealForm

```
┌─────────────────────────────────────────┐
│ ← Appeal                                │
├─────────────────────────────────────────┤
│ Item:   [snippet of hidden content]     │
│ Region: Germany                         │
│ Rule:   de.symbols.nazi                 │
│                                         │
│ Tell us why this should be visible:     │
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Your appeal will be reviewed by our     │
│ trust & safety team within 7 days.      │
│                                         │
│ [ Submit ]                              │
└─────────────────────────────────────────┘
```

### Screen 7 — AdminRulesEditor (web)

```
┌──────────────────────────────────────────────────────────┐
│ Regional Rules                            [+ New rule]    │
├──────────────────────────────────────────────────────────┤
│ ID                       Region  Kind     Enabled  Fires │
│ de.symbols.nazi          DE      regex    ✓        4,210 │
│ kr.under19.adult         KR      age_gate ✓          892 │
│ uk.adult.age             GB      age_gate ✓        1,310 │
│ us.coppa.13              US      age_gate ✓        2,901 │
│ global.csam              *       hash     ✓           14 │
│ ...                                                       │
└──────────────────────────────────────────────────────────┘
```

## 5. Component Specs

### `HiddenPlaceholder`
- Props: `String region`, `String summary`, `String auditId`
- Layout: small banner with region flag, one-line summary, two CTAs
- Tap "Why?" → opens `HiddenExplainerSheet`
- Tap "Appeal" → opens `AppealForm`
- Subtle background (`colorScheme.surfaceContainer`); flag adds context

### `HiddenExplainerSheet`
- Bottom sheet
- Fields: region, rule_id, reason, legal_ref (link)
- "Submit appeal" button at bottom

### `AgeAttestationDialog`
- Modal (cannot dismiss without choosing)
- Two buttons: "I am X+" / "I am under X"
- Choosing under hides the content, sets profile flag, returns user to feed
- Choosing over sets `age_attestations.<scope> = true`, lets user proceed

### `PreSendWarning`
- Inline above the composer
- Shows when classifier flagged outgoing content for any region
- "Edit" focuses input; "Post anyway" sends but the message will be hidden for affected viewers (author warned)

## 6. Empty / Error / Loading

- **Empty (no hidden items in feed):** unchanged feed.
- **Error fetching explainer:** "Couldn't load details. Try again." with retry.
- **Loading:** explainer sheet shows spinner.

## 7. Copy

| Surface | Copy (en source) |
|---------|------------------|
| Hidden placeholder | This message is hidden in your region under {legal_ref}. |
| Why CTA | Why? |
| Appeal CTA | Appeal |
| Explainer subtitle | This was hidden automatically. The original poster's view is unaffected. |
| Pre-send warning | This message will be hidden for users in {regions}. |
| Pre-send CTA primary | Post anyway |
| Pre-send CTA secondary | Edit |
| Age dialog title | Age confirmation required |
| Age dialog body | Are you {n} or older? Required by {law}. |
| Age dialog confirm | I am {n}+ |
| Age dialog deny | I am under {n} |
| Appeal title | Appeal |
| Appeal helper | Tell us why this should be visible. |
| Appeal submitted toast | Appeal submitted. We'll review within 7 days. |

Voice: matter-of-fact, second-person, no shaming.

## 8. Motion

- Hidden placeholder: fades in 150ms.
- Explainer sheet: standard bottom-sheet curve.
- Age dialog: scale + fade.
- Reduced-motion: instant.

## 9. Accessibility

- HiddenPlaceholder Semantics: "Hidden message. Hidden in {region} under {rule}. Tap to learn why or appeal."
- Color contrast on placeholder ≥4.5:1.
- Age dialog: focus auto-set to body; both buttons reachable via Tab.

## 10. Responsive

- Phone: full-width placeholders.
- Tablet/web: same; explainer is a side-sheet on tablet/desktop.
- Foldable: identical to phone.

## 11. Theming

- Hidden placeholder uses `colorScheme.surfaceContainerHighest` and `colorScheme.outlineVariant` border.
- Region flag emoji (no color overrides).
- Pre-send warning uses `colorScheme.tertiaryContainer`.

## 12. Edge UX

- **Server admin's view:** in addition to the hidden placeholder, admins see a "Hidden for {region} viewers" badge with click-to-explain. Author-only view unchanged.
- **Search results:** if a search hit is filtered, render a placeholder count: "3 hidden matches" tappable to see explainer.
- **Push notifications:** if filtered, push falls back to "You have a new message in Flicko" without preview.
- **Mail templates:** receipt subject lines are filtered; if filtered, fall back to "Receipt from Flicko".

## 13. Transparency Report Page (web)

- Public URL `/transparency`
- Quarterly stats: total filtered / region / rule / kind, anonymized counts.
- Methodology section.
- Data exports as CSV.
