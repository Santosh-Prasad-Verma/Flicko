# Whiteboard — Product Requirements

> **One-line:** Real-time collaborative whiteboard (tldraw) inside voice channels and any channel.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P2

## 1. Problem

Voice calls in any chat platform get hand-wavy fast. People resort to screen
sharing a Miro tab, Excalidraw URL, or scribble on paper. Discord's voice/Stage
channels have no native canvas. Slack Huddles have a basic doodle but nothing
freeform. Flicko ships a real whiteboard powered by tldraw (open source) so
calls and async ideation share a canvas with no extra app.

## 2. Users & Use Cases

- **Primary persona:** small team or study group on a Flicko voice call.
- **Secondary personas:** designers sketching async; mods drawing rules diagrams.
- **Top jobs-to-be-done:**
  1. As a team in a voice call, we want to sketch on a shared canvas without
     leaving Flicko.
  2. As a designer, I want to drop and arrange wireframe-like shapes during
     a session.
  3. As an async contributor, I want to open the same canvas later and add
     to it.

## 3. Goals & Non-Goals

**Goals**
- Real-time collaborative canvas using tldraw + Yjs
- Pan / zoom / draw / shapes / sticky notes / arrows / text
- Embed inside a voice channel as a side panel; also standalone in a channel
- Export PNG snapshot
- Permission tiers: editor / viewer
- Version snapshots (named + auto)

**Non-Goals (v1)**
- AI auto-cleanup
- Voice/video annotations
- External embed
- Offline editing (defer to v1.1)

## 4. Scope (v1)

- [ ] Create / archive whiteboard per channel or per voice room
- [ ] Real-time multi-user editing (Hocuspocus + tldraw Yjs adapter)
- [ ] Tools: select, draw, eraser, sticky, text, shapes, arrows, image
- [ ] Cursor presence
- [ ] Snapshot to PNG (server-rendered)
- [ ] Voice-channel-attached mode: side drawer
- [ ] Permission tiers
- [ ] Audit log

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Calls with whiteboard active | 8% | events |
| Median session minutes | 12 | events |
| Concurrent users p95 | 4 | telemetry |
| Cost / whiteboard / month | <$0.003 | infra |

## 6. Open Questions / Risks

- Tldraw bundle size (~1.5 MB gzipped) on mobile WebView: lazy load, prewarm.
- Voice channel attachment: when the call ends, the whiteboard persists and
  becomes channel-wide.
- Phone usability for freehand drawing: stylus support but not required.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Whole feature |
| Slack Huddle doodle | Basic | Full canvas |
| Miro | External | Embedded |
| Microsoft Whiteboard | Tied to Teams | Embedded in chat |
| Excalidraw | Anyone-link share | Auth + permissions |

## 8. Rollout

- Internal dogfood 14d
- 20-server beta 28d
- Flag `feature.whiteboard.enabled`
- 1% -> 10% -> 50% -> 100% over 28d
