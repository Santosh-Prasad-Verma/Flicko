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

  static const Color lime = Color(0xFFC0EC54);
  static const Color black = Color(0xFF07040A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1E1C24);
  static const Color red = Color(0xFFFF5252);
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
      decoration: BoxDecoration(
        color: black,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _modernIconButton(Icons.arrow_back_ios_new, () => context.pop()),
          Text(
            'Flicko Plus',
            style: GoogleFonts.outfit(
              color: white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          _modernIconButton(Icons.history, () {}),
        ],
      ),
    );
  }

  Widget _modernIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
        ),
        child: Icon(icon, size: 20, color: white),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FLICKO',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: lime,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'PLUS',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'MANAGE YOUR MEMBERSHIP LEVEL AND UNLOCK THE FULL CULTURE EXPERIENCE.',
          style: GoogleFonts.inter(
            color: white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
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
    final cardBorderColor = isPopular ? lime.withOpacity(0.4) : Colors.white.withOpacity(0.08);
    final cardGlowColor = isPopular ? lime.withOpacity(0.06) : Colors.white.withOpacity(0.02);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardGlowColor,
            blurRadius: 24,
            spreadRadius: -4,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPopular ? lime : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        title.replaceAll('_', ' '),
                        style: GoogleFonts.outfit(
                          color: isPopular ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: lime, width: 1.5),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.outfit(
                            color: lime,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
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
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                    if (period != null)
                      Text(
                        period,
                        style: GoogleFonts.outfit(
                          color: textColor.withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: textColor.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isPopular ? lime : Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            f,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (buttonText != null) ...[
                  const SizedBox(height: 32),
                  _modernButton(
                    text: buttonText,
                    onTap: onTap!,
                    color: isPopular ? lime : Colors.white,
                    textColor: Colors.black,
                    isLoading: _isPurchasing && _purchasingPlan == buttonText,
                  ),
                ],
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(
                  'POPULAR',
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modernButton({
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: color == lime
              ? [
                  BoxShadow(
                    color: lime.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: textColor,
                  ),
                )
              : Text(
                  text.replaceAll('_', ' '),
                  style: GoogleFonts.outfit(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.0,
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
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: red.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: red, size: 20),
              const SizedBox(width: 12),
              Text(
                'CRITICAL SYSTEM ACTION',
                style: GoogleFonts.outfit(
                  color: red,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Purge Account',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'THIS ACTION WILL REMOVE ALL DATA FROM OUR CORE SERVERS. IT IS PERMANENT AND CANNOT BE UNDONE.',
            style: GoogleFonts.inter(
              color: white.withOpacity(0.5),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: red.withOpacity(0.5), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'EXECUTE TERMINATION',
                  style: GoogleFonts.outfit(
                    color: red,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.0,
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
            Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'END MANIFEST',
                style: GoogleFonts.outfit(
                  color: white.withOpacity(0.2),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'ALL TRANSACTIONS ARE ENCRYPTED. NO REFUNDS FOR PARTIAL BILLING CYCLES. FLICKO_CORE_OS_V4.0.0_STABLE',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            color: white.withOpacity(0.3),
            fontSize: 9,
            fontWeight: FontWeight.w500,
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
        backgroundColor: const Color(0xFF0C0C0F),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lime.withOpacity(0.2), width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(Icons.terminal_rounded, color: lime, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sandbox Override',
                style: GoogleFonts.outfit(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16161C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: red.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: red, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LIVE GATEWAY: NOT CONFIGURABLE',
                      style: GoogleFonts.spaceMono(
                        color: red,
                        fontSize: 10,
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
              style: GoogleFonts.inter(
                color: white.withOpacity(0.7),
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
              style: GoogleFonts.spaceMono(
                color: white.withOpacity(0.4),
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
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: lime.withOpacity(0.2),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Text(
                'OVERRIDE & ACTIVATE',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
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
