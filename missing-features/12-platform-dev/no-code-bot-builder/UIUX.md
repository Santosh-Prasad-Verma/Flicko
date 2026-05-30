# UIUX: No-Code Bot Builder

## Layout
Three-pane SPA at `bots.flicko.app`.

- **Left rail (240px)**: server picker, bot list, "New Bot" button. Selected bot is highlighted with a 3px left accent.
- **Center canvas**: full bleed React Flow board. Pan with space drag, zoom with cmd scroll. Mini-map bottom right. Grid background dotted.
- **Right rail (320px)**: collapsible. Tabs are Node Inspector, Variables, Run Logs, Test.

Top bar: bot name (inline editable), enabled toggle, save button (disabled when no changes), "Test" pill, version dropdown.

## Visual Language
- Background `#0E0F11`, canvas `#16181D`, edges `#3D89F5` with 2px stroke.
- Trigger nodes: pill shape, accent color `#22C55E` (green), icon left.
- Action nodes: rounded rectangle, accent color `#3D89F5` (blue).
- Control flow nodes: rhombus with `#F59E0B` (amber) accent.
- End nodes: gray `#6B7280`.
- Selected node has 2px accent border plus drop shadow `0 0 0 4px rgba(61,137,245,0.25)`.
- All node corners 12px radius. Inter font 13/16/20.

## Node Palette
Bottom drawer, sliding up. Search box at top. Categories tabbed.
- Triggers (12)
- Server actions (send message, send DM, set topic, pin, create thread)
- Member actions (add role, remove role, kick, ban, mute)
- Control flow (branch_if, wait, end, set_variable)
- Utility (log_audit, increment_counter, react, delete_message)

Drag from palette to canvas. Each card shows icon, name, one-line description.

## Node Inspector
Opens on node click. Fields render based on node `type`:
- `send_message`: channel picker (autocomplete), message body (Monaco editor with template hints), embeds toggle.
- `add_role`: role picker (multi-select), target selector (trigger.user, named variable).
- `branch_if`: left value, operator dropdown (eq, neq, contains, gt, lt, in), right value, both with template autocomplete.
- `wait`: duration in seconds, max 300.
- `scheduled_cron`: cron expression with human-readable preview ("every weekday at 9 AM").

Each field has a small `i` tooltip. Errors render inline in red below the field.

## Variables Tab
Table with columns name, type, default. Add row button. Type select limits the cells. Variables can be referenced as `{{var.name}}` in any string field with autocomplete.

## Run Logs Tab
Latest 100 runs as a virtual list. Each row: status pill (success, failed, timed out), trigger snippet, duration, age. Click expands to per-node trace. Failed nodes are red, error message preformatted.

## Test Tab
Synthetic trigger builder. Pick trigger type, fill payload form, "Run". Output renders as a step-by-step accordion. Variables and outputs are pretty-printed JSON.

## Empty States
- No bots: large illustration of a robot holding a wrench, "Build your first bot" CTA, three template cards (Welcome bot, Mod bot, Reaction roles).
- Empty canvas: faint dashed rectangle in center "Drag a trigger here to get started".
- No runs: "Bot has not run yet. Save and enable to capture runs."

## Microcopy
- Save button states: "Save", "Saving", "Saved 5s ago".
- Enabled toggle: "Bot is live" green dot, "Bot is paused" amber dot.
- Validation errors: "Channel is required" inline, never modal.
- Confirm rollback: "Restore version 7? Current draft will be saved as version 12."

## Keyboard
- `cmd+s` save.
- `cmd+z` undo (Zustand undo middleware, 30 step history).
- `cmd+d` duplicate selected node.
- `delete` remove selected node and its edges.
- `cmd+/` open palette.
- `cmd+enter` run test with current trigger.

## Responsive
Desktop only above 1280px. Below that, "Bot Builder is best on a desktop browser" banner with link to mobile-friendly run logs view at `/bots/:id/runs`.

## Mobile Companion
Mobile app shows read-only run logs at `bots/runs` route. Admin can pause or resume but not edit. Same design tokens as the existing settings screen.

## Accessibility
- Canvas nodes are focusable with tab and keyboard movable with arrow keys.
- All icons have `aria-label`.
- Color is never the only signal: status pills include text plus icon.
- Contrast ratio meets WCAG AA on the dark theme.
