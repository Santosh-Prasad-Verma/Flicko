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
import 'core/theme/app_theme.dart';
import 'core/services/translation_service.dart';
import 'features/notifications/application/notification_service.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'data/services/clerk_auth_service.dart';

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
  
  // Initialize Notification Service
  await container.read(notificationServiceProvider).init();

  // Initialize Clerk
  final ClerkAuthState clerkAuthState = await ClerkAuthService.getAuthState();

  Widget app = const FlickoApp();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ClerkAuth(
        authState: clerkAuthState,
        child: app,
      ),
    ),
  );
}

class FlickoApp extends ConsumerWidget {
  const FlickoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Flicko',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

