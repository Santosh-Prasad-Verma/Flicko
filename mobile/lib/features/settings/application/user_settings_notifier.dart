import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/user_settings.dart';
import 'package:mobile/data/repositories/user_settings_repository.dart';

final userSettingsNotifierProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(
        UserSettingsNotifier.new);

class UserSettingsNotifier extends Notifier<UserSettings> {
  late final UserSettingsRepository _repository;
  Timer? _debounceTimer;
  bool _initialized = false;

  @override
  UserSettings build() {
    _repository = ref.watch(userSettingsRepositoryProvider);
    _loadInitial();
    return const UserSettings();
  }

  Future<void> _loadInitial() async {
    final settings = await _repository.loadSettings();
    if (!_initialized) {
      state = settings;
      _initialized = true;
      // Sync from remote in background
      _syncRemote();
    }
  }

  Future<void> _syncRemote() async {
    try {
      final remote = await _repository.syncFromRemote();
      state = remote;
    } catch (_) {}
  }

  /// Updates a boolean setting and debounces persistence to Supabase.
  void setBool(String key, bool value) {
    final updated = _updateField(key, value);
    _debouncedSave(updated);
  }

  /// Updates a string setting.
  void setString(String key, String value) {
    final updated = _updateField(key, value);
    _debouncedSave(updated);
  }

  /// Updates a double setting.
  void setDouble(String key, double value) {
    final updated = _updateField(key, value);
    _debouncedSave(updated);
  }

  UserSettings _updateField(String key, Object value) {
    final current = state.toPreferencesMap();
    current[key] = value;
    final updated = userSettingsFromPreferencesMap(current);
    state = updated;
    return updated;
  }

  void _debouncedSave(UserSettings settings) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _repository.saveSettings(settings);
    });
  }
}
