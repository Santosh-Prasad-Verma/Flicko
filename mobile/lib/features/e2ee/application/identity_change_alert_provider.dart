import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/e2ee_session.dart';
import '../domain/identity_verification.dart';

/// Per-peer identity-change alert state for chat screens.
///
/// On `build` (and on every refresh) this calls
/// [E2EESession.checkPeerIdentityChange]:
///   - If the peer has no published identity, the value is null.
///   - On true first-contact (TOFU — `oldFingerprint` empty), the alert is
///     auto-acknowledged silently. We do NOT show a banner for every brand-
///     new conversation; the user only needs to be alerted on rotations.
///   - On a real rotation (oldFingerprint non-empty and different from the
///     newly published one), the alert is exposed verbatim so the chat
///     screen can render [IdentityChangeBanner].
final identityChangeAlertProvider = FutureProvider.autoDispose
    .family<IdentityChangeAlert?, String>((ref, peerUserId) async {
  final session = ref.watch(e2eeSessionProvider);
  final alert = await session.checkPeerIdentityChange(peerUserId);
  if (alert == null) return null;
  if (alert.oldFingerprint.isEmpty) {
    // TOFU: pin silently; don't pester.
    await session.acknowledgePeerIdentity(peerUserId);
    return null;
  }
  return alert;
});
