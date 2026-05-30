import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/e2ee_session.dart';
import '../domain/identity_verification.dart';

/// Banner shown above a chat when a peer's identity key has rotated.
///
/// Surfaces both the previously-trusted fingerprint and the new one so the
/// user can decide whether the change is benign (peer reinstalled the app,
/// got a new device) or suspicious (potential MITM). The user can:
///   - Verify: navigate to the safety-number screen for an out-of-band check.
///   - Trust:  pin the new fingerprint silently. Use only after verifying.
///   - Dismiss: hide for now. The next [E2EESession.checkPeerIdentityChange]
///     call will surface the banner again until the user explicitly trusts.
///
/// First-contact (TOFU) alerts — `oldFingerprint` is empty — render a softer
/// "this is a new contact" tone instead of a warning. The caller decides
/// whether to even show the banner in that case.
class IdentityChangeBanner extends ConsumerWidget {
  final IdentityChangeAlert alert;

  /// Called when the user taps "Verify". Typically pushes a route to the
  /// safety-number screen. The widget itself does not navigate.
  final VoidCallback? onVerify;

  /// Called when the user taps "Dismiss" (hide for this session).
  final VoidCallback? onDismiss;

  /// Called after the user taps "Trust" and the new fingerprint has been
  /// pinned via [E2EESession.acknowledgePeerIdentity].
  final VoidCallback? onTrusted;

  const IdentityChangeBanner({
    super.key,
    required this.alert,
    this.onVerify,
    this.onDismiss,
    this.onTrusted,
  });

  bool get _isFirstContact => alert.oldFingerprint.isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = _isFirstContact ? scheme.primary : scheme.error;

    return Material(
      color: tone.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isFirstContact ? Icons.person_add_alt_1 : Icons.warning_amber_rounded,
                  color: tone,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isFirstContact
                        ? 'New contact'
                        : 'Their security code changed',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isFirstContact
                  ? 'Verify their security code in person or over a trusted channel before sharing anything sensitive.'
                  : 'This may happen if they reinstalled the app or got a new device, but it can also indicate a man-in-the-middle attack.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (!_isFirstContact) ...[
              const SizedBox(height: 8),
              _FingerprintPair(
                label: 'Previously',
                fingerprint: alert.oldFingerprint,
              ),
              const SizedBox(height: 4),
              _FingerprintPair(
                label: 'Now',
                fingerprint: alert.newFingerprint,
                emphasised: true,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (onVerify != null)
                  TextButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Verify'),
                  ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () async {
                    // Silently pin the new fingerprint as trusted. UI flow is
                    // expected to confirm with the user *before* invoking this
                    // (banner offers Verify first); the widget only commits
                    // the keystore write.
                    final session = ref.read(e2eeSessionProvider);
                    await session.acknowledgePeerIdentity(alert.userId);
                    onTrusted?.call();
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Trust'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintPair extends StatelessWidget {
  final String label;
  final String fingerprint;
  final bool emphasised;

  const _FingerprintPair({
    required this.label,
    required this.fingerprint,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            _shorten(fingerprint),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// Show the first 16 hex chars with an ellipsis. Full fingerprint is
  /// available on the safety-number screen.
  String _shorten(String fp) {
    if (fp.length <= 16) return fp;
    return '${fp.substring(0, 16)}…';
  }
}
