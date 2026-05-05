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
  
  Future<UserModel> createProfile(UserModel user) async {
    final response = await _client
        .from('profiles')
        .insert(user.toJson())
        .select()
        .single();
    return UserModel.fromJson(response);
  }

  Future<UserModel> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  }

  Future<bool> checkUsernameExists(String username) async {
    try {
      final response = await _client
          .rpc('check_username_exists', params: {'target_username': username});
      return response == true;
    } catch (e) {
      return false; // If query fails (e.g. network error), let the sign up process handle validation
    }
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

  /// Disable account (soft delete)
  Future<void> disableAccount(String userId) async {
    await _client
        .from('profiles')
        .update({'disabled': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Delete account (mark for deletion)
  Future<void> deleteAccount(String userId) async {
    await _client
        .from('profiles')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}
