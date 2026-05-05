import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: Env.fileName);

  // Initialize AppConfig
  AppConfig.init();

  // Initialize Stripe SDK
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  await Stripe.instance.applySettings();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

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
      themeMode: ThemeMode.dark, // Default to dark mode based on Discord-like request
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
