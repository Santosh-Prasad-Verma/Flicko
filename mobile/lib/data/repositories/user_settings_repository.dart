import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/user_settings.dart';

class UserSettingsRepository {
  final Dio _dio;

  UserSettingsRepository(this._dio);

  static const _prefsKey = 'user_settings_v2';

  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        return userSettingsFromPreferencesMap(map);
      } catch (_) {}
    }
    return const UserSettings();
  }

  Future<void> saveSettings(UserSettings settings) async {
    final map = settings.toPreferencesMap();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(map));
    for (final entry in map.entries) {
      if (entry.value is bool) {
        await prefs.setBool(entry.key, entry.value as bool);
      } else if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      } else if (entry.value is double) {
        await prefs.setDouble(entry.key, entry.value as double);
      }
    }

    try {
      await _dio.patch('/api/v1/users/@me', data: {'preferences': map});
    } catch (_) {}
  }

  Future<UserSettings> syncFromRemote() async {
    try {
      final response = await _dio.get('/api/v1/users/@me');
      final remotePrefs = (response.data['preferences'] as Map<String, dynamic>?) ?? {};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(remotePrefs));
      return userSettingsFromPreferencesMap(remotePrefs);
    } catch (_) {
      return await loadSettings();
    }
  }
}

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(ref.watch(dioProvider));
});
