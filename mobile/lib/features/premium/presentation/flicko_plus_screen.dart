import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/services/stripe_service.dart';
import '../../../../data/models/subscription_model.dart';

class FlickoPlusScreen extends ConsumerStatefulWidget {
  const FlickoPlusScreen({super.key});

  @override
  ConsumerState<FlickoPlusScreen> createState() => _FlickoPlusScreenState();
}

class _FlickoPlusScreenState extends ConsumerState<FlickoPlusScreen> {
  String _selectedPlan = 'plus';
  String _billing = 'monthly';
  bool _isPurchasing = false;

  final List<Map<String, dynamic>> _featureMatrix = [
    {'feature': 'File Upload Size', 'basic': '50MB', 'plus': '500MB'},
    {'feature': 'Video Streaming', 'basic': 'HD (720p)', 'plus': '4K UHD (2160p)'},
    {'feature': 'Custom Status Badges', 'basic': true, 'plus': true},
    {'feature': 'Custom Emojis Everywhere', 'basic': true, 'plus': true},
    {'feature': 'Profile Banner/Theme', 'basic': false, 'plus': true},
    {'feature': 'Long Messages (4K chars)', 'basic': false, 'plus': true},
    {'feature': 'GIF Server Icons', 'basic': false, 'plus': true},
    {'feature': 'Early Feature Access', 'basic': false, 'plus': true},
  ];

  @override
  Widget build(BuildContext context) {
    final isPlus = _selectedPlan == 'plus';
    final price = _billing == 'monthly' 
        ? (isPlus ? '\u20B9849' : '\u20B9249')
        : (isPlus ? '\u20B98,499' : '\u20B92,499');
    final accentColor = isPlus ? const Color(FlickoColors.pink) : const Color(FlickoColors.blurple);

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FLICKO',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: const Color(FlickoColors.textPrimary),
                height: 0.9,
              ),
            ),
            Text(
              'PREMIUM',
              style: GoogleFonts.playfairDisplay(
                fontSize: 42,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Boost your digital environment with custom configurations, elite file thresholds, and visual identity layers.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(FlickoColors.textSecondary),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Plan Cards
            Row(
              children: [
                Expanded(child: _buildPlanSelectCard('basic', 'BASIC', '\u20B9249', const Color(FlickoColors.blurple))),
                const SizedBox(width: 16),
                Expanded(child: _buildPlanSelectCard('plus', 'PLUS', '\u20B9849', const Color(FlickoColors.pink))),
              ],
            ),
            
            const SizedBox(height: 24),

            // Billing Cycle Toggle
            _buildBillingCycleToggle(),

            const SizedBox(height: 32),
            
            // Feature Matrix
            Text(
              'FEATURE CAPABILITY MATRIX',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: const Color(FlickoColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            _buildMatrixTable(),
            
            const SizedBox(height: 32),
            
            // Stripe Banner
            _buildSecurityBanner(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          border: Border(top: BorderSide(color: Color(0xFF232428), width: 2)),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : _handlePurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'DEPLOY SYSTEM — $price / ${_billing == 'monthly' ? 'mo' : 'yr'}',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSelectCard(String planId, String title, String basePrice, Color color) {
    final isSelected = _selectedPlan == planId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF232428),
            width: isSelected ? 2.5 : 2.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected ? color : const Color(FlickoColors.textMuted),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              basePrice,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(FlickoColors.textPrimary),
              ),
            ),
            Text(
              'Base monthly rate',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(FlickoColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCycleToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232428), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _billing = 'monthly'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _billing == 'monthly' ? const Color(0xFF18191C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'MONTHLY BILLING',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.0,
                      color: _billing == 'monthly' ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _billing = 'yearly'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _billing == 'yearly' ? const Color(0xFF18191C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'YEARLY PROTOCOL',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.0,
                          color: _billing == 'yearly' ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.green).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SAVE',
                          style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(FlickoColors.green)),
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

  Widget _buildMatrixTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232428), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFF232428), width: 1.5),
          verticalInside: BorderSide(color: Color(0xFF232428), width: 1.5),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF0D0E10)),
            children: [
              _buildTableCell('FEATURE', isHeader: true),
              _buildTableCell('BASIC', isHeader: true, align: TextAlign.center),
              _buildTableCell('PLUS', isHeader: true, align: TextAlign.center),
            ],
          ),
          ..._featureMatrix.map((row) {
            return TableRow(
              children: [
                _buildTableCell(row['feature'], isFeatureName: true),
                _buildTableCellValue(row['basic']),
                _buildTableCellValue(row['plus'], isPremiumColumn: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isFeatureName = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.spaceGrotesk(
          fontSize: isHeader ? 10 : 13,
          fontWeight: isHeader ? FontWeight.w900 : (isFeatureName ? FontWeight.bold : FontWeight.w500),
          letterSpacing: isHeader ? 1.0 : 0.0,
          color: isHeader 
              ? const Color(FlickoColors.textMuted) 
              : (isFeatureName ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildTableCellValue(dynamic val, {bool isPremiumColumn = false}) {
    if (val is bool) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: Icon(
          val ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: val 
              ? (isPremiumColumn ? const Color(FlickoColors.pink) : const Color(FlickoColors.blurple))
              : const Color(0xFF232428),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        val.toString(),
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isPremiumColumn ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232428), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(FlickoColors.textMuted), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'SECURE PAYMENT VIA STRIPE.\nTransactions are encrypted and fully compliant with global finance standards.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(FlickoColors.textMuted),
                height: 1.4,
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
      
      // 1. Create PaymentIntent on backend
      final paymentData = await stripeService.createPaymentIntent(
        plan: _selectedPlan == 'plus' ? SubscriptionPlan.plus : SubscriptionPlan.basic,
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
          content: Text('Successfully subscribed to Flicko ${_selectedPlan.toUpperCase()}!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('System integration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
}
