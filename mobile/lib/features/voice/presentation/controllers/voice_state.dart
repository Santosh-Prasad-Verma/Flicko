import 'package:livekit_client/livekit_client.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_state.freezed.dart';

@freezed
class VoiceState with _$VoiceState {
  const factory VoiceState({
    Room? room,
    @Default(false) bool isConnected,
    @Default(false) bool isConnecting,
    @Default(false) bool isMuted,
    @Default(false) bool isDeafened,
    @Default([]) List<Participant> participants,
    @Default({}) Set<String> speakingParticipants, // Set of sids who are speaking
    String? error,
    String? activeChannelId,
  }) = _VoiceState;
}
