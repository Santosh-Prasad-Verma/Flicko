import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Process payment for store items
  /// Returns PaymentResult with success status and payment details
  Future<PaymentResult> processPayment({
    required double amount,
    required String userEmail,
    required String userPhone,
    required String description,
    required List<CartItem> items,
  }) async {
    try {
      // Create order via backend
      final orderData = await _razorpayService.createStoreOrder(
        amount: amount,
        items: items.map((i) => {
          'product_id': i.product.id,
          'quantity': i.quantity,
          'price': i.product.price,
        }).toList(),
      );

      final orderId = orderData['id'] as String;
      final amountPaise = orderData['amount'] as num;

      // Start Razorpay payment
      final paymentResult = await _razorpayService.startPayment(
        orderId: orderId,
        amount: amountPaise / 100.0,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
      );

      // Verify payment
      final isVerified = await _razorpayService.verifyPayment(
        orderId: orderId,
        paymentId: paymentResult['paymentId'] as String,
        signature: paymentResult['signature'] as String,
        email: userEmail,
        username: '',
        amount: '\$${amount.toStringAsFixed(2)}',
      );

      if (isVerified) {
        // Record purchase in Supabase
        await _recordPurchases(items, paymentResult['paymentId'] as String);

        return PaymentResult(
          success: true,
          paymentId: paymentResult['paymentId'] as String,
          orderId: orderId,
        );
      } else {
        return PaymentResult(
          success: false,
          error: 'Payment verification failed',
        );
      }
    } catch (e) {
      dev.log('[STORE_PAYMENT] Error: $e');
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
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

/// Extension to RazorpayService for store orders
extension StoreOrderExtension on RazorpayService {
  Future<Map<String, dynamic>> createStoreOrder({
    required double amount,
    required List<Map<String, dynamic>> items,
  }) async {
    // This would typically call your backend endpoint
    // For now, return a mock order for development
    return {
      'id': 'order_store_${DateTime.now().millisecondsSinceEpoch}',
      'amount': (amount * 100).toInt(),
      'currency': 'USD',
      'status': 'created',
    };
  }
}
