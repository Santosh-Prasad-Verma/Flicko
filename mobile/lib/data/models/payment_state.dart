import 'package:freezed_annotation/freezed_annotation.dart';
import 'subscription_model.dart';

part 'payment_state.freezed.dart';

/// Union type representing all possible states of a payment flow.
///
/// States:
///   - [initial]   → No payment in progress.
///   - [loading]   → A PaymentIntent is being created or the sheet is opening.
///   - [ready]     → Payment sheet is initialized and ready to present.
///   - [success]   → Payment completed; optional subscription attached.
///   - [cancelled] → User dismissed the payment sheet without paying.
///   - [error]     → A Stripe or network error occurred.
@freezed
abstract class PaymentState with _$PaymentState {
  const factory PaymentState.initial() = _Initial;
  const factory PaymentState.loading({String? message}) = _Loading;
  const factory PaymentState.ready() = _Ready;
  const factory PaymentState.success({SubscriptionModel? subscription}) = _Success;
  const factory PaymentState.cancelled() = _Cancelled;
  const factory PaymentState.error(String message) = _Error;
}
