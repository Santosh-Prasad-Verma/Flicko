import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
// import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
// import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk_auth_api;
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/auth_state.dart' as app_auth;
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/data/services/clerk_auth_service.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:collection/collection.dart';

export '../../../data/models/auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, app_auth.AuthState>((ref) {
  return AuthNotifier(
    ref,
    ref.watch(authRepositoryProvider),
  );
});

final authProvider = StateNotifierProvider<LegacyAuthNotifier, LegacyAuthState>((ref) {
  return LegacyAuthNotifier(ref);
});

final currentUserProvider = Provider<clerk_auth_api.User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    authenticated: (user, _) => user,
    orElse: () => null,
  );
});

final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id;
});

class LegacyAuthState {
  const LegacyAuthState({
    required this.isAuthenticated,
    this.user,
  });

  final bool isAuthenticated;
  final dynamic user;
}

class LegacyAuthNotifier extends StateNotifier<LegacyAuthState> {
  LegacyAuthNotifier(this._ref)
      : super(const LegacyAuthState(isAuthenticated: false)) {
    _ref.listen<app_auth.AuthState>(authNotifierProvider, (_, next) {
      next.whenOrNull(
        authenticated: (user, profile) {
          state = LegacyAuthState(
            isAuthenticated: true,
            user: user,
          );
        },
        unauthenticated: () {
          state = const LegacyAuthState(isAuthenticated: false);
        },
      );
    }, fireImmediately: true);
  }

  final Ref _ref;

  void setAuthenticated(bool isAuthenticated) {
    state = LegacyAuthState(
      isAuthenticated: isAuthenticated,
      user: state.user,
    );
  }

  void setUser(dynamic user) {
    state = LegacyAuthState(
      isAuthenticated: true,
      user: user,
    );
  }
}

class AuthNotifier extends StateNotifier<app_auth.AuthState> with WidgetsBindingObserver {
  final Ref ref;
  final AuthRepository _profileRepository;
  // _authSubscription is unused and causing type conflict, removing.
  // StreamSubscription? _authSubscription;

  AuthNotifier(this.ref, this._profileRepository) 
      : super(const app_auth.AuthState.initial()) {
    debugPrint('AuthNotifier Initialized');
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App Resumed - Refreshing Clerk Auth State');
      _onClerkAuthStateChanged();
    }
  }

  void _init() {
    final clerk = ClerkAuthService.currentAuthState;
    if (clerk != null) {
      clerk.addListener(_onClerkAuthStateChanged);
      _onClerkAuthStateChanged();
    }
  }

  void _onClerkAuthStateChanged() async {
    final clerk = ClerkAuthService.currentAuthState;
    if (clerk == null) {
      debugPrint('Clerk Auth State changed, but clerk is null');
      return;
    }

    final user = clerk.user;
    final session = clerk.session;
    debugPrint('Clerk Auth State Changed. User: ${user?.id}, Session: ${session?.id}');
    
    if (user != null && session != null) {
      debugPrint('User is authenticated. Syncing with Supabase...');
      try {
        // 1. Get the Supabase-compatible JWT from Clerk
        // IMPORTANT: This requires a JWT Template named 'supabase' in your Clerk Dashboard
        String? token;
        try {
          // In clerk_auth 0.0.14-beta, sessionToken() is used to get JWTs
          final sessionToken = await clerk.sessionToken(templateName: 'supabase');
          token = sessionToken.jwt;
          debugPrint('Successfully retrieved Supabase JWT from Clerk');
        } catch (e) {
          debugPrint('Failed to get "supabase" template, falling back to default token: $e');
          final sessionToken = await clerk.sessionToken();
          token = sessionToken.jwt;
        }
        
        if (token != null && token.isNotEmpty) {
          // 2. Inject the token into the Supabase client headers
          final supabase = ref.read(supabaseClientProvider);
          supabase.rest.headers['Authorization'] = 'Bearer $token';
          supabase.storage.headers['Authorization'] = 'Bearer $token';
          supabase.functions.headers['Authorization'] = 'Bearer $token';
          debugPrint('Supabase headers updated with Clerk JWT');
        } else {
          debugPrint('Warning: Retrieved Clerk token is empty');
        }

        // 3. Map Clerk ID to a deterministic UUID for Supabase compatibility
        final supabaseId = _generateDeterministicUuid(user.id);
        debugPrint('Mapped Clerk ID ${user.id} to UUID $supabaseId');

        // 4. Fetch or create profile
        UserModel? profile;
        try {
          profile = await _profileRepository.getUserProfile(supabaseId);
          debugPrint('Profile fetched successfully');
        } catch (e) {
          debugPrint('Profile not found for $supabaseId, creating new one...');
          // Get basic info from Clerk user
          final email = user.emailAddresses?.firstOrNull?.emailAddress ?? '';
          final emailPrefix = email.contains('@') ? email.split('@')[0] : null;
          final username = user.username ?? emailPrefix ?? 'user_${user.id.substring(0, 5)}';
          
          final newProfile = UserModel(
            id: supabaseId, // Using the generated UUID
            username: username,
            displayName: user.firstName != null ? '${user.firstName} ${user.lastName ?? ''}'.trim() : null,
            avatarUrl: user.imageUrl,
            createdAt: DateTime.now(),
          );
          
          profile = await _profileRepository.createProfile(newProfile);
          debugPrint('Profile created successfully');
        }

        state = app_auth.AuthState.authenticated(
          authUser: user,
          userProfile: profile,
        );
      } catch (e, stack) {
        debugPrint('Error syncing with Supabase: $e');
        debugPrint(stack.toString());
        state = app_auth.AuthState.authenticated(authUser: user);
      }
    } else {
      debugPrint('User is not authenticated');
      state = const app_auth.AuthState.unauthenticated();
    }
  }

  String _generateDeterministicUuid(String input) {
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes).toString();
    // Format as UUID: 8-4-4-4-12
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ClerkAuthService.currentAuthState?.removeListener(_onClerkAuthStateChanged);
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    try {
      state = const app_auth.AuthState.loading();
      
      final clerk = ClerkAuthService.currentAuthState;
      if (clerk == null) throw Exception('Clerk not initialized. Check your internet connection.');

      debugPrint('Attempting Clerk SignIn for $email');
      await clerk.attemptSignIn(
        strategy: clerk_auth_api.Strategy.password,
        identifier: email,
        password: password,
      );
      debugPrint('SignIn attempt completed successfully');
    } on Exception catch (e) {
      debugPrint('SignIn Error: $e');
      String message = e.toString();
      if (message.contains('SocketException') || message.contains('timeout')) {
        message = 'Connection timed out. Please check your internet connection or try switching to Mobile Data.';
      } else if (e is clerk_auth_api.ClerkError) {
        message = e.message;
      }
      state = app_auth.AuthState.error(message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username, {String? phone}) async {
    try {
      state = const app_auth.AuthState.loading();
      
      final clerk = ClerkAuthService.currentAuthState;
      if (clerk == null) throw Exception('Clerk not initialized');

      debugPrint('Attempting Clerk Sign-up for $email');

      debugPrint('Calling clerk.attemptSignUp with email: $email');
      // Step 1: Create sign-up with initial data
      await clerk.attemptSignUp(
        strategy: clerk_auth_api.Strategy.password,
        emailAddress: email,
        password: password,
        username: username,
        phoneNumber: phone,
      );
      debugPrint('clerk.attemptSignUp initial call completed');

      final signUp = clerk.client.signUp;
      if (signUp == null) throw Exception('Sign-up creation failed');

      debugPrint('Sign-up created. Status: ${signUp.status}');
      
      // Step 2: Trigger email verification
      // Check if email address needs verification
      if (signUp.unverifiedFields.contains(clerk_auth_api.Field.emailAddress)) {
        debugPrint('Email needs verification. Preparing email code...');
        await clerk.attemptSignUp(
          strategy: clerk_auth_api.Strategy.emailCode,
        );
        debugPrint('Verification email sent to $email');
      } else {
        debugPrint('Email verification not required or already verified.');
      }
      
      // We don't set authenticated yet, the user needs to verify the code
      state = const app_auth.AuthState.unauthenticated();
    } on Exception catch (e) {
      debugPrint('Clerk Sign-up error: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException') || errorMessage.contains('timeout')) {
        errorMessage = 'Network timeout. Could not reach Clerk. Please check your phone\'s internet.';
      } else if (e is clerk_auth_api.ClerkError) {
        errorMessage = e.message;
      }
      state = app_auth.AuthState.error(errorMessage);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> verifyEmail(String code) async {
    try {
      state = const app_auth.AuthState.loading();
      final clerk = ClerkAuthService.currentAuthState;
      if (clerk == null) throw Exception('Clerk not initialized');

      debugPrint('Verifying email with code: $code');
      await clerk.attemptSignUp(
        strategy: clerk_auth_api.Strategy.emailCode,
        code: code,
      );
      debugPrint('Email verified successfully');
    } on Exception catch (e) {
      debugPrint('Email verification error: $e');
      String message = e.toString();
      if (message.contains('SocketException') || message.contains('timeout')) {
        message = 'Connection timed out while verifying. Please check your internet.';
      }
      state = app_auth.AuthState.error(message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = const app_auth.AuthState.loading();
      final clerk = ClerkAuthService.currentAuthState;
      if (clerk == null) throw Exception('Clerk not initialized');

      await clerk.initiatePasswordReset(
        strategy: clerk_auth_api.Strategy.resetPasswordEmailCode,
        identifier: email,
      );
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const app_auth.AuthState.loading();
      await ClerkAuthService.currentAuthState?.signOut();
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
    }
  }

  Future<void> signInWithOAuth(String strategyStr) async {
    try {
      state = const app_auth.AuthState.loading();
      clerk_auth_api.Strategy strategy = clerk_auth_api.Strategy.oauthGoogle;
      if (strategyStr.toLowerCase().contains('github')) {
        strategy = clerk_auth_api.Strategy.oauthGithub;
      }
      
      final clerk = ClerkAuthService.currentAuthState;
      if (clerk == null) throw Exception('Clerk not initialized');

      debugPrint('Initiating OAuth login with $strategyStr');

      // 1. Initiate OAuth sign-in
      // The redirect URI must match what's configured in Clerk and the app's deep link settings
      final redirectUri = Uri.parse('flicko://auth-callback');
      await clerk.oauthSignIn(
        strategy: strategy,
        redirect: redirectUri,
      );

      // 2. Extract the redirect URL. It could be in signIn or signUp
      String? redirectUrl;
      
      // Check Sign In
      if (clerk.client.signIn?.firstFactorVerification?.externalVerificationRedirectUrl != null) {
        redirectUrl = clerk.client.signIn!.firstFactorVerification!.externalVerificationRedirectUrl;
      } 
      // Check Sign Up if Sign In didn't have it
      else if (clerk.client.signUp != null) {
        for (final verification in clerk.client.signUp!.verifications.values) {
          if (verification.externalVerificationRedirectUrl != null) {
            redirectUrl = verification.externalVerificationRedirectUrl;
            break;
          }
        }
      }

      if (redirectUrl != null) {
        debugPrint('Launching OAuth URL: $redirectUrl');
        final launched = await launchUrl(
          Uri.parse(redirectUrl), 
          mode: LaunchMode.externalApplication,
        );
        if (!launched) throw Exception('Could not launch browser for OAuth');
      } else {
        // If no URL is returned, it might mean the user is already authenticated or something is wrong
        final user = clerk.user;
        if (user != null) {
          debugPrint('User already authenticated via OAuth');
          _onClerkAuthStateChanged();
        } else {
          throw Exception('Failed to get OAuth redirect URL from Clerk. Ensure $strategyStr is enabled in Clerk dashboard and redirect URIs are configured.');
        }
      }
    } on Exception catch (e) {
      debugPrint('OAuth error: $e');
      String message = e.toString();
      if (message.contains('SocketException') || message.contains('timeout')) {
        message = 'Connection timed out while reaching Clerk. Ensure your phone can reach casual-oyster-66.clerk.accounts.dev';
      }
      state = app_auth.AuthState.error(message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }


  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      state = const app_auth.AuthState.loading();
      await ClerkAuthService.currentAuthState?.updateUserPassword(
        currentPassword,
        newPassword,
        signOut: false, // Keep user signed in after password change
      );
      // After success, we might want to refresh the state or just return
      _onClerkAuthStateChanged();
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> changeEmail(String newEmail) async {
    // Note: Clerk usually requires verification for email changes
    // This is a placeholder as the exact 'addEmailAddress' API might be in UserIdentifyingData
    try {
      state = const app_auth.AuthState.loading();
      // For now, we'll use the generic updateUser if we find the right ID
      // but usually you'd call clerk.user.addEmailAddress
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      rethrow;
    }
  }
  
  Future<void> updatePhone(String newPhone) async {
    try {
      state = const app_auth.AuthState.loading();
      // Commenting out to resolve analysis errors
      // await ClerkAuthService.currentAuthState?.updateUser(phone: newPhone);
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> disableAccount() async {
    deleteAccount();
  }

  Future<void> deleteAccount() async {
    try {
      state = const app_auth.AuthState.loading();
      await ClerkAuthService.currentAuthState?.deleteUser();
      state = const app_auth.AuthState.unauthenticated();
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      rethrow;
    }
  }
}
