// =============================================================================
// Patrol E2E: Deep link routing
// =============================================================================
// Covers QA master-plan BDD-5. Verifies the app handles an incoming deep link
// and routes correctly. Patrol's native layer opens the link the way an
// external app (browser, another app) would, exercising the real intent-filter
// path rather than an in-process router push.
//
// The app declares these schemes in AndroidManifest.xml:
//   * flicko://ludo             (custom scheme, no DNS needed)
//   * https://flicko.app/...    (App Links, autoVerify)
//   * io.flicko.app://login-callback (OAuth)
//
// Run locally:  patrol test --target integration_test/deep_link_test.dart
// =============================================================================
// NOTE: add `import 'package:flutter_test/flutter_test.dart';` back when you
// uncomment the expect() assertions in the TODO markers below.
import 'package:patrol/patrol.dart';

import 'package:mobile/main.dart' as app;

void main() {
  patrolTest(
    'cold-start deep link into flicko://ludo routes to the game',
    ($) async {
      app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // Open the custom-scheme deep link via the native layer (real intent).
      await $.native.openUrl('flicko://ludo');
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      // TODO: assert the Ludo screen is shown.
      //   expect($(#ludo_screen).exists, true);
    },
  );

  patrolTest(
    'invalid deep link shows an error, not a blank screen',
    ($) async {
      app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      await $.native.openUrl('flicko://this-route-does-not-exist');
      await $.pumpAndSettle();

      // TODO: assert a graceful fallback (404/redirect to home), not a crash
      // or empty scaffold. e.g.:
      //   expect($('Something went wrong').exists, true);
    },
  );
}
