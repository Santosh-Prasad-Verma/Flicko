import 'package:mobile/features/ai_assistant/summary/domain/summary.dart';

/// Wire shape returned by `POST /api/v1/ai/summary/request`.
class SummaryRequestResponseDto {
  final String requestId;
  final String streamUrl;
  final bool cached;

  SummaryRequestResponseDto({
    required this.requestId,
    required this.streamUrl,
    required this.cached,
  });

  factory SummaryRequestResponseDto.fromJson(Map<String, dynamic> json) {
    return SummaryRequestResponseDto(
      requestId: json['request_id'] as String,
      streamUrl: (json['stream_url'] as String?) ?? '',
      cached: (json['cached'] as bool?) ?? false,
    );
  }
}

/// `bullet` SSE event payload.
SummaryBullet bulletEventFromJson(Map<String, dynamic> data) {
  final citations = (data['citations'] as List?)?.cast<String>() ?? const [];
  return SummaryBullet(
    index: (data['index'] as num?)?.toInt() ?? 0,
    text: (data['text'] as String?)?.trim() ?? '',
    citations: citations,
  );
}

/// `meta` SSE event payload.
class SummaryMetaDto {
  final List<String> participants;
  final SummarySentiment sentiment;
  final int? messageCount;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  SummaryMetaDto({
    required this.participants,
    required this.sentiment,
    this.messageCount,
    this.windowStart,
    this.windowEnd,
  });

  factory SummaryMetaDto.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;
    return SummaryMetaDto(
      participants:
          (json['participants'] as List?)?.cast<String>() ?? const [],
      sentiment:
          summarySentimentFromString(json['sentiment'] as String?),
      messageCount: (json['message_count'] as num?)?.toInt(),
      windowStart: parse(json['window_start']),
      windowEnd: parse(json['window_end']),
    );
  }
}

/// `done` SSE event payload.
class SummaryDoneDto {
  final String summaryId;
  final int tokensIn;
  final int tokensOut;
  final String model;
  final bool cached;

  SummaryDoneDto({
    required this.summaryId,
    required this.tokensIn,
    required this.tokensOut,
    required this.model,
    required this.cached,
  });

  factory SummaryDoneDto.fromJson(Map<String, dynamic> json) {
    return SummaryDoneDto(
      summaryId: (json['summary_id'] as String?) ?? '',
      tokensIn: (json['tokens_in'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokens_out'] as num?)?.toInt() ?? 0,
      model: (json['model'] as String?) ?? '',
      cached: (json['cached'] as bool?) ?? false,
    );
  }
}

/// `error` SSE event payload.
class SummaryErrorDto {
  final String code;
  final String message;
  SummaryErrorDto({required this.code, required this.message});
  factory SummaryErrorDto.fromJson(Map<String, dynamic> json) {
    return SummaryErrorDto(
      code: (json['code'] as String?) ?? 'error',
      message: (json['message'] as String?) ?? '',
    );
  }
}
