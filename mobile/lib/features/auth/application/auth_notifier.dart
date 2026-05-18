import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../data/models/auth_state.dart';
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/features/e2ee/application/e2ee_session.dart';
import 'package:mobile/features/e2ee/data/feature_flags_repository.dart';
import 'package:mobile/features/e2ee/data/secure_keystore.dart';

export 'package:mobile/data/models/auth_state.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).maybeWhen(
    authenticated: (user, _) => user.id,
    orElse: () => null,
  );
});

/// Provider for current user
final currentUserProvider = Provider<supabase.User?>((ref) {
  return ref.watch(authNotifierProvider).maybeWhen(
    authenticated: (user, _) => user,
    orElse: () => null,
  );
});

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
        _bootstrapE2EE();
      } else {
        state = const AuthState.unauthenticated();
      }
    });

    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = AuthState.authenticated(authUser: currentUser);
      _fetchProfile(currentUser.id);
      _bootstrapE2EE();
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  /// Best-effort: ensure E2EE keys are uploaded once the user is authenticated.
  /// Failures here are non-fatal — DMs simply stay unencrypted until next try.
  void _bootstrapE2EE() {
    Future(() async {
      try {
        // Fetch v2 rollout flags first so the bootstrap path can branch.
        final flags = await ref.read(featureFlagsRepositoryProvider).fetch();
        ref.read(e2eeFlagsProvider.notifier).state = flags;
        await ref.read(e2eeSessionProvider).ensureBootstrapped();
      } catch (_) {}
    });
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
      // Wipe E2EE keys before clearing the auth session — keeps device clean.
      try {
        await ref.read(secureKeystoreProvider).wipe();
      } catch (_) {}
      await _repository.signOut();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> changeEmail(String newEmail) async {
    final userId = _repository.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.changeEmail(newEmail);
  }

  Future<void> updatePhone(String phone) async {
    final userId = _repository.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.updatePhone(userId, phone);
  }

  Future<void> disableAccount() async {
    final userId = _repository.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.disableAccount(userId);
  }

  Future<void> deleteAccount() async {
    final userId = _repository.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.deleteAccount(userId);
  }

  /// Re-fetches the profile from the DB and updates state in-place.
  /// Use this after saving profile edits instead of invalidating the provider.
  Future<void> refreshProfile() async {
    final userId = _repository.currentUser?.id;
    if (userId == null) return;
    await _fetchProfile(userId);
  }
}
