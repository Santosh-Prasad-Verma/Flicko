import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/services/razorpay_service.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';
import 'package:mobile/data/models/payment_method_model.dart';
import 'dart:developer' as dev;

/// Service for handling store payments
final storePaymentServiceProvider = Provider<StorePaymentService>((ref) {
  return StorePaymentService(
    ref.watch(razorpayServiceProvider),
    ref.watch(paymentMethodsProvider),
  );
});

/// Result of a payment attempt
class PaymentResult {
  final bool success;
  final String? error;
  final String? paymentId;
  final String? orderId;

  PaymentResult({
    required this.success,
    this.error,
    this.paymentId,
    this.orderId,
  });
}

class StorePaymentService {
  final RazorpayService _razorpayService;
  final AsyncValue<List<PaymentMethodModel>> _paymentMethods;

  StorePaymentService(this._razorpayService, this._paymentMethods);

  /// Check if user has any saved payment methods
  bool get hasPaymentMethods {
    return _paymentMethods.when(
      data: (methods) => methods.isNotEmpty,
      loading: () => false,
      error: (_, __) => false,
    );
  }

  /// Get default payment method
  PaymentMethodModel? get defaultPaymentMethod {
    return _paymentMethods.when(
      data: (methods) => methods.firstWhere((m) => m.isDefault, orElse: () => methods.first),
      loading: () => null,
      error: (_, __) => null,
    );
  }

  /// Attempts to charge for store items.
  ///
  /// Currently always fails: **there is no store payment path on the backend.**
  /// A real charge needs two things that do not exist yet:
  ///
  ///   1. A server endpoint that creates the Razorpay order. The backend only
  ///      exposes `/premium/orders` and `/premium/verify`, which are hardcoded
  ///      to the subscription plans and their prices — they cannot price a cart.
  ///   2. Server-side price authority. `cosmetic_catalog` has no price column,
  ///      so item prices are currently invented client-side (see
  ///      `store_service.dart`). Charging against a client-supplied price is
  ///      not something to ship.
  ///
  /// This method previously fabricated a Razorpay order id locally
  /// (`order_store_<timestamp>`), skipped signature verification, and — on any
  /// exception — granted the items anyway with a fake payment id. That meant
  /// every failure path handed out paid cosmetics for free while reporting
  /// success. Returning an explicit failure is the honest behaviour until a
  /// real endpoint exists; the caller decides what to show.
  Future<PaymentResult> processPayment({
    required double amount,
    required String userEmail,
    required String userPhone,
    required String description,
    required List<CartItem> items,
  }) async {
    dev.log(
      '[STORE_PAYMENT] Refusing to charge ₹${amount.toStringAsFixed(2)}: '
      'no backend store-order endpoint is configured.',
    );
    return PaymentResult(
      success: false,
      error: 'Store payments are not available yet.',
    );
  }

  /// Grants [items] without payment. Debug builds only.
  ///
  /// This backs the "sandbox" checkout used during development. It is guarded
  /// so a release build can never reach it: previously the same free-grant ran
  /// whenever the live gateway errored, which turned any payment outage into
  /// free cosmetics in production.
  Future<PaymentResult> grantWithoutPaymentForDebug(List<CartItem> items) async {
    if (!AppConfig.isDebug) {
      return PaymentResult(
        success: false,
        error: 'Sandbox checkout is disabled in release builds.',
      );
    }

    try {
      final sandboxPaymentId =
          'pay_debug_${DateTime.now().millisecondsSinceEpoch}';
      await _recordPurchases(items, sandboxPaymentId);
      return PaymentResult(success: true, paymentId: sandboxPaymentId);
    } catch (e) {
      return PaymentResult(success: false, error: e.toString());
    }
  }

  /// Process free items (no payment needed)
  Future<PaymentResult> processFreeItems(List<CartItem> items) async {
    try {
      await _recordPurchases(items, null);
      return PaymentResult(success: true);
    } catch (e) {
      return PaymentResult(success: false, error: e.toString());
    }
  }

  /// Record purchases in Supabase
  Future<void> _recordPurchases(List<CartItem> items, String? paymentId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    for (final item in items) {
      try {
        await client.from('user_cosmetics').insert({
          'user_id': user.id,
          'cosmetic_id': item.product.id,
          'source': 'purchase',
          'metadata': {
            'quantity': item.quantity,
            'price_per_item': item.product.price,
            'payment_id': paymentId,
          },
        });
      } catch (e) {
        dev.log('[STORE_PAYMENT] Failed to record purchase for ${item.product.id}: $e');
        // Continue with other items
      }
    }
  }

  /// Calculate total with any discounts
  double calculateTotal(List<CartItem> items, {double? discountPercent}) {
    final subtotal = items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    if (discountPercent != null && discountPercent > 0) {
      return subtotal * (1 - discountPercent / 100);
    }
    return subtotal;
  }
}

// The `StoreOrderExtension.createStoreOrder` that used to live here was removed.
// It fabricated a Razorpay order id client-side (`order_store_<timestamp>`) and
// returned it as though the gateway had issued it. Razorpay rejects ids it did
// not create, so that order could never be charged — it only served to make the
// checkout flow look wired up. A real implementation belongs on the backend,
// next to `/premium/orders`, where the price can be trusted.
