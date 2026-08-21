import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/data/services/azure_calling_service.dart';

part 'voice_state.freezed.dart';

@freezed
abstract class VoiceState with _$VoiceState {
  const factory VoiceState({
    String? token,
    String? roomName,
    @Default(false) bool isConnected,
    @Default(false) bool isConnecting,
    @Default(false) bool isMuted,
    @Default(false) bool isCameraEnabled,
    @Default(false) bool isScreenSharing,
    @Default(false) bool isDeafened,
    @Default([]) List<AzureCallingParticipant> participants,
    @Default({}) Set<String> speakingParticipants,
    @Default({}) Map<String, double> participantVolumes,
    @Default(0) int trackVersion,
    @Default([]) List<Map<String, String>> chatMessages,
    String? error,
    String? activeChannelId,
  }) = _VoiceState;
}
