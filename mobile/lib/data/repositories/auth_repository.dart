import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

class AuthRepository {
  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

  AuthRepository(this._dio);

  Future<String?> getStoredToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  dynamic get currentUser => null;
  Stream<dynamic> get authStateChanges => const Stream.empty();

  Future<void> signUp({
    required String username,
    required String password,
    String? email,
    String? phone,
  }) async {
    final response = await _dio.post('/api/v1/auth/register', data: {
      'username': username,
      'email': email ?? '',
      'phone': phone ?? '',
      'password': password,
    });
    if (response.data != null && response.data['token'] != null) {
      await _secureStorage.write(key: 'auth_token', value: response.data['token']);
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('/api/v1/auth/login', data: {
      'identifier': identifier,
      'email': identifier,
      'password': password,
    });
    if (response.data != null && response.data['token'] != null) {
      await _secureStorage.write(key: 'auth_token', value: response.data['token']);
    }
  }

  Future<void> signInWithMicrosoftEntraID({
    required String email,
    required String name,
    String? idToken,
  }) async {
    final response = await _dio.post('/api/v1/auth/entra-id', data: {
      'email': email,
      'name': name,
      'id_token': idToken ?? '',
    });
    if (response.data != null && response.data['token'] != null) {
      await _secureStorage.write(key: 'auth_token', value: response.data['token']);
    }
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  Future<UserModel> getUserProfile(String userId) async {
    final response = await _dio.get('/api/v1/users/@me');
    return UserModel.fromJson(response.data);
  }

  Future<UserModel> updateProfile(String userId, Map<String, dynamic> updates) async {
    final response = await _dio.patch('/api/v1/users/@me', data: updates);
    return UserModel.fromJson(response.data);
  }

  Future<void> updatePhone(String userId, String phone) async {
    await _dio.patch('/api/v1/users/@me', data: {'phone': phone});
  }

  Future<void> changePassword(String newPassword) async {
    await _dio.post('/api/v1/auth/change-password', data: {'password': newPassword});
  }

  Future<void> changeEmail(String newEmail) async {
    await _dio.post('/api/v1/auth/change-email', data: {'email': newEmail});
  }

  Future<void> disableAccount(String userId) async {
    await _dio.post('/api/v1/privacy/delete-account');
    await signOut();
  }

  Future<void> deleteAccount(String userId) async {
    await _dio.post('/api/v1/privacy/delete-account');
    await signOut();
  }
}
