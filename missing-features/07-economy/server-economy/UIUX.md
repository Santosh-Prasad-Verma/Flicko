# Server Economy — UI/UX Design

## 1. Design Principles

- Currency is **branded by the server**, not by Flicko: every coin label uses server-defined name + icon, no global "Flicko Coin" copy on the wallet surface.
- Numbers are the hero. Balances render in display1 weight on the home card.
- Motion is value-bound: balance counter always ticks; every other surface waits for state.
- Match Flicko theme tokens (`mobile/lib/core/theme/`), specifically `surfaceContainerHighest` for cards and `colorScheme.tertiary` for currency accents.
- Existing components reused: `BalancePill`, `EmptyStateScaffold`, `MfaChallengeSheet`, `BottomActionBar`.

## 2. Information Architecture

- Entry points: server header avatar tap menu > Wallet, member profile drawer > Wallet, push notification deep link.
- Parent navigation: inside server stack as a modal sheet on phone, side panel on tablet.
- Deep links: `flicko://server/<sid>/wallet`, `flicko://server/<sid>/wallet/leaderboard`, `flicko://server/<sid>/wallet/settings` (admin only).

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Wallet Home | balance, daily claim, txn list | empty, loading, content, frozen, error |
| 2 | Leaderboard | weekly/monthly/all-time top earners | loading, content, empty |
| 3 | Currency Settings (admin) | configure name/icon/rates | initial, editing, saving, error |
| 4 | Mod Grant Sheet | grant/revoke with reason+MFA | idle, mfa, submitting, success, error |
| 5 | Transaction Detail | full info on one entry | content (no other states) |
| 6 | Provisioning Progress | only on first enable | running, done, error |

## 4. Wireframes

### Screen 1 — Wallet Home (phone)

```
┌────────────────────────────────────┐
│ ←  Wallet               ⋯ Mod      │
├────────────────────────────────────┤
│  ╭──────────────────────────────╮  │
│  │  Stardust  [icon]            │  │
│  │  1,205                       │  │
│  │  +25 today    streak 4d 🔥    │  │
│  ╰──────────────────────────────╯  │
│                                    │
│  [   Claim daily +25   ]           │
│                                    │
│  Recent activity                   │
│  • +1   message       2m ago       │
│  • +25  daily claim   8m ago       │
│  • -50  gift to @yui  1h ago       │
│  • +5   voice 5m      3h ago       │
│  ─ load more ─                     │
├────────────────────────────────────┤
│  Leaderboard ▸                     │
└────────────────────────────────────┘
```

### Screen 2 — Leaderboard

```
┌────────────────────────────────────┐
│ ← Leaderboard      [W][M][All]     │
├────────────────────────────────────┤
│  1  @sasha       12,488    ↑       │
│  2  @riku         9,210    →       │
│  3  @priya        7,890    ↓       │
│ ...                                │
│  ─ you: #87 (1,205) ─              │
└────────────────────────────────────┘
```

### Screen 3 — Currency Settings (admin)

```
┌────────────────────────────────────┐
│ ← Currency settings        Save    │
├────────────────────────────────────┤
│  Icon   [ + upload ]               │
│  Name   [ Stardust            ]    │
│  Time-zone [ America/Los_Angeles ▾]│
│  Starting balance   [ 100        ] │
│                                    │
│  Earn rates                        │
│  Per message    [ 1   ]  cap [ 50 ]│
│  Per voice min  [ 2   ]  cap [120 ]│
│  Daily base     [ 10  ]            │
│  Streak max x   [ 2.5 ]            │
│                                    │
│  Velocity                          │
│  Window  [ 1 hour ▾ ]              │
│  Cap     [ 500 ]                   │
│                                    │
│  [ Disable economy ]   (danger)    │
└────────────────────────────────────┘
```

### Screen 4 — Mod Grant Sheet

```
┌─────────────────────────┐
│  Grant Stardust         │
│  to @riku               │
├─────────────────────────┤
│  Amount  [ 500 ]        │
│  Reason  [ helped...]   │
│  ☐ Notify member        │
│                         │
│  [Cancel]    [Grant]    │
└─────────────────────────┘
   |
   v if amount > 10,000
┌─────────────────────────┐
│  Confirm with MFA       │
│  [ ____ ____ ]          │
└─────────────────────────┘
```

## 5. Component Specs

### `BalanceCard`
- Props: `name`, `iconUrl`, `balance`, `delta24h`, `streak`, `onClaim`, `claimEnabled`.
- States: idle / claiming / claimed-cooldown / frozen.
- Tokens: `colorScheme.tertiaryContainer` background, `textTheme.displaySmall` for number.
- Animation: balance counter ticks via `TweenAnimationBuilder<int>` over 600ms, easeOutCubic.

### `TransactionTile`
- Props: `direction` (+/-), `amount`, `source`, `refLabel`, `time`.
- Direction colored: `+` green-700, `-` neutral-300; never red (red is only for errors).
- Long-press opens detail sheet.

### `LeaderboardRow`
- Rank | avatar | username | amount | trend (up/flat/down arrow vs prior period).
- Highlights logged-in user with subtle outline.

### `DailyClaimButton`
- Idle (eligible): pulse 1.5s; copy `Claim daily +<amount>`.
- Disabled (cooldown): countdown `ready in 04:12:08`.
- Claiming: spinner.
- Claimed: confetti burst (skipped if reduced-motion), then collapses into the cooldown state.

## 6. Empty / Error / Loading

- **Empty (server has no economy):** illustration of a piggy bank, copy `Your server hasn't turned on a currency yet`. Admin sees CTA `Set up <serverName> coins`. Member sees CTA `Suggest it to a mod` (sends a templated DM).
- **Error:** inline banner under balance card; never blocks the screen. Recent activity section continues to render from cache.
- **Loading:** shimmer skeleton matching final layout: 1 large card + 5 short rows.
- **Frozen:** lock icon overlay on balance card, tooltip `Wallet under review`. Claim and spend buttons disabled. No reason exposed unless admin.

## 7. Copy

| Surface | Copy |
|---------|------|
| Header title | `Wallet` |
| Daily CTA (idle) | `Claim daily +{amount}` |
| Daily CTA (cooldown) | `Ready in {hh:mm:ss}` |
| Streak label | `{n}-day streak` (no fire emoji past 30) |
| Empty admin | `Set up {serverName} coins` |
| Empty member | `Ask a mod to turn on coins` |
| Mod grant button | `Grant` |
| Mod revoke confirm | `Take {amount} from @{user}? This is logged.` |
| Frozen banner | `This wallet is under review.` |

Voice: friendly, concise, second-person, no jargon, no exclamation marks.

## 8. Motion

- Page transitions: shared-axis Y, 300ms.
- Balance ticker: 600ms tween, easeOutCubic.
- Claim success: confetti 800ms, skipped under reduced-motion (replaced by 200ms crossfade of CTA -> cooldown).
- Streak fire icon: 2-frame loop, 1.2s; static under reduced-motion.

## 9. Accessibility

- All amounts read as `"<number> <currency name>"` via `Semantics`. Localized number formatting (1,205 → en-US, 1.205 → de-DE).
- Color contrast: green-700 on `tertiaryContainer` >=4.6:1 verified.
- Tap targets: claim CTA 56pt; leaderboard rows 56pt; mod menu items 48pt.
- Live region: `economy:<sid>` push triggers `SemanticsEvent.announce` in TalkBack/VoiceOver: `"Balance updated, +25 Stardust"`.
- Keyboard: Tab through claim, transactions, leaderboard tab, settings.
- Reduced motion respects `MediaQuery.disableAnimations`.

## 10. Responsive

- Phone (360-599): full-width modal sheet.
- Foldable hinge: split view, balance left, txn list right.
- Tablet (600-839): side rail with balance + leaderboard, transactions right.
- Web (>=1200): dedicated page with currency settings always visible to admin.

## 11. Theming

- Light, dark, AMOLED variants. AMOLED uses pure black background, balance text full-white, icons preserve color.
- Honors server accent color from feature `09-customization/accent-colors` once it ships; until then defaults to Flicko brand.
