# Forms & Surveys — UI/UX Design

## 1. Design Principles

- Form builder feels like rearranging blocks; question types are large icons
- Fill flow is one-question-per-screen on phone, scrollable list on tablet
- Aggregates use simple bar/pie; never 3D
- Required field marked with red dot, never an asterisk

## 2. Information Architecture

- Entry points:
  1. Server side rail "Forms"
  2. Channel "+" -> Form
  3. Channel card "Fill"
- Deep links: `flicko://server/<sid>/form/<id>` and `flicko://form/<id>/fill`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Form List | All forms in server | empty, content |
| 2 | Builder | Compose questions | draft, validating, saving |
| 3 | Fill | Member answer | progress, submitting, thanks, closed |
| 4 | Responses Dashboard | Aggregates + table | empty, content, exporting |
| 5 | Channel Card | Embedded prompt | active, closed |

## 4. Wireframes (ASCII)

### Builder

```
┌────────────────────────────────────────────────┐
│ ✕ New form                          [Publish]  │
├────────────────────────────────────────────────┤
│ Title       [ Event Feedback                ]  │
│ Description [ Took 2 minutes                ]  │
│ Settings    ☑ Anonymous   ☑ One per user       │
│             Closes [ Jun 15 11:59 PM ▾ ]      │
├────────────────────────────────────────────────┤
│ Questions                                      │
│ ┌────────────────────────────────────────────┐ │
│ │ ≡  1. Name                                 │ │
│ │    Short text · optional                   │ │
│ ├────────────────────────────────────────────┤ │
│ │ ≡  2. Rating *                             │ │
│ │    Single choice: 1 / 2 / 3 / 4 / 5        │ │
│ ├────────────────────────────────────────────┤ │
│ │ ≡  3. What did you enjoy?                  │ │
│ │    Multi choice: Talks / Food / Network    │ │
│ ├────────────────────────────────────────────┤ │
│ │ ≡  4. Comments                             │ │
│ │    Long text · optional                    │ │
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │
│ │ + Add question                             │ │
│ │  [Aa Short]  [¶ Long]  [◯ Single] [☐ Multi]│ │
│ │  [▼ Dropdown] [≡ Scale] [📅 Date] [📎 File]│ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

### Fill (one-per-screen, phone)

```
┌────────────────────────────────────────────────┐
│ Event Feedback              ●●●○                │
├────────────────────────────────────────────────┤
│  2 of 4                                        │
│                                                │
│  Rating *                                      │
│                                                │
│  ◯ 1   ◯ 2   ●  3   ◯ 4   ◯ 5                 │
│                                                │
│  ────────────────────────────                  │
│                                                │
│                              [ Back ] [ Next ] │
└────────────────────────────────────────────────┘
```

### Responses Dashboard

```
┌────────────────────────────────────────────────┐
│ ← Event Feedback · Responses (47)              │
├────────────────────────────────────────────────┤
│ Q2 Rating                                      │
│  1 ▍                       (2)                 │
│  2 █                       (5)                 │
│  3 ████████                (15)                │
│  4 ██████████████          (18)                │
│  5 ███████                 (7)                 │
│                                                │
│ Q3 What did you enjoy?                         │
│  Talks      ████████████████   38              │
│  Food       ██████████          22             │
│  Networking ████████             18             │
│                                                │
│ Q4 Comments (sample 3 of 47)                   │
│  "loved the talks, more please"                │
│  "venue was great"                             │
│  "more food next time"                         │
│                                                │
│ [ Export CSV ]   [ Close form ]                │
└────────────────────────────────────────────────┘
```

### Channel Card

```
┌────────────────────────────────────────────────┐
│ 📋  Event Feedback                             │
│  Took 2 minutes · 47 responses · closes Fri    │
│                                       [ Fill ] │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `QuestionBlock`
- Props: `question`, `onEdit`, `onDelete`, `onReorder`
- States: idle, editing, dragging

### `AggregateChart`
- Bar for single/multi choice and scale
- Word cloud (top 20) for long text (v1: list of samples)

### `FillProgressDots`
- One dot per question; current filled

## 6. Empty / Error / Loading

- Empty list: clipboard illustration + "No forms yet"
- Empty responses: "No responses yet"
- Error: "Couldn't submit. Retry"
- Loading: skeleton

## 7. Copy

| Surface | Copy |
|---------|------|
| FAB | New form |
| Channel CTA | Fill |
| Fill thank-you | Thanks. Your response was saved. |
| Closed | This form is closed. |
| Required hint | This question is required. |

## 8. Motion

- Question reorder: lift+drop with shadow
- Submit success: checkmark draw 300ms
- Reduced motion: instant

## 9. Accessibility

- Keyboard nav across questions; Tab/Shift+Tab
- Screen reader announces "Question 2 of 4, Rating, required"
- Color paired with shape on choice dots

## 10. Responsive

- Phone: one question per screen
- Tablet/web: full form scroll
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Honors server accent for primary CTA
