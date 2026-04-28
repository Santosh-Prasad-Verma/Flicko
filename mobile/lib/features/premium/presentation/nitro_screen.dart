import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/services/stripe_service.dart';
import '../../../../data/models/subscription_model.dart';

/// Nitro Screen — The premium subscription home
/// 
/// High-fidelity landing page with tier comparison, feature highlights,
/// and animated premium branding.
class NitroScreen extends ConsumerStatefulWidget {
  const NitroScreen({super.key});

  @override
  ConsumerState<NitroScreen> createState() => _NitroScreenState();
}

class _NitroScreenState extends ConsumerState<NitroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _badgeController;
  int _selectedTier = 1; // 0: Basic, 1: Nitro
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
          // ── Hero Section ──
          SliverToBoxAdapter(
            child: _buildHero(),
          ),

          // ── Action Buttons ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTierSelector(),
                const SizedBox(height: 32),
                _buildHighlightsGrid(),
                const SizedBox(height: 48),
                _buildComparisonTable(),
                const SizedBox(height: 48),
                _buildGiftingSection(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      height: 440,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1F22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5865F2).withValues(alpha: 0.15),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 50, duration: 4.seconds),
          ),
          Positioned(
            bottom: 50,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEB459E).withValues(alpha: 0.12),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: 0, end: -40, duration: 5.seconds),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 20),
                // Animated Nitro Logo/Badge
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating rings
                      RotationTransition(
                        turns: _badgeController,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF73FA).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEB459E).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5865F2), Color(0xFFEB459E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                          size: 56,
                        ),
                      ).animate().scale(
                            duration: 800.ms,
                            curve: Curves.elasticOut,
                            begin: const Offset(0.5, 0.5),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'FLICKO NITRO',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Unleash the full power of Flicko with enhanced features, profile customization, and more.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB5BAC1),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),
                const SizedBox(height: 32),
                _buildPrimaryAction(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => context.pop(),
          ),
          Text(
            'Nitro Premium',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handlePurchase(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: _isPurchasing 
          ? const SizedBox(
              height: 20, 
              width: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : Text(
              'Get Nitro',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildTierSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          _TierTab(
            label: 'Nitro Basic',
            isSelected: _selectedTier == 0,
            onTap: () => setState(() => _selectedTier = 0),
          ),
          _TierTab(
            label: 'Nitro',
            isSelected: _selectedTier == 1,
            onTap: () => setState(() => _selectedTier = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsGrid() {
    final highlights = [
      {'icon': Icons.emoji_emotions, 'title': 'Custom Emoji', 'desc': 'Use your favorite emojis anywhere.'},
      {'icon': Icons.badge, 'title': 'Nitro Badge', 'desc': 'Show off your support on your profile.'},
      {'icon': Icons.cloud_upload, 'title': '500MB Uploads', 'desc': 'Share high-res videos and files.'},
      {'icon': Icons.videocam, 'title': '4K Streaming', 'desc': 'Go live in stunning ultra HD.'},
      {'icon': Icons.style, 'title': 'Profile Themes', 'desc': 'Customize your banner and colors.'},
      {'icon': Icons.auto_awesome, 'title': 'Special Roles', 'desc': 'Unlock exclusive server roles.'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        final item = highlights[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item['icon'] as IconData, color: const Color(FlickoColors.blurple), size: 28),
              const Spacer(),
              Text(
                item['title'] as String,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                item['desc'] as String,
                style: GoogleFonts.inter(color: const Color(0xFFB5BAC1), fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 100).ms).moveX(begin: 20, end: 0);
      },
    );
  }

  Widget _buildComparisonTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compare Plans',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _ComparisonRow(label: 'Custom Emoji', basic: true, nitro: true),
        _ComparisonRow(label: 'Special Badge', basic: true, nitro: true),
        _ComparisonRow(label: '500MB Uploads', basic: false, nitro: true),
        _ComparisonRow(label: '4K HD Streaming', basic: false, nitro: true),
        _ComparisonRow(label: 'Profile Themes', basic: false, nitro: true),
        _ComparisonRow(label: 'Server Boosts', basic: false, nitro: true),
      ],
    );
  }

  Widget _buildGiftingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2D31), Color(0xFF1E1F22)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEB459E).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard, color: Color(0xFFEB459E), size: 48),
          const SizedBox(height: 16),
          Text(
            'Gift Nitro',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Support your friends and share the premium love across Flicko.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFB5BAC1),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _handleGiftPurchase(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEB459E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text(
                'Select a Gift',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);
    
    try {
      final stripeService = ref.read(stripeServiceProvider);
      
      // 1. Create PaymentIntent on the backend
      final paymentData = await stripeService.createPaymentIntent(
        plan: _selectedTier == 0 ? SubscriptionPlan.basic : SubscriptionPlan.plus,
        billingCycle: BillingCycle.monthly,
      );

      // 2. Initialize PaymentSheet
      await stripeService.initPaymentSheet(
        clientSecret: paymentData['clientSecret'],
        customerId: paymentData['customerId'],
        ephemeralKey: paymentData['ephemeralKey'],
      );

      // 3. Present PaymentSheet
      await stripeService.presentPaymentSheet();

      // 4. Success — Show success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to Flicko ${_selectedTier == 0 ? 'Basic' : 'Nitro'}!'),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
        context.go('/settings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment failed or cancelled.'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handleGiftPurchase() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Gift Nitro',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Select a friend to gift Flicko Nitro subscription.',
          style: GoogleFonts.inter(color: const Color(0xFFB5BAC1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFFB5BAC1))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gift feature coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
            ),
            child: Text('Continue', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TierTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TierTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.black : const Color(0xFFB5BAC1),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final bool basic;
  final bool nitro;

  const _ComparisonRow({
    required this.label,
    required this.basic,
    required this.nitro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2B2D31))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.inter(color: const Color(0xFFDBDEE1), fontSize: 14),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                basic ? Icons.check : Icons.close,
                color: basic ? const Color(0xFF57F287) : const Color(0xFF949BA4),
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                nitro ? Icons.check : Icons.close,
                color: nitro ? const Color(0xFFEB459E) : const Color(0xFF949BA4),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
