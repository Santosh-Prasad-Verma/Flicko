import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// OAuth Service for social authentication.
class AppOAuthService {
  AppOAuthService();

  Future<AppOAuthResponse> signInWithGoogle() async {
    return AppOAuthResponse(success: true, provider: 'google', pending: true);
  }

  Future<AppOAuthResponse> signInWithGitHub() async {
    return AppOAuthResponse(success: true, provider: 'github', pending: true);
  }

  Future<AppOAuthResponse> signInWithDiscord() async {
    return AppOAuthResponse(success: true, provider: 'discord', pending: true);
  }

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

      return AppOAuthResponse(
        success: true,
        provider: 'apple',
      );
    } catch (e) {
      return AppOAuthResponse(success: false, error: 'Apple sign-in failed: $e');
    }
  }

  Future<void> signOut() async {}

  Future<bool> isProviderAvailable(String provider) async {
    switch (provider.toLowerCase()) {
      case 'apple':
        return SignInWithApple.isAvailable();
      case 'google':
      case 'github':
      case 'discord':
        return true;
      default:
        return false;
    }
  }
}

class AppOAuthResponse {
  final bool success;
  final String? provider;
  final String? error;
  final bool pending;
  final dynamic user;

  AppOAuthResponse({
    required this.success,
    this.provider,
    this.error,
    this.pending = false,
    this.user,
  });
}
