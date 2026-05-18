import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth Service for social authentication
/// 
/// Handles OAuth 2.0 authentication with third-party providers.
/// Supports Google, Apple, and Discord login.
class OAuthService {
  // Read from --dart-define=FLICKO_GOOGLE_CLIENT_ID=... (set via Doppler, never hardcoded)
  static const _googleClientId = String.fromEnvironment('FLICKO_GOOGLE_CLIENT_ID');

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitialization;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize(
      serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
    );
  }

  /// Authenticate with Google
  /// 
  /// Returns the OAuth credentials for Supabase authentication
  Future<OAuthResponse> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final authz = await googleUser.authorizationClient.authorizationForScopes(
            const ['email', 'profile'],
          ) ??
          await googleUser.authorizationClient.authorizeScopes(
            const ['email', 'profile'],
          );
      final accessToken = authz.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return OAuthResponse(success: false, error: 'Failed to get Google tokens');
      }

      // Authenticate with Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        return OAuthResponse(success: false, error: 'Supabase authentication failed');
      }

      return OAuthResponse(
        success: true,
        user: response.user,
        provider: 'google',
      );
    } catch (e) {
      return OAuthResponse(success: false, error: 'Google sign-in failed: $e');
    }
  }

  /// Authenticate with Apple
  /// 
  /// Returns the OAuth credentials for Supabase authentication
  Future<OAuthResponse> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        return OAuthResponse(success: false, error: 'Failed to get Apple token');
      }

      // Authenticate with Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );

      if (response.user == null) {
        return OAuthResponse(success: false, error: 'Supabase authentication failed');
      }

      return OAuthResponse(
        success: true,
        user: response.user,
        provider: 'apple',
      );
    } catch (e) {
      return OAuthResponse(success: false, error: 'Apple sign-in failed: $e');
    }
  }

  /// Authenticate with Discord (placeholder for future implementation)
  /// 
  /// Note: Discord OAuth requires custom implementation
  /// This is a placeholder for future Discord integration
  Future<OAuthResponse> signInWithDiscord() async {
    try {
      // Discord OAuth requires custom implementation
      // This would involve opening a web view for Discord OAuth flow
      // For now, return an error indicating it's not implemented
      return OAuthResponse(
        success: false,
        error: 'Discord sign-in is not yet implemented',
      );
    } catch (e) {
      return OAuthResponse(success: false, error: 'Discord sign-in failed: $e');
    }
  }

  /// Sign out from all OAuth providers
  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
      // Apple doesn't have a sign-out method, as it's handled by the OS
    } catch (e) {
      // Ignore sign-out errors
    }
  }

  /// Check if a provider is available on the device
  Future<bool> isProviderAvailable(String provider) async {
    switch (provider.toLowerCase()) {
      case 'google':
        await _ensureGoogleInitialized();
        return _googleSignIn.supportsAuthenticate();
      case 'apple':
        return await SignInWithApple.isAvailable();
      case 'discord':
        return false; // Not yet implemented
      default:
        return false;
    }
  }
}

/// OAuth Response Model
class OAuthResponse {
  final bool success;
  final User? user;
  final String? provider;
  final String? error;

  OAuthResponse({
    required this.success,
    this.user,
    this.provider,
    this.error,
  });
}
