// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SubscriptionModel {
  String get id;
  @JsonKey(name: 'user_id')
  String get userId;
  SubscriptionPlan get plan;
  SubscriptionStatus get status;
  String get store;
  @JsonKey(name: 'current_period_start')
  String? get currentPeriodStart;
  @JsonKey(name: 'current_period_end')
  String? get currentPeriodEnd;
  @JsonKey(name: 'cancel_at_period_end')
  bool get cancelAtPeriodEnd;
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @JsonKey(name: 'updated_at')
  String? get updatedAt;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubscriptionModelCopyWith<SubscriptionModel> get copyWith =>
      _$SubscriptionModelCopyWithImpl<SubscriptionModel>(
          this as SubscriptionModel, _$identity);

  /// Serializes this SubscriptionModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SubscriptionModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.plan, plan) || other.plan == plan) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.store, store) || other.store == store) &&
            (identical(other.currentPeriodStart, currentPeriodStart) ||
                other.currentPeriodStart == currentPeriodStart) &&
            (identical(other.currentPeriodEnd, currentPeriodEnd) ||
                other.currentPeriodEnd == currentPeriodEnd) &&
            (identical(other.cancelAtPeriodEnd, cancelAtPeriodEnd) ||
                other.cancelAtPeriodEnd == cancelAtPeriodEnd) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      plan,
      status,
      store,
      currentPeriodStart,
      currentPeriodEnd,
      cancelAtPeriodEnd,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'SubscriptionModel(id: $id, userId: $userId, plan: $plan, status: $status, store: $store, currentPeriodStart: $currentPeriodStart, currentPeriodEnd: $currentPeriodEnd, cancelAtPeriodEnd: $cancelAtPeriodEnd, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $SubscriptionModelCopyWith<$Res> {
  factory $SubscriptionModelCopyWith(
          SubscriptionModel value, $Res Function(SubscriptionModel) _then) =
      _$SubscriptionModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      SubscriptionPlan plan,
      SubscriptionStatus status,
      String store,
      @JsonKey(name: 'current_period_start') String? currentPeriodStart,
      @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
      @JsonKey(name: 'cancel_at_period_end') bool cancelAtPeriodEnd,
      @JsonKey(name: 'created_at') String? createdAt,
      @JsonKey(name: 'updated_at') String? updatedAt});
}

/// @nodoc
class _$SubscriptionModelCopyWithImpl<$Res>
    implements $SubscriptionModelCopyWith<$Res> {
  _$SubscriptionModelCopyWithImpl(this._self, this._then);

  final SubscriptionModel _self;
  final $Res Function(SubscriptionModel) _then;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? plan = null,
    Object? status = null,
    Object? store = null,
    Object? currentPeriodStart = freezed,
    Object? currentPeriodEnd = freezed,
    Object? cancelAtPeriodEnd = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      plan: null == plan
          ? _self.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as SubscriptionPlan,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SubscriptionStatus,
      store: null == store
          ? _self.store
          : store // ignore: cast_nullable_to_non_nullable
              as String,
      currentPeriodStart: freezed == currentPeriodStart
          ? _self.currentPeriodStart
          : currentPeriodStart // ignore: cast_nullable_to_non_nullable
              as String?,
      currentPeriodEnd: freezed == currentPeriodEnd
          ? _self.currentPeriodEnd
          : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelAtPeriodEnd: null == cancelAtPeriodEnd
          ? _self.cancelAtPeriodEnd
          : cancelAtPeriodEnd // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SubscriptionModel].
extension SubscriptionModelPatterns on SubscriptionModel {
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
    TResult Function(_SubscriptionModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel() when $default != null:
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
    TResult Function(_SubscriptionModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel():
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
    TResult? Function(_SubscriptionModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel() when $default != null:
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
            @JsonKey(name: 'user_id') String userId,
            SubscriptionPlan plan,
            SubscriptionStatus status,
            String store,
            @JsonKey(name: 'current_period_start') String? currentPeriodStart,
            @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
            @JsonKey(name: 'cancel_at_period_end') bool cancelAtPeriodEnd,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'updated_at') String? updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.plan,
            _that.status,
            _that.store,
            _that.currentPeriodStart,
            _that.currentPeriodEnd,
            _that.cancelAtPeriodEnd,
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
            @JsonKey(name: 'user_id') String userId,
            SubscriptionPlan plan,
            SubscriptionStatus status,
            String store,
            @JsonKey(name: 'current_period_start') String? currentPeriodStart,
            @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
            @JsonKey(name: 'cancel_at_period_end') bool cancelAtPeriodEnd,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'updated_at') String? updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel():
        return $default(
            _that.id,
            _that.userId,
            _that.plan,
            _that.status,
            _that.store,
            _that.currentPeriodStart,
            _that.currentPeriodEnd,
            _that.cancelAtPeriodEnd,
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
            @JsonKey(name: 'user_id') String userId,
            SubscriptionPlan plan,
            SubscriptionStatus status,
            String store,
            @JsonKey(name: 'current_period_start') String? currentPeriodStart,
            @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
            @JsonKey(name: 'cancel_at_period_end') bool cancelAtPeriodEnd,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'updated_at') String? updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubscriptionModel() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.plan,
            _that.status,
            _that.store,
            _that.currentPeriodStart,
            _that.currentPeriodEnd,
            _that.cancelAtPeriodEnd,
            _that.createdAt,
            _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SubscriptionModel implements SubscriptionModel {
  const _SubscriptionModel(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      required this.plan,
      required this.status,
      this.store = 'stripe',
      @JsonKey(name: 'current_period_start') this.currentPeriodStart,
      @JsonKey(name: 'current_period_end') this.currentPeriodEnd,
      @JsonKey(name: 'cancel_at_period_end') this.cancelAtPeriodEnd = false,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt});
  factory _SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final SubscriptionPlan plan;
  @override
  final SubscriptionStatus status;
  @override
  @JsonKey()
  final String store;
  @override
  @JsonKey(name: 'current_period_start')
  final String? currentPeriodStart;
  @override
  @JsonKey(name: 'current_period_end')
  final String? currentPeriodEnd;
  @override
  @JsonKey(name: 'cancel_at_period_end')
  final bool cancelAtPeriodEnd;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SubscriptionModelCopyWith<_SubscriptionModel> get copyWith =>
      __$SubscriptionModelCopyWithImpl<_SubscriptionModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SubscriptionModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SubscriptionModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.plan, plan) || other.plan == plan) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.store, store) || other.store == store) &&
            (identical(other.currentPeriodStart, currentPeriodStart) ||
                other.currentPeriodStart == currentPeriodStart) &&
            (identical(other.currentPeriodEnd, currentPeriodEnd) ||
                other.currentPeriodEnd == currentPeriodEnd) &&
            (identical(other.cancelAtPeriodEnd, cancelAtPeriodEnd) ||
                other.cancelAtPeriodEnd == cancelAtPeriodEnd) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      plan,
      status,
      store,
      currentPeriodStart,
      currentPeriodEnd,
      cancelAtPeriodEnd,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'SubscriptionModel(id: $id, userId: $userId, plan: $plan, status: $status, store: $store, currentPeriodStart: $currentPeriodStart, currentPeriodEnd: $currentPeriodEnd, cancelAtPeriodEnd: $cancelAtPeriodEnd, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$SubscriptionModelCopyWith<$Res>
    implements $SubscriptionModelCopyWith<$Res> {
  factory _$SubscriptionModelCopyWith(
          _SubscriptionModel value, $Res Function(_SubscriptionModel) _then) =
      __$SubscriptionModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      SubscriptionPlan plan,
      SubscriptionStatus status,
      String store,
      @JsonKey(name: 'current_period_start') String? currentPeriodStart,
      @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
      @JsonKey(name: 'cancel_at_period_end') bool cancelAtPeriodEnd,
      @JsonKey(name: 'created_at') String? createdAt,
      @JsonKey(name: 'updated_at') String? updatedAt});
}

/// @nodoc
class __$SubscriptionModelCopyWithImpl<$Res>
    implements _$SubscriptionModelCopyWith<$Res> {
  __$SubscriptionModelCopyWithImpl(this._self, this._then);

  final _SubscriptionModel _self;
  final $Res Function(_SubscriptionModel) _then;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? plan = null,
    Object? status = null,
    Object? store = null,
    Object? currentPeriodStart = freezed,
    Object? currentPeriodEnd = freezed,
    Object? cancelAtPeriodEnd = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_SubscriptionModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      plan: null == plan
          ? _self.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as SubscriptionPlan,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SubscriptionStatus,
      store: null == store
          ? _self.store
          : store // ignore: cast_nullable_to_non_nullable
              as String,
      currentPeriodStart: freezed == currentPeriodStart
          ? _self.currentPeriodStart
          : currentPeriodStart // ignore: cast_nullable_to_non_nullable
              as String?,
      currentPeriodEnd: freezed == currentPeriodEnd
          ? _self.currentPeriodEnd
          : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelAtPeriodEnd: null == cancelAtPeriodEnd
          ? _self.cancelAtPeriodEnd
          : cancelAtPeriodEnd // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
