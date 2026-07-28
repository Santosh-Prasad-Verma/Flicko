import 'package:livekit_client/livekit_client.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_state.freezed.dart';

@freezed
abstract class VoiceState with _$VoiceState {
  const factory VoiceState({
    Room? room,
    @Default(false) bool isConnected,
    @Default(false) bool isConnecting,
    @Default(false) bool isMuted,
    @Default(false) bool isDeafened,
    @Default([]) List<Participant> participants,
    @Default({}) Set<String> speakingParticipants, // Set of sids who are speaking
    @Default({}) Map<String, double> participantVolumes, // Map of sid/identity -> volume (0.0 to 2.0)
    @Default(0) int trackVersion,
    @Default([]) List<Map<String, String>> chatMessages,
    String? error,
    String? activeChannelId,
  }) = _VoiceState;
}
