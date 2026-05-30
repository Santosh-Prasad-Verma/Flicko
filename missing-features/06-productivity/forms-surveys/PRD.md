# Forms & Surveys — Product Requirements

> **One-line:** Native form builder; send to channel; collect and visualize responses.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P1

## 1. Problem

Communities run feedback surveys, RSVPs that need richer fields, internal
polls with multiple sub-questions, and gear-rental sign-ups. Today they paste
a Google Forms link, breaking flow and analytics. Slack workflows do this; we
do too, native, free.

## 2. Users & Use Cases

- **Primary persona:** mod running quarterly community surveys.
- **Secondary personas:** event organizers collecting registrations; team
  collecting bug reports.
- **Top jobs-to-be-done:**
  1. As a mod, I want to build a 5-question survey in 60 seconds.
  2. As a member, I want to fill it without leaving the chat.
  3. As a mod, I want to see results visualized + export CSV.

## 3. Goals & Non-Goals

**Goals**
- Question types: short text, long text, single choice, multi choice, scale 1-N, dropdown, date, file upload (image/pdf only)
- Validation: required, min/max length, regex (advanced)
- Send: channel post with native fill button
- Anonymous mode (hashed user_id per form)
- One-response-per-user enforcement
- Live aggregate view with chart per question
- CSV export

**Non-Goals (v1)**
- Branching logic
- Conditional questions
- Quiz scoring
- Webhooks

## 4. Scope (v1)

- [ ] Form builder
- [ ] Publish to channel as a card with "Fill" button
- [ ] Mobile fill UI
- [ ] Aggregates view + chart
- [ ] CSV export
- [ ] Close / archive states
- [ ] Anonymous + per-user limit

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Forms published per active server / month | 1.5 | events |
| Median response rate | 30% | derived |
| Cost per response | <$0.0001 | infra |

## 6. Open Questions / Risks

- Required field UX on mobile: keep simple; star next to label.
- Schema edits after responses: forbid except label fixes.
- File upload abuse: virus-scan via existing pipeline; cap 8 MB.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Google Forms | external | embedded |
| Slack workflows | paid tier | free, native |
| Discord | None | whole feature |
| Typeform | external | embedded, free |

## 8. Rollout

- Internal 7d, beta 14d, 1% -> 100% over 21d
- Flag `feature.forms_surveys.enabled`
