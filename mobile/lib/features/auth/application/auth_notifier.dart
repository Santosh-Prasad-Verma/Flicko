import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../data/models/auth_state.dart' as app_auth;
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/clients/supabase_client.dart';

export '../../../data/models/auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, app_auth.AuthState>((ref) {
  return AuthNotifier(
    ref,
    ref.watch(authRepositoryProvider),
  );
});



final currentUserProvider = Provider<supabase.User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    authenticated: (user, _) => user as supabase.User?,
    orElse: () => null,
  );
});

final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id;
});



class AuthNotifier extends StateNotifier<app_auth.AuthState> with WidgetsBindingObserver {
  final Ref ref;
  final AuthRepository _profileRepository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthNotifier(this.ref, this._profileRepository) 
      : super(const app_auth.AuthState.initial()) {
    debugPrint('AuthNotifier Initialized (Supabase)');
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  bool _isSyncing = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Supabase handles persistence and refresh automatically, but we can manually refresh if needed
    if (state == AppLifecycleState.resumed) {
      debugPrint('App Resumed - Supabase Auth State Check');
      _refreshSession();
    }
  }

  void _init() {
    final supabaseClient = ref.read(supabaseClientProvider);
    
    // Listen to auth state changes
    _authSubscription = supabaseClient.auth.onAuthStateChange.listen((data) {
      _onAuthStateChanged(data.event, data.session);
    });

    // Check initial session
    final initialSession = supabaseClient.auth.currentSession;
    if (initialSession != null) {
      _onAuthStateChanged(supabase.AuthChangeEvent.signedIn, initialSession);
    } else {
      state = const app_auth.AuthState.unauthenticated();
    }
  }

  Future<void> _refreshSession() async {
    try {
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.refreshSession();
    } catch (e) {
      debugPrint('Error refreshing Supabase session: $e');
    }
  }

  void _onAuthStateChanged(supabase.AuthChangeEvent event, supabase.Session? session) async {
    if (_isSyncing) return;

    final user = session?.user;
    debugPrint('Supabase Auth Event: $event, User: ${user?.id}');

    if (user != null) {
      _isSyncing = true;
      try {
        UserModel? profile;
        try {
          profile = await _profileRepository.getUserProfile(user.id);
          debugPrint('Supabase Profile fetched successfully');
        } catch (e) {
          debugPrint('Profile not found for ${user.id}, creating if metadata exists...');
          
          final username = user.userMetadata?['username'] as String? ?? 
                          user.email?.split('@')[0] ?? 
                          'user_${user.id.substring(0, 5)}';
          
          final newProfile = UserModel(
            id: user.id,
            username: username,
            displayName: user.userMetadata?['full_name'] as String?,
            avatarUrl: user.userMetadata?['avatar_url'] as String?,
            createdAt: DateTime.now(),
          );
          
          try {
            profile = await _profileRepository.createProfile(newProfile);
            debugPrint('Supabase Profile created successfully');
          } catch (e2) {
            debugPrint('Failed to create profile: $e2');
          }
        }

        state = app_auth.AuthState.authenticated(
          authUser: user,
          userProfile: profile,
        );
      } catch (e) {
        debugPrint('Error syncing profile: $e');
        state = app_auth.AuthState.authenticated(authUser: user);
      } finally {
        _isSyncing = false;
      }
    } else {
      if (event == supabase.AuthChangeEvent.signedOut || session == null) {
        state = const app_auth.AuthState.unauthenticated();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> reloadProfile() async {
    await state.maybeWhen(
      authenticated: (user, _) async {
        try {
          final profile = await _profileRepository.getUserProfile(user.id);
          state = app_auth.AuthState.authenticated(
            authUser: user,
            userProfile: profile,
          );
        } catch (e) {
          debugPrint('Error reloading profile in notifier: $e');
        }
      },
      orElse: () async {},
    );
  }


  Future<void> signIn(String identifier, String password) async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);

      String email = identifier;

      // Handle Username Login: If no '@', lookup email by username
      if (!identifier.contains('@')) {
        debugPrint('Username login detected for: $identifier');
        try {
          final res = await supabaseClient
              .from('profiles')
              .select('id')
              .eq('username', identifier)
              .maybeSingle();
          
          if (res == null) {
            throw Exception('User not found with username: $identifier');
          }

          // In Supabase, if we don't have the email in the profiles table, 
          // we might need to fetch it differently or ensure it's synced.
          // Assuming for now we use the ID to sign in if possible, 
          // but Supabase signInWithPassword usually needs email.
          // Let's check if we have the email in the profiles table.
          final fullProfile = await supabaseClient
              .from('profiles')
              .select('email') // You might need to add this column to profiles
              .eq('username', identifier)
              .maybeSingle();
          
          if (fullProfile != null && fullProfile['email'] != null) {
            email = fullProfile['email'];
          } else {
            // Fallback: If your schema doesn't store email in profiles, 
            // you might need an Edge Function to resolve this.
            throw Exception('Could not resolve email for username: $identifier. Please use email.');
          }
        } catch (e) {
          debugPrint('Username lookup failed: $e');
          state = app_auth.AuthState.error('User not found');
          state = const app_auth.AuthState.unauthenticated();
          rethrow;
        }
      }

      debugPrint('Attempting Supabase SignIn for $email');
      await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on supabase.AuthException catch (e) {
      state = app_auth.AuthState.error(e.message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String passwordConfirmation, String username, {String? phone}) async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);

      debugPrint('Attempting Supabase Sign-up for $email');

      final res = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'phone': phone,
        },
      );

      if (res.user != null) {
        debugPrint('Sign-up success. User: ${res.user!.id}');
        // If email confirmation is disabled, the user is signed in immediately.
        // Otherwise, we might need to show verification screen.
        if (res.session == null) {
          state = app_auth.AuthState.needsVerification(
            email: email,
            phone: phone,
            isPhone: false,
          );
        }
      }
    } on supabase.AuthException catch (e) {
      state = app_auth.AuthState.error(e.message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> verifyEmail(String email, String token) async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);

      await supabaseClient.auth.verifyOTP(
        type: supabase.OtpType.signup,
        token: token,
        email: email,
      );
    } on supabase.AuthException catch (e) {
      state = app_auth.AuthState.error(e.message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> verifyPhone(String phone, String token) async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);

      await supabaseClient.auth.verifyOTP(
        type: supabase.OtpType.sms,
        token: token,
        phone: phone,
      );
    } on supabase.AuthException catch (e) {
      state = app_auth.AuthState.error(e.message);
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.signOut();
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
    }
  }

  Future<void> signInWithOAuth(String providerStr) async {
    try {
      state = const app_auth.AuthState.loading();
      final supabaseClient = ref.read(supabaseClientProvider);
      
      supabase.OAuthProvider provider = supabase.OAuthProvider.google;
      if (providerStr.toLowerCase().contains('github')) {
        provider = supabase.OAuthProvider.github;
      }

      await supabaseClient.auth.signInWithOAuth(
        provider,
        redirectTo: 'flicko://auth-callback',
      );
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  Future<void> updatePhone(String phone) async {
    try {
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.updateUser(supabase.UserAttributes(phone: phone));
    } catch (e) {
      debugPrint('Update phone error: $e');
      rethrow;
    }
  }

  Future<void> disableAccount() async {
    await signOut();
  }

  Future<void> deleteAccount() async {
    await signOut();
  }

  Future<void> changeEmail(String newEmail) async {
    try {
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.updateUser(supabase.UserAttributes(email: newEmail));
    } catch (e) {
      debugPrint('Change email error: $e');
      rethrow;
    }
  }

  Future<void> changePassword(String newPassword) async {
    try {
      final supabaseClient = ref.read(supabaseClientProvider);
      await supabaseClient.auth.updateUser(supabase.UserAttributes(password: newPassword));
    } catch (e) {
      debugPrint('Change password error: $e');
      rethrow;
    }
  }
}
