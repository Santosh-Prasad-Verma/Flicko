import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/services/azure_calling_service.dart';
import 'package:mobile/features/server_channels/shared/models/participant_state.dart';

final roomNotifierProvider =
    NotifierProvider<RoomNotifier, RoomState>(RoomNotifier.new);

class RoomNotifier extends Notifier<RoomState> {
  late final AzureCallingService _callingService;
  StreamSubscription<List<AzureCallingParticipant>>? _speakerSub;

  @override
  RoomState build() {
    _callingService = ref.watch(azureCallingServiceProvider);

    ref.onDispose(() {
      _speakerSub?.cancel();
      _callingService.disconnect();
    });

    return const RoomState.disconnected();
  }

  Future<void> connect(String token, {String? roomName, String? channelId}) async {
    try {
      state = const RoomState.connecting();

      await _callingService.connect(
        token,
        roomName: roomName,
        channelId: channelId,
      );

      _speakerSub?.cancel();
      _speakerSub = _callingService.activeSpeakersStream.listen((_) {
        _updateParticipants();
      });

      _updateParticipants();
    } catch (e) {
      state = RoomState.error(e.toString());
    }
  }

  void _updateParticipants() {
    final participants = <String, ParticipantState>{};

    // Add local user
    participants['me'] = ParticipantState(
      id: 'me',
      name: 'You',
      videoRenderer: _callingService.localVideoRenderer,
      hasVideo: _callingService.isCameraEnabled,
      isSpeaking: false,
      isMuted: _callingService.isMuted,
      isScreenSharing: _callingService.isScreenSharing,
    );

    // Add remote participants
    for (final p in _callingService.remoteParticipants.values) {
      participants[p.id] = ParticipantState(
        id: p.id,
        name: p.name,
        videoRenderer: p.videoRenderer,
        hasVideo: p.hasVideo,
        isSpeaking: p.isSpeaking,
        isMuted: p.isMuted,
        isScreenSharing: false,
      );
    }

    state = RoomState.connected(
      roomName: _callingService.currentRoom ?? 'voice_room',
      participants: participants,
    );
  }

  Future<void> disconnect() async {
    _speakerSub?.cancel();
    await _callingService.disconnect();
    state = const RoomState.disconnected();
  }
}
