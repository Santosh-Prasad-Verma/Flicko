import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/subscription_model.dart';

final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  return RazorpayService(ref.watch(dioProvider));
});

class RazorpayService {
  final Dio _dio;
  static const String _backendPaymentEndpoint = '/api/payments';

  RazorpayService(this._dio);

  /// Call backend to create a Razorpay order.
  Future<Map<String, dynamic>> createOrder({
    required SubscriptionPlan plan,
    BillingCycle billingCycle = BillingCycle.monthly,
  }) async {
    final response = await _dio.post(
      '$_backendPaymentEndpoint/razorpay/create-order',
      data: {
        'plan': plan.name,
        'billing_cycle': billingCycle.name,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Start Razorpay payment flow. Returns a future that resolves with payment details
  /// when payment succeeds, or throws if it fails/cancels.
  Future<Map<String, dynamic>> startPayment({
    required String orderId,
    required double amount,
    required String userEmail,
    required String userPhone,
    required String description,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      completer.complete({
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
      });
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      completer.completeError(
        Exception(response.message ?? 'Payment failed or cancelled (Code: ${response.code})'),
      );
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      completer.completeError(
        Exception('External wallet selected: ${response.walletName}'),
      );
      razorpay.clear();
    });

    final options = {
      'key': AppConfig.razorpayKeyId,
      'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
      'name': 'Flicko',
      'order_id': orderId,
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'theme': {
        'color': '#52B788', // Flicko lime color
      }
    };

    try {
      razorpay.open(options);
    } catch (e) {
      razorpay.clear();
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Verify signature on backend.
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String email,
    required String username,
    required String amount,
  }) async {
    final response = await _dio.post(
      '$_backendPaymentEndpoint/razorpay/verify',
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'email': email,
        'username': username,
        'amount': amount,
      },
    );
    return response.statusCode == 200;
  }
}
