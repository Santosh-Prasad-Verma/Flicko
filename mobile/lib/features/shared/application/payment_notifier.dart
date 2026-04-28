import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mobile/data/models/payment_state.dart';
import 'package:mobile/data/models/subscription_model.dart';
import 'package:mobile/data/services/stripe_service.dart';

/// Riverpod provider for [PaymentNotifier].
///
/// Manages the complete lifecycle of a Stripe payment flow:
///   CreatePaymentIntent → InitPaymentSheet → PresentPaymentSheet
///
/// Also exposes subscription management (fetch, cancel, restore).
final paymentNotifierProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref.watch(stripeServiceProvider));
});

/// Convenience provider that exposes the current user subscription.
///
/// Reads from [paymentNotifierProvider] success state if available,
/// or triggers an initial fetch.
final currentSubscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final stripeService = ref.watch(stripeServiceProvider);
  return stripeService.fetchSubscription();
});

/// State notifier that orchestrates the Stripe payment flow.
///
/// Pattern mirrors [AuthNotifier]:
///   - Union-based states via freezed ([PaymentState])
///   - Single service dependency injected via constructor
///   - Methods correspond 1:1 to user-facing actions
class PaymentNotifier extends StateNotifier<PaymentState> {
  final StripeService _stripeService;

  PaymentNotifier(this._stripeService) : super(const PaymentState.initial());

  /// Full purchase flow: create intent → init sheet → present sheet.
  ///
  /// [plan] – Which subscription plan to purchase.
  /// [billingCycle] – Monthly or yearly billing cadence.
  ///
  /// On success, fetches the updated subscription and moves to [PaymentState.success].
  /// On cancellation by user, moves to [PaymentState.cancelled].
  /// On error, moves to [PaymentState.error] with a descriptive message.
  Future<void> purchaseSubscription({
    required SubscriptionPlan plan,
    BillingCycle billingCycle = BillingCycle.monthly,
  }) async {
    try {
      // Step 1: Loading → create PaymentIntent on the backend
      state = const PaymentState.loading(message: 'Creating payment intent...');

      final intentData = await _stripeService.createPaymentIntent(
        plan: plan,
        billingCycle: billingCycle,
      );

      final clientSecret = intentData['clientSecret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        state = const PaymentState.error('Failed to retrieve payment intent from server.');
        return;
      }

      // Step 2: Initialize the PaymentSheet
      state = const PaymentState.loading(message: 'Initializing payment sheet...');

      await _stripeService.initPaymentSheet(
        clientSecret: clientSecret,
        customerId: intentData['customerId'] as String?,
        ephemeralKey: intentData['ephemeralKey'] as String?,
      );

      state = const PaymentState.ready();

      // Step 3: Present the PaymentSheet to the user
      await _stripeService.presentPaymentSheet();

      // Step 4: Payment succeeded — refresh subscription data
      state = const PaymentState.loading(message: 'Confirming subscription...');
      final subscription = await _stripeService.fetchSubscription();

      state = PaymentState.success(subscription: subscription);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        state = const PaymentState.cancelled();
      } else {
        state = PaymentState.error(
          e.error.localizedMessage ?? 'A payment error occurred.',
        );
      }
    } catch (e) {
      state = PaymentState.error(e.toString());
    }
  }

  /// Cancels the current subscription via the backend.
  ///
  /// The subscription remains active until the end of the billing period.
  Future<bool> cancelSubscription() async {
    try {
      state = const PaymentState.loading(message: 'Cancelling subscription...');
      final success = await _stripeService.cancelSubscription();

      if (success) {
        final subscription = await _stripeService.fetchSubscription();
        state = PaymentState.success(subscription: subscription);
      } else {
        state = const PaymentState.error('Failed to cancel subscription.');
      }

      return success;
    } catch (e) {
      state = PaymentState.error(e.toString());
      return false;
    }
  }

  /// Restore purchases by re-fetching subscription from the backend.
  Future<SubscriptionModel?> restorePurchases() async {
    try {
      state = const PaymentState.loading(message: 'Restoring purchases...');
      final subscription = await _stripeService.restorePurchases();

      if (subscription != null) {
        state = PaymentState.success(subscription: subscription);
      } else {
        state = const PaymentState.error('No active subscription found.');
      }

      return subscription;
    } catch (e) {
      state = PaymentState.error(e.toString());
      return null;
    }
  }

  /// Resets the payment state (e.g., after dismissing an error dialog).
  void reset() {
    state = const PaymentState.initial();
  }
}
