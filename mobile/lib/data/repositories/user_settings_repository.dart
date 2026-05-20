import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/models/user_settings.dart';

class UserSettingsRepository {
  final SupabaseClient _supabase;

  UserSettingsRepository(this._supabase);

  static const _prefsKey = 'user_settings_v2';

  /// Loads settings from SharedPreferences (instant), then syncs from Supabase.
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

  /// Saves settings to Supabase `profiles.preferences` JSONB column.
  /// Also caches to SharedPreferences for offline access.
  Future<void> saveSettings(UserSettings settings) async {
    final map = settings.toPreferencesMap();

    // Cache locally first (instant)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(map));

    // Persist to Supabase
    try {
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId == null) return;

      await _supabase
          .from('profiles')
          .update({'preferences': map})
          .eq('id', userId);
    } catch (_) {
      // Silently fail — local cache is sufficient for offline use
    }
  }

  /// Syncs settings from Supabase into local cache.
  /// Returns merged settings (remote overrides local).
  Future<UserSettings> syncFromRemote() async {
    try {
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId == null) return await loadSettings();

      final response = await _supabase
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return await loadSettings();

      final remotePrefs =
          (response['preferences'] as Map<String, dynamic>?) ?? {};

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(remotePrefs));

      return userSettingsFromPreferencesMap(remotePrefs);
    } catch (_) {
      return await loadSettings();
    }
  }
}

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(Supabase.instance.client);
});
