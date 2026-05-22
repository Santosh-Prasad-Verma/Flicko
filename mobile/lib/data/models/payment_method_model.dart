import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_method_model.freezed.dart';
part 'payment_method_model.g.dart';

@freezed
abstract class PaymentMethodModel with _$PaymentMethodModel {
  const factory PaymentMethodModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'card_number_last_four') required String cardNumberLastFour,
    @JsonKey(name: 'card_type') String? cardType,
    @JsonKey(name: 'expiry_month') required int expiryMonth,
    @JsonKey(name: 'expiry_year') required int expiryYear,
    @JsonKey(name: 'cardholder_name') String? cardholderName,
    @JsonKey(name: 'is_default') @Default(false) bool isDefault,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _PaymentMethodModel;

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) => _$PaymentMethodModelFromJson(json);
}
