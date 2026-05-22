// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Badge {
  String get id;
  String get name;
  String get icon;
  String get color;

  /// Create a copy of Badge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BadgeCopyWith<Badge> get copyWith =>
      _$BadgeCopyWithImpl<Badge>(this as Badge, _$identity);

  /// Serializes this Badge to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Badge &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, icon, color);

  @override
  String toString() {
    return 'Badge(id: $id, name: $name, icon: $icon, color: $color)';
  }
}

/// @nodoc
abstract mixin class $BadgeCopyWith<$Res> {
  factory $BadgeCopyWith(Badge value, $Res Function(Badge) _then) =
      _$BadgeCopyWithImpl;
  @useResult
  $Res call({String id, String name, String icon, String color});
}

/// @nodoc
class _$BadgeCopyWithImpl<$Res> implements $BadgeCopyWith<$Res> {
  _$BadgeCopyWithImpl(this._self, this._then);

  final Badge _self;
  final $Res Function(Badge) _then;

  /// Create a copy of Badge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [Badge].
extension BadgePatterns on Badge {
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
    TResult Function(_Badge value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Badge() when $default != null:
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
    TResult Function(_Badge value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Badge():
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
    TResult? Function(_Badge value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Badge() when $default != null:
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
    TResult Function(String id, String name, String icon, String color)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Badge() when $default != null:
        return $default(_that.id, _that.name, _that.icon, _that.color);
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
    TResult Function(String id, String name, String icon, String color)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Badge():
        return $default(_that.id, _that.name, _that.icon, _that.color);
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
    TResult? Function(String id, String name, String icon, String color)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Badge() when $default != null:
        return $default(_that.id, _that.name, _that.icon, _that.color);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Badge implements Badge {
  const _Badge(
      {required this.id,
      required this.name,
      required this.icon,
      required this.color});
  factory _Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String icon;
  @override
  final String color;

  /// Create a copy of Badge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BadgeCopyWith<_Badge> get copyWith =>
      __$BadgeCopyWithImpl<_Badge>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BadgeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Badge &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, icon, color);

  @override
  String toString() {
    return 'Badge(id: $id, name: $name, icon: $icon, color: $color)';
  }
}

/// @nodoc
abstract mixin class _$BadgeCopyWith<$Res> implements $BadgeCopyWith<$Res> {
  factory _$BadgeCopyWith(_Badge value, $Res Function(_Badge) _then) =
      __$BadgeCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String name, String icon, String color});
}

/// @nodoc
class __$BadgeCopyWithImpl<$Res> implements _$BadgeCopyWith<$Res> {
  __$BadgeCopyWithImpl(this._self, this._then);

  final _Badge _self;
  final $Res Function(_Badge) _then;

  /// Create a copy of Badge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(_Badge(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$UserModel {
  String get id;
  String get username;
  @JsonKey(name: 'display_name')
  String? get displayName;
  @JsonKey(name: 'avatar')
  String? get avatarUrl;
  @JsonKey(name: 'banner')
  String? get bannerUrl;
  String? get bio;
  String? get pronouns;
  String? get phone;
  String? get location;
  @JsonKey(name: 'website_url')
  String? get websiteUrl;
  @JsonKey(name: 'social_link')
  String? get socialLink;
  @JsonKey(name: 'accent_color')
  String? get accentColor;
  @JsonKey(name: 'banner_colors')
  List<String>? get bannerColors;
  @JsonKey(name: 'avatar_decoration')
  String? get avatarDecoration;
  @JsonKey(name: 'online_status')
  String get onlineStatus;
  @JsonKey(name: 'custom_status')
  String? get customStatus;
  @JsonKey(name: 'custom_status_emoji')
  String? get customStatusEmoji;
  List<Badge> get badges;
  @JsonKey(name: 'is_staff')
  bool get isStaff;
  @JsonKey(name: 'is_partner')
  bool get isPartner;
  @JsonKey(name: 'has_nitro')
  bool get hasNitro;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<UserModel> get copyWith =>
      _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.pronouns, pronouns) ||
                other.pronouns == pronouns) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.websiteUrl, websiteUrl) ||
                other.websiteUrl == websiteUrl) &&
            (identical(other.socialLink, socialLink) ||
                other.socialLink == socialLink) &&
            (identical(other.accentColor, accentColor) ||
                other.accentColor == accentColor) &&
            const DeepCollectionEquality()
                .equals(other.bannerColors, bannerColors) &&
            (identical(other.avatarDecoration, avatarDecoration) ||
                other.avatarDecoration == avatarDecoration) &&
            (identical(other.onlineStatus, onlineStatus) ||
                other.onlineStatus == onlineStatus) &&
            (identical(other.customStatus, customStatus) ||
                other.customStatus == customStatus) &&
            (identical(other.customStatusEmoji, customStatusEmoji) ||
                other.customStatusEmoji == customStatusEmoji) &&
            const DeepCollectionEquality().equals(other.badges, badges) &&
            (identical(other.isStaff, isStaff) || other.isStaff == isStaff) &&
            (identical(other.isPartner, isPartner) ||
                other.isPartner == isPartner) &&
            (identical(other.hasNitro, hasNitro) ||
                other.hasNitro == hasNitro) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        username,
        displayName,
        avatarUrl,
        bannerUrl,
        bio,
        pronouns,
        phone,
        location,
        websiteUrl,
        socialLink,
        accentColor,
        const DeepCollectionEquality().hash(bannerColors),
        avatarDecoration,
        onlineStatus,
        customStatus,
        customStatusEmoji,
        const DeepCollectionEquality().hash(badges),
        isStaff,
        isPartner,
        hasNitro,
        createdAt,
        updatedAt
      ]);

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bannerUrl: $bannerUrl, bio: $bio, pronouns: $pronouns, phone: $phone, location: $location, websiteUrl: $websiteUrl, socialLink: $socialLink, accentColor: $accentColor, bannerColors: $bannerColors, avatarDecoration: $avatarDecoration, onlineStatus: $onlineStatus, customStatus: $customStatus, customStatusEmoji: $customStatusEmoji, badges: $badges, isStaff: $isStaff, isPartner: $isPartner, hasNitro: $hasNitro, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) =
      _$UserModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String username,
      @JsonKey(name: 'display_name') String? displayName,
      @JsonKey(name: 'avatar') String? avatarUrl,
      @JsonKey(name: 'banner') String? bannerUrl,
      String? bio,
      String? pronouns,
      String? phone,
      String? location,
      @JsonKey(name: 'website_url') String? websiteUrl,
      @JsonKey(name: 'social_link') String? socialLink,
      @JsonKey(name: 'accent_color') String? accentColor,
      @JsonKey(name: 'banner_colors') List<String>? bannerColors,
      @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
      @JsonKey(name: 'online_status') String onlineStatus,
      @JsonKey(name: 'custom_status') String? customStatus,
      @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
      List<Badge> badges,
      @JsonKey(name: 'is_staff') bool isStaff,
      @JsonKey(name: 'is_partner') bool isPartner,
      @JsonKey(name: 'has_nitro') bool hasNitro,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res> implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._self, this._then);

  final UserModel _self;
  final $Res Function(UserModel) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarUrl = freezed,
    Object? bannerUrl = freezed,
    Object? bio = freezed,
    Object? pronouns = freezed,
    Object? phone = freezed,
    Object? location = freezed,
    Object? websiteUrl = freezed,
    Object? socialLink = freezed,
    Object? accentColor = freezed,
    Object? bannerColors = freezed,
    Object? avatarDecoration = freezed,
    Object? onlineStatus = null,
    Object? customStatus = freezed,
    Object? customStatusEmoji = freezed,
    Object? badges = null,
    Object? isStaff = null,
    Object? isPartner = null,
    Object? hasNitro = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _self.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _self.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      pronouns: freezed == pronouns
          ? _self.pronouns
          : pronouns // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      websiteUrl: freezed == websiteUrl
          ? _self.websiteUrl
          : websiteUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      socialLink: freezed == socialLink
          ? _self.socialLink
          : socialLink // ignore: cast_nullable_to_non_nullable
              as String?,
      accentColor: freezed == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerColors: freezed == bannerColors
          ? _self.bannerColors
          : bannerColors // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      avatarDecoration: freezed == avatarDecoration
          ? _self.avatarDecoration
          : avatarDecoration // ignore: cast_nullable_to_non_nullable
              as String?,
      onlineStatus: null == onlineStatus
          ? _self.onlineStatus
          : onlineStatus // ignore: cast_nullable_to_non_nullable
              as String,
      customStatus: freezed == customStatus
          ? _self.customStatus
          : customStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      customStatusEmoji: freezed == customStatusEmoji
          ? _self.customStatusEmoji
          : customStatusEmoji // ignore: cast_nullable_to_non_nullable
              as String?,
      badges: null == badges
          ? _self.badges
          : badges // ignore: cast_nullable_to_non_nullable
              as List<Badge>,
      isStaff: null == isStaff
          ? _self.isStaff
          : isStaff // ignore: cast_nullable_to_non_nullable
              as bool,
      isPartner: null == isPartner
          ? _self.isPartner
          : isPartner // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNitro: null == hasNitro
          ? _self.hasNitro
          : hasNitro // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
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
    TResult Function(_UserModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserModel() when $default != null:
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
    TResult Function(_UserModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserModel():
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
    TResult? Function(_UserModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserModel() when $default != null:
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
            String id,
            String username,
            @JsonKey(name: 'display_name') String? displayName,
            @JsonKey(name: 'avatar') String? avatarUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            String? bio,
            String? pronouns,
            String? phone,
            String? location,
            @JsonKey(name: 'website_url') String? websiteUrl,
            @JsonKey(name: 'social_link') String? socialLink,
            @JsonKey(name: 'accent_color') String? accentColor,
            @JsonKey(name: 'banner_colors') List<String>? bannerColors,
            @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
            @JsonKey(name: 'online_status') String onlineStatus,
            @JsonKey(name: 'custom_status') String? customStatus,
            @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
            List<Badge> badges,
            @JsonKey(name: 'is_staff') bool isStaff,
            @JsonKey(name: 'is_partner') bool isPartner,
            @JsonKey(name: 'has_nitro') bool hasNitro,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserModel() when $default != null:
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarUrl,
            _that.bannerUrl,
            _that.bio,
            _that.pronouns,
            _that.phone,
            _that.location,
            _that.websiteUrl,
            _that.socialLink,
            _that.accentColor,
            _that.bannerColors,
            _that.avatarDecoration,
            _that.onlineStatus,
            _that.customStatus,
            _that.customStatusEmoji,
            _that.badges,
            _that.isStaff,
            _that.isPartner,
            _that.hasNitro,
            _that.createdAt,
            _that.updatedAt);
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
            String id,
            String username,
            @JsonKey(name: 'display_name') String? displayName,
            @JsonKey(name: 'avatar') String? avatarUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            String? bio,
            String? pronouns,
            String? phone,
            String? location,
            @JsonKey(name: 'website_url') String? websiteUrl,
            @JsonKey(name: 'social_link') String? socialLink,
            @JsonKey(name: 'accent_color') String? accentColor,
            @JsonKey(name: 'banner_colors') List<String>? bannerColors,
            @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
            @JsonKey(name: 'online_status') String onlineStatus,
            @JsonKey(name: 'custom_status') String? customStatus,
            @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
            List<Badge> badges,
            @JsonKey(name: 'is_staff') bool isStaff,
            @JsonKey(name: 'is_partner') bool isPartner,
            @JsonKey(name: 'has_nitro') bool hasNitro,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserModel():
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarUrl,
            _that.bannerUrl,
            _that.bio,
            _that.pronouns,
            _that.phone,
            _that.location,
            _that.websiteUrl,
            _that.socialLink,
            _that.accentColor,
            _that.bannerColors,
            _that.avatarDecoration,
            _that.onlineStatus,
            _that.customStatus,
            _that.customStatusEmoji,
            _that.badges,
            _that.isStaff,
            _that.isPartner,
            _that.hasNitro,
            _that.createdAt,
            _that.updatedAt);
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
            String id,
            String username,
            @JsonKey(name: 'display_name') String? displayName,
            @JsonKey(name: 'avatar') String? avatarUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            String? bio,
            String? pronouns,
            String? phone,
            String? location,
            @JsonKey(name: 'website_url') String? websiteUrl,
            @JsonKey(name: 'social_link') String? socialLink,
            @JsonKey(name: 'accent_color') String? accentColor,
            @JsonKey(name: 'banner_colors') List<String>? bannerColors,
            @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
            @JsonKey(name: 'online_status') String onlineStatus,
            @JsonKey(name: 'custom_status') String? customStatus,
            @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
            List<Badge> badges,
            @JsonKey(name: 'is_staff') bool isStaff,
            @JsonKey(name: 'is_partner') bool isPartner,
            @JsonKey(name: 'has_nitro') bool hasNitro,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserModel() when $default != null:
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarUrl,
            _that.bannerUrl,
            _that.bio,
            _that.pronouns,
            _that.phone,
            _that.location,
            _that.websiteUrl,
            _that.socialLink,
            _that.accentColor,
            _that.bannerColors,
            _that.avatarDecoration,
            _that.onlineStatus,
            _that.customStatus,
            _that.customStatusEmoji,
            _that.badges,
            _that.isStaff,
            _that.isPartner,
            _that.hasNitro,
            _that.createdAt,
            _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _UserModel implements UserModel {
  const _UserModel(
      {required this.id,
      required this.username,
      @JsonKey(name: 'display_name') this.displayName,
      @JsonKey(name: 'avatar') this.avatarUrl,
      @JsonKey(name: 'banner') this.bannerUrl,
      this.bio,
      this.pronouns,
      this.phone,
      this.location,
      @JsonKey(name: 'website_url') this.websiteUrl,
      @JsonKey(name: 'social_link') this.socialLink,
      @JsonKey(name: 'accent_color') this.accentColor,
      @JsonKey(name: 'banner_colors') final List<String>? bannerColors,
      @JsonKey(name: 'avatar_decoration') this.avatarDecoration,
      @JsonKey(name: 'online_status') this.onlineStatus = 'offline',
      @JsonKey(name: 'custom_status') this.customStatus,
      @JsonKey(name: 'custom_status_emoji') this.customStatusEmoji,
      final List<Badge> badges = const [],
      @JsonKey(name: 'is_staff') this.isStaff = false,
      @JsonKey(name: 'is_partner') this.isPartner = false,
      @JsonKey(name: 'has_nitro') this.hasNitro = false,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _bannerColors = bannerColors,
        _badges = badges;
  factory _UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  @override
  final String id;
  @override
  final String username;
  @override
  @JsonKey(name: 'display_name')
  final String? displayName;
  @override
  @JsonKey(name: 'avatar')
  final String? avatarUrl;
  @override
  @JsonKey(name: 'banner')
  final String? bannerUrl;
  @override
  final String? bio;
  @override
  final String? pronouns;
  @override
  final String? phone;
  @override
  final String? location;
  @override
  @JsonKey(name: 'website_url')
  final String? websiteUrl;
  @override
  @JsonKey(name: 'social_link')
  final String? socialLink;
  @override
  @JsonKey(name: 'accent_color')
  final String? accentColor;
  final List<String>? _bannerColors;
  @override
  @JsonKey(name: 'banner_colors')
  List<String>? get bannerColors {
    final value = _bannerColors;
    if (value == null) return null;
    if (_bannerColors is EqualUnmodifiableListView) return _bannerColors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'avatar_decoration')
  final String? avatarDecoration;
  @override
  @JsonKey(name: 'online_status')
  final String onlineStatus;
  @override
  @JsonKey(name: 'custom_status')
  final String? customStatus;
  @override
  @JsonKey(name: 'custom_status_emoji')
  final String? customStatusEmoji;
  final List<Badge> _badges;
  @override
  @JsonKey()
  List<Badge> get badges {
    if (_badges is EqualUnmodifiableListView) return _badges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_badges);
  }

  @override
  @JsonKey(name: 'is_staff')
  final bool isStaff;
  @override
  @JsonKey(name: 'is_partner')
  final bool isPartner;
  @override
  @JsonKey(name: 'has_nitro')
  final bool hasNitro;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserModelCopyWith<_UserModel> get copyWith =>
      __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.pronouns, pronouns) ||
                other.pronouns == pronouns) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.websiteUrl, websiteUrl) ||
                other.websiteUrl == websiteUrl) &&
            (identical(other.socialLink, socialLink) ||
                other.socialLink == socialLink) &&
            (identical(other.accentColor, accentColor) ||
                other.accentColor == accentColor) &&
            const DeepCollectionEquality()
                .equals(other._bannerColors, _bannerColors) &&
            (identical(other.avatarDecoration, avatarDecoration) ||
                other.avatarDecoration == avatarDecoration) &&
            (identical(other.onlineStatus, onlineStatus) ||
                other.onlineStatus == onlineStatus) &&
            (identical(other.customStatus, customStatus) ||
                other.customStatus == customStatus) &&
            (identical(other.customStatusEmoji, customStatusEmoji) ||
                other.customStatusEmoji == customStatusEmoji) &&
            const DeepCollectionEquality().equals(other._badges, _badges) &&
            (identical(other.isStaff, isStaff) || other.isStaff == isStaff) &&
            (identical(other.isPartner, isPartner) ||
                other.isPartner == isPartner) &&
            (identical(other.hasNitro, hasNitro) ||
                other.hasNitro == hasNitro) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        username,
        displayName,
        avatarUrl,
        bannerUrl,
        bio,
        pronouns,
        phone,
        location,
        websiteUrl,
        socialLink,
        accentColor,
        const DeepCollectionEquality().hash(_bannerColors),
        avatarDecoration,
        onlineStatus,
        customStatus,
        customStatusEmoji,
        const DeepCollectionEquality().hash(_badges),
        isStaff,
        isPartner,
        hasNitro,
        createdAt,
        updatedAt
      ]);

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bannerUrl: $bannerUrl, bio: $bio, pronouns: $pronouns, phone: $phone, location: $location, websiteUrl: $websiteUrl, socialLink: $socialLink, accentColor: $accentColor, bannerColors: $bannerColors, avatarDecoration: $avatarDecoration, onlineStatus: $onlineStatus, customStatus: $customStatus, customStatusEmoji: $customStatusEmoji, badges: $badges, isStaff: $isStaff, isPartner: $isPartner, hasNitro: $hasNitro, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(
          _UserModel value, $Res Function(_UserModel) _then) =
      __$UserModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      @JsonKey(name: 'display_name') String? displayName,
      @JsonKey(name: 'avatar') String? avatarUrl,
      @JsonKey(name: 'banner') String? bannerUrl,
      String? bio,
      String? pronouns,
      String? phone,
      String? location,
      @JsonKey(name: 'website_url') String? websiteUrl,
      @JsonKey(name: 'social_link') String? socialLink,
      @JsonKey(name: 'accent_color') String? accentColor,
      @JsonKey(name: 'banner_colors') List<String>? bannerColors,
      @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
      @JsonKey(name: 'online_status') String onlineStatus,
      @JsonKey(name: 'custom_status') String? customStatus,
      @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
      List<Badge> badges,
      @JsonKey(name: 'is_staff') bool isStaff,
      @JsonKey(name: 'is_partner') bool isPartner,
      @JsonKey(name: 'has_nitro') bool hasNitro,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$UserModelCopyWithImpl<$Res> implements _$UserModelCopyWith<$Res> {
  __$UserModelCopyWithImpl(this._self, this._then);

  final _UserModel _self;
  final $Res Function(_UserModel) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarUrl = freezed,
    Object? bannerUrl = freezed,
    Object? bio = freezed,
    Object? pronouns = freezed,
    Object? phone = freezed,
    Object? location = freezed,
    Object? websiteUrl = freezed,
    Object? socialLink = freezed,
    Object? accentColor = freezed,
    Object? bannerColors = freezed,
    Object? avatarDecoration = freezed,
    Object? onlineStatus = null,
    Object? customStatus = freezed,
    Object? customStatusEmoji = freezed,
    Object? badges = null,
    Object? isStaff = null,
    Object? isPartner = null,
    Object? hasNitro = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_UserModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _self.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _self.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      pronouns: freezed == pronouns
          ? _self.pronouns
          : pronouns // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      websiteUrl: freezed == websiteUrl
          ? _self.websiteUrl
          : websiteUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      socialLink: freezed == socialLink
          ? _self.socialLink
          : socialLink // ignore: cast_nullable_to_non_nullable
              as String?,
      accentColor: freezed == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerColors: freezed == bannerColors
          ? _self._bannerColors
          : bannerColors // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      avatarDecoration: freezed == avatarDecoration
          ? _self.avatarDecoration
          : avatarDecoration // ignore: cast_nullable_to_non_nullable
              as String?,
      onlineStatus: null == onlineStatus
          ? _self.onlineStatus
          : onlineStatus // ignore: cast_nullable_to_non_nullable
              as String,
      customStatus: freezed == customStatus
          ? _self.customStatus
          : customStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      customStatusEmoji: freezed == customStatusEmoji
          ? _self.customStatusEmoji
          : customStatusEmoji // ignore: cast_nullable_to_non_nullable
              as String?,
      badges: null == badges
          ? _self._badges
          : badges // ignore: cast_nullable_to_non_nullable
              as List<Badge>,
      isStaff: null == isStaff
          ? _self.isStaff
          : isStaff // ignore: cast_nullable_to_non_nullable
              as bool,
      isPartner: null == isPartner
          ? _self.isPartner
          : isPartner // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNitro: null == hasNitro
          ? _self.hasNitro
          : hasNitro // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
