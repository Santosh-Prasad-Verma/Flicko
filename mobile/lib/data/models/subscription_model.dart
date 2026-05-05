import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_model.freezed.dart';
part 'subscription_model.g.dart';

/// Subscription plan tiers matching the React Native store.
enum SubscriptionPlan {
  @JsonValue('basic')
  basic,
  @JsonValue('plus')
  plus,
  @JsonValue('basic_yearly')
  basicYearly,
  @JsonValue('plus_yearly')
  plusYearly,
}

/// Billing cadence.
enum BillingCycle {
  @JsonValue('monthly')
  monthly,
  @JsonValue('yearly')
  yearly,
}

/// Backend subscription status.
enum SubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('canceled')
  canceled,
  @JsonValue('past_due')
  pastDue,
  @JsonValue('incomplete')
  incomplete,
  @JsonValue('trialing')
  trialing,
}

/// Represents a user's subscription returned from the backend.
@freezed
class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required SubscriptionPlan plan,
    required SubscriptionStatus status,
    @Default('stripe') String store,
    @JsonKey(name: 'current_period_start') String? currentPeriodStart,
    @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
    @JsonKey(name: 'cancel_at_period_end') @Default(false) bool cancelAtPeriodEnd,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _SubscriptionModel;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);
}
