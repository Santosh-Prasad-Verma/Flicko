import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ai_assistant/translate/application/translate_provider.dart';
import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';

/// Loads the caller's translate prefs from `/ai/translate/settings`.
///
/// Returns `TranslateUserSettings.defaults` while the request is in flight or
/// if the backend is unreachable, so dependent UI never has to handle null.
final translateUserSettingsProvider =
    AsyncNotifierProvider<TranslateSettingsController, TranslateUserSettings>(
  TranslateSettingsController.new,
);

class TranslateSettingsController
    extends AsyncNotifier<TranslateUserSettings> {
  @override
  Future<TranslateUserSettings> build() async {
    final repo = ref.read(translateRepositoryProvider);
    try {
      return await repo.getSettings();
    } catch (_) {
      return TranslateUserSettings.defaults;
    }
  }

  /// Save a partial patch and refresh state. Named `save` to avoid shadowing
  /// the inherited `AsyncNotifier.update(cb)`.
  Future<void> save(TranslateUserSettingsPatch patch) async {
    final repo = ref.read(translateRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repo.updateSettings(patch));
  }
}

