import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState.unauthenticated();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await dotenv.load(fileName: '.env.example', isOptional: true);
    AppConfig.init();
  });

  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame with a mocked auth notifier.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => FakeAuthNotifier()),
        ],
        child: const FlickoApp(),
      ),
    );
    await tester.pumpAndSettle();
  });
}
