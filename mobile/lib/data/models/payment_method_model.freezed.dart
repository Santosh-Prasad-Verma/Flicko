// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_method_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentMethodModel {
  String get id;
  @JsonKey(name: 'user_id')
  String get userId;
  @JsonKey(name: 'card_number_last_four')
  String get cardNumberLastFour;
  @JsonKey(name: 'card_type')
  String? get cardType;
  @JsonKey(name: 'expiry_month')
  int get expiryMonth;
  @JsonKey(name: 'expiry_year')
  int get expiryYear;
  @JsonKey(name: 'cardholder_name')
  String? get cardholderName;
  @JsonKey(name: 'is_default')
  bool get isDefault;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaymentMethodModelCopyWith<PaymentMethodModel> get copyWith =>
      _$PaymentMethodModelCopyWithImpl<PaymentMethodModel>(
          this as PaymentMethodModel, _$identity);

  /// Serializes this PaymentMethodModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaymentMethodModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.cardNumberLastFour, cardNumberLastFour) ||
                other.cardNumberLastFour == cardNumberLastFour) &&
            (identical(other.cardType, cardType) ||
                other.cardType == cardType) &&
            (identical(other.expiryMonth, expiryMonth) ||
                other.expiryMonth == expiryMonth) &&
            (identical(other.expiryYear, expiryYear) ||
                other.expiryYear == expiryYear) &&
            (identical(other.cardholderName, cardholderName) ||
                other.cardholderName == cardholderName) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, cardNumberLastFour,
      cardType, expiryMonth, expiryYear, cardholderName, isDefault, createdAt);

  @override
  String toString() {
    return 'PaymentMethodModel(id: $id, userId: $userId, cardNumberLastFour: $cardNumberLastFour, cardType: $cardType, expiryMonth: $expiryMonth, expiryYear: $expiryYear, cardholderName: $cardholderName, isDefault: $isDefault, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $PaymentMethodModelCopyWith<$Res> {
  factory $PaymentMethodModelCopyWith(
          PaymentMethodModel value, $Res Function(PaymentMethodModel) _then) =
      _$PaymentMethodModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'card_number_last_four') String cardNumberLastFour,
      @JsonKey(name: 'card_type') String? cardType,
      @JsonKey(name: 'expiry_month') int expiryMonth,
      @JsonKey(name: 'expiry_year') int expiryYear,
      @JsonKey(name: 'cardholder_name') String? cardholderName,
      @JsonKey(name: 'is_default') bool isDefault,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class _$PaymentMethodModelCopyWithImpl<$Res>
    implements $PaymentMethodModelCopyWith<$Res> {
  _$PaymentMethodModelCopyWithImpl(this._self, this._then);

  final PaymentMethodModel _self;
  final $Res Function(PaymentMethodModel) _then;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? cardNumberLastFour = null,
    Object? cardType = freezed,
    Object? expiryMonth = null,
    Object? expiryYear = null,
    Object? cardholderName = freezed,
    Object? isDefault = null,
    Object? createdAt = null,
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
      cardNumberLastFour: null == cardNumberLastFour
          ? _self.cardNumberLastFour
          : cardNumberLastFour // ignore: cast_nullable_to_non_nullable
              as String,
      cardType: freezed == cardType
          ? _self.cardType
          : cardType // ignore: cast_nullable_to_non_nullable
              as String?,
      expiryMonth: null == expiryMonth
          ? _self.expiryMonth
          : expiryMonth // ignore: cast_nullable_to_non_nullable
              as int,
      expiryYear: null == expiryYear
          ? _self.expiryYear
          : expiryYear // ignore: cast_nullable_to_non_nullable
              as int,
      cardholderName: freezed == cardholderName
          ? _self.cardholderName
          : cardholderName // ignore: cast_nullable_to_non_nullable
              as String?,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [PaymentMethodModel].
extension PaymentMethodModelPatterns on PaymentMethodModel {
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
    TResult Function(_PaymentMethodModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel() when $default != null:
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
    TResult Function(_PaymentMethodModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel():
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
    TResult? Function(_PaymentMethodModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel() when $default != null:
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
            @JsonKey(name: 'card_number_last_four') String cardNumberLastFour,
            @JsonKey(name: 'card_type') String? cardType,
            @JsonKey(name: 'expiry_month') int expiryMonth,
            @JsonKey(name: 'expiry_year') int expiryYear,
            @JsonKey(name: 'cardholder_name') String? cardholderName,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.cardNumberLastFour,
            _that.cardType,
            _that.expiryMonth,
            _that.expiryYear,
            _that.cardholderName,
            _that.isDefault,
            _that.createdAt);
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
            @JsonKey(name: 'card_number_last_four') String cardNumberLastFour,
            @JsonKey(name: 'card_type') String? cardType,
            @JsonKey(name: 'expiry_month') int expiryMonth,
            @JsonKey(name: 'expiry_year') int expiryYear,
            @JsonKey(name: 'cardholder_name') String? cardholderName,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel():
        return $default(
            _that.id,
            _that.userId,
            _that.cardNumberLastFour,
            _that.cardType,
            _that.expiryMonth,
            _that.expiryYear,
            _that.cardholderName,
            _that.isDefault,
            _that.createdAt);
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
            @JsonKey(name: 'card_number_last_four') String cardNumberLastFour,
            @JsonKey(name: 'card_type') String? cardType,
            @JsonKey(name: 'expiry_month') int expiryMonth,
            @JsonKey(name: 'expiry_year') int expiryYear,
            @JsonKey(name: 'cardholder_name') String? cardholderName,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodModel() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.cardNumberLastFour,
            _that.cardType,
            _that.expiryMonth,
            _that.expiryYear,
            _that.cardholderName,
            _that.isDefault,
            _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PaymentMethodModel implements PaymentMethodModel {
  const _PaymentMethodModel(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'card_number_last_four') required this.cardNumberLastFour,
      @JsonKey(name: 'card_type') this.cardType,
      @JsonKey(name: 'expiry_month') required this.expiryMonth,
      @JsonKey(name: 'expiry_year') required this.expiryYear,
      @JsonKey(name: 'cardholder_name') this.cardholderName,
      @JsonKey(name: 'is_default') this.isDefault = false,
      @JsonKey(name: 'created_at') required this.createdAt});
  factory _PaymentMethodModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodModelFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'card_number_last_four')
  final String cardNumberLastFour;
  @override
  @JsonKey(name: 'card_type')
  final String? cardType;
  @override
  @JsonKey(name: 'expiry_month')
  final int expiryMonth;
  @override
  @JsonKey(name: 'expiry_year')
  final int expiryYear;
  @override
  @JsonKey(name: 'cardholder_name')
  final String? cardholderName;
  @override
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaymentMethodModelCopyWith<_PaymentMethodModel> get copyWith =>
      __$PaymentMethodModelCopyWithImpl<_PaymentMethodModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PaymentMethodModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaymentMethodModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.cardNumberLastFour, cardNumberLastFour) ||
                other.cardNumberLastFour == cardNumberLastFour) &&
            (identical(other.cardType, cardType) ||
                other.cardType == cardType) &&
            (identical(other.expiryMonth, expiryMonth) ||
                other.expiryMonth == expiryMonth) &&
            (identical(other.expiryYear, expiryYear) ||
                other.expiryYear == expiryYear) &&
            (identical(other.cardholderName, cardholderName) ||
                other.cardholderName == cardholderName) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, cardNumberLastFour,
      cardType, expiryMonth, expiryYear, cardholderName, isDefault, createdAt);

  @override
  String toString() {
    return 'PaymentMethodModel(id: $id, userId: $userId, cardNumberLastFour: $cardNumberLastFour, cardType: $cardType, expiryMonth: $expiryMonth, expiryYear: $expiryYear, cardholderName: $cardholderName, isDefault: $isDefault, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$PaymentMethodModelCopyWith<$Res>
    implements $PaymentMethodModelCopyWith<$Res> {
  factory _$PaymentMethodModelCopyWith(
          _PaymentMethodModel value, $Res Function(_PaymentMethodModel) _then) =
      __$PaymentMethodModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'card_number_last_four') String cardNumberLastFour,
      @JsonKey(name: 'card_type') String? cardType,
      @JsonKey(name: 'expiry_month') int expiryMonth,
      @JsonKey(name: 'expiry_year') int expiryYear,
      @JsonKey(name: 'cardholder_name') String? cardholderName,
      @JsonKey(name: 'is_default') bool isDefault,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class __$PaymentMethodModelCopyWithImpl<$Res>
    implements _$PaymentMethodModelCopyWith<$Res> {
  __$PaymentMethodModelCopyWithImpl(this._self, this._then);

  final _PaymentMethodModel _self;
  final $Res Function(_PaymentMethodModel) _then;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? cardNumberLastFour = null,
    Object? cardType = freezed,
    Object? expiryMonth = null,
    Object? expiryYear = null,
    Object? cardholderName = freezed,
    Object? isDefault = null,
    Object? createdAt = null,
  }) {
    return _then(_PaymentMethodModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      cardNumberLastFour: null == cardNumberLastFour
          ? _self.cardNumberLastFour
          : cardNumberLastFour // ignore: cast_nullable_to_non_nullable
              as String,
      cardType: freezed == cardType
          ? _self.cardType
          : cardType // ignore: cast_nullable_to_non_nullable
              as String?,
      expiryMonth: null == expiryMonth
          ? _self.expiryMonth
          : expiryMonth // ignore: cast_nullable_to_non_nullable
              as int,
      expiryYear: null == expiryYear
          ? _self.expiryYear
          : expiryYear // ignore: cast_nullable_to_non_nullable
              as int,
      cardholderName: freezed == cardholderName
          ? _self.cardholderName
          : cardholderName // ignore: cast_nullable_to_non_nullable
              as String?,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
