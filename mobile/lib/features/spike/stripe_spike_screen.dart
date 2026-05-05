import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/config/app_config.dart';

class StripeSpikeScreen extends StatefulWidget {
  const StripeSpikeScreen({super.key});

  @override
  State<StripeSpikeScreen> createState() => _StripeSpikeScreenState();
}

class _StripeSpikeScreenState extends State<StripeSpikeScreen> {
  bool _isReady = false;
  bool _isLoading = false;
  String? _statusMessage;
  
  // Replace with your actual backend endpoint to fetch standard payment intents
  final String _backendUrl = 'https://your-flicko-backend.internal';

  @override
  void initState() {
    super.initState();
    _initStripe();
  }

  Future<void> _initStripe() async {
    // 1. Initialize Stripe with the publishable key from configuration
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
    setState(() {
      _isReady = true;
    });
  }

  Future<void> _testPaymentFlow() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Fetching payment intent from backend...";
    });

    try {
      // 2. Fetch the PaymentIntent client secret from your backend
      // This is a placeholder standard API call
      // Response requires: { clientSecret, customerId, ephemeralKey, publishableKey }
      
      // final response = await Dio().post('\$_backendUrl/create-payment-intent', data: {'amount': 1000});
      // final data = response.data;

      // Mocked secret for UI demonstration (Will fail Stripe validation without a real one)
      final String clientSecret = "pi_test_123456_secret_123456"; 

      setState(() {
         _statusMessage = "Initializing Payment Sheet...";
      });

      // 3. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Flicko Spike Test',
          // customerId: data['customer'],
          // customerEphemeralKeySecret: data['ephemeralKey'],
          // Optional: Add Apple Pay / Google Pay
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
          googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true),
        ),
      );

      setState(() {
        _statusMessage = "Presenting Payment Sheet...";
      });

      // 4. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      setState(() {
        _statusMessage = "Payment completed successfully!";
      });

    } on StripeException catch (e) {
      setState(() {
        if (e.error.code == FailureCode.Canceled) {
          _statusMessage = "Payment was cancelled.";
        } else {
          _statusMessage = "Stripe Error: \${e.error.localizedMessage}";
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: \$e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stripe Payments Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Validate Stripe Payment Sheet Integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Test Product: 1 Month Flicko Subscription\nPrice: \$10.00'),
                    const SizedBox(height: 16),
                    if (!_isReady)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testPaymentFlow,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Pay with Stripe', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black12,
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
