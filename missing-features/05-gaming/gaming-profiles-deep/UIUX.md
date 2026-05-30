# Gaming Profiles Deep — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Gaming tab on profile | Composed sections |
| 2 | Public profile page | SSR HTML, OG image |
| 3 | Profile editor | Toggle sections, set codes |
| 4 | Share card export | PNG composer |

## Wireframes

### Profile gaming tab
```
┌──────────────────────────────────┐
│ alice · Diamond III · 142 hr/wk  │
├──────────────────────────────────┤
│ [Stats] [Achievements] [Clips]   │
│                                   │
│ Stats                             │
│  Valorant  D3   K/D 1.42          │
│  LoL       Plat 2  62% wr         │
│ ─────────────                     │
│ Achievements                      │
│  🏆🏅🎖️🏆🏅 +20                  │
│ ─────────────                     │
│ Recent clips                      │
│  [▶][▶][▶]                        │
│ ─────────────                     │
│ Friend codes                      │
│  Steam: 7656…  Riot: alice#NA1    │
└──────────────────────────────────┘
```

### Editor
```
┌──────────────────────────────────┐
│ Customize gaming profile          │
├──────────────────────────────────┤
│ Public link    flicko.app/@alice  │
│ Privacy   ◉ Public  ◯ Friends ... │
│ Sections                          │
│  ☑ Stats  ☑ Achievements          │
│  ☑ Clips  ☑ Friend codes          │
│  ☑ Recent games                   │
│ Banner   [ Upload ]               │
│ Bio      ____________________     │
│                                   │
│ Friend codes                      │
│  + Add code                       │
└──────────────────────────────────┘
```

## Components
- `<SectionToggle>` per section.
- `<ShareCardComposer>` produces 1200×630 PNG via canvas / server-side renderer.

## Empty/Error
- No data: each section shows "Connect <provider> to populate".

## Copy
| Surface | Copy |
|---------|------|
| Editor title | Customize gaming profile |
| Share button | Share card |

## Motion
- Section reorder with drag handles.
- Reduced-motion: drag without springiness.

## Accessibility
- Focus order: tabs → sections → action buttons.
- All toggles labeled.

## Responsive
- Phone: stacked. Tablet: 2-col. Web public profile: hero + grid.

## Theming
- Banner backgrounds respect AMOLED/dark/light.
