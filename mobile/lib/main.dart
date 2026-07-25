import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/config/env.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/translation_service.dart';
import 'features/ludo/services/ludo_deep_links.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';
import 'package:mobile/features/voice/services/flicko_audio_handler.dart';

import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:mobile/features/sonic_music/Helpers/logging.dart';
import 'package:mobile/features/sonic_music/constants/constants.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart' as sonic_player;
import 'package:mobile/features/sonic_music/Services/audio_service.dart' as sonic_service;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: Env.fileName, isOptional: true);

  // Initialize AppConfig
  AppConfig.init();

  // Native crypto acceleration for E2EE is enabled automatically.

  final missingStartupConfig = AppConfig.missingStartupConfig;
  if (missingStartupConfig.isNotEmpty) {
    runApp(ConfigErrorApp(missingKeys: missingStartupConfig));
    return;
  }

  // If Sentry DSN is configured, wrap the app startup in Sentry
  if (AppConfig.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = 1.0; // 100% of performance traces
        options.enableLogs = true; // Searchable structured logging support
        options.addIntegration(LoggingIntegration()); // Hook standard Dart logging package
      },
      appRunner: () => _initializeApp(),
    );
  } else {
    await _initializeApp();
  }
}

Future<void> _initializeApp() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureSupabaseStorage(),
    ),
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
  await Future.wait(
    hiveBoxes.map(
      (box) => openHiveBox(
        box['name'].toString(),
        limit: box['limit'] as bool? ?? false,
      ),
    ),
  );
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

  // Initialize the Flicko audio handler — single AudioService.init for the
  // whole app. Sonic Drip's notifier (`features/voice`) discovers it via
  // GetIt and routes playback through it so lock-screen + notification +
  // Bluetooth controls all work.
  final handler = await AudioService.init(
    builder: () => FlickoAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'tech.focko.flicko.audio',
      androidNotificationChannelName: 'Flicko Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  GetIt.I.registerSingleton<FlickoAudioHandler>(handler);
  GetIt.I.registerSingleton<MyTheme>(MyTheme());

  // Sonic Music UI (BlackHole-derived) looks up AudioPlayerHandler in GetIt.
  // We register a plain AudioPlayerHandlerImpl instance — AudioService.init
  // is already consumed by FlickoAudioHandler above, so this instance only
  // drives in-app playback for the sonic_music screens. It does not get
  // OS notification / lockscreen integration; that path stays on
  // FlickoAudioHandler.
  GetIt.I.registerSingleton<sonic_player.AudioPlayerHandler>(
    sonic_service.AudioPlayerHandlerImpl(),
  );
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
    // The previous version unconditionally deleted the box file on any error
    // — that wipes user data on transient I/O issues. Try the safer
    // deleteBoxFromDisk helper inside a guard, then attempt one re-open.
    debugPrint('Hive box "$boxName" failed to open: $error. Attempting recovery.');
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (e) {
      debugPrint('deleteBoxFromDisk failed for $boxName: $e');
      // Fallback: manual file delete (kept for completeness).
      try {
        final Directory dir = await getApplicationDocumentsDirectory();
        final String dirPath = dir.path;
        File dbFile = File('$dirPath/$boxName.hive');
        File lockFile = File('$dirPath/$boxName.lock');
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          dbFile = File('$dirPath/BlackHole/$boxName.hive');
          lockFile = File('$dirPath/BlackHole/$boxName.lock');
        }
        if (await dbFile.exists()) await dbFile.delete();
        if (await lockFile.exists()) await lockFile.delete();
      } catch (_) {}
    }
    return await Hive.openBox(boxName);
  });
  if (limit && box.length > 500) {
    box.clear();
  }
}

class FlickoApp extends ConsumerStatefulWidget {
  const FlickoApp({super.key});

  @override
  ConsumerState<FlickoApp> createState() => _FlickoAppState();
}

class _FlickoAppState extends ConsumerState<FlickoApp> {
  LudoDeepLinks? _deepLinks;

  @override
  void initState() {
    super.initState();
    // Wire deep links after first frame so the router is fully built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      _deepLinks = LudoDeepLinks(router)..start();
    });
  }

  @override
  void dispose() {
    _deepLinks?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final activeTheme = ref.watch(themeDataProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Flicko',
      theme: activeTheme,
      // themeMode.light forces Flutter to always use theme: above,
      // so our themeDataProvider (dark/light/amoled) is always applied.
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
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

class SecureSupabaseStorage extends LocalStorage {
  const SecureSupabaseStorage();

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null;
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: 'supabase_session');
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: 'supabase_session');
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: 'supabase_session', value: persistSessionString);
  }
}
