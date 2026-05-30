# UIUX: Native Desktop App

## Surfaces
The desktop app surfaces are: the main application window (Flutter UI as on web), the system tray menu, native notification toasts, the auto-update banner, the Preferences panel, and the first-run setup screen. Everything else inherits from the existing web UI.

## First Run
The first launch shows a slim setup screen: Flicko logo, two-line copy ("Welcome to Flicko Desktop. We'll set up notifications and updates."), and a primary button "Get Started". Behind the scenes the shell registers the URL scheme, generates a device key, and asks the OS for notification permission. If the user declines notifications the app continues without them and surfaces a re-prompt link in Preferences.

After Get Started, the app drops into the standard sign-in flow that already exists on web.

## Main Window
The main window is the Flutter web build with no chrome additions. The only visual difference from web is a small "Online" status bubble next to the avatar that reflects desktop-app presence. Window controls are platform-native: traffic lights on macOS, system menu on Windows, decorations or client-side controls on Linux depending on the desktop environment.

## System Tray
The tray icon reflects status with three states: outlined (signed out), filled (online), filled with red dot (notifications). Click behavior is platform-conventional. The menu items in order:
- Open Flicko
- Quick Status submenu (Online, Idle, Do Not Disturb, Invisible)
- Mute Microphone (toggle, shows current state)
- Mute Notifications for 1 hour, 8 hours, until tomorrow
- Preferences
- Check for Updates
- Quit Flicko

## Notification Toasts
Toasts use the OS native style. Content includes server name, channel, sender, and a one-line preview. Actions vary by platform:
- macOS: Reply (inline text input), Mark as Read, Mute Channel.
- Windows: same set, rendered as toast buttons.
- Linux: Open and Mark as Read; inline reply not supported.

If end-to-end encryption is on for the channel, the body shows "New message" with no preview, since the OS-level layer cannot decrypt.

## Update Banner
When a downloaded update is staged and ready, a slim banner appears at the top of the main window: "An update is ready. Restart to apply." with two buttons (Restart Now, Later). Dismissing snoozes for 24 hours; the banner reappears with a slightly more assertive tone after three snoozes.

If an update is in progress, a discreet progress indicator sits in the bottom-right of the window with a tooltip showing the percent and current step.

## Preferences Panel
A dedicated Preferences route inside the app, with desktop-only sections:
- Startup: Launch Flicko on system startup, Start in tray.
- Updates: Channel (Stable, Beta, Dev), Last checked, Check for Updates button.
- Notifications: Enable native notifications, Show message preview, Notification sound, Per-server overrides.
- Hotkeys: Editable list with Push-to-Talk, Mute, Deafen, Toggle DND, Jump to Search. Each has a recorder field.
- Privacy: Send crash reports, Send usage telemetry, View what was last sent.
- Advanced: Open data directory, Reset window state, Clear local cache.

Each toggle has a one-line subhead explaining the impact.

## Hotkey Recorder
Clicking a hotkey field shifts the field into "Press a combination" mode. The recorder shows the live combination as the user holds keys. Conflicts surface inline ("This combo is registered by another app. Pick another."). Saving registers the binding atomically; failures revert.

## Privacy Disclosure
The Privacy section includes a "View last telemetry payload" button that opens a side sheet with the JSON of the most recent submission, scrubbed of identifiers. Copy and Export buttons make it easy for skeptical users to inspect.

## Global Hotkey Visualization
When a hotkey fires (e.g., push-to-talk), a small ephemeral pill appears in the bottom-center of the screen for 800 ms confirming the action. This is OS-level so it works even when the app window is not focused.

## Empty States
- No notifications received yet: tray menu shows "Nothing new" italicized.
- Updates section after a fresh install: "You're on the latest version (1.0.0)."

## Error States
- Push registration failed: a soft banner in Preferences ("We couldn't register for notifications. Click to retry.").
- Update apply failed: red banner with the failure reason and a Retry button. After three failures, the banner suggests downloading the full installer manually with a link.
- Hotkey conflict on launch: a single toast on first occurrence ("Some hotkeys couldn't be registered. Check Preferences.").

## Microcopy
- Quit confirmation (only if media call active): "You're in a voice call. Quit anyway?"
- Update banner: "An update is ready. Restart to apply." not "Update available."
- Privacy: "We don't track who you are or what you say. Tap View to see exactly what's sent."

## Accessibility
- All tray menu items have keyboard accelerators on Windows and Linux.
- VoiceOver and Narrator labels for tray and toast actions.
- Hotkey recorder can be operated via screen reader with a press-and-confirm pattern.
- Update progress is announced at 0%, 50%, and 100%.

## Visual Tone
The desktop chrome is intentionally invisible. Tray icons and toasts match Flicko's brand without dominating the OS. Update and privacy surfaces are calm and direct, never alarming or salesy.
