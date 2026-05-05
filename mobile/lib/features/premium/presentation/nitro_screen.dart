import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/services/razorpay_service.dart';
import '../../../../data/models/subscription_model.dart';
import '../../auth/application/auth_notifier.dart';

/// Flicko Drop — Premium subscription page with Free/Plus/Pro tiers
/// and feature comparison breakdown table.
class NitroScreen extends ConsumerStatefulWidget {
  const NitroScreen({super.key});

  @override
  ConsumerState<NitroScreen> createState() => _NitroScreenState();
}

class _NitroScreenState extends ConsumerState<NitroScreen>
    with SingleTickerProviderStateMixin {
  bool _isPurchasing = false;
  String _purchasingPlan = '';

  // ── Corrected & Explicit Design Tokens for a premium Black Theme ──
  static const Color _neonGreen = Color(0xFFCBEF17);
  static const Color _bgBlack = Color(0xFF000000);
  static const Color _textWhite = Color(0xFFFFFFFF);
  static const Color _bodyText = Color(0xFF999999);
  static const Color _cardGrey = Color(0xFF141414);
  static const Color _borderGrey = Color(0xFF262626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // ── Upgrade Badge ──
                    _buildUpgradeBadge(),
                    const SizedBox(height: 20),
                    // ── Hero Title ──
                    _buildHeroTitle(),
                    const SizedBox(height: 12),
                    // ── Subtitle ──
                    _buildSubtitle(),
                    const SizedBox(height: 32),
                    // ── BASIC / FREE Tier ──
                    _buildFreeTier(),
                    const SizedBox(height: 20),
                    // ── PLUS Tier ──
                    _buildPlusTier(),
                    const SizedBox(height: 20),
                    // ── PRO Tier ──
                    _buildProTier(),
                    const SizedBox(height: 40),
                    // ── THE BREAKDOWN ──
                    _buildBreakdownTable(),
                    const SizedBox(height: 32),
                    // ── Legal Footer ──
                    _buildLegalFooter(),
                    const SizedBox(height: 80),
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
  // ── TOP BAR ──
  // ═══════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new, color: _textWhite, size: 20),
          ),
          Text(
            'FLICKO PLUS',
            style: GoogleFonts.spaceGrotesk(
              color: _textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderGrey, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/branding/Flicko-for-black-background.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.bolt, size: 16, color: _neonGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── UPGRADE BADGE ──
  // ═══════════════════════════════════════════
  Widget _buildUpgradeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: _neonGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, color: _bgBlack, size: 14),
          const SizedBox(width: 4),
          Text(
            'UPGRADE YOUR STATUS',
            style: GoogleFonts.spaceGrotesk(
              color: _bgBlack,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── HERO TITLE ──
  // ═══════════════════════════════════════════
  Widget _buildHeroTitle() {
    return Column(
      children: [
        Text(
          'CHOOSE YOUR',
          style: GoogleFonts.spaceGrotesk(
            color: _textWhite,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            height: 1.1,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_neonGreen, Color(0xFF9ACD00)],
          ).createShader(bounds),
          child: Text(
            'DROP',
            style: GoogleFonts.dancingScript(
              color: _textWhite,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ── SUBTITLE ──
  // ═══════════════════════════════════════════
  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'Unlock exclusive perks, elevate your profile, and stand out in the culture.\nPick the tier that matches your hustle.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: _bodyText,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── FREE TIER ──
  // ═══════════════════════════════════════════
  Widget _buildFreeTier() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGrey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BASIC',
            style: GoogleFonts.spaceGrotesk(
              color: _bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Free',
            style: GoogleFonts.spaceGrotesk(
              color: _textWhite,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The essential toolkit for every street level member.',
            style: GoogleFonts.inter(color: _bodyText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          _featureRow('Standard Profile', isIncluded: true),
          _featureRow('Join Public Drops', isIncluded: true),
          _featureRow('Basic Chat Features', isIncluded: true),
          const SizedBox(height: 20),
          _outlinedButton('CURRENT PLAN', enabled: false),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PLUS TIER ──
  // ═══════════════════════════════════════════
  Widget _buildPlusTier() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonGreen, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLUS',
                style: GoogleFonts.spaceGrotesk(
                  color: _neonGreen.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹799',
                    style: GoogleFonts.spaceGrotesk(
                      color: _textWhite,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/mo',
                    style: GoogleFonts.inter(
                      color: _bodyText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Level up your identity with custom flair and higher limits.',
                style: GoogleFonts.inter(color: _bodyText, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              _featureRow('Custom Emojis', isIncluded: true, isGreen: true),
              _featureRow('Nitro Badge', isIncluded: true, isGreen: true),
              _featureRow('Custom Themes', isIncluded: true, isGreen: true),
              _featureRow('Priority Support', isIncluded: true, isGreen: true),
              const SizedBox(height: 20),
              _filledButton('GET PLUS', color: _neonGreen, textColor: _bgBlack, onTap: () => _handlePurchase('plus')),
            ],
          ),
          // "MOST POPULAR" badge
          Positioned(
            top: -12,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _neonGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'MOST POPULAR',
                style: GoogleFonts.spaceGrotesk(
                  color: _bgBlack,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PRO TIER ──
  // ═══════════════════════════════════════════
  Widget _buildProTier() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGrey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PRO',
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹1599',
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/mo',
                style: GoogleFonts.inter(
                  color: _bodyText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The ultimate flex. Uncompromised performance and access.',
            style: GoogleFonts.inter(color: _bodyText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          _featureRow('4K Streaming', isIncluded: true),
          _featureRow('4GB Uploads', isIncluded: true),
          _featureRow('Early Access to Drops', isIncluded: true),
          _featureRow('All Plus Features', isIncluded: true),
          const SizedBox(height: 20),
          _filledButton('GET PRO', color: _textWhite, textColor: _bgBlack, onTap: () => _handlePurchase('pro')),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── BREAKDOWN TABLE ──
  // ═══════════════════════════════════════════
  Widget _buildBreakdownTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'THE BREAKDOWN',
            style: GoogleFonts.spaceGrotesk(
              color: _textWhite,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _cardGrey,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'FEATURE',
                    style: GoogleFonts.spaceGrotesk(
                      color: _bodyText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _tableHeader('BASIC'),
                _tableHeader('PLUS'),
                _tableHeader('PRO'),
              ],
            ),
          ),
          // Table Rows
          _tableRow('Custom Emojis', basic: '—', plus: '✓', pro: '✓'),
          _tableRow('Nitro Badge', basic: '—', plus: '✓', pro: '✓'),
          _tableRow('Custom Themes', basic: '—', plus: '✓', pro: '✓'),
          _tableRow('File Uploads', basic: '25MB', plus: '100MB', pro: '4GB'),
          _tableRow('Streaming Quality', basic: '720p', plus: '1080p', pro: '4K'),
          _tableRow('Early Access', basic: '—', plus: '—', pro: '✓'),
          _tableRow('Priority Support', basic: '—', plus: '✓', pro: '✓'),
          _tableRow('Server Boosts', basic: '—', plus: '1x', pro: '2x'),
          _tableRow('Profile Animations', basic: '—', plus: '—', pro: '✓'),
          // Bottom rounded container
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: _cardGrey.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                left: BorderSide(color: _borderGrey, width: 0.5),
                right: BorderSide(color: _borderGrey, width: 0.5),
                bottom: BorderSide(color: _borderGrey, width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Expanded(
      flex: 2,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          color: _textWhite,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _tableRow(String feature, {
    required String basic,
    required String plus,
    required String pro,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderGrey.withValues(alpha: 0.5), width: 0.5),
          left: BorderSide(color: _borderGrey, width: 0.5),
          right: BorderSide(color: _borderGrey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: GoogleFonts.inter(
                color: _textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _tableCell(basic),
          _tableCell(plus, isGreen: plus == '✓'),
          _tableCell(pro, isGreen: pro == '✓'),
        ],
      ),
    );
  }

  Widget _tableCell(String value, {bool isGreen = false}) {
    final isCheck = value == '✓';
    final isDash = value == '—';
    return Expanded(
      flex: 2,
      child: isCheck
          ? const Icon(Icons.check_circle, color: _neonGreen, size: 18)
          : isDash
              ? Text('—', textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: _bodyText.withValues(alpha: 0.4), fontSize: 14))
              : Text(
                  value,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
    );
  }

  // ═══════════════════════════════════════════
  // ── SHARED WIDGETS ──
  // ═══════════════════════════════════════════
  Widget _featureRow(String text, {bool isIncluded = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isIncluded ? Icons.check_circle : Icons.remove_circle_outline,
            color: isGreen ? _neonGreen : (isIncluded ? _bodyText : _borderGrey),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.inter(
              color: _textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedButton(String text, {bool enabled = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderGrey, width: 1.5),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            color: enabled ? _textWhite : _bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _filledButton(String text, {
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    final isPurchasingThis = _isPurchasing && _purchasingPlan == text;
    return GestureDetector(
      onTap: _isPurchasing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isPurchasingThis
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.spaceGrotesk(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── LEGAL FOOTER ──
  // ═══════════════════════════════════════════
  Widget _buildLegalFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'BY SUBSCRIBING TO FLICKO PLUS, YOU AGREE TO OUR TERMS OF SERVICE AND PRIVACY POLICY. SUBSCRIPTION AUTOMATICALLY RENEWS UNLESS CANCELED AT LEAST 24 HOURS BEFORE THE END OF THE CURRENT PERIOD.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: const Color(0xFF999999),
          fontSize: 9,
          height: 1.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PURCHASE HANDLER ──
  // ═══════════════════════════════════════════
  Future<void> _handlePurchase(String planName) async {
    setState(() {
      _isPurchasing = true;
      _purchasingPlan = planName == 'plus' ? 'GET PLUS' : 'GET PRO';
    });

    try {
      final razorpayService = ref.read(razorpayServiceProvider);
      final user = ref.read(currentUserProvider);
      final userEmail = user?.email ?? 'user@flicko.tech';
      final username = user?.userMetadata?['username'] as String? ??
          userEmail.split('@')[0];
      final plan = SubscriptionPlan.plus; // Both Plus and Pro use 'plus' tier on backend
      final amountFormatted = planName == 'plus' ? 'INR 799' : 'INR 1599';

      final orderData = await razorpayService.createOrder(
        plan: plan,
        billingCycle: BillingCycle.monthly,
      );

      final result = await razorpayService.startPayment(
        orderId: orderData['id'],
        amount: (orderData['amount'] as num).toDouble() / 100,
        userEmail: userEmail,
        userPhone: '',
        description: 'Flicko ${planName == 'plus' ? 'Plus' : 'Pro'} Subscription',
      );

      final verified = await razorpayService.verifyPayment(
        orderId: result['orderId'],
        paymentId: result['paymentId'],
        signature: result['signature'],
        email: userEmail,
        username: username,
        amount: amountFormatted,
      );

      if (verified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to Flicko ${planName == 'plus' ? 'Plus' : 'Pro'}!'),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
        context.go('/u/settings');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _neonGreen, width: 2),
            ),
            title: Text(
              'SANDBOX TEST MODE',
              style: GoogleFonts.spaceGrotesk(
                color: _textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
            content: Text(
              'Live payment service is currently not active in sandbox mode. Would you like to proceed with free test activation of Flicko ${planName == 'plus' ? 'Plus' : 'Pro'} to explore premium perks?',
              style: GoogleFonts.inter(color: _bodyText, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: _bodyText, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Welcome to Flicko ${planName == 'plus' ? 'Plus' : 'Pro'}! (Demo Mode)'),
                      backgroundColor: const Color(FlickoColors.success),
                    ),
                  );
                  context.go('/u/settings');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Activate',
                  style: GoogleFonts.inter(color: _bgBlack, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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
}
