import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';
part 'user_settings.g.dart';

@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    // ── Voice & Video ──
    @Default(false) bool noiseSuppression,
    @Default(false) bool echoCancellation,
    @Default(false) bool autoGainControl,
    @Default(false) bool attenuation,
    @Default(false) bool answerOnJoin,
    @Default(false) bool videoOnJoin,
    @Default(true) bool callNotifications,

    // ── Privacy ──
    @Default(true) bool allowDirectMessages,
    @Default(true) bool allowFriendRequests,
    @Default(true) bool allowServerInvites,
    @Default(true) bool showOnlineStatus,
    @Default(false) bool shareActivityStatus,
    @Default(false) bool dataCollectionConsent,
    @Default(true) bool readReceipts,
    @Default(true) bool typingIndicator,

    // ── Chat ──
    @Default(false) bool compactMessages,
    @Default(true) bool emojiReactions,
    @Default(true) bool showStickers,
    @Default(true) bool gifPreviews,
    @Default(true) bool quickReactions,
    @Default(false) bool sendOnEnter,
    @Default(false) bool sendWithSound,
    // Legacy fields kept for backward-compat with any existing stored data
    @Default(false) bool autoPlayGifs,
    @Default(true) bool showEmbeds,
    @Default(true) bool showLinkPreview,
    @Default(false) bool convertEmoticons,

    // ── Notifications ──
    @Default(true) bool pushNotifications,
    @Default(true) bool soundOnNotification,
    @Default(true) bool callSound,
    @Default(true) bool vibrateOnNotification,
    @Default(true) bool messageNotifications,
    @Default(true) bool friendRequestNotifications,
    @Default(true) bool serverNotifications,
    @Default(true) bool dmNotifications,
    @Default(false) bool quietHoursEnabled,
    @Default('22:00') String quietHoursStart,
    @Default('08:00') String quietHoursEnd,

    // ── Accessibility ──
    @Default(false) bool reduceMotion,
    @Default(false) bool highContrast,
    @Default(false) bool largeText,
    @Default(true) bool hapticFeedback,

    // ── Appearance ──
    @Default(1.0) double fontScale,
    @Default('dark') String themeMode,
    @Default('default') String messageDisplay,
    @Default('#52B788') String accentColor,

    // ── System ──
    @Default(false) bool developerMode,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  const UserSettings._();
}

extension UserSettingsHelpers on UserSettings {
  Map<String, dynamic> toPreferencesMap() {
    return {
      // Voice
      'voice_noise_suppression': noiseSuppression,
      'voice_echo_cancellation': echoCancellation,
      'voice_auto_gain': autoGainControl,
      'voice_attenuation': attenuation,
      'voice_answer_on_join': answerOnJoin,
      'voice_video_on_join': videoOnJoin,
      'voice_call_notifications': callNotifications,
      // Privacy
      'privacy_allow_dms': allowDirectMessages,
      'privacy_allow_friend_requests': allowFriendRequests,
      'privacy_allow_server_invites': allowServerInvites,
      'privacy_show_online_status': showOnlineStatus,
      'privacy_share_activity': shareActivityStatus,
      'privacy_data_collection': dataCollectionConsent,
      'privacy_read_receipts': readReceipts,
      'privacy_typing_indicator': typingIndicator,
      // Chat
      'chat_compact': compactMessages,
      'chat_emoji_reactions': emojiReactions,
      'chat_show_stickers': showStickers,
      'chat_gif_previews': gifPreviews,
      'chat_quick_reactions': quickReactions,
      'chat_send_on_enter': sendOnEnter,
      'chat_send_with_sound': sendWithSound,
      // Notifications
      'notif_push': pushNotifications,
      'notif_sound': soundOnNotification,
      'notif_call_sound': callSound,
      'notif_vibrate': vibrateOnNotification,
      'notif_messages': messageNotifications,
      'notif_friend_requests': friendRequestNotifications,
      'notif_servers': serverNotifications,
      'notif_dms': dmNotifications,
      'notif_quiet_hours': quietHoursEnabled,
      'notif_quiet_start': quietHoursStart,
      'notif_quiet_end': quietHoursEnd,
      // Accessibility
      'access_reduce_motion': reduceMotion,
      'access_high_contrast': highContrast,
      'access_large_text': largeText,
      'access_haptic_feedback': hapticFeedback,
      // Appearance
      'appearance_font_scale': fontScale,
      'appearance_theme': themeMode,
      'appearance_message_display': messageDisplay,
      'appearance_accent_color': accentColor,
      // System
      'system_developer_mode': developerMode,
    };
  }
}

UserSettings userSettingsFromPreferencesMap(Map<String, dynamic> map) {
  return UserSettings(
    // Voice
    noiseSuppression: map['voice_noise_suppression'] == true,
    echoCancellation: map['voice_echo_cancellation'] == true,
    autoGainControl: map['voice_auto_gain'] == true,
    attenuation: map['voice_attenuation'] == true,
    answerOnJoin: map['voice_answer_on_join'] == true,
    videoOnJoin: map['voice_video_on_join'] == true,
    callNotifications: map['voice_call_notifications'] ?? true,
    // Privacy
    allowDirectMessages: map['privacy_allow_dms'] ?? true,
    allowFriendRequests: map['privacy_allow_friend_requests'] ?? true,
    allowServerInvites: map['privacy_allow_server_invites'] ?? true,
    showOnlineStatus: map['privacy_show_online_status'] == true,
    shareActivityStatus: map['privacy_share_activity'] == true,
    dataCollectionConsent: map['privacy_data_collection'] == true,
    readReceipts: map['privacy_read_receipts'] ?? true,
    typingIndicator: map['privacy_typing_indicator'] ?? true,
    // Chat
    compactMessages: map['chat_compact'] == true,
    emojiReactions: map['chat_emoji_reactions'] ?? true,
    showStickers: map['chat_show_stickers'] ?? true,
    gifPreviews: map['chat_gif_previews'] ?? true,
    quickReactions: map['chat_quick_reactions'] ?? true,
    sendOnEnter: map['chat_send_on_enter'] == true,
    sendWithSound: map['chat_send_with_sound'] == true,
    // Notifications
    pushNotifications: map['notif_push'] ?? true,
    soundOnNotification: map['notif_sound'] ?? true,
    callSound: map['notif_call_sound'] ?? true,
    vibrateOnNotification: map['notif_vibrate'] ?? true,
    messageNotifications: map['notif_messages'] ?? true,
    friendRequestNotifications: map['notif_friend_requests'] ?? true,
    serverNotifications: map['notif_servers'] ?? true,
    dmNotifications: map['notif_dms'] ?? true,
    quietHoursEnabled: map['notif_quiet_hours'] == true,
    quietHoursStart: map['notif_quiet_start'] as String? ?? '22:00',
    quietHoursEnd: map['notif_quiet_end'] as String? ?? '08:00',
    // Accessibility
    reduceMotion: map['access_reduce_motion'] == true,
    highContrast: map['access_high_contrast'] == true,
    largeText: map['access_large_text'] == true,
    hapticFeedback: map['access_haptic_feedback'] ?? true,
    // Appearance
    fontScale: (map['appearance_font_scale'] as num?)?.toDouble() ?? 1.0,
    themeMode: map['appearance_theme'] as String? ?? 'dark',
    messageDisplay: map['appearance_message_display'] as String? ?? 'default',
    accentColor: map['appearance_accent_color'] as String? ?? '#52B788',
    // System
    developerMode: map['system_developer_mode'] == true,
  );
}
