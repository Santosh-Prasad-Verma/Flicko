// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerModel {
  String get id;
  String get name;
  String? get description;
  @JsonKey(name: 'icon')
  String? get iconUrl;
  @JsonKey(name: 'banner')
  String? get bannerUrl;
  @JsonKey(name: 'owner_id')
  String get ownerId;
  @JsonKey(name: 'member_count')
  int get memberCount;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of ServerModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ServerModelCopyWith<ServerModel> get copyWith =>
      _$ServerModelCopyWithImpl<ServerModel>(this as ServerModel, _$identity);

  /// Serializes this ServerModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ServerModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description, iconUrl,
      bannerUrl, ownerId, memberCount, createdAt);

  @override
  String toString() {
    return 'ServerModel(id: $id, name: $name, description: $description, iconUrl: $iconUrl, bannerUrl: $bannerUrl, ownerId: $ownerId, memberCount: $memberCount, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $ServerModelCopyWith<$Res> {
  factory $ServerModelCopyWith(
          ServerModel value, $Res Function(ServerModel) _then) =
      _$ServerModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(name: 'icon') String? iconUrl,
      @JsonKey(name: 'banner') String? bannerUrl,
      @JsonKey(name: 'owner_id') String ownerId,
      @JsonKey(name: 'member_count') int memberCount,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class _$ServerModelCopyWithImpl<$Res> implements $ServerModelCopyWith<$Res> {
  _$ServerModelCopyWithImpl(this._self, this._then);

  final ServerModel _self;
  final $Res Function(ServerModel) _then;

  /// Create a copy of ServerModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? bannerUrl = freezed,
    Object? ownerId = null,
    Object? memberCount = null,
    Object? createdAt = null,
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _self.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: null == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String,
      memberCount: null == memberCount
          ? _self.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [ServerModel].
extension ServerModelPatterns on ServerModel {
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
    TResult Function(_ServerModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ServerModel() when $default != null:
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
    TResult Function(_ServerModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ServerModel():
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
    TResult? Function(_ServerModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ServerModel() when $default != null:
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
            String name,
            String? description,
            @JsonKey(name: 'icon') String? iconUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            @JsonKey(name: 'owner_id') String ownerId,
            @JsonKey(name: 'member_count') int memberCount,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ServerModel() when $default != null:
        return $default(_that.id, _that.name, _that.description, _that.iconUrl,
            _that.bannerUrl, _that.ownerId, _that.memberCount, _that.createdAt);
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
            String name,
            String? description,
            @JsonKey(name: 'icon') String? iconUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            @JsonKey(name: 'owner_id') String ownerId,
            @JsonKey(name: 'member_count') int memberCount,
            @JsonKey(name: 'created_at') DateTime createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ServerModel():
        return $default(_that.id, _that.name, _that.description, _that.iconUrl,
            _that.bannerUrl, _that.ownerId, _that.memberCount, _that.createdAt);
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
            String name,
            String? description,
            @JsonKey(name: 'icon') String? iconUrl,
            @JsonKey(name: 'banner') String? bannerUrl,
            @JsonKey(name: 'owner_id') String ownerId,
            @JsonKey(name: 'member_count') int memberCount,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ServerModel() when $default != null:
        return $default(_that.id, _that.name, _that.description, _that.iconUrl,
            _that.bannerUrl, _that.ownerId, _that.memberCount, _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ServerModel implements ServerModel {
  const _ServerModel(
      {required this.id,
      required this.name,
      this.description,
      @JsonKey(name: 'icon') this.iconUrl,
      @JsonKey(name: 'banner') this.bannerUrl,
      @JsonKey(name: 'owner_id') required this.ownerId,
      @JsonKey(name: 'member_count') this.memberCount = 0,
      @JsonKey(name: 'created_at') required this.createdAt});
  factory _ServerModel.fromJson(Map<String, dynamic> json) =>
      _$ServerModelFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey(name: 'icon')
  final String? iconUrl;
  @override
  @JsonKey(name: 'banner')
  final String? bannerUrl;
  @override
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @override
  @JsonKey(name: 'member_count')
  final int memberCount;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Create a copy of ServerModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ServerModelCopyWith<_ServerModel> get copyWith =>
      __$ServerModelCopyWithImpl<_ServerModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ServerModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ServerModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description, iconUrl,
      bannerUrl, ownerId, memberCount, createdAt);

  @override
  String toString() {
    return 'ServerModel(id: $id, name: $name, description: $description, iconUrl: $iconUrl, bannerUrl: $bannerUrl, ownerId: $ownerId, memberCount: $memberCount, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$ServerModelCopyWith<$Res>
    implements $ServerModelCopyWith<$Res> {
  factory _$ServerModelCopyWith(
          _ServerModel value, $Res Function(_ServerModel) _then) =
      __$ServerModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(name: 'icon') String? iconUrl,
      @JsonKey(name: 'banner') String? bannerUrl,
      @JsonKey(name: 'owner_id') String ownerId,
      @JsonKey(name: 'member_count') int memberCount,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class __$ServerModelCopyWithImpl<$Res> implements _$ServerModelCopyWith<$Res> {
  __$ServerModelCopyWithImpl(this._self, this._then);

  final _ServerModel _self;
  final $Res Function(_ServerModel) _then;

  /// Create a copy of ServerModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? bannerUrl = freezed,
    Object? ownerId = null,
    Object? memberCount = null,
    Object? createdAt = null,
  }) {
    return _then(_ServerModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _self.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: null == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String,
      memberCount: null == memberCount
          ? _self.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
