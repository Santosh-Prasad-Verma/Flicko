import 'dart:async';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class ClerkAuthService {
  static ClerkAuthState? _currentAuthState;
  static final _appLinks = AppLinks();

  /// Broadcast controller so both logging and Clerk SDK receive deep link events.
  /// app_links v7 uriLinkStream may be single-subscription, so we must relay events.
  static final _deepLinkController = StreamController<Uri>.broadcast();

  static ClerkAuthState? get currentAuthState => _currentAuthState;

  /// The broadcast stream that Clerk SDK should listen to for deep links.
  static Stream<Uri> get deepLinkStream => _deepLinkController.stream;

  static void _setupDeepLinkRelay() {
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Incoming Deep Link: $uri');
      debugPrint('Deep Link query params: ${uri.queryParameters}');
      _deepLinkController.add(uri);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });
  }

  static Future<ClerkAuthState> getAuthState() async {
    if (_currentAuthState != null) return _currentAuthState!;

    _setupDeepLinkRelay();

    try {
      debugPrint('Initializing Clerk Auth with Publishable Key: ${AppConfig.clerkPublishableKey}');
      
      // Get the initial link that might have opened the app
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('App opened with initial link: $initialUri');
        debugPrint('Initial link query params: ${initialUri.queryParameters}');
        // Forward the initial link to Clerk as well
        _deepLinkController.add(initialUri);
      }

      _currentAuthState = await ClerkAuthState.create(
        config: ClerkAuthConfig(
          publishableKey: AppConfig.clerkPublishableKey,
          deepLinkStream: deepLinkStream,
          httpConnectionTimeout: const Duration(seconds: 30),
        ),
      ).timeout(const Duration(seconds: 35), onTimeout: () {
        debugPrint('Clerk initial state creation timed out after 35s');
        throw TimeoutException('Clerk initialization timed out');
      });
      debugPrint('Clerk Auth initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Clerk Auth: $e');
      // Create a dummy config if initialization fails so the app can at least start
      _currentAuthState = await ClerkAuthState.create(
        config: ClerkAuthConfig(
          publishableKey: AppConfig.clerkPublishableKey,
          deepLinkStream: deepLinkStream,
          httpConnectionTimeout: const Duration(seconds: 30),
        ),
      );
    }

    return _currentAuthState!;
  }
}
