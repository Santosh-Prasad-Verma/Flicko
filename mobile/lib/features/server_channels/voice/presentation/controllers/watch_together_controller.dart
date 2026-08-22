import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/services/watch_together_service.dart';
import 'package:mobile/data/models/watch_together_session.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'package:flutter/foundation.dart';

class WatchTogetherState {
  final WatchTogetherSession? session;
  final bool isLoading;
  final String? error;
  final String? resolvedStreamUrl;
  final bool isHost;
  final int lastPositionMs;
  final bool lastPlaying;
  final int seq;
  final Map<String, String> availableQualities;
  final String selectedQuality;

  const WatchTogetherState({
    this.session,
    this.isLoading = false,
    this.error,
    this.resolvedStreamUrl,
    this.isHost = false,
    this.lastPositionMs = 0,
    this.lastPlaying = false,
    this.seq = 0,
    this.availableQualities = const {},
    this.selectedQuality = 'Auto',
  });

  WatchTogetherState copyWith({
    WatchTogetherSession? session,
    bool? isLoading,
    String? error,
    String? resolvedStreamUrl,
    bool? isHost,
    int? lastPositionMs,
    bool? lastPlaying,
    int? seq,
    Map<String, String>? availableQualities,
    String? selectedQuality,
  }) {
    return WatchTogetherState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      resolvedStreamUrl: resolvedStreamUrl ?? this.resolvedStreamUrl,
      isHost: isHost ?? this.isHost,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      lastPlaying: lastPlaying ?? this.lastPlaying,
      seq: seq ?? this.seq,
      availableQualities: availableQualities ?? this.availableQualities,
      selectedQuality: selectedQuality ?? this.selectedQuality,
    );
  }
}

final watchTogetherControllerProvider =
    NotifierProvider<WatchTogetherController, WatchTogetherState>(WatchTogetherController.new);

class WatchTogetherController extends Notifier<WatchTogetherState> {
  late final WatchTogetherService _service;
  late final SupabaseClient _supabase;
  RealtimeChannel? _syncChannel;
  Timer? _syncTimer;
  final _ytExplode = yt_explode.YoutubeExplode();

  void Function(int positionMs, bool playing)? onSyncReceived;

  @override
  WatchTogetherState build() {
    _service = ref.watch(watchTogetherServiceProvider);
    _supabase = Supabase.instance.client;

    ref.onDispose(() {
      _cleanupSyncChannel();
      _syncTimer?.cancel();
      _ytExplode.close();
    });

    return const WatchTogetherState();
  }

  void _cleanupSyncChannel() {
    if (_syncChannel != null) {
      _supabase.removeChannel(_syncChannel!);
      _syncChannel = null;
    }
  }

  Future<void> startSession({
    required String roomId,
    required String url,
    required String title,
    required String kind,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = await _service.createSession(
        roomId: roomId,
        url: url,
        title: title,
        kind: kind,
      );

      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'Failed to start session');
        return;
      }

      state = state.copyWith(session: session, isHost: true);
      await joinSession(session.id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinSession(String sessionId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final username = _supabase.auth.currentUser?.email.split('@').first ?? 'Viewer';
      final joinResp = await _service.joinSession(
        sessionId: sessionId,
        username: username,
      );

      if (joinResp == null) {
        state = state.copyWith(isLoading: false, error: 'Failed to join session');
        return;
      }

      final session = joinResp.session;
      final currentUserId = _supabase.auth.currentUser?.id;
      final isHost = session.hostUserId == currentUserId;

      state = state.copyWith(
        session: session,
        isHost: isHost,
        isLoading: false,
      );

      // Resolve direct stream URL if YouTube
      _resolveMediaUrl(session.mediaUrl, session.mediaKind);

      // Connect to Realtime broadcast sync channel
      _setupSyncChannel(session.id);

      // Start periodic status sync if Host
      if (isHost) {
        _startHostSync();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _resolveMediaUrl(String url, String kind) async {
    if (kind == 'youtube' || url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        final video = await _ytExplode.videos.get(url);
        final manifest = await _ytExplode.videos.streamsClient.getManifest(video.id);

        final Map<String, String> qualities = {};
        String defaultUrl = url;

        if (manifest.muxed.isNotEmpty) {
          defaultUrl = manifest.muxed.first.url.toString();
          for (var stream in manifest.muxed) {
            final label = stream.videoQuality.name;
            if (!qualities.containsKey(label)) {
              qualities[label] = stream.url.toString();
            }
          }
        } else if (manifest.video.isNotEmpty) {
          defaultUrl = manifest.video.first.url.toString();
          for (var stream in manifest.video) {
            final label = stream.videoQuality.name;
            if (!qualities.containsKey(label)) {
              qualities[label] = stream.url.toString();
            }
          }
        }

        qualities['Auto'] = defaultUrl;

        state = state.copyWith(
          resolvedStreamUrl: defaultUrl,
          availableQualities: qualities,
          selectedQuality: 'Auto',
        );
      } catch (e) {
        debugPrint('Error resolving YouTube URL: $e');
        state = state.copyWith(
          resolvedStreamUrl: url,
          availableQualities: {'Auto': url},
          selectedQuality: 'Auto',
        );
      }
    } else {
      state = state.copyWith(
        resolvedStreamUrl: url,
        availableQualities: {'Auto': url},
        selectedQuality: 'Auto',
      );
    }
  }

  void selectQuality(String qualityLabel) {
    final targetUrl = state.availableQualities[qualityLabel];
    if (targetUrl != null) {
      state = state.copyWith(
        selectedQuality: qualityLabel,
        resolvedStreamUrl: targetUrl,
      );
    }
  }

  void _setupSyncChannel(String sessionId) {
    _cleanupSyncChannel();

    try {
      final channel = _supabase.channel('wt_sync:$sessionId');

      channel.onBroadcast(
        event: 'wt_sync',
        callback: (payload) {
          try {
            final data = (payload['payload'] is Map<String, dynamic>)
                ? payload['payload'] as Map<String, dynamic>
                : payload;
            final positionMs = (data['position_ms'] as num?)?.toInt() ?? 0;
            final playing = data['playing'] as bool? ?? false;
            final seq = (data['seq'] as num?)?.toInt() ?? 0;

            if (seq > state.seq) {
              state = state.copyWith(
                lastPositionMs: positionMs,
                lastPlaying: playing,
                seq: seq,
              );
              if (onSyncReceived != null) {
                onSyncReceived!(positionMs, playing);
              }
            }
          } catch (e) {
            debugPrint('Failed to parse wt_sync frame: $e');
          }
        },
      );

      channel.onBroadcast(
        event: 'change_media',
        callback: (payload) {
          try {
            final data = (payload['payload'] is Map<String, dynamic>)
                ? payload['payload'] as Map<String, dynamic>
                : payload;
            final url = data['url'] as String? ?? '';
            final title = data['title'] as String? ?? '';
            final kind = data['kind'] as String? ?? '';
            if (url.isNotEmpty) {
              changeMedia(url, title, kind);
            }
          } catch (e) {
            debugPrint('Failed to parse change_media frame: $e');
          }
        },
      );

      channel.subscribe();
      _syncChannel = channel;
    } catch (e) {
      debugPrint('Failed to setup sync channel: $e');
    }
  }

  void _startHostSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (state.session != null && state.isHost) {
        _service.pushAnchor(
          sessionId: state.session!.id,
          positionMs: state.lastPositionMs,
          playing: state.lastPlaying,
        );
      }
    });
  }

  Future<void> updateSyncState(int positionMs, bool playing) async {
    if (state.session == null) return;

    final nextSeq = state.seq + 1;
    state = state.copyWith(
      lastPositionMs: positionMs,
      lastPlaying: playing,
      seq: nextSeq,
    );

    if (state.isHost && _syncChannel != null) {
      try {
        await _syncChannel!.sendBroadcastMessage(
          event: 'wt_sync',
          payload: {
            'position_ms': positionMs,
            'playing': playing,
            'seq': nextSeq,
          },
        );
      } catch (e) {
        debugPrint('Failed to broadcast sync event: $e');
      }
    }
  }

  Future<void> leaveSession() async {
    _syncTimer?.cancel();
    if (state.session != null) {
      await _service.leaveSession(state.session!.id);
    }
    _cleanupSyncChannel();
    state = const WatchTogetherState();
  }

  Future<void> endSession() async {
    _syncTimer?.cancel();
    if (state.session != null) {
      await _service.endSession(state.session!.id);
    }
    _cleanupSyncChannel();
    state = const WatchTogetherState();
  }

  Future<void> changeMedia(String url, String title, String kind) async {
    if (state.session == null) return;

    final sessionId = state.session!.id;

    if (state.isHost) {
      try {
        await _supabase
            .from('wt_sessions')
            .update({
              'media_url': url,
              'media_title': title,
              'media_kind': kind,
            })
            .eq('id', sessionId);
      } catch (e) {
        debugPrint('Error updating session in database: $e');
      }

      // Broadcast to other participants in the channel
      if (_syncChannel != null) {
        try {
          await _syncChannel!.sendBroadcastMessage(
            event: 'change_media',
            payload: {
              'url': url,
              'title': title,
              'kind': kind,
            },
          );
        } catch (e) {
          debugPrint('Failed to broadcast change_media event: $e');
        }
      }
    }

    // Update local state and resolve the new stream URL
    final updatedSession = state.session!.copyWith(
      mediaUrl: url,
      mediaTitle: title,
      mediaKind: kind,
    );
    state = state.copyWith(
      session: updatedSession,
      resolvedStreamUrl: null, // Clear old stream url to force re-resolve/re-load
    );
    await _resolveMediaUrl(url, kind);
  }
}
