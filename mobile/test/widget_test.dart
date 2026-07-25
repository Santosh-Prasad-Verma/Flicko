import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
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
    SharedPreferences.setMockInitialValues({});
    await dotenv.load(fileName: '.env.example', isOptional: true);
    AppConfig.init();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fake-anon-key',
    );
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
  });
}
