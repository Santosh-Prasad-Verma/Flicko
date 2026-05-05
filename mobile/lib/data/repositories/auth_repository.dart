import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final supabase.SupabaseClient _client;

  AuthRepository(this._client);

  Stream<supabase.AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  supabase.User? get currentUser => _client.auth.currentUser;

  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserModel> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  }

  /// Update user profile fields
  Future<UserModel> updateProfile(String userId, Map<String, dynamic> updates) async {
    final response = await _client
        .from('profiles')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId)
        .select()
        .single();
    return UserModel.fromJson(response);
  }

  /// Update user phone number
  Future<void> updatePhone(String userId, String phone) async {
    await _client
        .from('profiles')
        .update({'phone': phone, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Change user password
  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }

  /// Change user email
  Future<void> changeEmail(String newEmail) async {
    await _client.auth.updateUser(
      supabase.UserAttributes(email: newEmail),
    );
  }

  /// Disable account (soft delete)
  Future<void> disableAccount(String userId) async {
    await _client
        .from('profiles')
        .update({'disabled': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
    await _client.auth.signOut();
  }

  /// Delete account (mark for deletion)
  Future<void> deleteAccount(String userId) async {
    await _client
        .from('profiles')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
    await _client.auth.signOut();
  }
}
