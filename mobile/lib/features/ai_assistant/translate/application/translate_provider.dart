import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/features/ai_assistant/translate/application/translate_settings_provider.dart';
import 'package:mobile/features/ai_assistant/translate/data/translate_repository.dart';
import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';

final translateRepositoryProvider = Provider<TranslateRepository>((ref) {
  return TranslateRepository(dio: ref.watch(dioProvider));
});

/// User's preferred target language. Reads `translate_user_settings.target_lang`
/// when available, otherwise falls back to the device locale's language code,
/// with `en` as the final safety net.
final translateTargetLangProvider = Provider<String>((ref) {
  final async = ref.watch(translateUserSettingsProvider);
  final settings = async.hasValue ? async.value : null;
  if (settings != null && settings.targetLang.isNotEmpty) {
    return settings.targetLang;
  }
  final locale = ui.PlatformDispatcher.instance.locale;
  final code = locale.languageCode;
  if (code.isEmpty) return 'en';
  return code;
});

/// One controller per (channelId, messageId). Started lazily by the menu item.
class TranslateKey {
  final String messageId;
  const TranslateKey(this.messageId);
  @override
  bool operator ==(Object other) =>
      other is TranslateKey && other.messageId == messageId;
  @override
  int get hashCode => messageId.hashCode;
}

final translationProvider = NotifierProvider.autoDispose
    .family<TranslationController, TranslationState, TranslateKey>(
  TranslationController.new,
);

class TranslationController extends Notifier<TranslationState> {
  TranslationController(this._key);

  final TranslateKey _key;

  @override
  TranslationState build() => const TranslationState();

  Future<void> translate({
    required String text,
    required String target,
    String? serverId,
    String? channelId,
  }) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(status: TranslationStatus.loading, errorCode: null);
    final repo = ref.read(translateRepositoryProvider);
    try {
      final result = await repo.translate(
        text: text,
        target: target,
        serverId: serverId,
        channelId: channelId,
        messageId: _key.messageId,
      );
      if (result == null) {
        // noop = source == target. Surface a friendly idle state.
        state = const TranslationState(status: TranslationStatus.idle);
        return;
      }
      // Honour user's fluent_langs: if the source language is one the user
      // already understands, don't surface the panel — they don't need it.
      final asyncSettings = ref.read(translateUserSettingsProvider);
      final settings =
          asyncSettings.hasValue ? asyncSettings.value : null;
      if (settings != null &&
          settings.fluentLangs.contains(result.srcLang)) {
        state = const TranslationState(status: TranslationStatus.idle);
        return;
      }
      state = state.copyWith(status: TranslationStatus.ready, value: result);
    } on TranslateException catch (e) {
      state = state.copyWith(
        status: TranslationStatus.error,
        errorCode: e.code,
      );
    } catch (_) {
      state = state.copyWith(
        status: TranslationStatus.error,
        errorCode: 'unknown',
      );
    }
  }

  void clear() => state = const TranslationState();
}

