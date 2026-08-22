import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/auth_user.dart';
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
final currentUserProvider = Provider<AuthUser?>((ref) {
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
    Future(() async {
      try {
        final token = await _repository.getStoredToken();
        if (token != null && token.isNotEmpty) {
          final profile = await _repository.getUserProfile('@me');
          final user = AuthUser(
            id: profile.id,
            email: '',
            userMetadata: {'username': profile.username},
          );
          state = AuthState.authenticated(
            authUser: user,
            userProfile: profile,
          );
          _bootstrapE2EE();
          return;
        }
      } catch (e) {
        // Token invalid or expired
      }
      state = const AuthState.unauthenticated();
    });
  }

  /// Best-effort: ensure E2EE keys are uploaded once the user is authenticated.
  /// Failures here are non-fatal — DMs simply stay unencrypted until next try.
  void _bootstrapE2EE() {
    Future(() async {
      try {
        // Fetch v2 rollout flags first so the bootstrap path can branch.
        final flags = await ref.read(featureFlagsRepositoryProvider).fetch();
        ref.read(e2eeFlagsProvider.notifier).update(flags);
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
      await _repository.signIn(identifier: email, password: password);
      final profile = await _repository.getUserProfile('@me');
      final user = AuthUser(
        id: profile.id,
        email: email,
        userMetadata: {'username': profile.username},
      );
      state = AuthState.authenticated(
        authUser: user,
        userProfile: profile,
      );
      _bootstrapE2EE();
    } catch (e) {
      state = AuthState.error(e.toString());
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      state = const AuthState.loading();
      await _repository.signUp(username: username, email: email, password: password);
      final profile = await _repository.getUserProfile('@me');
      final user = AuthUser(
        id: profile.id,
        email: email,
        userMetadata: {'username': profile.username},
      );
      state = AuthState.authenticated(
        authUser: user,
        userProfile: profile,
      );
      _bootstrapE2EE();
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
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  String? get _currentUserId => state.maybeWhen(
    authenticated: (user, _) => user.id,
    orElse: () => null,
  );

  Future<void> changeEmail(String newEmail) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.changeEmail(newEmail);
  }

  Future<void> changeUsername(String newUsername) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.updateProfile(userId, {'username': newUsername});
    await refreshProfile();
  }

  Future<void> changePassword(String newPassword) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.changePassword(newPassword);
  }

  Future<void> updatePhone(String phone) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.updatePhone(userId, phone);
    await refreshProfile();
  }

  Future<void> disableAccount() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.disableAccount(userId);
  }

  Future<void> deleteAccount() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _repository.deleteAccount(userId);
  }

  /// Re-fetches the profile from the DB and updates state in-place.
  /// Use this after saving profile edits instead of invalidating the provider.
  Future<void> refreshProfile() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _fetchProfile(userId);
  }
}
