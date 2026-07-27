import 'dart:async';

import 'package:dio/dio.dart';

import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/ai_assistant/summary/data/dto/summary_dtos.dart';
import 'package:mobile/features/ai_assistant/summary/data/summary_sse_client.dart';

/// Repository for the Catch-Me-Up AI feature.
///
/// Owns network plumbing for:
///   - kicking off a generation request (REST POST)
///   - subscribing to its event stream (SSE)
///   - submitting feedback
///
/// Returns parsed domain objects; widgets and providers never see DTOs.
class SummaryRepository {
  SummaryRepository({required Dio dio, SummarySseClient? sseClient})
      : _dio = dio,
        _sse = sseClient ??
            SummarySseClient(
              baseUri: Uri.parse(_normalizedBase()),
            );

  final Dio _dio;
  final SummarySseClient _sse;

  /// Begin generation. Returns a [SummaryHandle] the caller can listen to.
  Future<SummaryHandle> requestSummary({
    required String channelId,
    required String serverId,
    DateTime? since,
    String? anchorMsgId,
  }) async {
    final body = <String, dynamic>{
      'channel_id': channelId,
      'server_id': serverId,
      if (since != null) 'since_ts': since.toUtc().toIso8601String(),
      if (anchorMsgId != null) 'anchor_msg_id': anchorMsgId,
    };

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'ai/summary/request',
        data: body,
      );
      final data = res.data;
      if (data == null) {
        throw SummaryRequestException('empty_response');
      }
      final dto = SummaryRequestResponseDto.fromJson(data);
      return SummaryHandle(
        requestId: dto.requestId,
        cached: dto.cached,
        events: _sse.stream(dto.requestId),
      );
    } on DioException catch (e) {
      throw SummaryRequestException._fromDio(e);
    }
  }

  /// Send thumbs up/down feedback for a finalized summary.
  Future<void> sendFeedback({
    required String summaryId,
    required int rating,
    String? reason,
  }) async {
    assert(rating == 1 || rating == -1);
    await _dio.post<void>(
      'ai/summary/$summaryId/feedback',
      data: {
        'rating': rating,
        if (reason != null) 'reason': reason,
      },
    );
  }

  void dispose() => _sse.close();

  static String _normalizedBase() {
    final base = AppConfig.apiBaseUrl;
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base : '$base/';
  }
}

/// Result of a successful POST `/ai/summary/request`. Caller can consume the
/// event stream until `done` or `error` arrives.
class SummaryHandle {
  final String requestId;
  final bool cached;
  final Stream<SsePacket> events;
  SummaryHandle({
    required this.requestId,
    required this.cached,
    required this.events,
  });
}

/// Wraps non-success responses from the backend with the structured codes
/// surfaced in the OpenAPI spec.
class SummaryRequestException implements Exception {
  final String code;
  final int? status;
  final Map<String, dynamic>? body;

  SummaryRequestException(this.code, {this.status, this.body});

  factory SummaryRequestException._fromDio(DioException e) {
    final res = e.response;
    final data = res?.data;
    String code = 'request_error';
    Map<String, dynamic>? body;
    if (data is Map<String, dynamic>) {
      body = data;
      code = (data['code'] as String?) ??
          (data['error'] as String?) ??
          code;
    }
    return SummaryRequestException(code, status: res?.statusCode, body: body);
  }

  bool get isRateLimited => code == 'rate_limited' || status == 429;
  bool get isTooFew => code == 'too_few_messages' || status == 422;
  bool get isForbidden => code == 'no_channel_access' || status == 403;

  @override
  String toString() =>
      'SummaryRequestException(code: $code, status: $status)';
}
