# UIUX: Visual Webhook Builder

## Surfaces
The webhook builder lives at Server Settings → Integrations → Webhooks. It opens to a list of existing webhooks; clicking one or pressing New opens the canvas in a full-screen modal that takes over the workspace.

## Webhook List
Cards in a responsive grid: title, source icon (GitHub mark, Stripe S, generic globe), direction badge (In or Out), last run timestamp with status dot (green, yellow, red), and a kebab menu. Search bar at the top, filter chips for direction, status, and template type.

Empty state shows three featured templates as large clickable tiles ("GitHub releases to a channel", "Stripe receipts", "Custom HTTP") with a fourth "Start from scratch" tile.

## Canvas
A pannable, zoomable workspace with a subtle dot grid. The left sidebar holds a node palette grouped into Triggers, Transforms, and Destinations. The right sidebar is the inspector for the selected node. The bottom dock shows a test runner panel that can be expanded.

Nodes are rounded rectangles with a colored top stripe (purple for triggers, blue for transforms, green for destinations). The header has the node icon, title, and a small status dot reflecting the latest test run. The body shows the most important configured field as a preview ("Channel: #releases", "Path: items[0].name").

Edges are smooth bezier curves. While dragging, valid drop targets glow; invalid ones dim. Type mismatches show a tooltip explaining the conflict ("Trigger emits Object, this Transform expects Array").

## Node Inspector
Selecting a node opens the inspector. Fields are typed: short text, long text, secret, JSONata expression, channel picker, role picker, URL, key-value list. Validation runs live; invalid fields outline red with a one-line reason underneath.

For JSONata expressions, the editor is monospace with token highlighting and an autocomplete that pulls field names from the upstream node's schema. A "Preview" button under the expression evaluates against the most recent test payload and shows the result inline.

Secrets fields render as a single-line input with a Reveal toggle, a Copy button, and a Rotate action. Once saved, the value is masked permanently; rotation produces a new value shown once.

## Test Runner
The bottom dock has a Run Test button, a payload editor (JSON, with a Sample picker that suggests realistic payloads per template), and a result column. Running animates each node header to a spinner, then resolves to green check or red x. Each node's output is inspectable by clicking it; a side panel slides in with the node's input, output, and any error.

Failures highlight the offending field in the inspector. A "Copy as cURL" button reproduces the test as a shell command for offline debugging.

## Run History
A separate tab on the webhook detail page shows the last 100 runs. Each row: timestamp, source IP (for inbound), HTTP status, duration, and a Status pill. Clicking a row opens a side drawer with full request and response, the executed graph snapshot, and a Replay button.

Failed runs surface a banner at the top of the list with a count and a Replay All button. Replay All confirms via dialog, then animates each row to a "queued" state.

## Template Library
Accessible from the New Webhook flow. Two-column layout: categories on the left (Dev tools, Payments, Monitoring, Custom), template cards on the right. Each card has the source logo, a one-line description, and a "Use template" button. Hovering reveals a preview of the canvas the template ships with.

Selecting a template opens the canvas pre-populated and drops the user into the inspector for the trigger node so they can paste their secret immediately.

## Empty States
- No webhooks: an illustration of two connected nodes with the copy "Send events in or out of Flicko."
- No runs yet: "Trigger an event to see it appear here. Or run a test from the canvas."
- No failed runs: "All deliveries succeeded in the last 7 days." with a small confetti icon.

## Error States
- Pipeline invalid on save: a toast lists the issues with click-to-jump links to each affected node.
- Destination 5xx loops: a banner suggests checking the destination URL or rotating credentials.
- Signature mismatch incoming: counter on the webhook list card with a tooltip "Sender's signature did not match. Verify the secret."

## Microcopy
- Save button: "Save webhook".
- Rotation confirm: "Rotating the secret will break any current senders. They'll need the new value."
- Replay: "Replay sends this event to the destination again, exactly as it was received."

## Accessibility
- Canvas is keyboard-navigable: Tab cycles nodes, Enter opens inspector, arrow keys reposition.
- Status dots have aria-label text and shape variations for color-blind users.
- All inspector fields are labeled and announce validation errors.

## Responsive Behavior
- Desktop only for the canvas in v1; on mobile, the list and run history are read-only with a banner directing to desktop for editing.
- The list view fully responsive on mobile so admins can monitor on the go.

## Visual Tone
The canvas leans calm and technical. Node colors are saturated but not loud; the grid background fades at the edges. Transitions are quick (150-200 ms). Test-run animations use a confident green check, never a celebratory burst.
