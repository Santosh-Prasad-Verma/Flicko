import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable native crypto acceleration (XChaCha20-Poly1305, Argon2id, etc.)
  // for the E2EE stack. Falls back to pure-Dart automatically.
  // (Task 1.5, R14.4)
  FlutterCryptography.enable();

  // Load environment variables
  await dotenv.load(fileName: Env.fileName, isOptional: true);

  // Initialize AppConfig
  AppConfig.init();

  final missingStartupConfig = AppConfig.missingStartupConfig;
  if (missingStartupConfig.isNotEmpty) {
    runApp(ConfigErrorApp(missingKeys: missingStartupConfig));
    return;
  }
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialize Firebase before any FCM call. Wrapped in try/catch so the app
  // still launches if google-services.json hasn't been added yet.
  try {
    await Firebase.initializeApp();
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  final container = ProviderContainer();
  await container.read(translationServiceProvider.notifier).loadLocale('en');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FlickoApp(),
    ),
  );
}

class FlickoApp extends ConsumerWidget {
  const FlickoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the GoRouter instance from our provider
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Flicko',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          ThemeMode.dark, // Default to dark mode based on Discord-like request
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missingKeys});

  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flicko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missing Flicko configuration',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Launch with doppler run -- ./flutter-start.sh or pass these values with --dart-define:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(missingKeys.join('\n')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
