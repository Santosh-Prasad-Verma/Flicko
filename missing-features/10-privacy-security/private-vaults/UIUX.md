# Private Vaults — UI/UX Design

## 1. Design Principles

- The vault feels like a private drawer, not a security console. Casual users should be able to drop files in without dealing with crypto jargon.
- Honesty about the loss model: "If you forget the passphrase, your files are gone. We can't recover them — that is the point."
- Lock state is visible at all times: a tiny lock icon on the home screen indicates unlocked vs locked.
- Recovery seed is presented carefully: revealed once, copy-protected (Android) and recording-protected (iOS), with a verify-back-by-typing step.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): tab/menu "Vault"; profile → "Private storage"; share-sheet "Save to Vault."
- Parent navigation: top-level.
- Deep links: `flicko://vault`, `flicko://vault/setup`, `flicko://vault/seed`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Vault home | List files | locked, empty, content |
| 2 | Setup wizard | Create passphrase | passphrase, confirm, kdf-progress, seed-show, seed-verify, done |
| 3 | Unlock sheet | Enter passphrase | idle, deriving, error |
| 4 | File detail | Preview / download | content |
| 5 | Recovery seed | Show 24 words | once-only, verify-typed, done |
| 6 | Quota | Manage storage | content |

## 4. Wireframes (ASCII)

### Vault home (locked)
```
┌────────────────────────────────────┐
│  Vault                          🔒 │
├────────────────────────────────────┤
│                                    │
│   Tap to unlock                    │
│                                    │
│   [ Use passphrase ]               │
│   [ Use biometrics ]               │
│                                    │
└────────────────────────────────────┘
```

### Vault home (unlocked)
```
┌────────────────────────────────────┐
│  Vault       2.1 GB / 5 GB     🔓 │
├────────────────────────────────────┤
│  📷 IMG_2845.jpeg          5 days  │
│  📄 contract-draft.pdf     1 wk   │
│  🎙 interview-014.m4a      2 wk   │
│  📁 backups/...                    │
└────────────────────────────────────┘
                          [ + upload ]
```

### Recovery seed screen
```
┌────────────────────────────────────┐
│  Save your recovery seed           │
├────────────────────────────────────┤
│  Write these 24 words on paper.    │
│  Without them and your passphrase, │
│  your files are unrecoverable.     │
│                                    │
│  1. veil      9.  marsh   17. lift │
│  2. orchid    10. quill   18. swam │
│  ... (24 total)                    │
│                                    │
│  Screenshots are blocked here.     │
│                                    │
│           [ I've saved them ]      │
└────────────────────────────────────┘
```

## 5. Component Specs

### `VaultUnlockSheet`
- Passphrase field with show/hide toggle.
- Progress indicator while Argon2 runs (typically 1-2s).
- Biometric quick-unlock if previously enabled (uses Keychain-wrapped derived key).

### `RecoverySeedScreen`
- Wrapped in `ProtectedScope` (FLAG_SECURE + iOS scrim) — see `screen-capture-protection`.
- Words displayed in a 3-column 8-row grid.
- "I've saved them" requires typing 3 random word indices to confirm.

### `FileItemTile`
- Icon by mime, name (decrypted client-side), size, last modified.
- Long-press → rename / share / delete.

### `QuotaBadge`
- Shown in app bar; turns amber at 80%, red at 95%.

## 6. Empty / Error / Loading

- **Empty:** illustration of an open drawer + "Drop a file to start your vault."
- **Error (decrypt fail on a specific file):** tile shows "Couldn't decrypt — try unlocking again."
- **Loading:** shimmering skeleton tiles.
- **Setup KDF in progress:** progress bar + "Securing your vault — this takes a moment."

## 7. Copy

| Surface | Copy |
|---------|------|
| Tab title | Vault |
| Setup intro | A private drawer for files only you can read. |
| Setup warning | If you forget your passphrase, your files cannot be recovered. |
| Recovery seed intro | These 24 words can unlock your vault on a new device. |
| Unlock prompt | Enter your vault passphrase |
| Empty state | Nothing here yet. Drop a file to start. |
| Quota near limit | Almost full. Delete files to free space. |

Voice: warm, plain, honest. Avoid "encrypted with military-grade ..." cliches.

## 8. Motion

- Lock icon flips 180° at unlock; reverses at lock.
- Tile add: slide-down + fade-in, 200ms.
- KDF progress: indeterminate then transitions to determinate near the end.

## 9. Accessibility

- Lock icon has Semantics label "Vault unlocked" / "Vault locked."
- Recovery seed words readable by screen reader sequentially with index numbers.
- Tap targets ≥44pt.
- Color-independent state indicators.

## 10. Responsive

- Phone: single-column file list.
- Tablet/web: split — file list on left, preview on right.
- Foldable: respects display feature.

## 11. Theming

- Light + Dark + AMOLED.
- Vault uses a slightly darker chrome than the rest of the app to communicate "private space."

## 12. Privacy-specific UX rules

- Auto-lock after 5 minutes idle (configurable down to 1 min, up to 30 min).
- App-switcher snapshot shows blank vault tile.
- Never display decrypted filenames in notifications. Push body for any vault event reads "Vault activity."
- Never log plaintext metadata (filename, mime) anywhere — even Sentry crash reports.
