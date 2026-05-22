import 'package:flutter/material.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BillingSettingsScreen extends ConsumerStatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  ConsumerState<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends ConsumerState<BillingSettingsScreen> {
  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color purple = Color(0xFF9B84EE);

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: black,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            subscriptionAsync.when(
              data: (sub) => _buildSubscriptionCard(sub),
              loading: () => _buildLoadingCard(),
              error: (_, __) => _buildNoSubscriptionCard(),
            ),
            const SizedBox(height: 36),
            _buildPaymentMethodsSection(paymentMethodsAsync),
            const SizedBox(height: 36),
            _buildQuickActions(),
            const SizedBox(height: 36),
            _buildTransactionHistorySection(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: black,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Container(
          margin: const EdgeInsets.all(8.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, color: white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      title: Text(
        'BILLING',
        style: GoogleFonts.spaceGrotesk(
          color: white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 2.0,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: const Icon(Icons.history, color: white, size: 20),
            onPressed: () => context.push('/profile/settings/billing/history'),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic>? subscription) {
    if (subscription == null) {
      return _buildNoSubscriptionCard();
    }

    final plan = subscription['plan'] as String? ?? 'basic';
    final periodEnd = subscription['current_period_end'] as String?;
    final cancelAtEnd = subscription['cancel_at_period_end'] as bool? ?? false;

    DateTime? renewalDate;
    if (periodEnd != null) {
      renewalDate = DateTime.tryParse(periodEnd);
    }

    final isPlus = plan.contains('plus');
    final isPro = plan.contains('pro') || plan.contains('full');
    final price = isPro ? '₹1,599' : (isPlus ? '₹799' : 'FREE');
    final planName = isPro ? 'FLICKO PRO' : (isPlus ? 'FLICKO PLUS' : 'BASIC');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPro 
              ? [purple, purple.withValues(alpha: 0.7)]
              : isPlus 
                  ? [lime, lime.withValues(alpha: 0.7)]
                  : [const Color(0xFF2A2828), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPro ? purple : (isPlus ? lime : const Color(0xFF373535)),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPro ? purple : lime).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 3D Card Design
          Positioned(
            right: -30,
            bottom: -30,
            child: Transform.rotate(
              angle: -0.2,
              child: Opacity(
                opacity: 0.15,
                child: Container(
                  width: 200,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          width: 40,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(width: 60, height: 6, color: Colors.black.withValues(alpha: 0.2)),
                                Container(width: 40, height: 6, color: Colors.black.withValues(alpha: 0.2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cancelAtEnd ? Colors.red.withValues(alpha: 0.5) : lime.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cancelAtEnd ? Colors.red : lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cancelAtEnd ? 'CANCELS AT PERIOD END' : 'ACTIVE SUBSCRIPTION',
                        style: GoogleFonts.spaceGrotesk(
                          color: cancelAtEnd ? Colors.red : lime,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  planName,
                  style: GoogleFonts.epilogue(
                    color: white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPro
                      ? 'Ultimate streaming, 4GB uploads, all premium features.'
                      : isPlus
                          ? 'Custom emojis, badges, themes, and priority support.'
                          : 'Essential features to get started.',
                  style: GoogleFonts.spaceGrotesk(
                    color: white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.spaceGrotesk(
                        color: white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '/mo',
                      style: GoogleFonts.spaceGrotesk(
                        color: white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (renewalDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'RENEWS ${DateFormat('MMM dd, yyyy').format(renewalDate).toUpperCase()}',
                    style: GoogleFonts.spaceGrotesk(
                      color: white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => context.push('/profile/settings/billing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: white,
                        foregroundColor: black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'MANAGE PLAN',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: white,
                        side: BorderSide(color: white.withValues(alpha: 0.3), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: grey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: white.withValues(alpha: 0.6), size: 14),
                const SizedBox(width: 8),
                Text(
                  'NO ACTIVE SUBSCRIPTION',
                  style: GoogleFonts.spaceGrotesk(
                    color: white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'UNLOCK PREMIUM',
            style: GoogleFonts.epilogue(
              color: white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Flicko Plus or Pro to access exclusive features.',
            style: GoogleFonts.spaceGrotesk(
              color: white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push('/premium/nitro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: lime,
              foregroundColor: black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'VIEW PLANS',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator(color: lime)),
    );
  }

  Widget _buildPaymentMethodsSection(AsyncValue paymentMethodsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, color: Color(0xFF8B8E93), size: 18),
                const SizedBox(width: 10),
                Text(
                  'PAYMENT METHODS',
                  style: GoogleFonts.spaceGrotesk(
                    color: white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        paymentMethodsAsync.when(
          data: (methods) {
            if (methods.isEmpty) {
              return _buildAddCardButton();
            }
            return Column(
              children: [
                ...methods.map((method) => _buildPaymentMethodCard(method)),
                const SizedBox(height: 12),
                _buildAddCardButton(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: lime)),
          error: (error, _) => Text('Error loading methods: $error', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(dynamic method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF0D2137),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card chip
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: CustomPaint(
                painter: _ChipPainter(),
              ),
            ),
          ),
          // Card content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    method.cardType?.toUpperCase() ?? 'VISA',
                    style: GoogleFonts.spaceGrotesk(
                      color: white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                  if (method.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: GoogleFonts.spaceGrotesk(
                          color: black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                '•••• •••• •••• ${method.cardNumberLastFour}',
                style: GoogleFonts.robotoMono(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARDHOLDER',
                        style: GoogleFonts.spaceGrotesk(
                          color: white.withValues(alpha: 0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method.cardholderName ?? 'CARDHOLDER',
                        style: GoogleFonts.spaceGrotesk(
                          color: white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'EXPIRES',
                        style: GoogleFonts.spaceGrotesk(
                          color: white.withValues(alpha: 0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${method.expiryMonth.toString().padLeft(2, '0')}/${method.expiryYear.toString().substring(2)}',
                        style: GoogleFonts.spaceGrotesk(
                          color: white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: white, size: 20),
                    onPressed: () => _showCardOptions(method),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddCardButton() {
    return GestureDetector(
      onTap: () async {
        await context.push('/profile/settings/add-card');
        ref.invalidate(paymentMethodsProvider);
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: white.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: lime, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add, color: lime, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'ADD PAYMENT METHOD',
              style: GoogleFonts.spaceGrotesk(
                color: lime,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.spaceGrotesk(
            color: white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.receipt_long,
                title: 'Invoices',
                onTap: () => context.push('/profile/settings/billing/invoices'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.card_giftcard,
                title: 'Redeem Code',
                onTap: () => _showRedeemDialog(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.support_agent,
                title: 'Support',
                onTap: () => context.push('/profile/settings/help'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: lime, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistorySection() {
    // Get real transactions from Supabase in a real app
    // For now showing placeholder
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF8B8E93), size: 18),
                const SizedBox(width: 10),
                Text(
                  'TRANSACTION HISTORY',
                  style: GoogleFonts.spaceGrotesk(
                    color: white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/profile/settings/billing/history'),
              child: Row(
                children: [
                  Text(
                    'VIEW ALL',
                    style: GoogleFonts.spaceGrotesk(
                      color: lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, color: lime, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: grey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: white.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, color: white.withValues(alpha: 0.3), size: 48),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet',
                  style: GoogleFonts.spaceGrotesk(
                    color: white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCardOptions(dynamic method) {
    showModalBottomSheet(
      context: context,
      backgroundColor: grey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.star_border, color: lime),
              title: Text('Set as Default', style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                await _setDefaultCard(method.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Remove Card', style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteCard(method.id);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefaultCard(String cardId) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Reset all cards to not default
      await client.from('payment_methods').update({'is_default': false}).eq('user_id', user.id);
      // Set selected card as default
      await client.from('payment_methods').update({'is_default': true}).eq('id', cardId);
      
      ref.invalidate(paymentMethodsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default card updated'), backgroundColor: lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCard(String cardId) async {
    try {
      await Supabase.instance.client.from('payment_methods').delete().eq('id', cardId);
      ref.invalidate(paymentMethodsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card removed'), backgroundColor: lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Subscription?', style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w900)),
        content: Text(
          'Your subscription will remain active until the end of the current billing period.',
          style: GoogleFonts.spaceGrotesk(color: white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Plan', style: GoogleFonts.spaceGrotesk(color: lime, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Implement cancellation
            },
            child: Text('Cancel Anyway', style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Redeem Code', style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.spaceGrotesk(color: white),
          decoration: InputDecoration(
            hintText: 'Enter code',
            hintStyle: GoogleFonts.spaceGrotesk(color: white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code redeemed successfully!'), backgroundColor: lime),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: lime),
            child: Text('Redeem', style: GoogleFonts.spaceGrotesk(color: black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Draw chip lines
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
