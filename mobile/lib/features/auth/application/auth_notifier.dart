import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../../../data/models/auth_state.dart';
import 'package:mobile/data/repositories/auth_repository.dart';

export 'package:mobile/data/models/auth_state.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    _init();
    return const AuthState.initial();
  }

  void _init() {
    _repository.authStateChanges.listen((data) async {
      final session = data.session;
      if (session != null && session.user != null) {
        try {
          final profile = await _repository.getUserProfile(session.user!.id);
          state = AuthState.authenticated(
            authUser: session.user!,
            userProfile: profile,
          );
        } catch (e) {
          state = AuthState.authenticated(
            authUser: session.user!,
          );
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    });

    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = AuthState.authenticated(authUser: currentUser);
      _fetchProfile(currentUser.id);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final profile = await _repository.getUserProfile(userId);
      state.maybeWhen(
        authenticated: (user, _) {
          state = AuthState.authenticated(
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
      state = const AuthState.loading();
      await _repository.signIn(email: email, password: password);
    } catch (e) {
      state = AuthState.error(e.toString());
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      state = const AuthState.loading();
      await _repository.signUp(email: email, password: password, username: username);
    } catch (e) {
      state = AuthState.error(e.toString());
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const AuthState.loading();
      await _repository.signOut();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}
