import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/music_party_session.dart';
import 'package:mobile/data/services/music_party_service.dart';

/// Current Music Party session state — null when not in a session.
final musicPartySessionProvider =
    NotifierProvider<MusicPartyNotifier, MusicPartyState?>(MusicPartyNotifier.new);

/// Convenience provider for just the queue list.
final musicPartyQueueProvider = Provider<List<MusicPartyQueueItem>>((ref) {
  return ref.watch(musicPartySessionProvider)?.queue ?? [];
});

/// Whether the current user is the DJ.
final musicPartyIsDJProvider = Provider.family<bool, String>((ref, userId) {
  final state = ref.watch(musicPartySessionProvider);
  return state?.session.djUserId == userId;
});

/// Full client state for the Music Party feature.
class MusicPartyState {
  final MusicPartySession session;
  final List<MusicPartyQueueItem> queue;
  final MusicPartyAnchor? anchor;
  final String? liveKitToken;
  final bool isLoading;
  final String? error;

  const MusicPartyState({
    required this.session,
    this.queue = const [],
    this.anchor,
    this.liveKitToken,
    this.isLoading = false,
    this.error,
  });

  MusicPartyState copyWith({
    MusicPartySession? session,
    List<MusicPartyQueueItem>? queue,
    MusicPartyAnchor? anchor,
    String? liveKitToken,
    bool? isLoading,
    String? error,
  }) {
    return MusicPartyState(
      session: session ?? this.session,
      queue: queue ?? this.queue,
      anchor: anchor ?? this.anchor,
      liveKitToken: liveKitToken ?? this.liveKitToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MusicPartyNotifier extends Notifier<MusicPartyState?> {
  late final MusicPartyService _service;
  Timer? _pollTimer;

  @override
  MusicPartyState? build() {
    _service = ref.watch(musicPartyServiceProvider);
    ref.onDispose(() {
      _stopQueuePolling();
    });
    return null;
  }

  // ── Session Lifecycle ────────────────────────────────────────

  Future<bool> createSession({
    required String roomId,
    String rotationMode = 'manual',
    double voteSkipThreshold = 0.5,
    int maxListeners = 25,
  }) async {
    final session = await _service.createSession(
      roomId: roomId,
      rotationMode: rotationMode,
      voteSkipThreshold: voteSkipThreshold,
      maxListeners: maxListeners,
    );

    if (session != null) {
      state = MusicPartyState(session: session);
      return true;
    }
    return false;
  }

  Future<bool> joinSession(String sessionId, {String spotifyTier = 'none'}) async {
    final response = await _service.joinSession(
      sessionId: sessionId,
      spotifyTier: spotifyTier,
    );

    if (response != null) {
      state = MusicPartyState(
        session: response.session,
        queue: response.queue,
        anchor: response.anchor,
        liveKitToken: response.liveKitToken,
      );

      // Start polling queue for updates
      _startQueuePolling(sessionId);
      return true;
    }
    return false;
  }

  Future<void> leaveSession() async {
    final currentState = state;
    if (currentState == null) return;
    final sessionId = currentState.session.id;

    await _service.leaveSession(sessionId);
    _stopQueuePolling();
    state = null;
  }

  Future<void> endSession() async {
    final currentState = state;
    if (currentState == null) return;
    final sessionId = currentState.session.id;

    await _service.endSession(sessionId);
    _stopQueuePolling();
    state = null;
  }

  // ── Queue ────────────────────────────────────────────────────

  Future<bool> addToQueue({
    required String spotifyUri,
    String? title,
    String? artist,
    int? durationMs,
    String? albumArtUrl,
    String? previewUrl,
  }) async {
    final currentState = state;
    if (currentState == null) return false;

    final item = await _service.addToQueue(
      sessionId: currentState.session.id,
      spotifyUri: spotifyUri,
      title: title,
      artist: artist,
      durationMs: durationMs,
      albumArtUrl: albumArtUrl,
      previewUrl: previewUrl,
    );

    if (item != null) {
      state = currentState.copyWith(queue: [...currentState.queue, item]);
      return true;
    }
    return false;
  }

  Future<void> refreshQueue() async {
    final currentState = state;
    if (currentState == null) return;
    final queue = await _service.getQueue(currentState.session.id);
    state = currentState.copyWith(queue: queue);
  }

  Future<bool> removeQueueItem(String itemId) async {
    final currentState = state;
    if (currentState == null) return false;

    final success = await _service.removeQueueItem(currentState.session.id, itemId);
    if (success) {
      state = currentState.copyWith(
        queue: currentState.queue.where((i) => i.id != itemId).toList(),
      );
    }
    return success;
  }

  // ── Playback Control ─────────────────────────────────────────

  Future<void> play() async {
    final currentState = state;
    if (currentState == null) return;
    final session = await _service.play(currentState.session.id);
    if (session != null) {
      state = currentState.copyWith(session: session);
    }
  }

  Future<void> skip({String reason = 'dj'}) async {
    final currentState = state;
    if (currentState == null) return;
    final session = await _service.skip(currentState.session.id, reason: reason);
    if (session != null) {
      state = currentState.copyWith(session: session);
    }
  }

  Future<void> handoffDJ(String toUserId) async {
    final currentState = state;
    if (currentState == null) return;
    final session = await _service.handoffDJ(currentState.session.id, toUserId);
    if (session != null) {
      state = currentState.copyWith(session: session);
    }
  }

  // ── Anchor ───────────────────────────────────────────────────

  Future<void> pushAnchor({
    required String trackUri,
    required int positionMs,
    required bool playing,
  }) async {
    final currentState = state;
    if (currentState == null) return;
    await _service.pushAnchor(
      sessionId: currentState.session.id,
      trackUri: trackUri,
      positionMs: positionMs,
      playing: playing,
    );
  }

  Future<void> refreshAnchor() async {
    final currentState = state;
    if (currentState == null) return;
    final anchor = await _service.getAnchor(currentState.session.id);
    if (anchor != null) {
      state = currentState.copyWith(anchor: anchor);
    }
  }

  // ── Vibes ────────────────────────────────────────────────────

  Future<SkipVoteStatus?> addVibe({
    required String queueItemId,
    required String kind,
  }) async {
    final currentState = state;
    if (currentState == null) return null;
    return await _service.addVibe(
      sessionId: currentState.session.id,
      queueItemId: queueItemId,
      kind: kind,
    );
  }

  // ── Session Updates (from Centrifugo/WebSocket) ──────────────

  void updateSessionFromEvent(MusicPartySession session) {
    final currentState = state;
    if (currentState != null) {
      state = currentState.copyWith(session: session);
    }
  }

  void updateQueueFromEvent(List<MusicPartyQueueItem> queue) {
    final currentState = state;
    if (currentState != null) {
      state = currentState.copyWith(queue: queue);
    }
  }

  void updateAnchorFromEvent(MusicPartyAnchor anchor) {
    final currentState = state;
    if (currentState != null) {
      state = currentState.copyWith(anchor: anchor);
    }
  }

  // ── Polling (fallback for when WebSocket events are missed) ──

  void _startQueuePolling(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final queue = await _service.getQueue(sessionId);
        final currentState = state;
        if (currentState != null) {
          state = currentState.copyWith(queue: queue);
        }
      } catch (e) {
        debugPrint('Queue polling error: $e');
      }
    });
  }

  void _stopQueuePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
