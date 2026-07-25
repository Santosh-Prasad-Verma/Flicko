import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _PremiumBillingScreenState extends ConsumerState<PremiumBillingScreen>
    with SingleTickerProviderStateMixin {
  bool _isPurchasing = false;
  String _purchasingPlan = '';
  int _selectedPlanIndex = 1; // Default to Plus (popular)
  late AnimationController _shimmerController;

  // Premium color palette
  static const Color lime = Color(0xFFC0EC54);
  static const Color limeGlow = Color(0xFF9BD03B);
  static const Color deepBlack = Color(0xFF050508);
  static const Color cardSurface = Color(0xFF0C0C10);
  static const Color borderSubtle = Color(0xFF1A1A22);
  static const Color white = Color(0xFFFBF9FA);
  static const Color purple = Color(0xFFAB8FFF);
  static const Color purpleGlow = Color(0xFF8B6FDF);

  static const _plans = [
    _PlanData(
      id: 'free',
      title: 'Basic',
      subtitle: 'GET STARTED',
      price: '₹0',
      period: '/forever',
      accent: Color(0xFF71717A),
      features: [
        _FeatureItem('Standard Profile', true),
        _FeatureItem('Join Public Drops', true),
        _FeatureItem('Basic Chat', true),
        _FeatureItem('Custom Emojis', false),
        _FeatureItem('HD Streaming', false),
        _FeatureItem('Priority Support', false),
      ],
    ),
    _PlanData(
      id: 'plus',
      title: 'Flicko Plus',
      subtitle: 'MOST POPULAR',
      price: '₹799',
      period: '/month',
      accent: lime,
      features: [
        _FeatureItem('Everything in Basic', true),
        _FeatureItem('Custom Emojis & Stickers', true),
        _FeatureItem('Verified Badge', true),
        _FeatureItem('Custom Themes', true),
        _FeatureItem('Priority Support', true),
        _FeatureItem('4K Streaming', false),
      ],
    ),
    _PlanData(
      id: 'pro',
      title: 'Flicko Pro',
      subtitle: 'ULTIMATE',
      price: '₹1,599',
      period: '/month',
      accent: purple,
      features: [
        _FeatureItem('Everything in Plus', true),
        _FeatureItem('4K Streaming', true),
        _FeatureItem('4GB File Uploads', true),
        _FeatureItem('Early Access Features', true),
        _FeatureItem('Exclusive Pro Badge', true),
        _FeatureItem('Dedicated Support', true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 36),
                    _buildPlanSelector(),
                    const SizedBox(height: 32),
                    _buildSelectedPlanCard(),
                    const SizedBox(height: 24),
                    _buildFeatureComparison(),
                    const SizedBox(height: 32),
                    _buildTrustBadges(),
                    const SizedBox(height: 24),
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

  // ═══════════════════════════════════════════
  // ── APP BAR ──
  // ═══════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Image.asset('assets/images/back.png',
                  width: 18, height: 18, fit: BoxFit.contain),
            ),
          ),
          Row(
            children: [
              Icon(Icons.diamond_rounded, color: lime, size: 20),
              const SizedBox(width: 8),
              Text(
                'Membership',
                style: GoogleFonts.outfit(
                  color: white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 38), // Balance
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── HERO SECTION ──
  // ═══════════════════════════════════════════
  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F1A0A),
                const Color(0xFF0A0F06),
                const Color(0xFF0D0D14),
              ],
            ),
            border: Border.all(
              color: lime.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: lime.withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Animated icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lime, limeGlow],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lime.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.black, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Upgrade Your\nExperience',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unlock premium features, custom themes, and priority access.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // ── PLAN SELECTOR PILLS ──
  // ═══════════════════════════════════════════
  Widget _buildPlanSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle),
      ),
      child: Row(
        children: List.generate(_plans.length, (i) {
          final plan = _plans[i];
          final isSelected = _selectedPlanIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedPlanIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? plan.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: plan.accent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(
                      plan.title.split(' ').last,
                      style: GoogleFonts.outfit(
                        color: isSelected
                            ? Colors.black
                            : white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (i == 1 && !isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: lime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: GoogleFonts.inter(
                            color: lime,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── SELECTED PLAN CARD ──
  // ═══════════════════════════════════════════
  Widget _buildSelectedPlanCard() {
    final plan = _plans[_selectedPlanIndex];
    final isPaid = _selectedPlanIndex > 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(plan.id),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isPaid
                ? plan.accent.withValues(alpha: 0.3)
                : borderSubtle,
            width: isPaid ? 1.5 : 1,
          ),
          boxShadow: isPaid
              ? [
                  BoxShadow(
                    color: plan.accent.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: -10,
                    offset: const Offset(0, 16),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan badge + subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: plan.accent.withValues(alpha: isPaid ? 1.0 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    plan.subtitle,
                    style: GoogleFonts.outfit(
                      color: isPaid ? Colors.black : plan.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (_selectedPlanIndex == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lime, width: 1.2),
                    ),
                    child: Text(
                      'CURRENT',
                      style: GoogleFonts.outfit(
                        color: lime,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              plan.title,
              style: GoogleFonts.outfit(
                color: white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.price,
                  style: GoogleFonts.outfit(
                    color: plan.accent,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  plan.period,
                  style: GoogleFonts.inter(
                    color: white.withValues(alpha: 0.35),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Features
            ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: f.included
                              ? plan.accent.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          f.included
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 14,
                          color: f.included
                              ? plan.accent
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        f.name,
                        style: GoogleFonts.inter(
                          color: f.included
                              ? white
                              : white.withValues(alpha: 0.25),
                          fontSize: 14,
                          fontWeight:
                              f.included ? FontWeight.w600 : FontWeight.w400,
                          decoration: f.included
                              ? null
                              : TextDecoration.lineThrough,
                          decorationColor: white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                )),

            // CTA Button
            if (isPaid) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isPurchasing ? null : () => _handlePurchase(plan.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: plan.id == 'plus'
                          ? [lime, limeGlow]
                          : [purple, purpleGlow],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: plan.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isPurchasing && _purchasingPlan == plan.id
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rocket_launch_rounded,
                                  color: Colors.black, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'Subscribe to ${plan.title}',
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── FEATURE COMPARISON ──
  // ═══════════════════════════════════════════
  Widget _buildFeatureComparison() {
    final compareFeatures = [
      ('Custom Emojis', false, true, true),
      ('Custom Themes', false, true, true),
      ('Verified Badge', false, true, true),
      ('HD Streaming', true, true, true),
      ('4K Streaming', false, false, true),
      ('Upload Limit', '50MB', '500MB', '4GB'),
      ('Priority Support', false, true, true),
      ('Early Access', false, false, true),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.compare_arrows_rounded,
                    color: lime, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Compare Plans',
                  style: GoogleFonts.outfit(
                    color: white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderSubtle),
                bottom: BorderSide(color: borderSubtle),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Feature',
                      style: GoogleFonts.inter(
                          color: white.withValues(alpha: 0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                ...['Basic', 'Plus', 'Pro'].map((h) => Expanded(
                      flex: 2,
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              color: white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    )),
              ],
            ),
          ),
          ...compareFeatures.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: white.withValues(alpha: 0.03)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      f.$1,
                      style: GoogleFonts.inter(
                        color: white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildCompareCell(f.$2, const Color(0xFF71717A)),
                  _buildCompareCell(f.$3, lime),
                  _buildCompareCell(f.$4, purple),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompareCell(Object value, Color accent) {
    return Expanded(
      flex: 2,
      child: Center(
        child: value is bool
            ? Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value
                      ? accent.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  value ? Icons.check_rounded : Icons.close_rounded,
                  size: 12,
                  color: value
                      ? accent
                      : Colors.white.withValues(alpha: 0.12),
                ),
              )
            : Text(
                value.toString(),
                style: GoogleFonts.spaceMono(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── TRUST BADGES ──
  // ═══════════════════════════════════════════
  Widget _buildTrustBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildTrustItem(Icons.lock_rounded, 'Encrypted\nPayments'),
          const SizedBox(width: 12),
          _buildTrustItem(Icons.autorenew_rounded, 'Cancel\nAnytime'),
          const SizedBox(width: 12),
          _buildTrustItem(Icons.shield_rounded, 'Secure\nBilling'),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: lime.withValues(alpha: 0.6), size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── LEGAL FOOTER ──
  // ═══════════════════════════════════════════
  Widget _buildLegalFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(height: 1, color: borderSubtle),
          const SizedBox(height: 16),
          Text(
            'Subscriptions auto-renew monthly. Cancel anytime from your account settings. '
            'All transactions are processed securely.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: white.withValues(alpha: 0.2),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flicko v4.0.0',
            style: GoogleFonts.spaceMono(
              color: white.withValues(alpha: 0.08),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PURCHASE FLOW ──
  // ═══════════════════════════════════════════

  Future<void> _handlePurchase(String planName) async {
    setState(() {
      _isPurchasing = true;
      _purchasingPlan = planName;
    });

    final bool hasLiveGateway =
        AppConfig.hasApiBaseUrl && AppConfig.razorpayKeyId.isNotEmpty;

    if (hasLiveGateway) {
      await _handleLiveGatewayPurchase(planName);
    } else {
      dev.log(
        '[BILLING] Live gateway not configured. '
        'Presenting activation dialog.',
      );
      await _handleDirectActivation(planName);
    }

    if (mounted) {
      setState(() {
        _isPurchasing = false;
        _purchasingPlan = '';
      });
    }
  }

  /// Full Razorpay payment flow: create order → launch checkout → verify.
  Future<void> _handleLiveGatewayPurchase(String planName) async {
    try {
      final razorpayService = ref.read(razorpayServiceProvider);
      final plan = planName == 'plus'
          ? SubscriptionPlan.plus
          : SubscriptionPlan.pro;

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
          _showSuccessSnackBar(planName);
          context.go('/u/settings');
        }
      } else {
        throw Exception('Payment verification failed');
      }
    } catch (e) {
      dev.log('[BILLING] Live gateway error: $e');
      if (mounted) {
        await _handleDirectActivation(planName);
      }
    }
  }

  /// Direct activation: writes a subscription record to Supabase when no
  /// payment gateway is configured. Shows a confirmation dialog.
  Future<void> _handleDirectActivation(String planName) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0F),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lime.withValues(alpha: 0.15), width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lime.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.diamond_rounded, color: lime, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Activate ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'}',
                style: GoogleFonts.outfit(
                  color: white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
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
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: lime.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lime.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: lime.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Payment gateway is being set up. '
                      'You can activate your subscription directly.',
                      style: GoogleFonts.inter(
                        color: white.withValues(alpha: 0.6),
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Activate ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'} '
              'with full premium access for 30 days?',
              style: GoogleFonts.inter(
                color: white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: planName == 'plus'
                      ? [lime, limeGlow]
                      : [purple, purpleGlow],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (planName == 'plus' ? lime : purple)
                        .withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                'Activate Now',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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

      if (currentUser != null) {
        await client.from('subscriptions').upsert(
          {
            'user_id': currentUser.id,
            'plan': planName,
            'status': 'active',
            'store': 'direct',
            'current_period_start': DateTime.now().toIso8601String(),
            'current_period_end': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'cancel_at_period_end': false,
          },
          onConflict: 'user_id',
        );

        try {
          await client.from('profiles').update({
            'is_premium': true,
            'premium_plan': planName,
          }).eq('id', currentUser.id);
        } catch (e) {
          dev.log('[BILLING] Profile update skipped: $e');
        }
      }

      if (mounted) {
        _showSuccessSnackBar(planName);
        context.go('/u/settings');
      }
    } catch (e) {
      dev.log('[BILLING] Activation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: white,
              ),
            ),
            backgroundColor: const Color(0xFFFF5252),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  void _showSuccessSnackBar(String planName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 12),
            Text(
              'Welcome to ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'}!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: lime,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ── DATA MODELS ──
// ═══════════════════════════════════════════

class _PlanData {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String period;
  final Color accent;
  final List<_FeatureItem> features;

  const _PlanData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.accent,
    required this.features,
  });
}

class _FeatureItem {
  final String name;
  final bool included;

  const _FeatureItem(this.name, this.included);
}
