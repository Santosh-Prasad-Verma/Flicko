import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../../../data/models/auth_state.dart' as app_auth;
import 'package:mobile/data/repositories/auth_repository.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, app_auth.AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<app_auth.AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const app_auth.AuthState.initial()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen((data) async {
      final session = data.session;
      if (session != null && session.user != null) {
        try {
          final profile = await _repository.getUserProfile(session.user!.id);
          state = app_auth.AuthState.authenticated(
            authUser: session.user!,
            userProfile: profile,
          );
        } catch (e) {
          state = app_auth.AuthState.authenticated(
            authUser: session.user!,
          );
        }
      } else {
        state = const app_auth.AuthState.unauthenticated();
      }
    });

    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = app_auth.AuthState.authenticated(authUser: currentUser);
      _fetchProfile(currentUser.id);
    } else {
      state = const app_auth.AuthState.unauthenticated();
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final profile = await _repository.getUserProfile(userId);
      state.maybeWhen(
        authenticated: (user, _) {
          state = app_auth.AuthState.authenticated(
            authUser: user,
            userProfile: profile,
          );
        },
        orElse: () {},
      );
    } catch (_) {}
  }

  Future<void> signIn(String email, String password) async {
    try {
      state = const app_auth.AuthState.loading();
      await _repository.signIn(email: email, password: password);
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      state = const app_auth.AuthState.loading();
      await _repository.signUp(email: email, password: password, username: username);
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
      state = const app_auth.AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const app_auth.AuthState.loading();
      await _repository.signOut();
    } catch (e) {
      state = app_auth.AuthState.error(e.toString());
    }
  }
}
