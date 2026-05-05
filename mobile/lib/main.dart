import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/config/env.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/translation_service.dart';
import 'core/theme/theme_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Load environment variables
  await dotenv.load(fileName: Env.fileName);

  // Initialize AppConfig
  AppConfig.init();

  // Initialize Stripe SDK (only if key is provided)
  if (AppConfig.stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // Initialize Supabase
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
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
    final router = ref.watch(appRouterProvider);
    final currentThemeId = ref.watch(themeProvider);
    final currentThemeData = ref.watch(themeDataProvider);

    return MaterialApp.router(
      key: ValueKey(currentThemeId),
      title: 'Flicko',
      theme: currentThemeData,
      darkTheme: currentThemeData,
      themeMode: currentThemeData.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/branding/Flicko-for-black-background.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.05), // very subtle
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
    );
  }
}
