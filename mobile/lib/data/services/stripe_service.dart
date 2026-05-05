import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/subscription_model.dart';

/// Provides a singleton [StripeService] via Riverpod.
final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService(ref.watch(dioProvider));
});

/// Service layer for Stripe payment operations.
///
/// Responsibilities:
///   1. Initialize Stripe SDK with the publishable key.
///   2. Communicate with the Flicko backend to create PaymentIntents.
///   3. Initialize and present the Stripe PaymentSheet.
///   4. Fetch the current subscription from the backend.
///   5. Cancel or restore subscriptions via the backend.
///
/// All backend calls go through [Dio] so interceptors (auth headers,
/// logging, retry) are applied consistently from [dioProvider].
class StripeService {
  final Dio _dio;

  /// Backend base URL — typically loaded from AppConfig or .env.
  /// Should point to your Flicko backend that wraps Stripe's server-side API.
  static const String _backendPaymentEndpoint = '/api/payments';

  StripeService(this._dio);

  // ──────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────

  /// Initializes the Stripe SDK with the publishable key from [AppConfig].
  /// Must be called once before any other Stripe operations (typically in main.dart).
  Future<void> initialize() async {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // ──────────────────────────────────────────────────────────
  // Payment Flow
  // ──────────────────────────────────────────────────────────

  /// Creates a PaymentIntent on the backend and returns the client secret
  /// along with optional customer ID and ephemeral key for the PaymentSheet.
  ///
  /// [plan] – The subscription plan to purchase (e.g., `basic`, `plus`).
  /// [billingCycle] – Monthly or yearly billing cadence.
  ///
  /// Returns a map with keys: `clientSecret`, `customerId`, `ephemeralKey`.
  Future<Map<String, dynamic>> createPaymentIntent({
    required SubscriptionPlan plan,
    BillingCycle billingCycle = BillingCycle.monthly,
  }) async {
    final response = await _dio.post(
      '$_backendPaymentEndpoint/create-payment-intent',
      data: {
        'plan': plan.name,
        'billing_cycle': billingCycle.name,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Initializes the Stripe PaymentSheet with the given parameters.
  ///
  /// [clientSecret] – The PaymentIntent client secret from [createPaymentIntent].
  /// [customerId] – Optional Stripe customer ID for returning customers.
  /// [ephemeralKey] – Optional ephemeral key for secure customer operations.
  Future<void> initPaymentSheet({
    required String clientSecret,
    String? customerId,
    String? ephemeralKey,
  }) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Flicko',
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        applePay: const PaymentSheetApplePay(
          merchantCountryCode: 'IN',
        ),
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'IN',
          testEnv: true, // Set to false for production
        ),
        style: ThemeMode.dark,
      ),
    );
  }

  /// Presents the native Stripe PaymentSheet to the user.
  ///
  /// Throws [StripeException] if the user cancels or an error occurs.
  Future<void> presentPaymentSheet() async {
    await Stripe.instance.presentPaymentSheet();
  }

  // ──────────────────────────────────────────────────────────
  // Subscription Management
  // ──────────────────────────────────────────────────────────

  /// Fetches the current user's active subscription from the backend.
  ///
  /// Returns `null` if no active subscription exists.
  Future<SubscriptionModel?> fetchSubscription() async {
    try {
      final response = await _dio.get('$_backendPaymentEndpoint/subscription');
      if (response.statusCode == 200 && response.data != null) {
        return SubscriptionModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      // 404 means no subscription found — not an error
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Requests the backend to cancel the current subscription.
  ///
  /// The subscription typically remains active until the end of the current
  /// billing period (`cancel_at_period_end: true`).
  ///
  /// Returns `true` if cancellation was acknowledged by the backend.
  Future<bool> cancelSubscription() async {
    final response = await _dio.post('$_backendPaymentEndpoint/cancel');
    return response.statusCode == 200;
  }

  /// Restores purchases by checking the backend for any active subscription
  /// tied to the current authenticated user.
  ///
  /// Returns the subscription if found, `null` otherwise.
  Future<SubscriptionModel?> restorePurchases() async {
    try {
      final response = await _dio.get('$_backendPaymentEndpoint/restore');
      if (response.statusCode == 200 && response.data != null) {
        return SubscriptionModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
