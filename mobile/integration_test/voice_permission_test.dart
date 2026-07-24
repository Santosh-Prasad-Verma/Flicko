// =============================================================================
// Patrol E2E: Microphone permission flow for voice channels
// =============================================================================
// This is the flagship reason to use Patrol over vanilla integration_test:
// it can tap the NATIVE OS permission dialog. Joining voice (LiveKit) triggers
// the system mic prompt, which lives outside the Flutter view hierarchy and is
// invisible to a normal WidgetTester.
//
// Covers QA master-plan BDD-3 (voice hardware / permission handling).
//
// NOTE: selectors below (keys/text) are placeholders describing intent. Wire
// them to real widget keys before enabling in CI — see the TODO markers.
//
// Run locally:  patrol test --target integration_test/voice_permission_test.dart
// =============================================================================
// NOTE: add `import 'package:flutter_test/flutter_test.dart';` back when you
// uncomment the expect() assertions in the TODO markers below.
import 'package:patrol/patrol.dart';

import 'package:mobile/main.dart' as app;

void main() {
  patrolTest(
    'granting mic permission lets the user join a voice channel',
    ($) async {
      app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // TODO: navigate to a voice channel and tap "Join Voice".
      // Replace with the real key once added to the join button, e.g.:
      //   await $(const Key('join_voice_button')).tap();
      //
      // await $(#join_voice_button).tap();

      // The native mic permission dialog is handled OUTSIDE Flutter.
      // Patrol drives it via the platform automator:
      if (await $.native.isPermissionDialogVisible()) {
        await $.native.grantPermissionWhenInUse();
      }

      await $.pumpAndSettle();

      // TODO: assert connected state (e.g. participant tile / speaking indicator)
      //   expect($(#voice_connected_indicator).exists, true);
    },
  );

  patrolTest(
    'denying mic permission shows a graceful in-app explanation, no crash',
    ($) async {
      app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // TODO: tap "Join Voice" (see above).

      if (await $.native.isPermissionDialogVisible()) {
        await $.native.denyPermission();
      }

      await $.pumpAndSettle();

      // App must NOT hang in a "connecting" state or crash. Assert the
      // rationale UI appears instead.
      // TODO:
      //   expect($('Microphone access needed').exists, true);
      //   expect($('Open Settings').exists, true);
    },
  );
}
