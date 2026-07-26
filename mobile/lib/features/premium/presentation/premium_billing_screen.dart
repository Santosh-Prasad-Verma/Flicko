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
  bool _isAnnual = true; // Annual billing toggle with 20% discount
  late AnimationController _glowController;

  // Premium Vibrant Color System
  static const Color limePrimary = Color(0xFFC0EC54);
  static const Color limeGlow = Color(0xFF8DC621);
  static const Color cyanAccent = Color(0xFF00F2FE);
  static const Color purplePrimary = Color(0xFFB57CFF);
  static const Color purpleGlow = Color(0xFF8F43FF);
  static const Color deepBg = Color(0xFF08090C);
  static const Color cardSurface = Color(0xFF111319);
  static const Color borderGlass = Color(0xFF222634);
  static const Color textWhite = Color(0xFFF9FAFB);

  static const _plans = [
    _PlanData(
      id: 'free',
      title: 'Basic',
      badge: 'STARTER',
      monthlyPrice: '₹0',
      annualPrice: '₹0',
      period: 'Forever Free',
      accent: Color(0xFF6B7280),
      gradient: [Color(0xFF1F2937), Color(0xFF111827)],
      features: [
        _FeatureItem('Standard User Profile', true),
        _FeatureItem('Join Public Servers & Drops', true),
        _FeatureItem('Standard Text & Voice Chat', true),
        _FeatureItem('Custom Emojis & Soundboard', false),
        _FeatureItem('1080p HD Screen Sharing', false),
        _FeatureItem('Verified Golden Badge', false),
        _FeatureItem('500MB Large File Uploads', false),
      ],
    ),
    _PlanData(
      id: 'plus',
      title: 'Flicko Plus',
      badge: 'MOST POPULAR ⭐️',
      monthlyPrice: '₹799',
      annualPrice: '₹639',
      period: '/month',
      accent: limePrimary,
      gradient: [Color(0xFF162A0D), Color(0xFF0D1608)],
      features: [
        _FeatureItem('Everything in Basic', true),
        _FeatureItem('Custom Emojis & Animated Stickers', true),
        _FeatureItem('Golden Verified Star Badge', true),
        _FeatureItem('Animated Profile Banners & Themes', true),
        _FeatureItem('1080p 60FPS HD Streaming', true),
        _FeatureItem('500MB Large File Uploads', true),
        _FeatureItem('Priority VIP Support', true),
      ],
    ),
    _PlanData(
      id: 'pro',
      title: 'Flicko Pro',
      badge: 'ULTIMATE VIP ⚡',
      monthlyPrice: '₹1,599',
      annualPrice: '₹1,279',
      period: '/month',
      accent: purplePrimary,
      gradient: [Color(0xFF231238), Color(0xFF130920)],
      features: [
        _FeatureItem('Everything in Plus', true),
        _FeatureItem('4K Ultra HD 60FPS Streaming', true),
        _FeatureItem('4GB Massive File Uploads', true),
        _FeatureItem('Early Access AI Features', true),
        _FeatureItem('Exclusive Cyber Pro Crown Badge', true),
        _FeatureItem('Dedicated 24/7 VIP Concierge', true),
        _FeatureItem('Unlimited Bot Automations', true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeroBanner(),
                    const SizedBox(height: 28),
                    _buildBillingToggle(),
                    const SizedBox(height: 24),
                    _buildPlanTabs(),
                    const SizedBox(height: 24),
                    _buildSelectedPlanCard(),
                    const SizedBox(height: 32),
                    _buildKeyFeaturesGrid(),
                    const SizedBox(height: 32),
                    _buildComparisonMatrix(),
                    const SizedBox(height: 32),
                    _buildTrustGuaranteeBar(),
                    const SizedBox(height: 24),
                    _buildFooterInfo(),
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
  // ── HEADER BAR ──
  // ═══════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF171A24))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [limePrimary, cyanAccent],
                ).createShader(bounds),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 8),
              Text(
                'Flicko Premium',
                style: GoogleFonts.outfit(
                  color: textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── HERO BANNER ──
  // ═══════════════════════════════════════════
  Widget _buildHeroBanner() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowValue = _glowController.value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF172D12), const Color(0xFF26183B), glowValue)!,
                const Color(0xFF0F1219),
                const Color(0xFF07080C),
              ],
            ),
            border: Border.all(
              color: Color.lerp(limePrimary.withValues(alpha: 0.4),
                  purplePrimary.withValues(alpha: 0.4), glowValue)!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(limePrimary.withValues(alpha: 0.15),
                    purplePrimary.withValues(alpha: 0.15), glowValue)!,
                blurRadius: 36,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Glowing Icon Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [limePrimary, cyanAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: limePrimary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.black, size: 36),
              ),
              const SizedBox(height: 20),
              
              // Badge Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: limePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: limePrimary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'UNLEASH FULL POWER',
                  style: GoogleFonts.outfit(
                    color: limePrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Supercharge Your Flicko',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: textWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Unlock 4K streaming, custom emojis, massive file sharing, and exclusive member badges.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: textWhite.withValues(alpha: 0.65),
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
  // ── MONTHLY / ANNUAL BILLING TOGGLE ──
  // ═══════════════════════════════════════════
  Widget _buildBillingToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGlass),
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
                  color: !_isAnnual
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'Monthly Billing',
                    style: GoogleFonts.outfit(
                      color: !_isAnnual ? textWhite : textWhite.withValues(alpha: 0.5),
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
                  color: _isAnnual ? limePrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isAnnual
                      ? [
                          BoxShadow(
                            color: limePrimary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Annual Billing',
                        style: GoogleFonts.outfit(
                          color: _isAnnual ? Colors.black : textWhite.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isAnnual ? Colors.black : limePrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SAVE 20%',
                          style: GoogleFonts.outfit(
                            color: _isAnnual ? limePrimary : Colors.black,
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
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PLAN SELECTION TABS ──
  // ═══════════════════════════════════════════
  Widget _buildPlanTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                margin: EdgeInsets.only(
                    left: i == 0 ? 0 : 4, right: i == _plans.length - 1 ? 0 : 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? plan.accent.withValues(alpha: 0.15) : cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? plan.accent : borderGlass,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      plan.title.split(' ').last,
                      style: GoogleFonts.outfit(
                        color: isSelected ? plan.accent : textWhite.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isAnnual ? plan.annualPrice : plan.monthlyPrice,
                      style: GoogleFonts.outfit(
                        color: isSelected ? textWhite : textWhite.withValues(alpha: 0.35),
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
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── SELECTED PLAN CARD ──
  // ═══════════════════════════════════════════
  Widget _buildSelectedPlanCard() {
    final plan = _plans[_selectedPlanIndex];
    final isPaid = _selectedPlanIndex > 0;
    final priceDisplay = _isAnnual ? plan.annualPrice : plan.monthlyPrice;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('${plan.id}_$_isAnnual'),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: plan.gradient,
          ),
          border: Border.all(
            color: isPaid ? plan.accent.withValues(alpha: 0.5) : borderGlass,
            width: isPaid ? 2 : 1,
          ),
          boxShadow: isPaid
              ? [
                  BoxShadow(
                    color: plan.accent.withValues(alpha: 0.2),
                    blurRadius: 36,
                    spreadRadius: -6,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge & Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: plan.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: plan.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    plan.badge,
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (_isAnnual && isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Billed Annually',
                      style: GoogleFonts.inter(
                        color: textWhite,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Plan Title
            Text(
              plan.title,
              style: GoogleFonts.outfit(
                color: textWhite,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),

            // Price Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceDisplay,
                  style: GoogleFonts.outfit(
                    color: plan.accent,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  plan.period,
                  style: GoogleFonts.inter(
                    color: textWhite.withValues(alpha: 0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 24),

            // Features List
            ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: f.included
                              ? plan.accent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          f.included ? Icons.check_rounded : Icons.close_rounded,
                          size: 14,
                          color: f.included ? plan.accent : Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          f.name,
                          style: GoogleFonts.inter(
                            color: f.included ? textWhite : textWhite.withValues(alpha: 0.3),
                            fontSize: 14,
                            fontWeight: f.included ? FontWeight.w600 : FontWeight.w400,
                            decoration: f.included ? null : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            if (isPaid) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isPurchasing ? null : () => _handlePurchase(plan.id),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: plan.id == 'plus'
                          ? [limePrimary, limeGlow]
                          : [purplePrimary, purpleGlow],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: plan.accent.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
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
                              const Icon(Icons.rocket_launch_rounded,
                                  color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Activate ${plan.title} Now',
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
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
  // ── KEY FEATURES HIGHLIGHT GRID ──
  // ═══════════════════════════════════════════
  Widget _buildKeyFeaturesGrid() {
    final highlights = [
      (Icons.emoji_emotions_rounded, 'Custom Emojis', 'Use custom stickers & animated emojis across all servers.'),
      (Icons.high_quality_rounded, '1080p / 4K Streaming', 'Stream your games and movies in crystal clear high FPS.'),
      (Icons.verified_rounded, 'Verified Badge', 'Show off a shiny golden star badge on your profile.'),
      (Icons.cloud_upload_rounded, '500MB Uploads', 'Share large videos, zip files, and audio without limits.'),
      (Icons.color_lens_rounded, 'Custom Themes', 'Personalize Flicko with neon glass background themes.'),
      (Icons.headset_mic_rounded, 'VIP Server Perks', 'Enjoy priority voice server quality and 24/7 VIP support.'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Upgrade to Flicko Plus?',
            style: GoogleFonts.outfit(
              color: textWhite,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: highlights.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final item = highlights[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderGlass),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: limePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.$1, color: limePrimary, size: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.$2,
                      style: GoogleFonts.outfit(
                        color: textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textWhite.withValues(alpha: 0.5),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── COMPARISON MATRIX ──
  // ═══════════════════════════════════════════
  Widget _buildComparisonMatrix() {
    final compareFeatures = [
      ('Custom Emojis & Stickers', false, true, true),
      ('Custom Themes & Banners', false, true, true),
      ('Verified Member Badge', false, true, true),
      ('Stream Quality', '720p', '1080p 60FPS', '4K 60FPS'),
      ('Max File Upload', '50MB', '500MB', '4GB'),
      ('Priority Support', false, true, true),
      ('Early AI Access', false, false, true),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGlass),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows_rounded,
                    color: limePrimary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Full Feature Comparison',
                  style: GoogleFonts.outfit(
                    color: textWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: borderGlass),
                bottom: BorderSide(color: borderGlass),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('FEATURE',
                      style: GoogleFonts.inter(
                          color: textWhite.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
                ...['Basic', 'Plus', 'Pro'].map((h) => Expanded(
                      flex: 2,
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              color: textWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    )),
              ],
            ),
          ),
          ...compareFeatures.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      f.$1,
                      style: GoogleFonts.inter(
                        color: textWhite.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildCompareCell(f.$2, Colors.grey),
                  _buildCompareCell(f.$3, limePrimary),
                  _buildCompareCell(f.$4, purplePrimary),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
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
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value
                      ? accent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  value ? Icons.check_rounded : Icons.close_rounded,
                  size: 14,
                  color: value ? accent : Colors.white24,
                ),
              )
            : Text(
                value.toString(),
                style: GoogleFonts.spaceMono(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── TRUST & GUARANTEE BAR ──
  // ═══════════════════════════════════════════
  Widget _buildTrustGuaranteeBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildTrustItem(Icons.lock_rounded, '256-Bit SSL\nSecure Payment'),
          const SizedBox(width: 10),
          _buildTrustItem(Icons.autorenew_rounded, 'Cancel Anytime\n1-Click'),
          const SizedBox(width: 10),
          _buildTrustItem(Icons.bolt_rounded, 'Instant\nActivation'),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderGlass),
        ),
        child: Column(
          children: [
            Icon(icon, color: limePrimary, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: textWhite.withValues(alpha: 0.5),
                fontSize: 11,
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
  // ── FOOTER INFO ──
  // ═══════════════════════════════════════════
  Widget _buildFooterInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            'Subscriptions auto-renew monthly or annually. Cancel anytime in account settings. All transactions are end-to-end encrypted.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textWhite.withValues(alpha: 0.3),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flicko Premium v4.2.0',
            style: GoogleFonts.spaceMono(
              color: textWhite.withValues(alpha: 0.15),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PURCHASE LOGIC & RAZORPAY INTEGRATION ──
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
      dev.log('[BILLING] Direct activation fallback.');
      await _handleDirectActivation(planName);
    }

    if (mounted) {
      setState(() {
        _isPurchasing = false;
        _purchasingPlan = '';
      });
    }
  }

  Future<void> _handleLiveGatewayPurchase(String planName) async {
    try {
      final razorpayService = ref.read(razorpayServiceProvider);
      final plan = planName == 'plus'
          ? SubscriptionPlan.plus
          : SubscriptionPlan.pro;

      final orderData = await razorpayService.createOrder(
        plan: plan,
        billingCycle: _isAnnual ? BillingCycle.yearly : BillingCycle.monthly,
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
      final formattedAmount = planName == 'plus'
          ? (_isAnnual ? '₹639/mo' : '₹799/mo')
          : (_isAnnual ? '₹1279/mo' : '₹1599/mo');

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

  Future<void> _handleDirectActivation(String planName) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1218),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: limePrimary, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: limePrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: limePrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Activate ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'}',
                style: GoogleFonts.outfit(
                  color: textWhite,
                  fontWeight: FontWeight.w800,
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
            Text(
              'Confirm activating ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'} (${_isAnnual ? 'Annual Discount' : 'Monthly'}) with full instant access?',
              style: GoogleFonts.inter(
                color: textWhite.withValues(alpha: 0.8),
                fontSize: 14,
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
                color: textWhite.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: limePrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Activate Now',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
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
                .add(Duration(days: _isAnnual ? 365 : 30))
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
    }
  }

  void _showSuccessSnackBar(String planName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: Colors.black, size: 22),
            const SizedBox(width: 12),
            Text(
              'Welcome to ${planName == 'plus' ? 'Flicko Plus' : 'Flicko Pro'}!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ],
        ),
        backgroundColor: limePrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  final String badge;
  final String monthlyPrice;
  final String annualPrice;
  final String period;
  final Color accent;
  final List<Color> gradient;
  final List<_FeatureItem> features;

  const _PlanData({
    required this.id,
    required this.title,
    required this.badge,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.period,
    required this.accent,
    required this.gradient,
    required this.features,
  });
}

class _FeatureItem {
  final String name;
  final bool included;

  const _FeatureItem(this.name, this.included);
}
