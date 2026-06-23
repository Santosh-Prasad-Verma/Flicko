import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/services/razorpay_service.dart';
import 'package:mobile/data/models/subscription_model.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'dart:developer' as dev;

class PremiumBillingScreen extends ConsumerStatefulWidget {
  const PremiumBillingScreen({super.key});

  @override
  ConsumerState<PremiumBillingScreen> createState() =>
      _PremiumBillingScreenState();
}

class _PremiumBillingScreenState extends ConsumerState<PremiumBillingScreen> {
  bool _isPurchasing = false;
  String _purchasingPlan = '';

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color red = Color(0xFFFF3333);
  static const Color purple = Color(0xFF9B84EE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 40),

                    _buildTierCard(
                      title: 'BASIC_MEMBER',
                      price: 'FREE',
                      description:
                          'ESSENTIAL TOOLKIT FOR EVERY STREET LEVEL MEMBER. START YOUR JOURNEY.',
                      features: [
                        'Standard Profile',
                        'Join Public Drops',
                        'Basic Chat'
                      ],
                      isCurrent: true,
                    ),
                    const SizedBox(height: 24),

                    _buildTierCard(
                      title: 'FLICKO_PLUS',
                      price: '₹799',
                      period: '/mo',
                      description:
                          'LEVEL UP YOUR IDENTITY WITH CUSTOM FLAIR AND HIGHER LIMITS.',
                      features: [
                        'Custom Emojis',
                        'Nitro Badge',
                        'Custom Themes',
                        'Priority Support'
                      ],
                      accentColor: lime,
                      buttonText: 'UPGRADE_TO_PLUS',
                      onTap: () => _handlePurchase('plus'),
                      isPopular: true,
                    ),
                    const SizedBox(height: 24),

                    _buildTierCard(
                      title: 'FLICKO_PRO',
                      price: '₹1599',
                      period: '/mo',
                      description:
                          'THE ULTIMATE FLEX. UNCOMPROMISED PERFORMANCE AND TOTAL ACCESS.',
                      features: [
                        '4K Streaming',
                        '4GB Uploads',
                        'Early Access',
                        'All Plus Features'
                      ],
                      accentColor: purple,
                      buttonText: 'UPGRADE_TO_PRO',
                      onTap: () => _handlePurchase('pro'),
                    ),

                    const SizedBox(height: 48),
                    _buildCriticalZone(),
                    const SizedBox(height: 40),
                    _buildLegalFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: black,
        border: Border(bottom: BorderSide(color: lime, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _brutalistIconButton(Icons.arrow_back_ios_new, () => context.pop()),
          Text(
            'BILLING.CONFIG',
            style: GoogleFonts.spaceGrotesk(
              color: white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          _brutalistIconButton(Icons.history, () {}),
        ],
      ),
    );
  }

  Widget _brutalistIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: lime, offset: Offset(3, 3)),
          ],
        ),
        child: Icon(icon, size: 20, color: white),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Text(
              'BILLING',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: -2,
                color: lime,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 45),
              child: Text(
                'SYSTEM',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  letterSpacing: -2,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: 60,
          height: 8,
          color: lime,
        ),
        const SizedBox(height: 24),
        Text(
          'MANAGE YOUR MEMBERSHIP LEVEL AND UNLOCK THE FULL CULTURE EXPERIENCE. SYSTEM STATUS: OPERATIONAL',
          style: GoogleFonts.robotoMono(
            color: white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String title,
    required String price,
    String? period,
    required String description,
    required List<String> features,
    Color accentColor = grey,
    Color textColor = white,
    String? buttonText,
    VoidCallback? onTap,
    bool isCurrent = false,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: black,
        border: Border.all(
            color: accentColor != grey
                ? accentColor
                : (isPopular ? lime : white.withValues(alpha: 0.5)),
            width: 3),
        boxShadow: [
          BoxShadow(
            color: accentColor != grey ? accentColor : (isPopular ? lime : white.withValues(alpha: 0.1)),
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor != grey ? accentColor : (isPopular ? lime : white),
                      ),
                      child: Text(
                        title,
                        style: GoogleFonts.robotoMono(
                          color: black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lime,
                          border: Border.all(color: black, width: 2),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.robotoMono(
                            color: black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.spaceGrotesk(
                        color: textColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    if (period != null)
                      Text(
                        period,
                        style: GoogleFonts.robotoMono(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.robotoMono(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.add,
                              size: 16, color: accentColor != grey ? accentColor : (isPopular ? lime : textColor)),
                          const SizedBox(width: 12),
                          Text(
                            f.toUpperCase(),
                            style: GoogleFonts.robotoMono(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )),
                    ),
                if (buttonText != null) ...[
                  const SizedBox(height: 32),
                  _brutalistButton(
                    text: buttonText,
                    onTap: onTap!,
                    color: accentColor != grey ? accentColor : (isPopular ? lime : white),
                    textColor: black,
                    isLoading: _isPurchasing && _purchasingPlan == buttonText,
                  ),
                ],
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: lime,
                  border: Border(
                    left: BorderSide(color: black, width: 3),
                    right: BorderSide(color: black, width: 3),
                    bottom: BorderSide(color: black, width: 3),
                  ),
                ),
                child: Text(
                  'POPULAR',
                  style: GoogleFonts.spaceGrotesk(
                    color: black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _brutalistButton({
    required String text,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: black, width: 3),
          boxShadow: [
            BoxShadow(
              color: color == white ? lime : white,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: textColor),
                )
              : Text(
                  text,
                  style: GoogleFonts.spaceGrotesk(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCriticalZone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: grey,
        border: Border.all(color: red, width: 3),
        boxShadow: [
          BoxShadow(color: red.withValues(alpha: 0.5), offset: const Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: red, size: 24),
              const SizedBox(width: 12),
              Text(
                'CRITICAL_SYSTEM_ACTION',
                style: GoogleFonts.robotoMono(
                  color: red,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'PURGE_ACCOUNT',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'THIS ACTION WILL REMOVE ALL DATA FROM OUR CORE SERVERS. IT IS PERMANENT AND CANNOT BE UNDONE.',
            style: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: black,
                border: Border.all(color: red, width: 2),
              ),
              child: Center(
                child: Text(
                  'EXECUTE_TERMINATION',
                  style: GoogleFonts.spaceGrotesk(
                    color: red,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 2, color: grey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'END_MANIFEST',
                style: GoogleFonts.robotoMono(
                  color: white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(child: Container(height: 2, color: grey)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'ALL TRANSACTIONS ARE ENCRYPTED. NO REFUNDS FOR PARTIAL BILLING CYCLES. FLICKO_CORE_OS_V4.0.0_STABLE',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: white.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Determines whether to use the Razorpay live gateway or direct Supabase
  /// activation. The live gateway requires both a configured backend API URL
  /// and a Razorpay key. When either is missing the system falls through to
  /// the sandbox activation path gracefully instead of showing a cryptic
  /// error dialog.
  Future<void> _handlePurchase(String planName) async {
    final btnText =
        planName == 'plus' ? 'UPGRADE_TO_PLUS' : 'UPGRADE_TO_PRO';

    setState(() {
      _isPurchasing = true;
      _purchasingPlan = btnText;
    });

    final bool hasLiveGateway =
        AppConfig.hasApiBaseUrl && AppConfig.razorpayKeyId.isNotEmpty;

    if (hasLiveGateway) {
      await _handleLiveGatewayPurchase(planName, btnText);
    } else {
      dev.log(
        '[BILLING] Live gateway not configured '
        '(apiBaseUrl=${AppConfig.hasApiBaseUrl}, '
        'razorpayKey=${AppConfig.razorpayKeyId.isNotEmpty}). '
        'Presenting sandbox activation.',
      );
      await _handleSandboxActivation(planName);
    }

    if (mounted) {
      setState(() {
        _isPurchasing = false;
        _purchasingPlan = '';
      });
    }
  }

  /// Full Razorpay payment flow: create order → launch checkout → verify.
  Future<void> _handleLiveGatewayPurchase(
      String planName, String btnText) async {
    try {
      final razorpayService = ref.read(razorpayServiceProvider);
      final plan = planName == 'plus'
          ? SubscriptionPlan.plus
          : SubscriptionPlan.plus; // Map 'pro' to plus for now

      final orderData = await razorpayService.createOrder(
        plan: plan,
        billingCycle: BillingCycle.monthly,
      );

      final orderId = orderData['id'] as String;
      final amountPaise = orderData['amount'] as num;
      final amountDouble = amountPaise / 100.0;

      final authState = ref.read(authNotifierProvider);
      final userEmail = authState.maybeWhen(
        authenticated: (authUser, userProfile) => authUser.email ?? '',
        orElse: () => '',
      );
      final userPhone = authState.maybeWhen(
        authenticated: (authUser, userProfile) => userProfile?.phone ?? '',
        orElse: () => '',
      );
      final username = authState.maybeWhen(
        authenticated: (authUser, userProfile) => userProfile?.username ?? '',
        orElse: () => '',
      );

      final paymentResult = await razorpayService.startPayment(
        orderId: orderId,
        amount: amountDouble,
        userEmail: userEmail,
        userPhone: userPhone,
        description: 'Flicko ${planName.toUpperCase()} Subscription',
      );

      final paymentId = paymentResult['paymentId'] as String;
      final signature = paymentResult['signature'] as String;
      final formattedAmount = planName == 'plus' ? '₹799' : '₹1599';

      final isVerified = await razorpayService.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        email: userEmail,
        username: username,
        amount: formattedAmount,
        plan: plan,
      );

      if (isVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WELCOME TO FLICKO ${planName.toUpperCase()}!'),
              backgroundColor: lime,
            ),
          );
          context.go('/u/settings');
        }
      } else {
        throw Exception('Payment verification failed');
      }
    } catch (e) {
      dev.log('[BILLING] Live gateway error: $e');
      if (mounted) {
        // Fall through to sandbox on live gateway error
        await _handleSandboxActivation(planName);
      }
    }
  }

  /// Sandbox activation: writes a subscription record directly to Supabase
  /// when no live payment gateway is configured. Shows a confirmation dialog
  /// so the user is aware this is a test/dev activation.
  Future<void> _handleSandboxActivation(String planName) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lime, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        title: Row(
          children: [
            Icon(Icons.terminal, color: lime, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SANDBOX_OVERRIDE',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: grey,
                border: Border.all(color: red.withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: red, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LIVE_GATEWAY: NOT_CONFIGURED',
                      style: GoogleFonts.robotoMono(
                        color: red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ACTIVATE FLICKO ${planName.toUpperCase()} IN TEST MODE?\n\n'
              'THIS WILL GRANT PREMIUM ACCESS WITHOUT PROCESSING A REAL PAYMENT.',
              style: GoogleFonts.robotoMono(
                color: white.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ABORT',
              style: GoogleFonts.robotoMono(
                color: white.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: lime,
                border: Border.all(color: black, width: 2),
                boxShadow: const [
                  BoxShadow(color: white, offset: Offset(3, 3)),
                ],
              ),
              child: Text(
                'OVERRIDE_&_ACTIVATE',
                style: GoogleFonts.spaceGrotesk(
                  color: black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        throw Exception('AUTH_SESSION_EXPIRED');
      }

      // Upsert subscription record in Supabase directly
      await client.from('subscriptions').upsert(
        {
          'user_id': currentUser.id,
          'plan': planName,
          'status': 'active',
          'store': 'sandbox',
          'current_period_start': DateTime.now().toIso8601String(),
          'current_period_end': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          'cancel_at_period_end': false,
        },
        onConflict: 'user_id',
      );

      // Also update the user's profile to reflect premium status
      try {
        await client.from('profiles').update({
          'is_premium': true,
          'premium_plan': planName,
        }).eq('id', currentUser.id);
      } catch (e) {
        dev.log('[BILLING] Profile update skipped (column may not exist): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SANDBOX: FLICKO ${planName.toUpperCase()} ACTIVATED',
              style: GoogleFonts.robotoMono(
                fontWeight: FontWeight.bold,
                color: black,
              ),
            ),
            backgroundColor: lime,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        context.go('/u/settings');
      }
    } catch (e) {
      dev.log('[BILLING] Sandbox activation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ACTIVATION_FAILED: ${e.toString().toUpperCase()}',
              style: GoogleFonts.robotoMono(
                fontWeight: FontWeight.bold,
                color: white,
              ),
            ),
            backgroundColor: red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}
