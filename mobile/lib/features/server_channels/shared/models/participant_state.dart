import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'participant_state.freezed.dart';

@freezed
abstract class ParticipantState with _$ParticipantState {
  const factory ParticipantState({
    required String id,
    required String name,
    RTCVideoRenderer? videoRenderer,
    RTCVideoRenderer? screenShareRenderer,
    @Default(false) bool hasVideo,
    @Default(false) bool isSpeaking,
    @Default(false) bool isMuted,
    @Default(false) bool isScreenSharing,
  }) = _ParticipantState;
}

@freezed
abstract class RoomState with _$RoomState {
  const factory RoomState.disconnected() = _Disconnected;
  const factory RoomState.connecting() = _Connecting;
  const factory RoomState.connected({
    required String roomName,
    required Map<String, ParticipantState> participants,
  }) = _Connected;
  const factory RoomState.error(String message) = _Error;
}
