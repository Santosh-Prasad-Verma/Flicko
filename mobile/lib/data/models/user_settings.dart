import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';
part 'user_settings.g.dart';

@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default(false) bool noiseSuppression,
    @Default(false) bool echoCancellation,
    @Default(false) bool autoGainControl,
    @Default(false) bool attenuation,
    @Default(false) bool answerOnJoin,
    @Default(false) bool videoOnJoin,
    @Default(false) bool callNotifications,
    @Default(true) bool allowDirectMessages,
    @Default(true) bool allowFriendRequests,
    @Default(true) bool allowServerInvites,
    @Default(false) bool showOnlineStatus,
    @Default(false) bool shareActivityStatus,
    @Default(false) bool dataCollectionConsent,
    @Default(false) bool compactMessages,
    @Default(false) bool autoPlayGifs,
    @Default(true) bool showEmbeds,
    @Default(true) bool showLinkPreview,
    @Default(false) bool convertEmoticons,
    @Default(false) bool sendOnEnter,
    @Default(true) bool pushNotifications,
    @Default(true) bool soundOnNotification,
    @Default(true) bool vibrateOnNotification,
    @Default(true) bool messageNotifications,
    @Default(true) bool friendRequestNotifications,
    @Default(true) bool serverNotifications,
    @Default(true) bool dmNotifications,
    @Default(false) bool suppressEveryone,
    @Default(false) bool reduceMotion,
    @Default(false) bool highContrast,
    @Default(false) bool largeText,
    @Default(1.0) double fontScale,
    @Default('dark') String themeMode,
    @Default('default') String messageDisplay,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  const UserSettings._();
}

extension UserSettingsHelpers on UserSettings {
  Map<String, dynamic> toPreferencesMap() {
    return {
      'voice_noise_suppression': noiseSuppression,
      'voice_echo_cancellation': echoCancellation,
      'voice_auto_gain': autoGainControl,
      'voice_attenuation': attenuation,
      'voice_answer_on_join': answerOnJoin,
      'voice_video_on_join': videoOnJoin,
      'voice_call_notifications': callNotifications,
      'privacy_allow_dms': allowDirectMessages,
      'privacy_allow_friend_requests': allowFriendRequests,
      'privacy_allow_server_invites': allowServerInvites,
      'privacy_show_online_status': showOnlineStatus,
      'privacy_share_activity': shareActivityStatus,
      'privacy_data_collection': dataCollectionConsent,
      'chat_compact': compactMessages,
      'chat_autoplay_gifs': autoPlayGifs,
      'chat_show_embeds': showEmbeds,
      'chat_link_preview': showLinkPreview,
      'chat_convert_emoticons': convertEmoticons,
      'chat_send_on_enter': sendOnEnter,
      'notif_push': pushNotifications,
      'notif_sound': soundOnNotification,
      'notif_vibrate': vibrateOnNotification,
      'notif_messages': messageNotifications,
      'notif_friend_requests': friendRequestNotifications,
      'notif_servers': serverNotifications,
      'notif_dms': dmNotifications,
      'notif_suppress_everyone': suppressEveryone,
      'access_reduce_motion': reduceMotion,
      'access_high_contrast': highContrast,
      'access_large_text': largeText,
      'appearance_font_scale': fontScale,
      'appearance_theme': themeMode,
      'appearance_message_display': messageDisplay,
    };
  }
}

UserSettings userSettingsFromPreferencesMap(Map<String, dynamic> map) {
  return UserSettings(
    noiseSuppression: map['voice_noise_suppression'] == true,
    echoCancellation: map['voice_echo_cancellation'] == true,
    autoGainControl: map['voice_auto_gain'] == true,
    attenuation: map['voice_attenuation'] == true,
    answerOnJoin: map['voice_answer_on_join'] == true,
    videoOnJoin: map['voice_video_on_join'] == true,
    callNotifications: map['voice_call_notifications'] == true,
    allowDirectMessages: map['privacy_allow_dms'] ?? true,
    allowFriendRequests: map['privacy_allow_friend_requests'] ?? true,
    allowServerInvites: map['privacy_allow_server_invites'] ?? true,
    showOnlineStatus: map['privacy_show_online_status'] == true,
    shareActivityStatus: map['privacy_share_activity'] == true,
    dataCollectionConsent: map['privacy_data_collection'] == true,
    compactMessages: map['chat_compact'] == true,
    autoPlayGifs: map['chat_autoplay_gifs'] == true,
    showEmbeds: map['chat_show_embeds'] ?? true,
    showLinkPreview: map['chat_link_preview'] ?? true,
    convertEmoticons: map['chat_convert_emoticons'] == true,
    sendOnEnter: map['chat_send_on_enter'] == true,
    pushNotifications: map['notif_push'] ?? true,
    soundOnNotification: map['notif_sound'] ?? true,
    vibrateOnNotification: map['notif_vibrate'] ?? true,
    messageNotifications: map['notif_messages'] ?? true,
    friendRequestNotifications: map['notif_friend_requests'] ?? true,
    serverNotifications: map['notif_servers'] ?? true,
    dmNotifications: map['notif_dms'] ?? true,
    suppressEveryone: map['notif_suppress_everyone'] == true,
    reduceMotion: map['access_reduce_motion'] == true,
    highContrast: map['access_high_contrast'] == true,
    largeText: map['access_large_text'] == true,
    fontScale: (map['appearance_font_scale'] as num?)?.toDouble() ?? 1.0,
    themeMode: map['appearance_theme'] as String? ?? 'dark',
    messageDisplay: map['appearance_message_display'] as String? ?? 'default',
  );
}
