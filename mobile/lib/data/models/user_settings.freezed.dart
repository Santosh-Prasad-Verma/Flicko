// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserSettings {
// ── Voice & Video ──
  bool get noiseSuppression;
  bool get echoCancellation;
  bool get autoGainControl;
  bool get attenuation;
  bool get answerOnJoin;
  bool get videoOnJoin;
  bool get callNotifications; // ── Privacy ──
  bool get allowDirectMessages;
  bool get allowFriendRequests;
  bool get allowServerInvites;
  bool get showOnlineStatus;
  bool get shareActivityStatus;
  bool get dataCollectionConsent;
  bool get readReceipts;
  bool get typingIndicator; // ── Chat ──
  bool get compactMessages;
  bool get emojiReactions;
  bool get showStickers;
  bool get gifPreviews;
  bool get quickReactions;
  bool get sendOnEnter;
  bool
      get sendWithSound; // Legacy fields kept for backward-compat with any existing stored data
  bool get autoPlayGifs;
  bool get showEmbeds;
  bool get showLinkPreview;
  bool get convertEmoticons; // ── Notifications ──
  bool get pushNotifications;
  bool get soundOnNotification;
  bool get callSound;
  bool get vibrateOnNotification;
  bool get messageNotifications;
  bool get friendRequestNotifications;
  bool get serverNotifications;
  bool get dmNotifications;
  bool get quietHoursEnabled;
  String get quietHoursStart;
  String get quietHoursEnd; // ── Accessibility ──
  bool get reduceMotion;
  bool get highContrast;
  bool get largeText;
  bool get hapticFeedback; // ── Appearance ──
  double get fontScale;
  String get themeMode;
  String get messageDisplay;
  String get accentColor; // ── System ──
  bool get developerMode;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserSettingsCopyWith<UserSettings> get copyWith =>
      _$UserSettingsCopyWithImpl<UserSettings>(
          this as UserSettings, _$identity);

  /// Serializes this UserSettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserSettings &&
            (identical(other.noiseSuppression, noiseSuppression) ||
                other.noiseSuppression == noiseSuppression) &&
            (identical(other.echoCancellation, echoCancellation) ||
                other.echoCancellation == echoCancellation) &&
            (identical(other.autoGainControl, autoGainControl) ||
                other.autoGainControl == autoGainControl) &&
            (identical(other.attenuation, attenuation) ||
                other.attenuation == attenuation) &&
            (identical(other.answerOnJoin, answerOnJoin) ||
                other.answerOnJoin == answerOnJoin) &&
            (identical(other.videoOnJoin, videoOnJoin) ||
                other.videoOnJoin == videoOnJoin) &&
            (identical(other.callNotifications, callNotifications) ||
                other.callNotifications == callNotifications) &&
            (identical(other.allowDirectMessages, allowDirectMessages) ||
                other.allowDirectMessages == allowDirectMessages) &&
            (identical(other.allowFriendRequests, allowFriendRequests) ||
                other.allowFriendRequests == allowFriendRequests) &&
            (identical(other.allowServerInvites, allowServerInvites) ||
                other.allowServerInvites == allowServerInvites) &&
            (identical(other.showOnlineStatus, showOnlineStatus) ||
                other.showOnlineStatus == showOnlineStatus) &&
            (identical(other.shareActivityStatus, shareActivityStatus) ||
                other.shareActivityStatus == shareActivityStatus) &&
            (identical(other.dataCollectionConsent, dataCollectionConsent) ||
                other.dataCollectionConsent == dataCollectionConsent) &&
            (identical(other.readReceipts, readReceipts) ||
                other.readReceipts == readReceipts) &&
            (identical(other.typingIndicator, typingIndicator) ||
                other.typingIndicator == typingIndicator) &&
            (identical(other.compactMessages, compactMessages) ||
                other.compactMessages == compactMessages) &&
            (identical(other.emojiReactions, emojiReactions) ||
                other.emojiReactions == emojiReactions) &&
            (identical(other.showStickers, showStickers) ||
                other.showStickers == showStickers) &&
            (identical(other.gifPreviews, gifPreviews) ||
                other.gifPreviews == gifPreviews) &&
            (identical(other.quickReactions, quickReactions) ||
                other.quickReactions == quickReactions) &&
            (identical(other.sendOnEnter, sendOnEnter) ||
                other.sendOnEnter == sendOnEnter) &&
            (identical(other.sendWithSound, sendWithSound) ||
                other.sendWithSound == sendWithSound) &&
            (identical(other.autoPlayGifs, autoPlayGifs) ||
                other.autoPlayGifs == autoPlayGifs) &&
            (identical(other.showEmbeds, showEmbeds) ||
                other.showEmbeds == showEmbeds) &&
            (identical(other.showLinkPreview, showLinkPreview) ||
                other.showLinkPreview == showLinkPreview) &&
            (identical(other.convertEmoticons, convertEmoticons) ||
                other.convertEmoticons == convertEmoticons) &&
            (identical(other.pushNotifications, pushNotifications) ||
                other.pushNotifications == pushNotifications) &&
            (identical(other.soundOnNotification, soundOnNotification) ||
                other.soundOnNotification == soundOnNotification) &&
            (identical(other.callSound, callSound) ||
                other.callSound == callSound) &&
            (identical(other.vibrateOnNotification, vibrateOnNotification) ||
                other.vibrateOnNotification == vibrateOnNotification) &&
            (identical(other.messageNotifications, messageNotifications) ||
                other.messageNotifications == messageNotifications) &&
            (identical(other.friendRequestNotifications, friendRequestNotifications) ||
                other.friendRequestNotifications ==
                    friendRequestNotifications) &&
            (identical(other.serverNotifications, serverNotifications) ||
                other.serverNotifications == serverNotifications) &&
            (identical(other.dmNotifications, dmNotifications) ||
                other.dmNotifications == dmNotifications) &&
            (identical(other.quietHoursEnabled, quietHoursEnabled) ||
                other.quietHoursEnabled == quietHoursEnabled) &&
            (identical(other.quietHoursStart, quietHoursStart) ||
                other.quietHoursStart == quietHoursStart) &&
            (identical(other.quietHoursEnd, quietHoursEnd) ||
                other.quietHoursEnd == quietHoursEnd) &&
            (identical(other.reduceMotion, reduceMotion) ||
                other.reduceMotion == reduceMotion) &&
            (identical(other.highContrast, highContrast) ||
                other.highContrast == highContrast) &&
            (identical(other.largeText, largeText) ||
                other.largeText == largeText) &&
            (identical(other.hapticFeedback, hapticFeedback) ||
                other.hapticFeedback == hapticFeedback) &&
            (identical(other.fontScale, fontScale) ||
                other.fontScale == fontScale) &&
            (identical(other.themeMode, themeMode) || other.themeMode == themeMode) &&
            (identical(other.messageDisplay, messageDisplay) || other.messageDisplay == messageDisplay) &&
            (identical(other.accentColor, accentColor) || other.accentColor == accentColor) &&
            (identical(other.developerMode, developerMode) || other.developerMode == developerMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        noiseSuppression,
        echoCancellation,
        autoGainControl,
        attenuation,
        answerOnJoin,
        videoOnJoin,
        callNotifications,
        allowDirectMessages,
        allowFriendRequests,
        allowServerInvites,
        showOnlineStatus,
        shareActivityStatus,
        dataCollectionConsent,
        readReceipts,
        typingIndicator,
        compactMessages,
        emojiReactions,
        showStickers,
        gifPreviews,
        quickReactions,
        sendOnEnter,
        sendWithSound,
        autoPlayGifs,
        showEmbeds,
        showLinkPreview,
        convertEmoticons,
        pushNotifications,
        soundOnNotification,
        callSound,
        vibrateOnNotification,
        messageNotifications,
        friendRequestNotifications,
        serverNotifications,
        dmNotifications,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        reduceMotion,
        highContrast,
        largeText,
        hapticFeedback,
        fontScale,
        themeMode,
        messageDisplay,
        accentColor,
        developerMode
      ]);

  @override
  String toString() {
    return 'UserSettings(noiseSuppression: $noiseSuppression, echoCancellation: $echoCancellation, autoGainControl: $autoGainControl, attenuation: $attenuation, answerOnJoin: $answerOnJoin, videoOnJoin: $videoOnJoin, callNotifications: $callNotifications, allowDirectMessages: $allowDirectMessages, allowFriendRequests: $allowFriendRequests, allowServerInvites: $allowServerInvites, showOnlineStatus: $showOnlineStatus, shareActivityStatus: $shareActivityStatus, dataCollectionConsent: $dataCollectionConsent, readReceipts: $readReceipts, typingIndicator: $typingIndicator, compactMessages: $compactMessages, emojiReactions: $emojiReactions, showStickers: $showStickers, gifPreviews: $gifPreviews, quickReactions: $quickReactions, sendOnEnter: $sendOnEnter, sendWithSound: $sendWithSound, autoPlayGifs: $autoPlayGifs, showEmbeds: $showEmbeds, showLinkPreview: $showLinkPreview, convertEmoticons: $convertEmoticons, pushNotifications: $pushNotifications, soundOnNotification: $soundOnNotification, callSound: $callSound, vibrateOnNotification: $vibrateOnNotification, messageNotifications: $messageNotifications, friendRequestNotifications: $friendRequestNotifications, serverNotifications: $serverNotifications, dmNotifications: $dmNotifications, quietHoursEnabled: $quietHoursEnabled, quietHoursStart: $quietHoursStart, quietHoursEnd: $quietHoursEnd, reduceMotion: $reduceMotion, highContrast: $highContrast, largeText: $largeText, hapticFeedback: $hapticFeedback, fontScale: $fontScale, themeMode: $themeMode, messageDisplay: $messageDisplay, accentColor: $accentColor, developerMode: $developerMode)';
  }
}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res> {
  factory $UserSettingsCopyWith(
          UserSettings value, $Res Function(UserSettings) _then) =
      _$UserSettingsCopyWithImpl;
  @useResult
  $Res call(
      {bool noiseSuppression,
      bool echoCancellation,
      bool autoGainControl,
      bool attenuation,
      bool answerOnJoin,
      bool videoOnJoin,
      bool callNotifications,
      bool allowDirectMessages,
      bool allowFriendRequests,
      bool allowServerInvites,
      bool showOnlineStatus,
      bool shareActivityStatus,
      bool dataCollectionConsent,
      bool readReceipts,
      bool typingIndicator,
      bool compactMessages,
      bool emojiReactions,
      bool showStickers,
      bool gifPreviews,
      bool quickReactions,
      bool sendOnEnter,
      bool sendWithSound,
      bool autoPlayGifs,
      bool showEmbeds,
      bool showLinkPreview,
      bool convertEmoticons,
      bool pushNotifications,
      bool soundOnNotification,
      bool callSound,
      bool vibrateOnNotification,
      bool messageNotifications,
      bool friendRequestNotifications,
      bool serverNotifications,
      bool dmNotifications,
      bool quietHoursEnabled,
      String quietHoursStart,
      String quietHoursEnd,
      bool reduceMotion,
      bool highContrast,
      bool largeText,
      bool hapticFeedback,
      double fontScale,
      String themeMode,
      String messageDisplay,
      String accentColor,
      bool developerMode});
}

/// @nodoc
class _$UserSettingsCopyWithImpl<$Res> implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? noiseSuppression = null,
    Object? echoCancellation = null,
    Object? autoGainControl = null,
    Object? attenuation = null,
    Object? answerOnJoin = null,
    Object? videoOnJoin = null,
    Object? callNotifications = null,
    Object? allowDirectMessages = null,
    Object? allowFriendRequests = null,
    Object? allowServerInvites = null,
    Object? showOnlineStatus = null,
    Object? shareActivityStatus = null,
    Object? dataCollectionConsent = null,
    Object? readReceipts = null,
    Object? typingIndicator = null,
    Object? compactMessages = null,
    Object? emojiReactions = null,
    Object? showStickers = null,
    Object? gifPreviews = null,
    Object? quickReactions = null,
    Object? sendOnEnter = null,
    Object? sendWithSound = null,
    Object? autoPlayGifs = null,
    Object? showEmbeds = null,
    Object? showLinkPreview = null,
    Object? convertEmoticons = null,
    Object? pushNotifications = null,
    Object? soundOnNotification = null,
    Object? callSound = null,
    Object? vibrateOnNotification = null,
    Object? messageNotifications = null,
    Object? friendRequestNotifications = null,
    Object? serverNotifications = null,
    Object? dmNotifications = null,
    Object? quietHoursEnabled = null,
    Object? quietHoursStart = null,
    Object? quietHoursEnd = null,
    Object? reduceMotion = null,
    Object? highContrast = null,
    Object? largeText = null,
    Object? hapticFeedback = null,
    Object? fontScale = null,
    Object? themeMode = null,
    Object? messageDisplay = null,
    Object? accentColor = null,
    Object? developerMode = null,
  }) {
    return _then(_self.copyWith(
      noiseSuppression: null == noiseSuppression
          ? _self.noiseSuppression
          : noiseSuppression // ignore: cast_nullable_to_non_nullable
              as bool,
      echoCancellation: null == echoCancellation
          ? _self.echoCancellation
          : echoCancellation // ignore: cast_nullable_to_non_nullable
              as bool,
      autoGainControl: null == autoGainControl
          ? _self.autoGainControl
          : autoGainControl // ignore: cast_nullable_to_non_nullable
              as bool,
      attenuation: null == attenuation
          ? _self.attenuation
          : attenuation // ignore: cast_nullable_to_non_nullable
              as bool,
      answerOnJoin: null == answerOnJoin
          ? _self.answerOnJoin
          : answerOnJoin // ignore: cast_nullable_to_non_nullable
              as bool,
      videoOnJoin: null == videoOnJoin
          ? _self.videoOnJoin
          : videoOnJoin // ignore: cast_nullable_to_non_nullable
              as bool,
      callNotifications: null == callNotifications
          ? _self.callNotifications
          : callNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      allowDirectMessages: null == allowDirectMessages
          ? _self.allowDirectMessages
          : allowDirectMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      allowFriendRequests: null == allowFriendRequests
          ? _self.allowFriendRequests
          : allowFriendRequests // ignore: cast_nullable_to_non_nullable
              as bool,
      allowServerInvites: null == allowServerInvites
          ? _self.allowServerInvites
          : allowServerInvites // ignore: cast_nullable_to_non_nullable
              as bool,
      showOnlineStatus: null == showOnlineStatus
          ? _self.showOnlineStatus
          : showOnlineStatus // ignore: cast_nullable_to_non_nullable
              as bool,
      shareActivityStatus: null == shareActivityStatus
          ? _self.shareActivityStatus
          : shareActivityStatus // ignore: cast_nullable_to_non_nullable
              as bool,
      dataCollectionConsent: null == dataCollectionConsent
          ? _self.dataCollectionConsent
          : dataCollectionConsent // ignore: cast_nullable_to_non_nullable
              as bool,
      readReceipts: null == readReceipts
          ? _self.readReceipts
          : readReceipts // ignore: cast_nullable_to_non_nullable
              as bool,
      typingIndicator: null == typingIndicator
          ? _self.typingIndicator
          : typingIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      compactMessages: null == compactMessages
          ? _self.compactMessages
          : compactMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      emojiReactions: null == emojiReactions
          ? _self.emojiReactions
          : emojiReactions // ignore: cast_nullable_to_non_nullable
              as bool,
      showStickers: null == showStickers
          ? _self.showStickers
          : showStickers // ignore: cast_nullable_to_non_nullable
              as bool,
      gifPreviews: null == gifPreviews
          ? _self.gifPreviews
          : gifPreviews // ignore: cast_nullable_to_non_nullable
              as bool,
      quickReactions: null == quickReactions
          ? _self.quickReactions
          : quickReactions // ignore: cast_nullable_to_non_nullable
              as bool,
      sendOnEnter: null == sendOnEnter
          ? _self.sendOnEnter
          : sendOnEnter // ignore: cast_nullable_to_non_nullable
              as bool,
      sendWithSound: null == sendWithSound
          ? _self.sendWithSound
          : sendWithSound // ignore: cast_nullable_to_non_nullable
              as bool,
      autoPlayGifs: null == autoPlayGifs
          ? _self.autoPlayGifs
          : autoPlayGifs // ignore: cast_nullable_to_non_nullable
              as bool,
      showEmbeds: null == showEmbeds
          ? _self.showEmbeds
          : showEmbeds // ignore: cast_nullable_to_non_nullable
              as bool,
      showLinkPreview: null == showLinkPreview
          ? _self.showLinkPreview
          : showLinkPreview // ignore: cast_nullable_to_non_nullable
              as bool,
      convertEmoticons: null == convertEmoticons
          ? _self.convertEmoticons
          : convertEmoticons // ignore: cast_nullable_to_non_nullable
              as bool,
      pushNotifications: null == pushNotifications
          ? _self.pushNotifications
          : pushNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      soundOnNotification: null == soundOnNotification
          ? _self.soundOnNotification
          : soundOnNotification // ignore: cast_nullable_to_non_nullable
              as bool,
      callSound: null == callSound
          ? _self.callSound
          : callSound // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrateOnNotification: null == vibrateOnNotification
          ? _self.vibrateOnNotification
          : vibrateOnNotification // ignore: cast_nullable_to_non_nullable
              as bool,
      messageNotifications: null == messageNotifications
          ? _self.messageNotifications
          : messageNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      friendRequestNotifications: null == friendRequestNotifications
          ? _self.friendRequestNotifications
          : friendRequestNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      serverNotifications: null == serverNotifications
          ? _self.serverNotifications
          : serverNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      dmNotifications: null == dmNotifications
          ? _self.dmNotifications
          : dmNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      quietHoursEnabled: null == quietHoursEnabled
          ? _self.quietHoursEnabled
          : quietHoursEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      quietHoursStart: null == quietHoursStart
          ? _self.quietHoursStart
          : quietHoursStart // ignore: cast_nullable_to_non_nullable
              as String,
      quietHoursEnd: null == quietHoursEnd
          ? _self.quietHoursEnd
          : quietHoursEnd // ignore: cast_nullable_to_non_nullable
              as String,
      reduceMotion: null == reduceMotion
          ? _self.reduceMotion
          : reduceMotion // ignore: cast_nullable_to_non_nullable
              as bool,
      highContrast: null == highContrast
          ? _self.highContrast
          : highContrast // ignore: cast_nullable_to_non_nullable
              as bool,
      largeText: null == largeText
          ? _self.largeText
          : largeText // ignore: cast_nullable_to_non_nullable
              as bool,
      hapticFeedback: null == hapticFeedback
          ? _self.hapticFeedback
          : hapticFeedback // ignore: cast_nullable_to_non_nullable
              as bool,
      fontScale: null == fontScale
          ? _self.fontScale
          : fontScale // ignore: cast_nullable_to_non_nullable
              as double,
      themeMode: null == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as String,
      messageDisplay: null == messageDisplay
          ? _self.messageDisplay
          : messageDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      accentColor: null == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String,
      developerMode: null == developerMode
          ? _self.developerMode
          : developerMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_UserSettings value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_UserSettings value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_UserSettings value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            bool noiseSuppression,
            bool echoCancellation,
            bool autoGainControl,
            bool attenuation,
            bool answerOnJoin,
            bool videoOnJoin,
            bool callNotifications,
            bool allowDirectMessages,
            bool allowFriendRequests,
            bool allowServerInvites,
            bool showOnlineStatus,
            bool shareActivityStatus,
            bool dataCollectionConsent,
            bool readReceipts,
            bool typingIndicator,
            bool compactMessages,
            bool emojiReactions,
            bool showStickers,
            bool gifPreviews,
            bool quickReactions,
            bool sendOnEnter,
            bool sendWithSound,
            bool autoPlayGifs,
            bool showEmbeds,
            bool showLinkPreview,
            bool convertEmoticons,
            bool pushNotifications,
            bool soundOnNotification,
            bool callSound,
            bool vibrateOnNotification,
            bool messageNotifications,
            bool friendRequestNotifications,
            bool serverNotifications,
            bool dmNotifications,
            bool quietHoursEnabled,
            String quietHoursStart,
            String quietHoursEnd,
            bool reduceMotion,
            bool highContrast,
            bool largeText,
            bool hapticFeedback,
            double fontScale,
            String themeMode,
            String messageDisplay,
            String accentColor,
            bool developerMode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(
            _that.noiseSuppression,
            _that.echoCancellation,
            _that.autoGainControl,
            _that.attenuation,
            _that.answerOnJoin,
            _that.videoOnJoin,
            _that.callNotifications,
            _that.allowDirectMessages,
            _that.allowFriendRequests,
            _that.allowServerInvites,
            _that.showOnlineStatus,
            _that.shareActivityStatus,
            _that.dataCollectionConsent,
            _that.readReceipts,
            _that.typingIndicator,
            _that.compactMessages,
            _that.emojiReactions,
            _that.showStickers,
            _that.gifPreviews,
            _that.quickReactions,
            _that.sendOnEnter,
            _that.sendWithSound,
            _that.autoPlayGifs,
            _that.showEmbeds,
            _that.showLinkPreview,
            _that.convertEmoticons,
            _that.pushNotifications,
            _that.soundOnNotification,
            _that.callSound,
            _that.vibrateOnNotification,
            _that.messageNotifications,
            _that.friendRequestNotifications,
            _that.serverNotifications,
            _that.dmNotifications,
            _that.quietHoursEnabled,
            _that.quietHoursStart,
            _that.quietHoursEnd,
            _that.reduceMotion,
            _that.highContrast,
            _that.largeText,
            _that.hapticFeedback,
            _that.fontScale,
            _that.themeMode,
            _that.messageDisplay,
            _that.accentColor,
            _that.developerMode);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            bool noiseSuppression,
            bool echoCancellation,
            bool autoGainControl,
            bool attenuation,
            bool answerOnJoin,
            bool videoOnJoin,
            bool callNotifications,
            bool allowDirectMessages,
            bool allowFriendRequests,
            bool allowServerInvites,
            bool showOnlineStatus,
            bool shareActivityStatus,
            bool dataCollectionConsent,
            bool readReceipts,
            bool typingIndicator,
            bool compactMessages,
            bool emojiReactions,
            bool showStickers,
            bool gifPreviews,
            bool quickReactions,
            bool sendOnEnter,
            bool sendWithSound,
            bool autoPlayGifs,
            bool showEmbeds,
            bool showLinkPreview,
            bool convertEmoticons,
            bool pushNotifications,
            bool soundOnNotification,
            bool callSound,
            bool vibrateOnNotification,
            bool messageNotifications,
            bool friendRequestNotifications,
            bool serverNotifications,
            bool dmNotifications,
            bool quietHoursEnabled,
            String quietHoursStart,
            String quietHoursEnd,
            bool reduceMotion,
            bool highContrast,
            bool largeText,
            bool hapticFeedback,
            double fontScale,
            String themeMode,
            String messageDisplay,
            String accentColor,
            bool developerMode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings():
        return $default(
            _that.noiseSuppression,
            _that.echoCancellation,
            _that.autoGainControl,
            _that.attenuation,
            _that.answerOnJoin,
            _that.videoOnJoin,
            _that.callNotifications,
            _that.allowDirectMessages,
            _that.allowFriendRequests,
            _that.allowServerInvites,
            _that.showOnlineStatus,
            _that.shareActivityStatus,
            _that.dataCollectionConsent,
            _that.readReceipts,
            _that.typingIndicator,
            _that.compactMessages,
            _that.emojiReactions,
            _that.showStickers,
            _that.gifPreviews,
            _that.quickReactions,
            _that.sendOnEnter,
            _that.sendWithSound,
            _that.autoPlayGifs,
            _that.showEmbeds,
            _that.showLinkPreview,
            _that.convertEmoticons,
            _that.pushNotifications,
            _that.soundOnNotification,
            _that.callSound,
            _that.vibrateOnNotification,
            _that.messageNotifications,
            _that.friendRequestNotifications,
            _that.serverNotifications,
            _that.dmNotifications,
            _that.quietHoursEnabled,
            _that.quietHoursStart,
            _that.quietHoursEnd,
            _that.reduceMotion,
            _that.highContrast,
            _that.largeText,
            _that.hapticFeedback,
            _that.fontScale,
            _that.themeMode,
            _that.messageDisplay,
            _that.accentColor,
            _that.developerMode);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            bool noiseSuppression,
            bool echoCancellation,
            bool autoGainControl,
            bool attenuation,
            bool answerOnJoin,
            bool videoOnJoin,
            bool callNotifications,
            bool allowDirectMessages,
            bool allowFriendRequests,
            bool allowServerInvites,
            bool showOnlineStatus,
            bool shareActivityStatus,
            bool dataCollectionConsent,
            bool readReceipts,
            bool typingIndicator,
            bool compactMessages,
            bool emojiReactions,
            bool showStickers,
            bool gifPreviews,
            bool quickReactions,
            bool sendOnEnter,
            bool sendWithSound,
            bool autoPlayGifs,
            bool showEmbeds,
            bool showLinkPreview,
            bool convertEmoticons,
            bool pushNotifications,
            bool soundOnNotification,
            bool callSound,
            bool vibrateOnNotification,
            bool messageNotifications,
            bool friendRequestNotifications,
            bool serverNotifications,
            bool dmNotifications,
            bool quietHoursEnabled,
            String quietHoursStart,
            String quietHoursEnd,
            bool reduceMotion,
            bool highContrast,
            bool largeText,
            bool hapticFeedback,
            double fontScale,
            String themeMode,
            String messageDisplay,
            String accentColor,
            bool developerMode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(
            _that.noiseSuppression,
            _that.echoCancellation,
            _that.autoGainControl,
            _that.attenuation,
            _that.answerOnJoin,
            _that.videoOnJoin,
            _that.callNotifications,
            _that.allowDirectMessages,
            _that.allowFriendRequests,
            _that.allowServerInvites,
            _that.showOnlineStatus,
            _that.shareActivityStatus,
            _that.dataCollectionConsent,
            _that.readReceipts,
            _that.typingIndicator,
            _that.compactMessages,
            _that.emojiReactions,
            _that.showStickers,
            _that.gifPreviews,
            _that.quickReactions,
            _that.sendOnEnter,
            _that.sendWithSound,
            _that.autoPlayGifs,
            _that.showEmbeds,
            _that.showLinkPreview,
            _that.convertEmoticons,
            _that.pushNotifications,
            _that.soundOnNotification,
            _that.callSound,
            _that.vibrateOnNotification,
            _that.messageNotifications,
            _that.friendRequestNotifications,
            _that.serverNotifications,
            _that.dmNotifications,
            _that.quietHoursEnabled,
            _that.quietHoursStart,
            _that.quietHoursEnd,
            _that.reduceMotion,
            _that.highContrast,
            _that.largeText,
            _that.hapticFeedback,
            _that.fontScale,
            _that.themeMode,
            _that.messageDisplay,
            _that.accentColor,
            _that.developerMode);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _UserSettings extends UserSettings {
  const _UserSettings(
      {this.noiseSuppression = false,
      this.echoCancellation = false,
      this.autoGainControl = false,
      this.attenuation = false,
      this.answerOnJoin = false,
      this.videoOnJoin = false,
      this.callNotifications = true,
      this.allowDirectMessages = true,
      this.allowFriendRequests = true,
      this.allowServerInvites = true,
      this.showOnlineStatus = true,
      this.shareActivityStatus = false,
      this.dataCollectionConsent = false,
      this.readReceipts = true,
      this.typingIndicator = true,
      this.compactMessages = false,
      this.emojiReactions = true,
      this.showStickers = true,
      this.gifPreviews = true,
      this.quickReactions = true,
      this.sendOnEnter = false,
      this.sendWithSound = false,
      this.autoPlayGifs = false,
      this.showEmbeds = true,
      this.showLinkPreview = true,
      this.convertEmoticons = false,
      this.pushNotifications = true,
      this.soundOnNotification = true,
      this.callSound = true,
      this.vibrateOnNotification = true,
      this.messageNotifications = true,
      this.friendRequestNotifications = true,
      this.serverNotifications = true,
      this.dmNotifications = true,
      this.quietHoursEnabled = false,
      this.quietHoursStart = '22:00',
      this.quietHoursEnd = '08:00',
      this.reduceMotion = false,
      this.highContrast = false,
      this.largeText = false,
      this.hapticFeedback = true,
      this.fontScale = 1.0,
      this.themeMode = 'dark',
      this.messageDisplay = 'default',
      this.accentColor = '#52B788',
      this.developerMode = false})
      : super._();
  factory _UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

// ── Voice & Video ──
  @override
  @JsonKey()
  final bool noiseSuppression;
  @override
  @JsonKey()
  final bool echoCancellation;
  @override
  @JsonKey()
  final bool autoGainControl;
  @override
  @JsonKey()
  final bool attenuation;
  @override
  @JsonKey()
  final bool answerOnJoin;
  @override
  @JsonKey()
  final bool videoOnJoin;
  @override
  @JsonKey()
  final bool callNotifications;
// ── Privacy ──
  @override
  @JsonKey()
  final bool allowDirectMessages;
  @override
  @JsonKey()
  final bool allowFriendRequests;
  @override
  @JsonKey()
  final bool allowServerInvites;
  @override
  @JsonKey()
  final bool showOnlineStatus;
  @override
  @JsonKey()
  final bool shareActivityStatus;
  @override
  @JsonKey()
  final bool dataCollectionConsent;
  @override
  @JsonKey()
  final bool readReceipts;
  @override
  @JsonKey()
  final bool typingIndicator;
// ── Chat ──
  @override
  @JsonKey()
  final bool compactMessages;
  @override
  @JsonKey()
  final bool emojiReactions;
  @override
  @JsonKey()
  final bool showStickers;
  @override
  @JsonKey()
  final bool gifPreviews;
  @override
  @JsonKey()
  final bool quickReactions;
  @override
  @JsonKey()
  final bool sendOnEnter;
  @override
  @JsonKey()
  final bool sendWithSound;
// Legacy fields kept for backward-compat with any existing stored data
  @override
  @JsonKey()
  final bool autoPlayGifs;
  @override
  @JsonKey()
  final bool showEmbeds;
  @override
  @JsonKey()
  final bool showLinkPreview;
  @override
  @JsonKey()
  final bool convertEmoticons;
// ── Notifications ──
  @override
  @JsonKey()
  final bool pushNotifications;
  @override
  @JsonKey()
  final bool soundOnNotification;
  @override
  @JsonKey()
  final bool callSound;
  @override
  @JsonKey()
  final bool vibrateOnNotification;
  @override
  @JsonKey()
  final bool messageNotifications;
  @override
  @JsonKey()
  final bool friendRequestNotifications;
  @override
  @JsonKey()
  final bool serverNotifications;
  @override
  @JsonKey()
  final bool dmNotifications;
  @override
  @JsonKey()
  final bool quietHoursEnabled;
  @override
  @JsonKey()
  final String quietHoursStart;
  @override
  @JsonKey()
  final String quietHoursEnd;
// ── Accessibility ──
  @override
  @JsonKey()
  final bool reduceMotion;
  @override
  @JsonKey()
  final bool highContrast;
  @override
  @JsonKey()
  final bool largeText;
  @override
  @JsonKey()
  final bool hapticFeedback;
// ── Appearance ──
  @override
  @JsonKey()
  final double fontScale;
  @override
  @JsonKey()
  final String themeMode;
  @override
  @JsonKey()
  final String messageDisplay;
  @override
  @JsonKey()
  final String accentColor;
// ── System ──
  @override
  @JsonKey()
  final bool developerMode;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserSettingsCopyWith<_UserSettings> get copyWith =>
      __$UserSettingsCopyWithImpl<_UserSettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserSettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserSettings &&
            (identical(other.noiseSuppression, noiseSuppression) ||
                other.noiseSuppression == noiseSuppression) &&
            (identical(other.echoCancellation, echoCancellation) ||
                other.echoCancellation == echoCancellation) &&
            (identical(other.autoGainControl, autoGainControl) ||
                other.autoGainControl == autoGainControl) &&
            (identical(other.attenuation, attenuation) ||
                other.attenuation == attenuation) &&
            (identical(other.answerOnJoin, answerOnJoin) ||
                other.answerOnJoin == answerOnJoin) &&
            (identical(other.videoOnJoin, videoOnJoin) ||
                other.videoOnJoin == videoOnJoin) &&
            (identical(other.callNotifications, callNotifications) ||
                other.callNotifications == callNotifications) &&
            (identical(other.allowDirectMessages, allowDirectMessages) ||
                other.allowDirectMessages == allowDirectMessages) &&
            (identical(other.allowFriendRequests, allowFriendRequests) ||
                other.allowFriendRequests == allowFriendRequests) &&
            (identical(other.allowServerInvites, allowServerInvites) ||
                other.allowServerInvites == allowServerInvites) &&
            (identical(other.showOnlineStatus, showOnlineStatus) ||
                other.showOnlineStatus == showOnlineStatus) &&
            (identical(other.shareActivityStatus, shareActivityStatus) ||
                other.shareActivityStatus == shareActivityStatus) &&
            (identical(other.dataCollectionConsent, dataCollectionConsent) ||
                other.dataCollectionConsent == dataCollectionConsent) &&
            (identical(other.readReceipts, readReceipts) ||
                other.readReceipts == readReceipts) &&
            (identical(other.typingIndicator, typingIndicator) ||
                other.typingIndicator == typingIndicator) &&
            (identical(other.compactMessages, compactMessages) ||
                other.compactMessages == compactMessages) &&
            (identical(other.emojiReactions, emojiReactions) ||
                other.emojiReactions == emojiReactions) &&
            (identical(other.showStickers, showStickers) ||
                other.showStickers == showStickers) &&
            (identical(other.gifPreviews, gifPreviews) ||
                other.gifPreviews == gifPreviews) &&
            (identical(other.quickReactions, quickReactions) ||
                other.quickReactions == quickReactions) &&
            (identical(other.sendOnEnter, sendOnEnter) ||
                other.sendOnEnter == sendOnEnter) &&
            (identical(other.sendWithSound, sendWithSound) ||
                other.sendWithSound == sendWithSound) &&
            (identical(other.autoPlayGifs, autoPlayGifs) ||
                other.autoPlayGifs == autoPlayGifs) &&
            (identical(other.showEmbeds, showEmbeds) ||
                other.showEmbeds == showEmbeds) &&
            (identical(other.showLinkPreview, showLinkPreview) ||
                other.showLinkPreview == showLinkPreview) &&
            (identical(other.convertEmoticons, convertEmoticons) ||
                other.convertEmoticons == convertEmoticons) &&
            (identical(other.pushNotifications, pushNotifications) ||
                other.pushNotifications == pushNotifications) &&
            (identical(other.soundOnNotification, soundOnNotification) ||
                other.soundOnNotification == soundOnNotification) &&
            (identical(other.callSound, callSound) ||
                other.callSound == callSound) &&
            (identical(other.vibrateOnNotification, vibrateOnNotification) ||
                other.vibrateOnNotification == vibrateOnNotification) &&
            (identical(other.messageNotifications, messageNotifications) ||
                other.messageNotifications == messageNotifications) &&
            (identical(other.friendRequestNotifications, friendRequestNotifications) ||
                other.friendRequestNotifications ==
                    friendRequestNotifications) &&
            (identical(other.serverNotifications, serverNotifications) ||
                other.serverNotifications == serverNotifications) &&
            (identical(other.dmNotifications, dmNotifications) ||
                other.dmNotifications == dmNotifications) &&
            (identical(other.quietHoursEnabled, quietHoursEnabled) ||
                other.quietHoursEnabled == quietHoursEnabled) &&
            (identical(other.quietHoursStart, quietHoursStart) ||
                other.quietHoursStart == quietHoursStart) &&
            (identical(other.quietHoursEnd, quietHoursEnd) ||
                other.quietHoursEnd == quietHoursEnd) &&
            (identical(other.reduceMotion, reduceMotion) ||
                other.reduceMotion == reduceMotion) &&
            (identical(other.highContrast, highContrast) ||
                other.highContrast == highContrast) &&
            (identical(other.largeText, largeText) ||
                other.largeText == largeText) &&
            (identical(other.hapticFeedback, hapticFeedback) ||
                other.hapticFeedback == hapticFeedback) &&
            (identical(other.fontScale, fontScale) ||
                other.fontScale == fontScale) &&
            (identical(other.themeMode, themeMode) || other.themeMode == themeMode) &&
            (identical(other.messageDisplay, messageDisplay) || other.messageDisplay == messageDisplay) &&
            (identical(other.accentColor, accentColor) || other.accentColor == accentColor) &&
            (identical(other.developerMode, developerMode) || other.developerMode == developerMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        noiseSuppression,
        echoCancellation,
        autoGainControl,
        attenuation,
        answerOnJoin,
        videoOnJoin,
        callNotifications,
        allowDirectMessages,
        allowFriendRequests,
        allowServerInvites,
        showOnlineStatus,
        shareActivityStatus,
        dataCollectionConsent,
        readReceipts,
        typingIndicator,
        compactMessages,
        emojiReactions,
        showStickers,
        gifPreviews,
        quickReactions,
        sendOnEnter,
        sendWithSound,
        autoPlayGifs,
        showEmbeds,
        showLinkPreview,
        convertEmoticons,
        pushNotifications,
        soundOnNotification,
        callSound,
        vibrateOnNotification,
        messageNotifications,
        friendRequestNotifications,
        serverNotifications,
        dmNotifications,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        reduceMotion,
        highContrast,
        largeText,
        hapticFeedback,
        fontScale,
        themeMode,
        messageDisplay,
        accentColor,
        developerMode
      ]);

  @override
  String toString() {
    return 'UserSettings(noiseSuppression: $noiseSuppression, echoCancellation: $echoCancellation, autoGainControl: $autoGainControl, attenuation: $attenuation, answerOnJoin: $answerOnJoin, videoOnJoin: $videoOnJoin, callNotifications: $callNotifications, allowDirectMessages: $allowDirectMessages, allowFriendRequests: $allowFriendRequests, allowServerInvites: $allowServerInvites, showOnlineStatus: $showOnlineStatus, shareActivityStatus: $shareActivityStatus, dataCollectionConsent: $dataCollectionConsent, readReceipts: $readReceipts, typingIndicator: $typingIndicator, compactMessages: $compactMessages, emojiReactions: $emojiReactions, showStickers: $showStickers, gifPreviews: $gifPreviews, quickReactions: $quickReactions, sendOnEnter: $sendOnEnter, sendWithSound: $sendWithSound, autoPlayGifs: $autoPlayGifs, showEmbeds: $showEmbeds, showLinkPreview: $showLinkPreview, convertEmoticons: $convertEmoticons, pushNotifications: $pushNotifications, soundOnNotification: $soundOnNotification, callSound: $callSound, vibrateOnNotification: $vibrateOnNotification, messageNotifications: $messageNotifications, friendRequestNotifications: $friendRequestNotifications, serverNotifications: $serverNotifications, dmNotifications: $dmNotifications, quietHoursEnabled: $quietHoursEnabled, quietHoursStart: $quietHoursStart, quietHoursEnd: $quietHoursEnd, reduceMotion: $reduceMotion, highContrast: $highContrast, largeText: $largeText, hapticFeedback: $hapticFeedback, fontScale: $fontScale, themeMode: $themeMode, messageDisplay: $messageDisplay, accentColor: $accentColor, developerMode: $developerMode)';
  }
}

/// @nodoc
abstract mixin class _$UserSettingsCopyWith<$Res>
    implements $UserSettingsCopyWith<$Res> {
  factory _$UserSettingsCopyWith(
          _UserSettings value, $Res Function(_UserSettings) _then) =
      __$UserSettingsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool noiseSuppression,
      bool echoCancellation,
      bool autoGainControl,
      bool attenuation,
      bool answerOnJoin,
      bool videoOnJoin,
      bool callNotifications,
      bool allowDirectMessages,
      bool allowFriendRequests,
      bool allowServerInvites,
      bool showOnlineStatus,
      bool shareActivityStatus,
      bool dataCollectionConsent,
      bool readReceipts,
      bool typingIndicator,
      bool compactMessages,
      bool emojiReactions,
      bool showStickers,
      bool gifPreviews,
      bool quickReactions,
      bool sendOnEnter,
      bool sendWithSound,
      bool autoPlayGifs,
      bool showEmbeds,
      bool showLinkPreview,
      bool convertEmoticons,
      bool pushNotifications,
      bool soundOnNotification,
      bool callSound,
      bool vibrateOnNotification,
      bool messageNotifications,
      bool friendRequestNotifications,
      bool serverNotifications,
      bool dmNotifications,
      bool quietHoursEnabled,
      String quietHoursStart,
      String quietHoursEnd,
      bool reduceMotion,
      bool highContrast,
      bool largeText,
      bool hapticFeedback,
      double fontScale,
      String themeMode,
      String messageDisplay,
      String accentColor,
      bool developerMode});
}

/// @nodoc
class __$UserSettingsCopyWithImpl<$Res>
    implements _$UserSettingsCopyWith<$Res> {
  __$UserSettingsCopyWithImpl(this._self, this._then);

  final _UserSettings _self;
  final $Res Function(_UserSettings) _then;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? noiseSuppression = null,
    Object? echoCancellation = null,
    Object? autoGainControl = null,
    Object? attenuation = null,
    Object? answerOnJoin = null,
    Object? videoOnJoin = null,
    Object? callNotifications = null,
    Object? allowDirectMessages = null,
    Object? allowFriendRequests = null,
    Object? allowServerInvites = null,
    Object? showOnlineStatus = null,
    Object? shareActivityStatus = null,
    Object? dataCollectionConsent = null,
    Object? readReceipts = null,
    Object? typingIndicator = null,
    Object? compactMessages = null,
    Object? emojiReactions = null,
    Object? showStickers = null,
    Object? gifPreviews = null,
    Object? quickReactions = null,
    Object? sendOnEnter = null,
    Object? sendWithSound = null,
    Object? autoPlayGifs = null,
    Object? showEmbeds = null,
    Object? showLinkPreview = null,
    Object? convertEmoticons = null,
    Object? pushNotifications = null,
    Object? soundOnNotification = null,
    Object? callSound = null,
    Object? vibrateOnNotification = null,
    Object? messageNotifications = null,
    Object? friendRequestNotifications = null,
    Object? serverNotifications = null,
    Object? dmNotifications = null,
    Object? quietHoursEnabled = null,
    Object? quietHoursStart = null,
    Object? quietHoursEnd = null,
    Object? reduceMotion = null,
    Object? highContrast = null,
    Object? largeText = null,
    Object? hapticFeedback = null,
    Object? fontScale = null,
    Object? themeMode = null,
    Object? messageDisplay = null,
    Object? accentColor = null,
    Object? developerMode = null,
  }) {
    return _then(_UserSettings(
      noiseSuppression: null == noiseSuppression
          ? _self.noiseSuppression
          : noiseSuppression // ignore: cast_nullable_to_non_nullable
              as bool,
      echoCancellation: null == echoCancellation
          ? _self.echoCancellation
          : echoCancellation // ignore: cast_nullable_to_non_nullable
              as bool,
      autoGainControl: null == autoGainControl
          ? _self.autoGainControl
          : autoGainControl // ignore: cast_nullable_to_non_nullable
              as bool,
      attenuation: null == attenuation
          ? _self.attenuation
          : attenuation // ignore: cast_nullable_to_non_nullable
              as bool,
      answerOnJoin: null == answerOnJoin
          ? _self.answerOnJoin
          : answerOnJoin // ignore: cast_nullable_to_non_nullable
              as bool,
      videoOnJoin: null == videoOnJoin
          ? _self.videoOnJoin
          : videoOnJoin // ignore: cast_nullable_to_non_nullable
              as bool,
      callNotifications: null == callNotifications
          ? _self.callNotifications
          : callNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      allowDirectMessages: null == allowDirectMessages
          ? _self.allowDirectMessages
          : allowDirectMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      allowFriendRequests: null == allowFriendRequests
          ? _self.allowFriendRequests
          : allowFriendRequests // ignore: cast_nullable_to_non_nullable
              as bool,
      allowServerInvites: null == allowServerInvites
          ? _self.allowServerInvites
          : allowServerInvites // ignore: cast_nullable_to_non_nullable
              as bool,
      showOnlineStatus: null == showOnlineStatus
          ? _self.showOnlineStatus
          : showOnlineStatus // ignore: cast_nullable_to_non_nullable
              as bool,
      shareActivityStatus: null == shareActivityStatus
          ? _self.shareActivityStatus
          : shareActivityStatus // ignore: cast_nullable_to_non_nullable
              as bool,
      dataCollectionConsent: null == dataCollectionConsent
          ? _self.dataCollectionConsent
          : dataCollectionConsent // ignore: cast_nullable_to_non_nullable
              as bool,
      readReceipts: null == readReceipts
          ? _self.readReceipts
          : readReceipts // ignore: cast_nullable_to_non_nullable
              as bool,
      typingIndicator: null == typingIndicator
          ? _self.typingIndicator
          : typingIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      compactMessages: null == compactMessages
          ? _self.compactMessages
          : compactMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      emojiReactions: null == emojiReactions
          ? _self.emojiReactions
          : emojiReactions // ignore: cast_nullable_to_non_nullable
              as bool,
      showStickers: null == showStickers
          ? _self.showStickers
          : showStickers // ignore: cast_nullable_to_non_nullable
              as bool,
      gifPreviews: null == gifPreviews
          ? _self.gifPreviews
          : gifPreviews // ignore: cast_nullable_to_non_nullable
              as bool,
      quickReactions: null == quickReactions
          ? _self.quickReactions
          : quickReactions // ignore: cast_nullable_to_non_nullable
              as bool,
      sendOnEnter: null == sendOnEnter
          ? _self.sendOnEnter
          : sendOnEnter // ignore: cast_nullable_to_non_nullable
              as bool,
      sendWithSound: null == sendWithSound
          ? _self.sendWithSound
          : sendWithSound // ignore: cast_nullable_to_non_nullable
              as bool,
      autoPlayGifs: null == autoPlayGifs
          ? _self.autoPlayGifs
          : autoPlayGifs // ignore: cast_nullable_to_non_nullable
              as bool,
      showEmbeds: null == showEmbeds
          ? _self.showEmbeds
          : showEmbeds // ignore: cast_nullable_to_non_nullable
              as bool,
      showLinkPreview: null == showLinkPreview
          ? _self.showLinkPreview
          : showLinkPreview // ignore: cast_nullable_to_non_nullable
              as bool,
      convertEmoticons: null == convertEmoticons
          ? _self.convertEmoticons
          : convertEmoticons // ignore: cast_nullable_to_non_nullable
              as bool,
      pushNotifications: null == pushNotifications
          ? _self.pushNotifications
          : pushNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      soundOnNotification: null == soundOnNotification
          ? _self.soundOnNotification
          : soundOnNotification // ignore: cast_nullable_to_non_nullable
              as bool,
      callSound: null == callSound
          ? _self.callSound
          : callSound // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrateOnNotification: null == vibrateOnNotification
          ? _self.vibrateOnNotification
          : vibrateOnNotification // ignore: cast_nullable_to_non_nullable
              as bool,
      messageNotifications: null == messageNotifications
          ? _self.messageNotifications
          : messageNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      friendRequestNotifications: null == friendRequestNotifications
          ? _self.friendRequestNotifications
          : friendRequestNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      serverNotifications: null == serverNotifications
          ? _self.serverNotifications
          : serverNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      dmNotifications: null == dmNotifications
          ? _self.dmNotifications
          : dmNotifications // ignore: cast_nullable_to_non_nullable
              as bool,
      quietHoursEnabled: null == quietHoursEnabled
          ? _self.quietHoursEnabled
          : quietHoursEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      quietHoursStart: null == quietHoursStart
          ? _self.quietHoursStart
          : quietHoursStart // ignore: cast_nullable_to_non_nullable
              as String,
      quietHoursEnd: null == quietHoursEnd
          ? _self.quietHoursEnd
          : quietHoursEnd // ignore: cast_nullable_to_non_nullable
              as String,
      reduceMotion: null == reduceMotion
          ? _self.reduceMotion
          : reduceMotion // ignore: cast_nullable_to_non_nullable
              as bool,
      highContrast: null == highContrast
          ? _self.highContrast
          : highContrast // ignore: cast_nullable_to_non_nullable
              as bool,
      largeText: null == largeText
          ? _self.largeText
          : largeText // ignore: cast_nullable_to_non_nullable
              as bool,
      hapticFeedback: null == hapticFeedback
          ? _self.hapticFeedback
          : hapticFeedback // ignore: cast_nullable_to_non_nullable
              as bool,
      fontScale: null == fontScale
          ? _self.fontScale
          : fontScale // ignore: cast_nullable_to_non_nullable
              as double,
      themeMode: null == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as String,
      messageDisplay: null == messageDisplay
          ? _self.messageDisplay
          : messageDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      accentColor: null == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String,
      developerMode: null == developerMode
          ? _self.developerMode
          : developerMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
