// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentMethodModel _$PaymentMethodModelFromJson(Map<String, dynamic> json) =>
    _PaymentMethodModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cardNumberLastFour: json['card_number_last_four'] as String,
      cardType: json['card_type'] as String?,
      expiryMonth: (json['expiry_month'] as num).toInt(),
      expiryYear: (json['expiry_year'] as num).toInt(),
      cardholderName: json['cardholder_name'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentMethodModelToJson(_PaymentMethodModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'card_number_last_four': instance.cardNumberLastFour,
      'card_type': instance.cardType,
      'expiry_month': instance.expiryMonth,
      'expiry_year': instance.expiryYear,
      'cardholder_name': instance.cardholderName,
      'is_default': instance.isDefault,
      'created_at': instance.createdAt.toIso8601String(),
    };
