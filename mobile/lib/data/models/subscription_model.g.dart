// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubscriptionModel _$SubscriptionModelFromJson(Map<String, dynamic> json) =>
    _SubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plan: $enumDecode(_$SubscriptionPlanEnumMap, json['plan']),
      status: $enumDecode(_$SubscriptionStatusEnumMap, json['status']),
      store: json['store'] as String? ?? 'razorpay',
      currentPeriodStart: json['current_period_start'] as String?,
      currentPeriodEnd: json['current_period_end'] as String?,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$SubscriptionModelToJson(_SubscriptionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'plan': _$SubscriptionPlanEnumMap[instance.plan]!,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'store': instance.store,
      'current_period_start': instance.currentPeriodStart,
      'current_period_end': instance.currentPeriodEnd,
      'cancel_at_period_end': instance.cancelAtPeriodEnd,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

const _$SubscriptionPlanEnumMap = {
  SubscriptionPlan.basic: 'basic',
  SubscriptionPlan.plus: 'plus',
  SubscriptionPlan.pro: 'pro',
  SubscriptionPlan.basicYearly: 'basic_yearly',
  SubscriptionPlan.plusYearly: 'plus_yearly',
  SubscriptionPlan.proYearly: 'pro_yearly',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.canceled: 'canceled',
  SubscriptionStatus.pastDue: 'past_due',
  SubscriptionStatus.incomplete: 'incomplete',
  SubscriptionStatus.trialing: 'trialing',
};
