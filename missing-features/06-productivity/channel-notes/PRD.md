# Channel Notes — Product Requirements

> **One-line:** A single shared notepad pinned to each channel for quick shared notes.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** S
> **Priority:** P1

## 1. Problem

Pinned messages don't scale; channel topic is one line; full collab-docs is
heavy. Communities want a "scratch pad" per channel: a single page anyone in
the channel can edit. Slack Canvas attempts this but it's coupled with paid
tiers; Discord has nothing.

Channel notes is the lightweight cousin of `collaborative-docs`: one note per
channel, simple markdown, real-time edits, auto-saved. No version history,
no comments, no permission tiers (channel write = note write). Cheap to ship,
easy to use.

## 2. Users & Use Cases

- **Primary persona:** any channel member.
- **Secondary personas:** mods using a notes pad as a rotating FAQ.
- **Top jobs-to-be-done:**
  1. As a member, I want a place to drop a checklist or current state of a
     topic that doesn't scroll away.
  2. As a mod, I want to maintain a current FAQ for the channel that anyone
     can update.
  3. As a contributor, I want my edits to show up live for others reading.

## 3. Goals & Non-Goals

**Goals**
- One note per channel
- Simple markdown rendering (headings, lists, code, links, mentions)
- Real-time multi-user editing via existing Hocuspocus infra (small Yjs doc)
- Always saved; no manual save button
- Pinned in channel header; one-tap open

**Non-Goals**
- Multiple notes per channel (use `collaborative-docs`)
- Page hierarchy
- Comments
- Version history (last edit metadata only)
- Tables / images (point to docs feature)

## 4. Scope (v1)

- [ ] One note row per channel (auto-created on first edit)
- [ ] Real-time editing via Hocuspocus
- [ ] Markdown render with mentions / channel links
- [ ] Channel header pin shows note title (or first line)
- [ ] Edit access = channel write permission
- [ ] Last edited by + when, displayed at top

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Channels with active note | 25% in 30d | events |
| Median edits per active note | 4 / week | events |
| Cost per note | <$0.0005 | infra |

## 6. Open Questions / Risks

- Who can clear a note? Channel mod only (audit logged).
- Conflict between two simultaneous deletes-and-types: Yjs handles.
- Bot posts a heads-up when note is created so members know it exists.

## 7. Competitive Landscape

| Product | Their take | Gap |
|---------|------------|-----|
| Slack Canvas | Paid; multi-page | Free, single |
| Discord | None | Whole feature |
| Notion | External | Embedded |

## 8. Rollout

- Internal 5d
- 1% -> 10% -> 50% -> 100% over 14d
- Flag `feature.channel_notes.enabled`
