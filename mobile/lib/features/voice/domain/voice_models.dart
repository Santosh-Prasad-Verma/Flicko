import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_models.freezed.dart';
part 'voice_models.g.dart';

@freezed
abstract class VoiceState with _$VoiceState {
  const factory VoiceState({
    required String channelId,
    required String userId,
    @Default(false) bool isMuted,
    @Default(false) bool isDeafened,
    @Default(false) bool isVideoEnabled,
    required DateTime joinedAt,
    String? avatarUrl,
    String? displayName,
  }) = _VoiceState;

  factory VoiceState.fromJson(Map<String, dynamic> json) => _$VoiceStateFromJson(json);
}

@freezed
abstract class VoiceParticipant with _$VoiceParticipant {
  const factory VoiceParticipant({
    required String participantSid, // LiveKit SID
    required String userId,         // Supabase user ID
    @Default(false) bool isMuted,
    @Default(false) bool isSpeaking,    // Local or Remote detection
    @Default(false) bool isDeafened,
    @Default(false) bool isLocal,
    bool? isVideoEnabled, // Future proofing
    required DateTime joinedAt,
    String? avatarUrl,
    String? displayName,
  }) = _VoiceParticipant;

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) => _$VoiceParticipantFromJson(json);
}
