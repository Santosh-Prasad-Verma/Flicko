import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth Service for social authentication.
///
/// Uses Supabase's built-in OAuth flow (`signInWithOAuth`) for Google,
/// GitHub, Discord, etc. This launches the system browser, the user
/// completes the consent screen, and Supabase calls our deep-link
/// callback with a session.
///
/// Apple uses the native Sign-In-with-Apple SDK because Apple requires it
/// on iOS for App Store approval. On other platforms Apple sign-in is
/// disabled.
///
/// This implementation deliberately avoids `google_sign_in` because its
/// 7.x API breaks every minor release; Supabase's OAuth route is stable.
class AppOAuthService {
  AppOAuthService();

  /// Authenticate with Google via Supabase OAuth redirect.
  Future<AppOAuthResponse> signInWithGoogle() => _signInWithProvider(
        OAuthProvider.google,
        providerName: 'google',
      );

  /// Authenticate with GitHub via Supabase OAuth redirect.
  Future<AppOAuthResponse> signInWithGitHub() => _signInWithProvider(
        OAuthProvider.github,
        providerName: 'github',
      );

  /// Authenticate with Discord via Supabase OAuth redirect.
  Future<AppOAuthResponse> signInWithDiscord() => _signInWithProvider(
        OAuthProvider.discord,
        providerName: 'discord',
      );

  /// Authenticate with Apple via the native SDK + Supabase exchange.
  Future<AppOAuthResponse> signInWithApple() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        return AppOAuthResponse(
          success: false,
          error: 'Apple Sign-In is only available on iOS / macOS.',
        );
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return AppOAuthResponse(success: false, error: 'No Apple identity token');
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user == null) {
        return AppOAuthResponse(success: false, error: 'Apple sign-in rejected by Supabase');
      }
      return AppOAuthResponse(
        success: true,
        user: response.user,
        provider: 'apple',
      );
    } catch (e) {
      return AppOAuthResponse(success: false, error: 'Apple sign-in failed: $e');
    }
  }

  /// Sign out from Supabase. Native OS handles per-provider logout.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Ignore — caller already wants to be signed out.
    }
  }

  /// Whether the device supports the named provider.
  Future<bool> isProviderAvailable(String provider) async {
    switch (provider.toLowerCase()) {
      case 'apple':
        return SignInWithApple.isAvailable();
      case 'google':
      case 'github':
      case 'discord':
        return true; // browser-based; always available
      default:
        return false;
    }
  }

  // ── internals ────────────────────────────────────────────────────────────

  /// Drives `signInWithOAuth` and returns once the deep-link callback
  /// has populated the auth session. We don't block on the redirect here
  /// because Supabase emits an `AuthChangeEvent.signedIn` once the user
  /// returns; the AuthNotifier listener picks it up.
  Future<AppOAuthResponse> _signInWithProvider(
    OAuthProvider provider, {
    required String providerName,
  }) async {
    try {
      final ok = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.flicko.app://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!ok) {
        return AppOAuthResponse(
          success: false,
          error: 'Could not launch $providerName sign-in.',
        );
      }
      // The actual session arrives via the deep-link handler; surface a
      // pending result so the caller knows to wait for AuthNotifier to
      // flip the state. AuthNotifier already listens for that event.
      return AppOAuthResponse(
        success: true,
        provider: providerName,
        pending: true,
      );
    } catch (e) {
      return AppOAuthResponse(
        success: false,
        error: '$providerName sign-in failed: $e',
      );
    }
  }
}

/// Response model for [AppOAuthService].
class AppOAuthResponse {
  /// True when the redirect was launched (or Apple credential captured)
  /// without error.
  final bool success;

  /// Populated when the provider returns a session synchronously (Apple).
  /// For browser-redirect flows (`pending == true`) the session arrives
  /// asynchronously via Supabase's auth state stream.
  final User? user;

  /// Lower-case provider name (`google`, `apple`, `github`, `discord`).
  final String? provider;

  /// User-visible error string when `success == false`.
  final String? error;

  /// True for redirect-based flows that have launched but not yet returned.
  final bool pending;

  AppOAuthResponse({
    required this.success,
    this.user,
    this.provider,
    this.error,
    this.pending = false,
  });
}
