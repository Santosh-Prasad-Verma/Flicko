# UIUX: Plugin System

## Principles
- Capability transparency first. Every install screen names what the plugin can read or write in plain language.
- Reversible by default. One tap to disable, one more to uninstall, no confirmation tax for safe paths.
- Developer affordances live in a separate "Developer" tab so members never see noise.

## Screen 1: Server Settings - Plugins List
```
+----------------------------------------------------+
| < Server Settings        Plugins        [+ Browse] |
+----------------------------------------------------+
| Installed (3)                                      |
|                                                    |
| [icon] Welcomer            v1.4.2     [On  ] >    |
|         posts greetings in #lobby                  |
|                                                    |
| [icon] AutoMod Lite        v0.9.1     [On  ] >    |
|         filters slurs in all channels              |
|                                                    |
| [icon] Stats Pro           v2.0.0     [Off ] >    |
|         daily server activity report               |
|                                                    |
| -- Inactive --                                     |
| (none)                                             |
+----------------------------------------------------+
```
Copy: row subtitle is the plugin's `summary` field truncated at 60 chars. Toggle is optimistic, reverts on error with toast `Couldn't toggle Welcomer. Try again.`

## Screen 2: Install Confirmation Sheet
```
+----------------------------------------------------+
|                Install Welcomer?                    |
|                v1.4.2 by Acme Co.                   |
|                                                     |
|  This plugin will be able to:                       |
|   - send messages in channels you allow             |
|   - read member join events                         |
|   - store small key-value data on its own           |
|                                                     |
|  It will NOT see:                                   |
|   - your DMs                                        |
|   - voice content                                   |
|                                                     |
|  Channels:  [#lobby]   [+ choose more]              |
|  Updates:   ( ) auto   (o) ask me                   |
|                                                     |
|       [Cancel]            [Install]                 |
+----------------------------------------------------+
```
- Capability bullets render from `manifest.scopes`, mapped to friendly strings via i18n.
- Negative list ("It will NOT see") is computed from the inverse to set expectations.
- Primary button disabled until at least one channel is chosen for write-scoped plugins.

## Screen 3: Plugin Detail (running state)
```
+----------------------------------------------------+
| < Plugins      Welcomer v1.4.2     [...]           |
+----------------------------------------------------+
| Status:  Healthy  -  last call 2s ago               |
|                                                     |
| Activity (24h)                                      |
|  invocations  1,204                                  |
|  failures        2 (0.16%)                          |
|  avg latency   18 ms                                |
|                                                     |
| Configuration                                       |
|  greeting:    "Welcome, {name}!"        [edit]      |
|  channel:     #lobby                    [edit]      |
|                                                     |
| Recent capability use                                |
|  09:14  posted message in #lobby                    |
|  09:14  read member.joined event                    |
|  ...                                                 |
|                                                     |
| [Disable]  [Uninstall]                              |
+----------------------------------------------------+
```

## Motion
- Toggle uses 120 ms ease-out, haptic light on state commit.
- Install sheet slides up 220 ms cubic-bezier(.2,.8,.2,1).
- Capability rows fade in staggered 30 ms each so users actually read them.

## Accessibility
- Capability bullets are a single semantic list, not decorative icons; screen readers announce "list of 3 permissions".
- Toggle has explicit labels "Enable Welcomer", "Disable Welcomer".
- Status colors paired with text and icon, never color alone.
- Min hit target 44x44.
- Dynamic Type up to XXL respected; capability sheet becomes scrollable rather than truncated.

## Empty States
- No plugins installed: illustration + "Browse the Store" CTA, two-line copy "Plugins add new behavior to your server, like welcomers and moderation."
- Plugin failing: amber banner "Welcomer hit an error. We'll keep trying. [View logs]".
