import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:livekit_client/livekit_client.dart';

part 'participant_state.freezed.dart';

@freezed
class ParticipantState with _$ParticipantState {
  const factory ParticipantState({
    required Participant participant,
    VideoTrack? videoTrack,
    AudioTrack? audioTrack,
    @Default(false) bool isSpeaking,
    @Default(false) bool isMuted,
  }) = _ParticipantState;
}

@freezed
class RoomState with _$RoomState {
  const factory RoomState.disconnected() = _Disconnected;
  const factory RoomState.connecting() = _Connecting;
  const factory RoomState.connected({
    required Room room,
    required Map<String, ParticipantState> participants,
  }) = _Connected;
  const factory RoomState.error(String message) = _Error;
}
