import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/features/ai_assistant/summary/data/dto/summary_dtos.dart';
import 'package:mobile/features/ai_assistant/summary/data/summary_repository.dart';
import 'package:mobile/features/ai_assistant/summary/data/summary_sse_client.dart';
import 'package:mobile/features/ai_assistant/summary/domain/summary.dart';

/// DI-friendly provider that other features can override in tests.
final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final repo = SummaryRepository(dio: dio);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Family-keyed notifier: one instance per channel id. Widgets watch the
/// channel id alone and call `start()` when the user taps the pill.
final summaryControllerProvider =
    NotifierProvider.autoDispose.family<SummaryController, Summary, String>(
  SummaryController.new,
);

class SummaryController extends Notifier<Summary> {
  SummaryController(this._channelId);

  final String _channelId;
  StreamSubscription<SsePacket>? _sub;

  @override
  Summary build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return Summary(requestId: '', channelId: _channelId);
  }

  /// Kick off a fresh generation. Cancels any in-flight stream first.
  Future<void> start({
    required String serverId,
    DateTime? since,
    String? anchorMsgId,
  }) async {
    await _sub?.cancel();
    _sub = null;

    state = Summary(
      requestId: '',
      channelId: _channelId,
      status: SummaryStatus.requesting,
    );

    final repo = ref.read(summaryRepositoryProvider);
    try {
      final handle = await repo.requestSummary(
        channelId: _channelId,
        serverId: serverId,
        since: since,
        anchorMsgId: anchorMsgId,
      );
      // Replace whole state — requestId is final on Summary.
      state = Summary(
        requestId: handle.requestId,
        channelId: _channelId,
        status: SummaryStatus.streaming,
        cached: handle.cached,
      );
      _sub = handle.events.listen(
        _onPacket,
        onError: _onStreamError,
        onDone: _onStreamDone,
      );
    } on SummaryRequestException catch (e) {
      _onRequestError(e);
    } catch (_) {
      state = state.copyWith(
        status: SummaryStatus.error,
        errorCode: 'unknown',
      );
    }
  }

  /// Reset state when the user dismisses the card.
  void dismiss() {
    _sub?.cancel();
    _sub = null;
    state = Summary(requestId: '', channelId: _channelId);
  }

  Future<void> rate(int rating, {String? reason}) async {
    final id = state.id;
    if (id == null || id.isEmpty) return;
    final repo = ref.read(summaryRepositoryProvider);
    await repo.sendFeedback(summaryId: id, rating: rating, reason: reason);
  }

  void _onPacket(SsePacket pkt) {
    switch (pkt.event) {
      case 'bullet':
        final b = bulletEventFromJson(pkt.data);
        // Dedupe by index — server may resend on disconnect/reconnect.
        final next = List<SummaryBullet>.from(state.bullets);
        final existing = next.indexWhere((x) => x.index == b.index);
        if (existing >= 0) {
          next[existing] = b;
        } else {
          next.add(b);
          next.sort((a, b) => a.index.compareTo(b.index));
        }
        state = state.copyWith(bullets: next);
        break;
      case 'meta':
        final m = SummaryMetaDto.fromJson(pkt.data);
        state = state.copyWith(
          participants: m.participants,
          sentiment: m.sentiment,
          messageCount: m.messageCount,
          windowStart: m.windowStart,
          windowEnd: m.windowEnd,
        );
        break;
      case 'done':
        final d = SummaryDoneDto.fromJson(pkt.data);
        state = state.copyWith(
          id: d.summaryId,
          model: d.model,
          cached: d.cached,
          status: SummaryStatus.done,
        );
        break;
      case 'error':
        final e = SummaryErrorDto.fromJson(pkt.data);
        state = state.copyWith(
          status: SummaryStatus.error,
          errorCode: e.code,
          errorMessage: e.message,
        );
        break;
    }
  }

  void _onStreamError(Object err, [StackTrace? _]) {
    state = state.copyWith(
      status: SummaryStatus.error,
      errorCode: 'stream_error',
      errorMessage: err.toString(),
    );
  }

  void _onStreamDone() {
    if (state.status == SummaryStatus.streaming) {
      // Server closed without sending `done` — treat as error.
      state = state.copyWith(
        status: SummaryStatus.error,
        errorCode: 'stream_closed',
      );
    }
  }

  void _onRequestError(SummaryRequestException e) {
    SummaryStatus status;
    if (e.isRateLimited) {
      status = SummaryStatus.rateLimited;
    } else if (e.isTooFew) {
      status = SummaryStatus.refused;
    } else if (e.isForbidden) {
      status = SummaryStatus.refused;
    } else {
      status = SummaryStatus.error;
    }
    state = state.copyWith(
      status: status,
      errorCode: e.code,
      errorMessage: e.body?['error'] as String?,
    );
  }
}
