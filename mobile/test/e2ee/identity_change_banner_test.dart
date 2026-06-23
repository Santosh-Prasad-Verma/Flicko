import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/e2ee/application/e2ee_session.dart';
import 'package:mobile/features/e2ee/domain/identity_verification.dart';
import 'package:mobile/features/e2ee/presentation/identity_change_banner.dart';

/// Minimal stub: only the methods the banner actually calls.
/// Avoids the full E2EESession ctor (keystore + repo + WAL).
class _StubE2EESession implements E2EESession {
  String? acknowledgedFor;

  @override
  Future<void> acknowledgePeerIdentity(String peerUserId) async {
    acknowledgedFor = peerUserId;
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Widget _wrap({required Widget child, required _StubE2EESession session}) {
  return ProviderScope(
    overrides: [
      e2eeSessionProvider.overrideWithValue(session),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('IdentityChangeBanner', () {
    testWidgets('first-contact (TOFU) shows soft "new contact" tone', (tester) async {
      final stub = _StubE2EESession();
      final alert = IdentityChangeAlert(
        userId: 'bob',
        oldFingerprint: '', // <- TOFU
        newFingerprint: 'abcdef0123456789abcdef0123456789',
        hasAttestation: false,
        detectedAt: DateTime.utc(2026, 5, 29),
      );

      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(alert: alert),
      ));

      expect(find.text('New contact'), findsOneWidget);
      expect(find.text("Their security code changed"), findsNothing);
      // First-contact does NOT show the old/new fingerprint pair.
      expect(find.text('Previously'), findsNothing);
      expect(find.text('Now'), findsNothing);
    });

    testWidgets('rotation shows warning + both fingerprints', (tester) async {
      final stub = _StubE2EESession();
      final alert = IdentityChangeAlert(
        userId: 'bob',
        oldFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        newFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        hasAttestation: false,
        detectedAt: DateTime.utc(2026, 5, 29),
      );

      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(alert: alert),
      ));

      expect(find.text('Their security code changed'), findsOneWidget);
      expect(find.text('Previously'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      // Truncated fingerprint preview is rendered.
      expect(find.text('aaaaaaaaaaaaaaaa…'), findsOneWidget);
      expect(find.text('bbbbbbbbbbbbbbbb…'), findsOneWidget);
    });

    testWidgets('Trust button calls acknowledgePeerIdentity and onTrusted', (tester) async {
      final stub = _StubE2EESession();
      var trustedCalled = false;
      final alert = IdentityChangeAlert(
        userId: 'carol',
        oldFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        newFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        hasAttestation: false,
        detectedAt: DateTime.utc(2026, 5, 29),
      );

      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(
          alert: alert,
          onTrusted: () => trustedCalled = true,
        ),
      ));

      await tester.tap(find.widgetWithText(TextButton, 'Trust'));
      await tester.pumpAndSettle();

      expect(stub.acknowledgedFor, 'carol');
      expect(trustedCalled, isTrue);
    });

    testWidgets('Verify button fires onVerify (no keystore writes)', (tester) async {
      final stub = _StubE2EESession();
      var verifyCalled = false;
      final alert = IdentityChangeAlert(
        userId: 'dave',
        oldFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        newFingerprint: 'cccccccccccccccccccccccccccccccc',
        hasAttestation: false,
        detectedAt: DateTime.utc(2026, 5, 29),
      );

      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(
          alert: alert,
          onVerify: () => verifyCalled = true,
        ),
      ));

      await tester.tap(find.widgetWithText(TextButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(verifyCalled, isTrue);
      expect(stub.acknowledgedFor, isNull,
          reason: 'Verify must not silently pin the new key');
    });

    testWidgets('Dismiss icon shown only when onDismiss is provided', (tester) async {
      final stub = _StubE2EESession();
      final alert = IdentityChangeAlert(
        userId: 'erin',
        oldFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        newFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        hasAttestation: false,
        detectedAt: DateTime.utc(2026, 5, 29),
      );

      // No onDismiss provided.
      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(alert: alert),
      ));
      expect(find.byIcon(Icons.close), findsNothing);

      // Now with onDismiss.
      await tester.pumpWidget(_wrap(
        session: stub,
        child: IdentityChangeBanner(alert: alert, onDismiss: () {}),
      ));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
