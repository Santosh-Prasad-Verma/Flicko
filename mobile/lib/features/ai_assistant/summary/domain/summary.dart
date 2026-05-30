/// Domain types for the Catch-Me-Up AI summary feature.
///
/// These mirror the backend `models.AISummary` shape on the wire and are what
/// the UI consumes via [SummaryNotifier]. Wire DTOs and JSON parsing live in
/// `data/dto/`; the domain layer stays JSON-free so widgets don't depend on
/// transport details.
library;

import 'package:flutter/foundation.dart';

/// One bullet of an AI summary plus the message ids it cites.
@immutable
class SummaryBullet {
  /// Order in the original output, starting at 0.
  final int index;

  /// Single-sentence summary text.
  final String text;

  /// Message ids this bullet quotes. Tapping a bullet jumps to the first.
  final List<String> citations;

  const SummaryBullet({
    required this.index,
    required this.text,
    this.citations = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is SummaryBullet &&
      other.index == index &&
      other.text == text &&
      listEquals(other.citations, citations);

  @override
  int get hashCode => Object.hash(index, text, Object.hashAll(citations));
}

/// Sentiment label assigned by the model. Free text "unknown" if unset.
enum SummarySentiment { positive, focused, mixed, tense, unknown }

SummarySentiment summarySentimentFromString(String? raw) {
  switch (raw) {
    case 'positive':
      return SummarySentiment.positive;
    case 'focused':
      return SummarySentiment.focused;
    case 'mixed':
      return SummarySentiment.mixed;
    case 'tense':
      return SummarySentiment.tense;
    default:
      return SummarySentiment.unknown;
  }
}

/// Summary state at a moment in time. The notifier mutates a single Summary
/// instance as bullets stream in.
@immutable
class Summary {
  final String requestId;
  final String? id;
  final String channelId;
  final List<SummaryBullet> bullets;
  final List<String> participants;
  final SummarySentiment sentiment;
  final int? messageCount;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final SummaryStatus status;
  final String? errorCode;
  final String? errorMessage;
  final String? model;
  final bool cached;

  const Summary({
    required this.requestId,
    required this.channelId,
    this.id,
    this.bullets = const [],
    this.participants = const [],
    this.sentiment = SummarySentiment.unknown,
    this.messageCount,
    this.windowStart,
    this.windowEnd,
    this.status = SummaryStatus.idle,
    this.errorCode,
    this.errorMessage,
    this.model,
    this.cached = false,
  });

  Summary copyWith({
    String? id,
    List<SummaryBullet>? bullets,
    List<String>? participants,
    SummarySentiment? sentiment,
    int? messageCount,
    DateTime? windowStart,
    DateTime? windowEnd,
    SummaryStatus? status,
    String? errorCode,
    String? errorMessage,
    String? model,
    bool? cached,
  }) {
    return Summary(
      requestId: requestId,
      channelId: channelId,
      id: id ?? this.id,
      bullets: bullets ?? this.bullets,
      participants: participants ?? this.participants,
      sentiment: sentiment ?? this.sentiment,
      messageCount: messageCount ?? this.messageCount,
      windowStart: windowStart ?? this.windowStart,
      windowEnd: windowEnd ?? this.windowEnd,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      model: model ?? this.model,
      cached: cached ?? this.cached,
    );
  }
}

/// High-level state of a streaming summary, used by widgets to switch between
/// loading skeleton, partial-card-with-bullets, and final-card.
enum SummaryStatus {
  idle,
  requesting,
  streaming,
  done,
  refused,
  rateLimited,
  error,
}
