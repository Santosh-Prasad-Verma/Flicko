# Cross-Server Channels — UI/UX Design

## 1. Design Principles

- The link is a property of the channel, not a separate place
- Always visible cue that "this message reaches multiple servers"
- Local moderation actions are clearly marked as local
- Cross-server presence indicator: "12 here + 8 in B"

## 2. Information Architecture

- Entry points: Channel settings -> Cross-server tab; chain badge in channel header
- Parent: channel settings
- Deep link: `flicko://server/<id>/channels/<cid>/link`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Channel header chip | Show link status | active, paused, none |
| 2 | Manage link sheet | View members, leave | content |
| 3 | Propose link | Pick servers/channels | drafting, submitting, error |
| 4 | Compose chip | Compose-time reminder | active, perm warning |
| 5 | Local mod menu | Hide/remove locally | one |

## 4. Wireframes (ASCII)

### Channel header with link

```
+--------------------------------------------------+
|  #lounge  [chain] Region Lounge                  |
|  3 servers - 412 members visible                 |
+--------------------------------------------------+
```

### Manage link sheet

```
+--------------------------------------------------+
|  Region Lounge                                   |
+--------------------------------------------------+
|  [logo] Aurora Devs - #lounge       active       |
|  [logo] Rust Nerds - #lounge        active       |
|  [logo] Birdwatch  - #regional      active       |
|                                                  |
|  Add a channel  [ +  Invite ]                    |
|                                                  |
|  [ Pause link ]   [ Leave link ]                 |
+--------------------------------------------------+
```

### Propose link

```
+--------------------------------------------------+
|  Link this channel with                          |
+--------------------------------------------------+
|  Server     [ select... ]                        |
|  Channel    [ #lounge   ]                        |
|                                                  |
|  Name the link                                    |
|  [ Region Lounge ]                                |
|                                                  |
|  Heads up: members in any linked channel will    |
|  see all messages here. Permissions intersect.   |
|                                                  |
|                                [ Send proposal ] |
+--------------------------------------------------+
```

### Compose chip

```
| Posting to: A.lounge + B.lounge + Birdwatch.regional |
| [chain]                                              |
| [ message field ]                                    |
| [ send ]                                             |
```

### Local mod menu

```
+----------------------------+
|  Local actions for B       |
|  - Hide locally            |
|  - Warn (DM author + log)  |
|  - Remove from B           |
|                            |
|  Global delete needs       |
|  author or global mod      |
+----------------------------+
```

## 5. Component Specs

### `LinkBadge`
- 12pt chain icon, label optional
- Long-press shows participants

### `ComposeLinkChip`
- Lists participating channels with overflow chip "+N more"

## 6. Empty / Error / Loading

- **Empty:** if not linked, settings shows "No links yet" and CTA
- **Error:** banner with retry; perm-denied gracefully
- **Loading:** skeleton chip and member list

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Cross-server link |
| CTA | Link this channel |
| Empty | This channel is not linked. |
| Perm-denied compose | You cannot post in {channel} |
| Local hide toast | Hidden in this server only |
| Dissolve confirm | Dissolve link? Messages stay where posted. |

## 8. Motion

- Badge pulse on first link 240ms
- Compose chip subtle slide-in 180ms
- Reduced motion: crossfade

## 9. Accessibility

- Chain badge has Semantics label "Linked across 3 servers"
- Compose chip announces the participant list before send
- Local mod menu items distinguished from global by label prefix "Locally"

## 10. Responsive

- Phone: bottom sheets for management
- Tablet/web: side panel for management

## 11. Theming

- Chain badge tinted by `tertiary`
- Pause state warmer-grey
