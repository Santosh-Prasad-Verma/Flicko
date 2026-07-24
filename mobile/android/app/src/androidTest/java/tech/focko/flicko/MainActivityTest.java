package tech.focko.flicko;

import androidx.test.platform.app.InstrumentationRegistry;
import pl.leancode.patrol.PatrolJUnitRunner;
import org.junit.runner.RunWith;
import org.junit.Test;
import dev.flutter.plugins.integration_test.FlutterDeviceScreenshot;

// Patrol test-bundle entrypoint. Firebase Test Lab / `patrol test` discovers
// this class via the PatrolJUnitRunner declared in build.gradle.kts. Do not add
// test logic here — the actual tests live in mobile/integration_test/*.dart.
// This file is generated-style boilerplate; regenerate with `patrol build` if
// the Patrol version changes its runner contract.
@RunWith(PatrolJUnitRunner.class)
public class MainActivityTest {
    @Test
    public void runDartTests() {
        // PatrolJUnitRunner bootstraps the Dart integration_test bundle.
        // The body is intentionally empty.
    }
}
