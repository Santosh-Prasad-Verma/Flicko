import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/subscription_model.dart';
import 'package:mobile/data/services/razorpay_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'dart:developer' as dev;

class PremiumBillingScreen extends ConsumerStatefulWidget {
  const PremiumBillingScreen({super.key});

  @override
  ConsumerState<PremiumBillingScreen> createState() => _PremiumBillingScreenState();
}

class _PlanModel {
  final String id;
  final String title;
  final String badge;
  final String monthlyPrice;
  final String annualPrice;
  final String period;
  final Color accentColor;
  final List<String> highlights;

  const _PlanModel({
    required this.id,
    required this.title,
    required this.badge,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.period,
    required this.accentColor,
    required this.highlights,
  });
}

class _PremiumBillingScreenState extends ConsumerState<PremiumBillingScreen> {
  bool _isPurchasing = false;
  String _purchasingPlan = '';
  int _selectedPlanIndex = 1; // Default to Plus
  bool _isAnnual = true; // Annual billing toggle with 20% discount

  static const Color accentLime = Color(FlickoColors.brandLime);
  static const Color darkBg = Color(0xFF0D0E12);
  static const Color cardBg = Color(0xFF161820);
  static const Color borderLine = Color(0xFF262A36);

  static const List<_PlanModel> _plans = [
    _PlanModel(
      id: 'free',
      title: 'Free',
      badge: 'STARTER',
      monthlyPrice: '₹0',
      annualPrice: '₹0',
      period: 'Forever',
      accentColor: Color(0xFF8E8E93),
      highlights: [
        'Standard User Profile & Status',
        'Join Public Servers & Channels',
        'Standard Voice & Text Messaging',
        '720p 30FPS Screen Sharing',
        '50MB File Attachment Limit',
      ],
    ),
    _PlanModel(
      id: 'plus',
      title: 'Flicko Plus',
      badge: 'RECOMMENDED',
      monthlyPrice: '₹799',
      annualPrice: '₹639',
      period: '/ month',
      accentColor: accentLime,
      highlights: [
        'Everything in Free Plan',
        'Custom Emojis & Animated Stickers',
        'Verified Golden Profile Star Badge',
        '1080p 60FPS HD Screen Sharing',
        '500MB Large File Upload Limit',
        'Custom Background Themes & Banners',
        'Priority Voice Server Quality',
      ],
    ),
    _PlanModel(
      id: 'pro',
      title: 'Flicko Pro',
      badge: 'ULTIMATE',
      monthlyPrice: '₹1,599',
      annualPrice: '₹1,279',
      period: '/ month',
      accentColor: Color(0xFFB57CFF),
      highlights: [
        'Everything in Plus Plan',
        '4K Ultra HD 60FPS Screen Sharing',
        '4GB Massive File Upload Limit',
        'Exclusive VIP Cyber Crown Badge',
        'Early Access to AI Automations',
        'Dedicated 24/7 VIP Support Concierge',
        'Unlimited Custom Soundboard Slots',
      ],
    ),
  ];

  Future<void> _handlePurchase(String planId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upgrade subscription')),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
      _purchasingPlan = planId;
    });

    try {
      final isAnnual = _isAnnual;
      final amountInRupees = planId == 'plus'
          ? (isAnnual ? 639 * 12 : 799)
          : (isAnnual ? 1279 * 12 : 1599);

      final razorpay = ref.read(razorpayServiceProvider);
      final planEnum = planId == 'plus'
          ? (isAnnual ? SubscriptionPlan.plusYearly : SubscriptionPlan.plus)
          : (isAnnual ? SubscriptionPlan.proYearly : SubscriptionPlan.pro);

      String orderId;
      try {
        final order = await razorpay.createOrder(
          plan: planEnum,
          billingCycle: isAnnual ? BillingCycle.yearly : BillingCycle.monthly,
        );
        orderId = order['id'] as String? ?? 'order_dummy_${DateTime.now().millisecondsSinceEpoch}';
      } catch (_) {
        orderId = 'order_sandbox_${DateTime.now().millisecondsSinceEpoch}';
      }

      await razorpay.startPayment(
        orderId: orderId,
        amount: amountInRupees.toDouble(),
        userEmail: user.email ?? 'user@flicko.tech',
        userPhone: '',
        description: 'Flicko ${planId.toUpperCase()} (${isAnnual ? "Annual" : "Monthly"})',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: accentLime,
          content: Text(
            '🎉 Welcome to Flicko ${planId.toUpperCase()}! Your premium perks are active.',
            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      dev.log('Purchase error: $e', name: 'PremiumBilling');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment cancelled or failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _purchasingPlan = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_selectedPlanIndex];

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Flicko Premium',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Header Section
              _buildCleanHeroHeader(),
              const SizedBox(height: 24),

              // Billing Toggle (Monthly vs Annual)
              _buildBillingToggle(),
              const SizedBox(height: 24),

              // Plan Selector Cards
              _buildPlanSelectorTabs(),
              const SizedBox(height: 24),

              // Selected Plan Highlights Card
              _buildSelectedPlanCard(selectedPlan),
              const SizedBox(height: 28),

              // Simple Features Grid
              _buildFeaturesGrid(),
              const SizedBox(height: 32),

              // Trust Footer
              _buildFooterTrust(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderLine),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentLime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentLime.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: accentLime, size: 14),
                const SizedBox(width: 6),
                Text(
                  'UPGRADE YOUR EXPERIENCE',
                  style: GoogleFonts.outfit(
                    color: accentLime,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Simple, Powerful Perks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy HD video streaming, custom emojis, higher file upload limits, and profile customization.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isAnnual = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isAnnual ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Monthly',
                    style: GoogleFonts.inter(
                      color: !_isAnnual ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isAnnual = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isAnnual ? accentLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Annual',
                      style: GoogleFonts.inter(
                        color: _isAnnual ? Colors.black : Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isAnnual ? Colors.black : accentLime,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '20% OFF',
                        style: GoogleFonts.outfit(
                          color: _isAnnual ? accentLime : Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelectorTabs() {
    return Row(
      children: List.generate(_plans.length, (index) {
        final plan = _plans[index];
        final isSelected = _selectedPlanIndex == index;
        final price = _isAnnual ? plan.annualPrice : plan.monthlyPrice;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedPlanIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == _plans.length - 1 ? 0 : 4,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? plan.accentColor.withValues(alpha: 0.12) : cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? plan.accentColor : borderLine,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    plan.title,
                    style: GoogleFonts.outfit(
                      color: isSelected ? plan.accentColor : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedPlanCard(_PlanModel plan) {
    final isPaid = plan.id != 'free';
    final priceDisplay = _isAnnual ? plan.annualPrice : plan.monthlyPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPaid ? plan.accentColor.withValues(alpha: 0.6) : borderLine,
          width: isPaid ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.badge,
                  style: GoogleFonts.outfit(
                    color: plan.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (_isAnnual && isPaid)
                Text(
                  'Billed Annually',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                priceDisplay,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                plan.period,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: borderLine),
          const SizedBox(height: 16),
          ...plan.highlights.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: plan.accentColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: plan.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isPurchasing ? null : () => _handlePurchase(plan.id),
                child: _isPurchasing && _purchasingPlan == plan.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Get ${plan.title}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final features = const [
      (Icons.high_quality_rounded, 'HD Streaming', '1080p & 4K high FPS video output.'),
      (Icons.emoji_emotions_rounded, 'Custom Emojis', 'Use custom stickers in any server.'),
      (Icons.verified_rounded, 'Golden Badge', 'Show off a verified star on your profile.'),
      (Icons.cloud_upload_rounded, '500MB Uploads', 'Share videos & zips without size limits.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Included Perks',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final f = features[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f.$1, color: accentLime, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    f.$2,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooterTrust() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(
          'Encrypted payment via Razorpay. Cancel anytime.',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
