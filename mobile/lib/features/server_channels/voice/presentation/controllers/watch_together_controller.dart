import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/services/watch_together_service.dart';
import 'package:mobile/data/models/watch_together_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Room? _sessionRoom;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _syncTimer;
  final _ytExplode = yt_explode.YoutubeExplode();

  void Function(int positionMs, bool playing)? onSyncReceived;

  @override
  WatchTogetherState build() {
    _service = ref.watch(watchTogetherServiceProvider);
    _supabase = Supabase.instance.client;

    ref.onDispose(() {
      _cleanupRoom();
      _syncTimer?.cancel();
      _ytExplode.close();
    });

    return const WatchTogetherState();
  }

  void _cleanupRoom() {
    _roomListener?.dispose();
    _sessionRoom?.disconnect();
    _sessionRoom = null;
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
      final username = _supabase.auth.currentUser?.email?.split('@').first ?? 'Viewer';
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

      // Connect to dedicated LiveKit data room for session sync
      await _connectToSyncRoom(session.id, joinResp.liveKitToken);

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

  Future<void> _connectToSyncRoom(String sessionId, String token) async {
    _cleanupRoom();

    try {
      final room = Room();
      _sessionRoom = room;

      _roomListener = room.createListener()
        ..on<DataReceivedEvent>((event) {
          final decoded = utf8.decode(event.data);
          try {
            final data = jsonDecode(decoded);
            if (data['type'] == 'wt_sync') {
              final positionMs = data['position_ms'] as int;
              final playing = data['playing'] as bool;
              final seq = data['seq'] as int;

              if (seq > state.seq) {
                state = state.copyWith(
                  lastPositionMs: positionMs,
                  lastPlaying: playing,
                  seq: seq,
                );
                // Call UI callback if bound
                if (onSyncReceived != null) {
                  onSyncReceived!(positionMs, playing);
                }
              }
            } else if (data['type'] == 'change_media') {
              final url = data['url'] as String;
              final title = data['title'] as String;
              final kind = data['kind'] as String;
              changeMedia(url, title, kind);
            }
          } catch (e) {
            debugPrint('Failed to parse sync frame: $e');
          }
        });

      await room.connect(AppConfig.livekitUrl, token);
    } catch (e) {
      debugPrint('Failed to connect to watch together sync room: $e');
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

    if (state.isHost) {
      final message = jsonEncode({
        'type': 'wt_sync',
        'position_ms': positionMs,
        'playing': playing,
        'seq': nextSeq,
      });

      try {
        await _sessionRoom?.localParticipant?.publishData(
          utf8.encode(message),
          reliable: true,
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
    _cleanupRoom();
    state = const WatchTogetherState();
  }

  Future<void> endSession() async {
    _syncTimer?.cancel();
    if (state.session != null) {
      await _service.endSession(state.session!.id);
    }
    _cleanupRoom();
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

      // Broadcast to other participants in the LiveKit room
      final message = jsonEncode({
        'type': 'change_media',
        'url': url,
        'title': title,
        'kind': kind,
      });

      try {
        await _sessionRoom?.localParticipant?.publishData(
          utf8.encode(message),
          reliable: true,
        );
      } catch (e) {
        debugPrint('Failed to broadcast change_media event: $e');
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
