import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/services/stripe_service.dart';
import '../../../../data/models/subscription_model.dart';

/// Flicko Plus — Premium Subscription Screen
///
/// Pricing page with two tiers, feature comparison, and animated gradient branding.
/// Route: /premium/plus
class FlickoPlusScreen extends ConsumerStatefulWidget {
  const FlickoPlusScreen({super.key});

  @override
  ConsumerState<FlickoPlusScreen> createState() => _FlickoPlusScreenState();
}

class _PlanFeature {
  final String text;
  final bool included;

  _PlanFeature({required this.text, required this.included});
}

class _Plan {
  final String id;
  final String name;
  final String tagline;
  final String monthlyPrice;
  final String yearlyPrice;
  final String yearlySaving;
  final IconData icon;
  final List<Color> gradient;
  final List<_PlanFeature> features;

  _Plan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlySaving,
    required this.icon,
    required this.gradient,
    required this.features,
  });
}

class _Perk {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  _Perk({required this.icon, required this.title, required this.description, required this.gradient});
}

class _FlickoPlusScreenState extends ConsumerState<FlickoPlusScreen> {
  String _selectedPlan = 'plus';
  String _billing = 'monthly';
  bool _isPurchasing = false;

  late final List<_Plan> _plans;
  late final List<_Perk> _perks;

  @override
  void initState() {
    super.initState();
    _plans = [
      _Plan(
        id: 'basic',
        name: 'Flicko Basic',
        tagline: 'Great for casual users',
        monthlyPrice: '\u20B9249',
        yearlyPrice: '\u20B92,499',
        yearlySaving: 'Save 16%',
        icon: Icons.flash_on,
        gradient: [const Color(0xFF5865F2), const Color(0xFF7289DA)],
        features: [
          _PlanFeature(text: '50MB file uploads', included: true),
          _PlanFeature(text: 'Custom emoji anywhere', included: true),
          _PlanFeature(text: 'HD video streaming (720p)', included: true),
          _PlanFeature(text: 'Animated avatar', included: true),
          _PlanFeature(text: 'Custom status badge', included: true),
          _PlanFeature(text: '2 Server Boosts', included: true),
          _PlanFeature(text: 'Custom profiles & banners', included: false),
          _PlanFeature(text: '4K video streaming', included: false),
          _PlanFeature(text: 'Longer messages (4000 chars)', included: false),
          _PlanFeature(text: 'Custom server icons (GIF)', included: false),
        ],
      ),
      _Plan(
        id: 'plus',
        name: 'Flicko Plus',
        tagline: 'The ultimate Flicko experience',
        monthlyPrice: '\u20B9849',
        yearlyPrice: '\u20B98,499',
        yearlySaving: 'Save 17%',
        icon: Icons.diamond,
        gradient: [const Color(0xFF5865F2), const Color(0xFFEB459E)],
        features: [
          _PlanFeature(text: '500MB file uploads', included: true),
          _PlanFeature(text: 'Custom emoji anywhere', included: true),
          _PlanFeature(text: '4K video streaming (2160p)', included: true),
          _PlanFeature(text: 'Animated avatar & banner', included: true),
          _PlanFeature(text: 'Custom status badge', included: true),
          _PlanFeature(text: '2 Server Boosts included', included: true),
          _PlanFeature(text: 'Custom profiles & themes', included: true),
          _PlanFeature(text: 'Longer messages (4000 chars)', included: true),
          _PlanFeature(text: 'Custom server icons (GIF)', included: true),
          _PlanFeature(text: 'Early access to new features', included: true),
        ],
      ),
    ];

    _perks = [
      _Perk(icon: Icons.cloud_upload, title: 'Bigger Uploads', description: 'Share files up to 500MB with your friends.', gradient: [const Color(0xFF5865F2), const Color(0xFF7289DA)]),
      _Perk(icon: Icons.emoji_emotions, title: 'Custom Emoji', description: 'Use your custom emoji in any server.', gradient: [const Color(0xFFFEE75C), const Color(0xFFF0B232)]),
      _Perk(icon: Icons.videocam, title: 'HD Streaming', description: 'Stream in stunning 4K quality for everyone to enjoy.', gradient: [const Color(0xFF57F287), const Color(0xFF248046)]),
      _Perk(icon: Icons.person, title: 'Custom Profiles', description: 'Stand out with animated avatars, banners, and themes.', gradient: [const Color(0xFFEB459E), const Color(0xFFFE73B1)]),
      _Perk(icon: Icons.rocket_launch, title: 'Server Boosts', description: '2 free boosts to level up your favorite servers.', gradient: [const Color(0xFFF47FFF), const Color(0xFFC472ED)]),
      _Perk(icon: Icons.auto_awesome, title: 'Early Access', description: 'Be the first to try upcoming Flicko features.', gradient: [const Color(0xFF5865F2), const Color(0xFFEB459E)]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plans.firstWhere((p) => p.id == _selectedPlan);
    final price = _billing == 'monthly' ? plan.monthlyPrice : plan.yearlyPrice;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
  // Hero header with animated gradient and pulse
  SliverToBoxAdapter(
    child: Container(
      height: 380,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5865F2), Color(0xFFEB459E), Color(0xFFFEE75C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background animated decorations
          Positioned(
            top: -50,
            right: -50,
            child: Icon(
              Icons.diamond,
              size: 200,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Animated Plus Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 1),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEB459E).withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEE75C), Color(0xFFEB459E)],
                          ),
                        ),
                        child: const Icon(Icons.diamond, color: Colors.white, size: 56),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'FLICKO PLUS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.black,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'The ultimate premium experience. Customize your profile, unlock larger uploads, and support the community.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Plan selector tabs
                Container(
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgSecondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _plans.map((p) {
                      final active = _selectedPlan == p.id;
                      return InkWell(
                        onTap: () => setState(() => _selectedPlan = p.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: active
                                ? const Border(left: BorderSide(color: Color(FlickoColors.blurple), width: 3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: p.gradient),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(p.icon, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: GoogleFonts.inter(
                                    color: active
                                        ? const Color(FlickoColors.textPrimary)
                                        : const Color(FlickoColors.textSecondary),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(Icons.check_circle, size: 18, color: Color(FlickoColors.blurple)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Billing toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgSecondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: ['monthly', 'yearly'].map((cycle) {
                      final active = _billing == cycle;
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _billing = cycle),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? const Color(FlickoColors.blurple) : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cycle == 'monthly' ? 'Monthly' : 'Yearly',
                                  style: GoogleFonts.inter(
                                    color: active ? Colors.white : const Color(FlickoColors.textSecondary),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (cycle == 'yearly') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF57F287),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      plan.yearlySaving,
                                      style: GoogleFonts.inter(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Price card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgSecondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: plan.gradient),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textPrimary),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  plan.tagline,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textSecondary),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  price,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textPrimary),
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '/${_billing == 'monthly' ? 'mo' : 'yr'}',
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textMuted),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Features list
                Text(
                  'WHAT YOU GET',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgSecondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: plan.features.asMap().entries.map((entry) {
                      final i = entry.key;
                      final feat = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: i < plan.features.length - 1
                              ? const Border(bottom: BorderSide(color: Color(0xFF232428)))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              feat.included ? Icons.check_circle : Icons.cancel,
                              size: 20,
                              color: feat.included ? const Color(0xFF57F287) : const Color(FlickoColors.textMuted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feat.text,
                                style: GoogleFonts.inter(
                                  color: feat.included
                                      ? const Color(FlickoColors.textPrimary)
                                      : const Color(FlickoColors.textMuted),
                                  fontSize: 14,
                                  decoration: feat.included ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Perks grid
                Text(
                  'WHY GO PREMIUM',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _perks.length,
                  itemBuilder: (context, index) {
                    final perk = _perks[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: perk.gradient),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(perk.icon, size: 20, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            perk.title,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            perk.description,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textSecondary),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // FAQ note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgSecondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Color(FlickoColors.textMuted)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Subscriptions are managed through your app store. You can cancel anytime from your device settings.',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textSecondary),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dev badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x14FAA61A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33FAA61A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.construction, size: 14, color: Color(0xFFFAA61A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dev Mode — No real charges. Subscriptions are mocked.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFAA61A),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(FlickoColors.bgPrimary),
          border: Border(top: BorderSide(color: Color(0xFF232428))),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : () => _handlePurchase(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              disabledBackgroundColor: const Color(FlickoColors.bgTertiary),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(plan.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Subscribe — $price/${_billing == 'monthly' ? 'month' : 'year'}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(_Plan plan) async {
    setState(() => _isPurchasing = true);

    try {
      final stripeService = ref.read(stripeServiceProvider);
      
      // 1. Create PaymentIntent on backend
      final paymentData = await stripeService.createPaymentIntent(
        plan: plan.id == 'plus' ? SubscriptionPlan.plus : SubscriptionPlan.basic,
        billingCycle: _billing == 'monthly' ? BillingCycle.monthly : BillingCycle.yearly,
      );

      // 2. Initialize PaymentSheet
      await stripeService.initPaymentSheet(
        clientSecret: paymentData['clientSecret'],
        customerId: paymentData['customerId'],
        ephemeralKey: paymentData['ephemeralKey'],
      );

      // 3. Present PaymentSheet
      await stripeService.presentPaymentSheet();

      // 4. Success
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome to Flicko ${plan.name}!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
}
