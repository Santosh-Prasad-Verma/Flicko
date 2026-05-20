// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserSettings _$UserSettingsFromJson(Map<String, dynamic> json) =>
    _UserSettings(
      noiseSuppression: json['noiseSuppression'] as bool? ?? false,
      echoCancellation: json['echoCancellation'] as bool? ?? false,
      autoGainControl: json['autoGainControl'] as bool? ?? false,
      attenuation: json['attenuation'] as bool? ?? false,
      answerOnJoin: json['answerOnJoin'] as bool? ?? false,
      videoOnJoin: json['videoOnJoin'] as bool? ?? false,
      callNotifications: json['callNotifications'] as bool? ?? false,
      allowDirectMessages: json['allowDirectMessages'] as bool? ?? true,
      allowFriendRequests: json['allowFriendRequests'] as bool? ?? true,
      allowServerInvites: json['allowServerInvites'] as bool? ?? true,
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? false,
      shareActivityStatus: json['shareActivityStatus'] as bool? ?? false,
      dataCollectionConsent: json['dataCollectionConsent'] as bool? ?? false,
      compactMessages: json['compactMessages'] as bool? ?? false,
      autoPlayGifs: json['autoPlayGifs'] as bool? ?? false,
      showEmbeds: json['showEmbeds'] as bool? ?? true,
      showLinkPreview: json['showLinkPreview'] as bool? ?? true,
      convertEmoticons: json['convertEmoticons'] as bool? ?? false,
      sendOnEnter: json['sendOnEnter'] as bool? ?? false,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      soundOnNotification: json['soundOnNotification'] as bool? ?? true,
      vibrateOnNotification: json['vibrateOnNotification'] as bool? ?? true,
      messageNotifications: json['messageNotifications'] as bool? ?? true,
      friendRequestNotifications:
          json['friendRequestNotifications'] as bool? ?? true,
      serverNotifications: json['serverNotifications'] as bool? ?? true,
      dmNotifications: json['dmNotifications'] as bool? ?? true,
      suppressEveryone: json['suppressEveryone'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      highContrast: json['highContrast'] as bool? ?? false,
      largeText: json['largeText'] as bool? ?? false,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      themeMode: json['themeMode'] as String? ?? 'dark',
      messageDisplay: json['messageDisplay'] as String? ?? 'default',
    );

Map<String, dynamic> _$UserSettingsToJson(_UserSettings instance) =>
    <String, dynamic>{
      'noiseSuppression': instance.noiseSuppression,
      'echoCancellation': instance.echoCancellation,
      'autoGainControl': instance.autoGainControl,
      'attenuation': instance.attenuation,
      'answerOnJoin': instance.answerOnJoin,
      'videoOnJoin': instance.videoOnJoin,
      'callNotifications': instance.callNotifications,
      'allowDirectMessages': instance.allowDirectMessages,
      'allowFriendRequests': instance.allowFriendRequests,
      'allowServerInvites': instance.allowServerInvites,
      'showOnlineStatus': instance.showOnlineStatus,
      'shareActivityStatus': instance.shareActivityStatus,
      'dataCollectionConsent': instance.dataCollectionConsent,
      'compactMessages': instance.compactMessages,
      'autoPlayGifs': instance.autoPlayGifs,
      'showEmbeds': instance.showEmbeds,
      'showLinkPreview': instance.showLinkPreview,
      'convertEmoticons': instance.convertEmoticons,
      'sendOnEnter': instance.sendOnEnter,
      'pushNotifications': instance.pushNotifications,
      'soundOnNotification': instance.soundOnNotification,
      'vibrateOnNotification': instance.vibrateOnNotification,
      'messageNotifications': instance.messageNotifications,
      'friendRequestNotifications': instance.friendRequestNotifications,
      'serverNotifications': instance.serverNotifications,
      'dmNotifications': instance.dmNotifications,
      'suppressEveryone': instance.suppressEveryone,
      'reduceMotion': instance.reduceMotion,
      'highContrast': instance.highContrast,
      'largeText': instance.largeText,
      'fontScale': instance.fontScale,
      'themeMode': instance.themeMode,
      'messageDisplay': instance.messageDisplay,
    };
