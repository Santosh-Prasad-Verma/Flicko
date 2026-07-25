// =============================================================================
// Patrol E2E: App launch smoke test
// =============================================================================
// The cheapest possible on-device signal: does the app boot to first frame
// without crashing on a real device? Runs first in CI so a broken build fails
// fast before the heavier permission/deep-link suites run.
//
// Run locally:  patrol test --target integration_test/app_launch_test.dart
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:mobile/main.dart' as app;

void main() {
  patrolTest(
    'app boots to first frame without crashing',
    ($) async {
      // Launch the real app entrypoint.
      app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // We reached a rendered frame. Assert *something* is on screen rather
      // than a specific widget, so this stays stable as the UI evolves.
      expect($(MaterialApp).exists, true, reason: 'MaterialApp should mount');
    },
  );
}
