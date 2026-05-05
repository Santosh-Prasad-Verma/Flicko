import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Biometrics Service for secure authentication
/// 
/// Handles fingerprint and face authentication for secure login.
/// Used to enable biometric login and store sensitive data securely.
class BiometricsService {
  static const _storage = FlutterSecureStorage();
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricCredentialsKey = 'biometric_credentials';

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometrics
  Future<bool> get isDeviceSupported async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types on device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if biometrics is enabled for the app
  Future<bool> isBiometricsEnabled() async {
    try {
      final enabled = await _storage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Enable biometrics for the app
  Future<void> enableBiometrics() async {
    await _storage.write(key: _biometricEnabledKey, value: 'true');
  }

  /// Disable biometrics for the app
  Future<void> disableBiometrics() async {
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _biometricCredentialsKey);
  }

  /// Store user credentials securely for biometric login
  Future<void> storeCredentials({
    required String email,
    required String password,
  }) async {
    final credentials = json.encode({
      'email': email,
      'password': password,
    });
    await _storage.write(key: _biometricCredentialsKey, value: credentials);
  }

  /// Retrieve stored credentials
  Future<Map<String, String>?> getCredentials() async {
    try {
      final credentials = await _storage.read(key: _biometricCredentialsKey);
      if (credentials == null) return null;
      
      final decoded = json.decode(credentials) as Map<String, dynamic>;
      return {
        'email': decoded['email'] as String,
        'password': decoded['password'] as String,
      };
    } catch (e) {
      return null;
    }
  }

  /// Authenticate using biometrics
  /// 
  /// Returns true if authentication succeeds
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to access your account',
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    bool biometricOnly = false,
  }) async {
    try {
      final isSupported = await isDeviceSupported;
      if (!isSupported) {
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        useErrorDialogs: useErrorDialogs,
        stickyAuth: stickyAuth,
        biometricOnly: biometricOnly,
      );

      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Check if biometrics is currently available
  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await isDeviceSupported;
      if (!isSupported) return false;

      final available = await getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get biometric type name for display
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Platform.isIOS ? 'Face ID' : 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scanner';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      case BiometricType.none:
        return 'None';
    }
  }

  /// Get the primary biometric type for display
  Future<String> getPrimaryBiometricType() async {
    try {
      final available = await getAvailableBiometrics();
      if (available.isEmpty) return 'Biometrics';
      
      // Prefer Face ID over fingerprint
      if (available.contains(BiometricType.face)) {
        return getBiometricTypeName(BiometricType.face);
      }
      if (available.contains(BiometricType.fingerprint)) {
        return getBiometricTypeName(BiometricType.fingerprint);
      }
      
      return getBiometricTypeName(available.first);
    } catch (e) {
      return 'Biometrics';
    }
  }

  /// Clear all biometric data
  Future<void> clearAll() async {
    await disableBiometrics();
  }
}
