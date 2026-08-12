import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ParticipantState;
import 'package:mobile/data/services/livekit_service.dart';
import 'package:mobile/features/server_channels/shared/models/participant_state.dart';

final roomNotifierProvider = NotifierProvider<RoomNotifier, RoomState>(RoomNotifier.new);

class RoomNotifier extends Notifier<RoomState> {
  late final LiveKitService _liveKitService;
  EventsListener<RoomEvent>? _listener;

  @override
  RoomState build() {
    _liveKitService = ref.watch(livekitServiceProvider);

    ref.onDispose(() {
      _listener?.dispose();
      _liveKitService.disconnect();
    });

    return const RoomState.disconnected();
  }

  Future<void> connect(String token) async {
    try {
      state = const RoomState.connecting();

      await _liveKitService.connect(token);
      final room = _liveKitService.currentRoom!;

      _listener = room.createListener();
      _listener!.on<RoomEvent>((event) {
        _updateParticipants(room);
      });
      _listener!.on<TrackSubscribedEvent>((_) => _updateParticipants(room));
      _listener!.on<TrackUnsubscribedEvent>((_) => _updateParticipants(room));
      _listener!.on<TrackPublishedEvent>((_) => _updateParticipants(room));
      _listener!.on<TrackUnpublishedEvent>((_) => _updateParticipants(room));
      _listener!.on<TrackMutedEvent>((_) => _updateParticipants(room));
      _listener!.on<TrackUnmutedEvent>((_) => _updateParticipants(room));
      _listener!.on<ParticipantConnectedEvent>((_) => _updateParticipants(room));
      _listener!.on<ParticipantDisconnectedEvent>((_) => _updateParticipants(room));
      _listener!.on<ActiveSpeakersChangedEvent>((_) => _updateParticipants(room));

      _updateParticipants(room);

    } catch (e) {
      state = RoomState.error(e.toString());
    }
  }

  void _updateParticipants(Room room) {
    final participants = <String, ParticipantState>{};

    final local = room.localParticipant;
    if (local != null) {
      final camPub = local.videoTrackPublications.firstWhereOrNull(
        (p) => (p.source == TrackSource.camera || p.source == TrackSource.unknown) && p.track != null && !p.muted,
      );
      final screenPub = local.videoTrackPublications.firstWhereOrNull(
        (p) => p.source == TrackSource.screenShareVideo && p.track != null && !p.muted,
      );
      final audioPub = local.audioTrackPublications.firstWhereOrNull(
        (p) => p.track != null && !p.muted,
      );

      participants[local.sid] = ParticipantState(
        participant: local,
        videoTrack: camPub?.track as VideoTrack?,
        screenShareTrack: screenPub?.track as VideoTrack?,
        audioTrack: audioPub?.track as AudioTrack?,
        isSpeaking: local.isSpeaking,
        isMuted: local.isMuted,
      );
    }

    for (var p in room.remoteParticipants.values) {
      final camPub = p.videoTrackPublications.firstWhereOrNull(
        (pub) => (pub.source == TrackSource.camera || pub.source == TrackSource.unknown) && pub.track != null && !pub.muted,
      );
      final screenPub = p.videoTrackPublications.firstWhereOrNull(
        (pub) => pub.source == TrackSource.screenShareVideo && pub.track != null && !pub.muted,
      );
      final audioPub = p.audioTrackPublications.firstWhereOrNull(
        (pub) => pub.track != null && !pub.muted,
      );

      participants[p.sid] = ParticipantState(
        participant: p,
        videoTrack: camPub?.track as VideoTrack?,
        screenShareTrack: screenPub?.track as VideoTrack?,
        audioTrack: audioPub?.track as AudioTrack?,
        isSpeaking: p.isSpeaking,
        isMuted: p.isMuted,
      );
    }

    state = RoomState.connected(
      room: room,
      participants: participants,
    );
  }

  Future<void> disconnect() async {
    await _listener?.dispose();
    await _liveKitService.disconnect();
    state = const RoomState.disconnected();
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
