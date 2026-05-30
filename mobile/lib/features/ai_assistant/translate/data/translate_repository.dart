import 'package:dio/dio.dart';

import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';

/// Repository for the AI Auto-Translate feature.
///
/// Single endpoint: `POST /api/v1/ai/translate`. Backend handles cache,
/// provider chain, and per-user logging.
class TranslateRepository {
  TranslateRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Translate `text` into `target`. Returns null on `noop` (src == tgt) or
  /// when the backend feature flag is off (404).
  Future<Translation?> translate({
    required String text,
    required String target,
    String? hintSrcLang,
    String? serverId,
    String? channelId,
    String? messageId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'api/v1/ai/translate',
        data: {
          'text': text,
          'target_lang': target,
          if (hintSrcLang != null) 'src_lang': hintSrcLang,
          if (serverId != null) 'server_id': serverId,
          if (channelId != null) 'channel_id': channelId,
          if (messageId != null) 'message_id': messageId,
        },
      );
      final data = res.data;
      if (data == null) return null;
      final provider = (data['provider'] as String?) ?? 'libre';
      if (provider == 'noop') return null;
      return Translation(
        text: (data['translated_text'] as String?) ?? '',
        srcLang: (data['src_lang'] as String?) ?? 'und',
        tgtLang: (data['tgt_lang'] as String?) ?? target,
        provider: provider,
        cached: (data['cached'] as bool?) ?? false,
        latencyMs: (data['latency_ms'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw TranslateException._fromDio(e);
    }
  }

  /// Read the caller's translate preferences. Backend defaults are returned
  /// for fresh accounts.
  Future<TranslateUserSettings> getSettings() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'api/v1/ai/translate/settings',
    );
    return TranslateUserSettings.fromJson(res.data ?? const {});
  }

  /// Patch the caller's preferences. Omitted fields keep their current value.
  Future<TranslateUserSettings> updateSettings(
    TranslateUserSettingsPatch patch,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      'api/v1/ai/translate/settings',
      data: patch.toJson(),
    );
    return TranslateUserSettings.fromJson(res.data ?? const {});
  }
}

class TranslateException implements Exception {
  final String code;
  final int? status;
  TranslateException(this.code, {this.status});

  factory TranslateException._fromDio(DioException e) {
    final s = e.response?.statusCode;
    final body = e.response?.data;
    String code = 'request_error';
    if (body is Map<String, dynamic>) {
      code = (body['error'] as String?) ??
          (body['code'] as String?) ??
          code;
    }
    return TranslateException(code, status: s);
  }

  bool get isUnavailable => code == 'translate_unavailable' || status == 404 || status == 502;

  @override
  String toString() => 'TranslateException($code, status: $status)';
}
