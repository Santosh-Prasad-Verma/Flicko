import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/stripe_service.dart';
import 'package:mobile/data/models/subscription_model.dart';

class FlickoPlusScreen extends ConsumerStatefulWidget {
  const FlickoPlusScreen({super.key});

  @override
  ConsumerState<FlickoPlusScreen> createState() => _FlickoPlusScreenState();
}

class _FlickoPlusScreenState extends ConsumerState<FlickoPlusScreen> {
  bool _isPurchasing = false;

  final List<Map<String, dynamic>> _featureMatrix = [
    {'feature': 'Custom Emojis', 'basic': false, 'plus': true},
    {'feature': 'Nitro Badge', 'basic': false, 'plus': true},
    {'feature': 'Custom Themes', 'basic': false, 'plus': true},
    {'feature': 'File Uploads', 'basic': '25MB', 'plus': '100MB'},
    {'feature': 'Streaming Quality', 'basic': '720p', 'plus': '1080p'},
    {'feature': 'Early Access', 'basic': false, 'plus': true},
  ];

  final Color _neonGreen = const Color(0xFFC8FF00);
  final Color _bgDark = const Color(0xFF0D0B14);
  final Color _cardDark = const Color(0xFF141124);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // UPGRADE BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neonGreen, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, color: _neonGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'UPGRADE YOUR STATUS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _neonGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // HEADER text
            Text(
              'CHOOSE YOUR',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Colors.white,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'DROP',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: _neonGreen,
                fontStyle: FontStyle.italic,
                height: 1.0,
                decoration: TextDecoration.underline,
                decorationColor: _neonGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Unlock exclusive perks, elevate your profile, and stand out in the culture. Pick the tier that matches your hustle.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // PLAN CARDS
            _buildBasicCard(),
            const SizedBox(height: 24),
            _buildPlusCard(),
            const SizedBox(height: 24),
            _buildProCard(),
            
            const SizedBox(height: 48),

            // BREAKDOWN
            Text(
              'THE BREAKDOWN',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildMatrixTable(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Feature Check Row
  Widget _buildCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGreenCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
           Icon(Icons.check, color: _neonGreen, size: 18),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBasicCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BASIC', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Free', style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
          const SizedBox(height: 12),
          Text('The essential toolkit for every\nstreet-level member.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white12, thickness: 1.5),
          ),
          _buildCheckRow('Standard Profile'),
          _buildCheckRow('Join Public Drops'),
          _buildCheckRow('Basic Chat Features'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white24, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('CURRENT PLAN', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, color: Colors.white60)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlusCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _neonGreen, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PLUS', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w900, color: _neonGreen)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$9.99', style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                  Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text('/mo', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54))),
                ],
              ),
              const SizedBox(height: 12),
              Text('Level up your identity with custom\nflair and higher limits.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white12, thickness: 1.5),
              ),
              _buildGreenCheckRow('Custom Emojis'),
              _buildGreenCheckRow('Nitro Badge'),
              _buildGreenCheckRow('Custom Themes'),
              _buildGreenCheckRow('Priority Support'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : () => _handlePurchase('plus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isPurchasing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                      : Text('GET PLUS', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _neonGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Text('MOST POPULAR', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _buildProCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRO', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$19.99', style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
              Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text('/mo', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54))),
            ],
          ),
          const SizedBox(height: 12),
          Text('The ultimate flex. Uncompromised\nperformance and access.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white12, thickness: 1.5),
          ),
          _buildCheckRow('4K Streaming'),
          _buildCheckRow('4GB Uploads'),
          _buildCheckRow('Early Access to Drops'),
          _buildCheckRow('All Plus Features'),
          const SizedBox(height: 12),
          SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               onPressed: _isPurchasing ? null : () => _handlePurchase('pro'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.white,
                 foregroundColor: Colors.black,
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                 elevation: 0,
               ),
               child: Text('GET PRO', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 13)),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: const TableBorder(
          horizontalInside: BorderSide(color: Colors.white12, width: 1.0),
          verticalInside: BorderSide(color: Colors.white12, width: 1.0),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: const Color(0xFF1E1E2A).withOpacity(0.5)),
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
                _buildTableCellValue(row['basic'], isNeon: false),
                _buildTableCellValue(row['plus'], isNeon: true),
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
          fontSize: isHeader ? 10 : 12,
          fontWeight: isHeader ? FontWeight.w900 : (isFeatureName ? FontWeight.w600 : FontWeight.w500),
          letterSpacing: isHeader ? 1.0 : 0.0,
          color: isHeader
              ? Colors.white54
              : (isFeatureName ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  Widget _buildTableCellValue(dynamic val, {bool isNeon = false}) {
    if (val is bool) {
      if (!val) {
        return Container(
          height: 50,
          alignment: Alignment.center,
          child: const Text('—', style: TextStyle(color: Colors.white30, fontSize: 16)),
        );
      }
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: Icon(
          Icons.check,
          size: 20,
          color: isNeon ? _neonGreen : Colors.white,
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
          fontWeight: FontWeight.w700,
          color: isNeon ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  Future<void> _handlePurchase(String planType) async {
    setState(() => _isPurchasing = true);
    try {
      final stripeService = ref.read(stripeServiceProvider);
      
      final planEnum = planType == 'plus' || planType == 'pro' ? SubscriptionPlan.plus : SubscriptionPlan.basic;
      final paymentData = await stripeService.createPaymentIntent(
        plan: planEnum,
        billingCycle: BillingCycle.monthly,
      );
      
      await stripeService.initPaymentSheet(
        clientSecret: paymentData['clientSecret'],
        customerId: paymentData['customerId'],
        ephemeralKey: paymentData['ephemeralKey'],
      );
      
      await stripeService.presentPaymentSheet();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully subscribed to Flicko ${planType.toUpperCase()}!'),
          backgroundColor: _neonGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
}
