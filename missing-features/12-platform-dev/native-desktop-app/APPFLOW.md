# APPFLOW: Native Desktop App

## Flow 1: First Launch
1. User downloads the installer for their platform from `flicko.app/download`.
2. Installer places the binary, registers the `flicko://` URL scheme, and creates a shortcut.
3. On first run, Tauri shell creates the app data directory, generates an X25519 device keypair, and stores the private key in the OS keychain (`Security.framework`, `wincred`, or `Secret Service`).
4. Shell asks the OS for notification permission via the platform API.
5. Shell loads the embedded Flutter web bundle from disk via Tauri's asset protocol.
6. Flutter UI renders the existing sign-in screen.
7. After sign-in, the app calls `POST /api/v1/desktop/devices` with the device public key and platform info, receives a device id, and persists it.

## Flow 2: Push Notification Delivery
1. A new message arrives on the server.
2. Backend looks up subscribed devices for the recipient, encrypts the payload to each device public key, and dispatches via APNs (macOS), WNS (Windows), or queues for long-poll (Linux).
3. Push provider delivers the encrypted blob with a lightweight wake hint to the OS.
4. OS hands the payload to the Rust shell. The shell decrypts using the keychain-stored private key, formats a native toast, and shows it.
5. If the user clicks Reply on macOS or Windows, the inline text is sent via a small invoke command that calls the Flicko API directly without opening the main window.
6. If the user clicks the toast body, the shell brings the window to front and sends a deep link to the Flutter UI to navigate to the relevant channel.

## Flow 3: Auto-Update Check
1. Shell timer fires every 4 hours, plus once at cold start.
2. Shell calls `GET /api/v1/desktop/releases/manifest?channel=stable&current=1.4.2&platform=darwin-arm64`.
3. Server responds with `{latest_version, full_url, full_size, full_signature, patch_url?, patch_size?, patch_signature?}`.
4. Shell picks the smaller path. If a patch exists and applies cleanly to the local binary, it downloads the patch.
5. Shell verifies the signature against the embedded Ed25519 public key.
6. Shell applies bsdiff to the staging copy, atomically renames the new binary into place.
7. Shell shows the "Update ready, restart to apply" banner. On next launch the new version runs.
8. Telemetry records `update.applied` with version, channel, size, and duration.

## Flow 4: Update Failure and Recovery
1. Patch fails to apply (hash mismatch after bsdiff).
2. Shell deletes the staging directory and retries with the full download.
3. If full download fails three times in a row, the banner switches to a red error state and shows a manual download link.
4. Telemetry records `update.failed` with the failure reason.

## Flow 5: Global Hotkey Registration
1. User opens Preferences → Hotkeys.
2. User clicks the Push-to-Talk row, presses Ctrl+Alt+Space.
3. Webview sends `set_hotkey` invoke with `{action: "ptt", combo: "Ctrl+Alt+Space"}`.
4. Shell unregisters the previous binding (if any), tries to register the new one. On conflict the shell returns an error code.
5. On success, the new binding is persisted to the desktop config file.
6. When fired, the shell emits a `hotkey:ptt` event to the webview, which dispatches the existing PTT logic.

## Flow 6: System Tray Interaction
1. User right-clicks the tray icon, selects "Mute Microphone".
2. Shell sends `mute:toggle` event to the webview.
3. Flutter UI flips the mic state and updates the tray menu via a `tray_set_state` invoke.
4. Shell redraws the tray menu to reflect the new state, plays a discrete confirmation chime if enabled.

## Flow 7: Deep Link Handling
1. External browser opens `flicko://server/abc/channel/xyz`.
2. OS routes the URL to the running app (or launches it if not running).
3. Shell receives the URL via the platform-specific deep-link callback.
4. Shell brings the window to front and sends `deeplink:navigate` event with the parsed URL.
5. Flutter router handles navigation as if the user clicked an in-app link.

## Flow 8: Telemetry Submission
1. Shell collects telemetry events into a local rolling buffer (cold start time, update outcomes, push delivery, crash signals).
2. Every 24 hours (or on graceful exit) the shell submits the buffer to `POST /api/v1/desktop/telemetry`.
3. Server validates the device and writes rows to `desktop_telemetry`.
4. If telemetry is disabled in Preferences, the buffer is never submitted and is purged daily.

## Flow 9: Window State Persistence
1. On every move, resize, and minimize, the shell debounces and writes to the local SQLite file.
2. On launch, the shell reads the file, validates the saved monitor exists in the current display layout, and applies the geometry. Falls back to a centered default if the monitor is gone.

## Flow 10: Push Token Rotation
1. APNs returns "expired token" on a delivery attempt.
2. Server marks the device row as `needs_refresh`.
3. Next time the app launches, it requests a fresh token from the OS and registers it via `POST /api/v1/desktop/devices/{id}/token`.
4. Server clears the `needs_refresh` flag and resumes deliveries.

## Flow 11: Sign Out
1. User signs out from the in-app menu.
2. Webview calls `desktop:revoke_device` invoke.
3. Shell calls `DELETE /api/v1/desktop/devices/{id}`, clears the OS keychain entries, deletes locally cached data per the user's preference.
4. Push subscription is unregistered with the platform.
5. App returns to the sign-in screen.
