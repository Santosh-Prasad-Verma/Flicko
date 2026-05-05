import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/subscription_model.dart';
import 'package:mobile/core/services/app_logger.dart';

/// Provides a singleton [RazorpayService] via Riverpod.
final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  return RazorpayService(ref.watch(dioProvider));
});

/// Service layer for Razorpay payment operations.
class RazorpayService {
  final Dio _dio;
  final Razorpay _razorpay = Razorpay();
  
  Completer<Map<String, dynamic>>? _paymentCompleter;

  static const String _backendPaymentEndpoint = '/api/payments';

  RazorpayService(this._dio) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  // ──────────────────────────────────────────────────────────
  // Payment Flow
  // ──────────────────────────────────────────────────────────

  /// Creates an Order on the backend and returns the Order ID.
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

  /// Starts the Razorpay checkout process.
  Future<Map<String, dynamic>> startPayment({
    required String orderId,
    required double amount,
    required String userEmail,
    required String userPhone,
    String description = 'Flicko Plus Subscription',
  }) async {
    _paymentCompleter = Completer<Map<String, dynamic>>();

    var options = {
      'key': AppConfig.razorpayKeyId,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'Flicko',
      'order_id': orderId,
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      },
      'theme': {
        'color': '#5865F2' // Blurple
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      AppLogger.e('Error opening Razorpay: $e');
      _paymentCompleter?.completeError(e);
    }

    return _paymentCompleter!.future;
  }

  /// Verifies the payment on the backend.
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

  // ──────────────────────────────────────────────────────────
  // Handlers
  // ──────────────────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    AppLogger.i('Razorpay Payment Success: ${response.paymentId}');
    _paymentCompleter?.complete({
      'status': 'success',
      'paymentId': response.paymentId,
      'orderId': response.orderId,
      'signature': response.signature,
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppLogger.e('Razorpay Payment Error: ${response.code} - ${response.message}');
    _paymentCompleter?.completeError({
      'status': 'error',
      'code': response.code,
      'message': response.message,
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    AppLogger.i('Razorpay External Wallet: ${response.walletName}');
  }
}
