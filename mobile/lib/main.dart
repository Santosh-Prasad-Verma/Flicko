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
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:mobile/features/sonic_music/Helpers/logging.dart';
import 'package:mobile/features/sonic_music/providers/audio_service_provider.dart';
import 'package:mobile/features/sonic_music/constants/constants.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';

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

  // BlackHole initialization
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await Hive.initFlutter('BlackHole/Database');
  } else if (Platform.isIOS) {
    await Hive.initFlutter('Database');
  } else {
    await Hive.initFlutter();
  }
  for (final box in hiveBoxes) {
    await openHiveBox(
      box['name'].toString(),
      limit: box['limit'] as bool? ?? false,
    );
  }
  await startBlackHoleService();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FlickoApp(),
    ),
  );
}

Future<void> startBlackHoleService() async {
  await initializeLogging();
  MetadataGod.initialize();
  final audioHandlerHelper = AudioHandlerHelper();
  final AudioPlayerHandler audioHandler =
      await audioHandlerHelper.getAudioHandler();
  GetIt.I.registerSingleton<AudioPlayerHandler>(audioHandler);
  GetIt.I.registerSingleton<MyTheme>(MyTheme());
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String dirPath = dir.path;
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dbFile = File('$dirPath/BlackHole/$boxName.hive');
      lockFile = File('$dirPath/BlackHole/$boxName.lock');
    }
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox(boxName);
    throw 'Failed to open $boxName Box\nError: $error';
  });
  if (limit && box.length > 500) {
    box.clear();
  }
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
