// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VoiceState _$VoiceStateFromJson(Map<String, dynamic> json) => _VoiceState(
  channelId: json['channelId'] as String,
  userId: json['userId'] as String,
  isMuted: json['isMuted'] as bool? ?? false,
  isDeafened: json['isDeafened'] as bool? ?? false,
  isVideoEnabled: json['isVideoEnabled'] as bool? ?? false,
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  avatarUrl: json['avatarUrl'] as String?,
  displayName: json['displayName'] as String?,
);

Map<String, dynamic> _$VoiceStateToJson(_VoiceState instance) =>
    <String, dynamic>{
      'channelId': instance.channelId,
      'userId': instance.userId,
      'isMuted': instance.isMuted,
      'isDeafened': instance.isDeafened,
      'isVideoEnabled': instance.isVideoEnabled,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'avatarUrl': instance.avatarUrl,
      'displayName': instance.displayName,
    };

_VoiceParticipant _$VoiceParticipantFromJson(Map<String, dynamic> json) =>
    _VoiceParticipant(
      participantSid: json['participantSid'] as String,
      userId: json['userId'] as String,
      isMuted: json['isMuted'] as bool? ?? false,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
      isDeafened: json['isDeafened'] as bool? ?? false,
      isLocal: json['isLocal'] as bool? ?? false,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? null,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      displayName: json['displayName'] as String?,
    );

Map<String, dynamic> _$VoiceParticipantToJson(_VoiceParticipant instance) =>
    <String, dynamic>{
      'participantSid': instance.participantSid,
      'userId': instance.userId,
      'isMuted': instance.isMuted,
      'isSpeaking': instance.isSpeaking,
      'isDeafened': instance.isDeafened,
      'isLocal': instance.isLocal,
      'isVideoEnabled': instance.isVideoEnabled,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'avatarUrl': instance.avatarUrl,
      'displayName': instance.displayName,
    };
