# Server Map — UI/UX Design

## 1. Design Principles

- Privacy first, visibility second; consent is loud and clear
- Map is calm: muted base style, clusters use server accent
- Never show pinpoint markers, even at max zoom
- Design for the "I changed my mind" moment: revoke is one tap

## 2. Information Architecture

- Entry points: Server -> Members -> Map tab; Owner analytics in settings
- Parent: server members area
- Deep link: `flicko://server/<id>/map`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Onboarding/Consent | Explain + opt in | step1, step2, step3, declined |
| 2 | Map | Cluster view | content, empty, loading, offline |
| 3 | Heatmap (owner) | Density | content, empty |
| 4 | Privacy controls | Per-server toggle, precision | content |

## 4. Wireframes (ASCII)

### Onboarding step 1

```
+--------------------------------------------------+
|  Show me on the map?                             |
+--------------------------------------------------+
|                                                  |
|  We never show your street.                      |
|  We never show your home.                        |
|                                                  |
|  Choose precision:                               |
|     ( ) Country only      (US)                   |
|     (*) Region/state      (California)           |
|     ( ) City              (Berkeley area)        |
|                                                  |
|                              [ Continue ]        |
+--------------------------------------------------+
```

### Onboarding step 2 (consent)

```
+--------------------------------------------------+
|  Just so you know                                |
+--------------------------------------------------+
|  Other members see CITY at most, never streets.  |
|  We bucket you with others nearby. If you are    |
|  the only one, we coarsen to your region.        |
|  You can change or remove this any time in       |
|  Settings -> Privacy -> Server map.              |
|                                                  |
|  [ I agree ]    [ Not now ]                      |
+--------------------------------------------------+
```

### Map screen

```
+--------------------------------------------------+
| <  Aurora Devs - Map                  filter (V) |
+--------------------------------------------------+
|                                                  |
|       *  *      *   *                            |
|     *  o12 *      o5    o3                       |
|        *           *                             |
|             o22                                  |
|       *   *                                      |
|                                                  |
|   o = cluster of N members at city level         |
+--------------------------------------------------+
|  You are showing as: Region (California)          |
|  [ Change precision ]   [ Stop sharing ]          |
+--------------------------------------------------+
```

### Cluster tap

```
+--------------------------------------------------+
|  Berkeley area  -  12 members                    |
+--------------------------------------------------+
|  This is a city-level cluster. We do not show    |
|  exact addresses.                                |
|                                                  |
|  Members who chose to be listed:                 |
|  @riku   @lex   @nova   ... +9                   |
|                                                  |
|  [ Plan a meetup ]                               |
+--------------------------------------------------+
```

### Privacy controls

```
+--------------------------------------------------+
| <  Server map                                    |
+--------------------------------------------------+
|  Aurora Devs                                     |
|     Sharing               [ on  /  off ]          |
|     Precision             ( ) Country  (*) Region|
|                            ( ) City              |
|     Auto-expire            180 days               |
|                                                  |
|  Rust Nerds                                      |
|     Sharing               [ off ]                 |
|                                                  |
|  All servers                                     |
|     [ Stop sharing everywhere ]                  |
+--------------------------------------------------+
```

## 5. Component Specs

### `MapClusterMarker`
- Props: `count`, `accentColor`, `isUserCluster`
- Sizes: 28pt for <10, 36pt for 10-49, 48pt for 50+

### `PrivacyConsentSheet`
- Three steps with progress dots
- Big readable copy

### `PrecisionPicker`
- Radio with sample label per option

## 6. Empty / Error / Loading

- **Empty:** "No members on the map yet. Be the first." with CTA Opt in
- **Error:** banner if tile load fails; degrade to country list
- **Loading:** map skeleton with spinner

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Map |
| CTA | Show me on the map |
| Empty | No members on the map yet. |
| Coarsen banner | Bucket too small, coarsened to region. |
| Stop banner | You stopped sharing for this server. |
| Minor lock | Country-level only for accounts under 18. |

Voice: friendly, transparent, never coercive.

## 8. Motion

- Cluster zoom: 250ms easeOutCubic
- Marker bounce on appear: 200ms
- Reduced motion: replace zoom with crossfade

## 9. Accessibility

- Map has alternate list view (toggle in filter)
- Markers expose count and bucket label to screen reader
- Color-blind safe palette (Wong) for density heatmap
- Consent text reading order verified with TalkBack

## 10. Responsive

- Phone: full-bleed map
- Tablet: split list/map
- Web: side panel for filters

## 11. Theming

- Base map: muted dark/light
- Server accent applied to markers (saturation cap)
