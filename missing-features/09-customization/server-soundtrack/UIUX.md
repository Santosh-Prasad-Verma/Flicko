# UI/UX - Server Soundtrack

Three flows on mobile (Flutter):
1. Admin Track Picker (browse curated library, preview, select).
2. Server Soundtrack Settings (enable/disable, volume, fade, status).
3. Member Mute Toggle (lightweight in-server affordance, no admin needed).

Tone: calm, ambient, low-friction. Avoid hype copy. Default state is "off"; turning it on is opt-in.

## 1. Track Picker

Path: Server Settings -> Customization -> Soundtrack -> "Choose Track".

```
+-----------------------------------------------+
| <-  Soundtrack Library             [Search Q] |
+-----------------------------------------------+
| Filters:  [All] [Lofi] [Nature] [Synth] [Jazz]|
+-----------------------------------------------+
|                                               |
|  +---------------------------------------+    |
|  | [WAVE] Rainy Window Lofi      3:24    |    |
|  | by Kestrel  -  CC0  -  -22 LUFS       |    |
|  | [ Preview ]  [ * Pin ]   [ Select  >] |    |
|  +---------------------------------------+    |
|                                               |
|  +---------------------------------------+    |
|  | [WAVE] Forest Dawn            4:01    |    |
|  | by Hollow  -  CC-BY  -  -22 LUFS      |    |
|  | [ Preview ]  [ * Pin ]   [ Select  >] |    |
|  +---------------------------------------+    |
|                                               |
|  +---------------------------------------+    |
|  | [WAVE] Subtle Synth Pad       5:12    |    |
|  | by Auralis  -  CC0  -  -22 LUFS       |    |
|  | [ Preview ]  [ * Pin ]   [ Select  >] |    |
|  +---------------------------------------+    |
|                                               |
|              -- load more --                  |
+-----------------------------------------------+
| Now previewing: Forest Dawn   [ Stop |||]     |
+-----------------------------------------------+
```

Copy:
- Empty state: "No tracks match. Try removing a filter."
- Preview hint (first time only, dismissible): "Previews play locally. They will not start on the server until you tap Select."
- License pill: small chip, tappable, opens bottom sheet with attribution text.

Motion:
- Waveform card: animated 80ms pulse on Preview tap, then steady 1.6s breathing.
- Selecting: card lifts 4dp, success snackbar slides in 240ms ease-out.
- Filter chips: 120ms color crossfade.

A11y:
- Each card is a single Semantics node with label "Track <name>, <duration>, by <artist>, license <kind>. Double tap to select."
- Preview button is a separate focusable child; announces "Playing preview" / "Preview stopped".
- Waveform is decorative (`excludeSemantics: true`); duration is text.
- Min tap target 48x48; chips 36 height + 12 padding.
- Reduced-motion: pulse and breathing disabled, card lift becomes opacity flicker.

## 2. Server Soundtrack Settings (admin)

Path: Server Settings -> Customization -> Soundtrack.

```
+-----------------------------------------------+
| <-  Soundtrack                                |
+-----------------------------------------------+
|                                               |
|  Enabled         (  )==[ON ]                  |
|                                               |
|  Track                                        |
|  +---------------------------------------+    |
|  | [WAVE] Rainy Window Lofi              |    |
|  | by Kestrel  -  CC0                    |    |
|  | [ Change track > ]                    |    |
|  +---------------------------------------+    |
|                                               |
|  Volume     -36dB ----O--------- -6dB         |
|             "Quiet"        currently -22dB    |
|                                               |
|  Fade in/out     [ 0s ][ 2s ]( 3s )[ 5s ]     |
|                                               |
|  Duck under voice  [x] On                     |
|                                               |
|  Status                                       |
|  - 142 members listening now                  |
|  - 31 muted locally                           |
|  - Last set by @rohan, 14 min ago             |
|                                               |
|  [ Save changes ]    [ Disable soundtrack ]   |
+-----------------------------------------------+
```

Copy:
- Header subtitle: "Plays a soft ambient loop for everyone in this server. Members can mute it for themselves."
- "Disable soundtrack" confirmation: "Stop the soundtrack for everyone? Members will hear silence after a short fade."
- Save success: "Soundtrack updated. Members will fade in within a few seconds."
- Save error: "Couldn't update the soundtrack. Try again, or pick another track."

Motion:
- Toggle: 200ms iOS-style; while transitioning the volume slider greys out.
- Volume slider: thumb scales 1.1x while dragged; debounced save at 600ms idle.
- Saving: button shows spinner inline, label changes to "Saving...".

A11y:
- Toggle has accessible label "Server soundtrack enabled" and accessible hint "Double tap to toggle".
- Volume slider exposes `Slider` semantics with min/max in dB, step 1.
- Status section is a single live region; updates announced politely.

## 3. Member Mute Toggle

Affordance lives in the in-server bottom audio strip (visible whenever a soundtrack is playing for the user). Always available, no admin needed.

```
+-----------------------------------------------+
| #general                            [voice 3] |
+-----------------------------------------------+
|                                               |
|     ... message list ...                      |
|                                               |
+-----------------------------------------------+
|  [WAVE] Rainy Window Lofi      |X mute |  v   |
+-----------------------------------------------+
|  [+] [Aa] message...                  [Send]  |
+-----------------------------------------------+
```

Expanded sheet (tap chevron):

```
+-----------------------------------------------+
|  Soundtrack                              [x]  |
+-----------------------------------------------+
|  Rainy Window Lofi   -  by Kestrel            |
|                                               |
|  [WAVE animated]                              |
|                                               |
|  My volume   -inf ------O-------- 0dB         |
|              currently -8dB (relative)        |
|                                               |
|  [ ] Mute on this server                      |
|  [ ] Mute on all servers                      |
|                                               |
|  Set by admin: -22dB master, fade 3s          |
+-----------------------------------------------+
```

Copy:
- Strip button label: "Mute soundtrack" / "Unmute soundtrack".
- Sheet hint: "Your settings only affect you. Other members keep hearing the soundtrack."
- All-servers toggle helper: "Useful if you prefer total quiet."

Motion:
- Strip slides up 180ms once the soundtrack starts; slides down 180ms when stopped.
- Mute tap: waveform fades to a flat line over 240ms; icon swaps with crossfade.
- Sheet: bottom sheet 280ms cubic ease-out; backdrop 60% opacity.

A11y:
- Strip is a landmark with role "region", label "Server soundtrack controls".
- Mute button has state ("muted" / "unmuted") announced.
- Volume slider focusable from the strip without opening the sheet (long-press = open).
- Reduced-motion: strip toggles visibility instantly, no slide.

## Cross-cutting

Theming: surface-2 background, primary accent only on action buttons. Waveform uses neutral-500 idle, primary at 60% while playing.

Localization: all strings in `intl_en.arb`, no concatenation; durations and dB values pass through `NumberFormat`.

Error states:
- Library fails to load: full-screen retry with last-cached items shown dimmed.
- Track 404 on play: toast "This track was retired. Pick another." + auto-route admin to picker.

Empty state (no soundtrack set, viewed by admin): friendly illustration, single CTA "Choose a track" - no secondary noise.
