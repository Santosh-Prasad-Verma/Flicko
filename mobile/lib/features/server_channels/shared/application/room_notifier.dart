import 'package:flutter_riverpod/legacy.dart';
import 'package:livekit_client/livekit_client.dart' hide ParticipantState;
import 'package:mobile/data/services/livekit_service.dart';
import 'package:mobile/features/server_channels/shared/models/participant_state.dart';

final roomNotifierProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier(ref.watch(livekitServiceProvider));
});

class RoomNotifier extends StateNotifier<RoomState> {
  final LiveKitService _liveKitService;
  EventsListener<RoomEvent>? _listener;

  RoomNotifier(this._liveKitService) : super(const RoomState.disconnected());

  Future<void> connect(String token) async {
    try {
      state = const RoomState.connecting();
      
      await _liveKitService.connect(token);
      final room = _liveKitService.currentRoom!;
      
      _listener = room.createListener();
      _listener!.on<RoomEvent>((event) {
        if (!mounted) return;
        _updateParticipants(room);
      });

      _updateParticipants(room);
      
    } catch (e) {
      state = RoomState.error(e.toString());
    }
  }

  void _updateParticipants(Room room) {
    if (!mounted) return;
    
    final participants = <String, ParticipantState>{};
    
    final local = room.localParticipant;
    if (local != null) {
      participants[local.sid] = ParticipantState(
        participant: local,
        videoTrack: local.videoTrackPublications.firstWhereOrNull((p) => p.track != null)?.track as VideoTrack?,
        audioTrack: local.audioTrackPublications.firstWhereOrNull((p) => p.track != null)?.track as AudioTrack?,
        isSpeaking: local.isSpeaking,
        isMuted: local.isMuted,
      );
    }
    
    for (var p in room.remoteParticipants.values) {
      participants[p.sid] = ParticipantState(
        participant: p,
        videoTrack: p.videoTrackPublications.firstWhereOrNull((pub) => pub.track != null)?.track as VideoTrack?,
        audioTrack: p.audioTrackPublications.firstWhereOrNull((pub) => pub.track != null)?.track as AudioTrack?,
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
    if (mounted) {
      state = const RoomState.disconnected();
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _liveKitService.disconnect();
    super.dispose();
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
