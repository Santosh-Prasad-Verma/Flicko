import 'package:flutter/material.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';
import 'package:mobile/features/settings/data/billing_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' show ImageFilter;
import 'dart:math' show pi;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/config/app_config.dart';

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
            icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
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
                      onPressed: () => context.push('/premium/nitro'),
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
                  Expanded(
                    child: Column(
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
                onTap: () => context.push('/profile/settings/billing/history'),
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

  /// Recent billing entries, newest first.
  ///
  /// This section previously rendered an unconditional "No transactions yet"
  /// card — it never queried anything, so a paying customer saw the same empty
  /// state as a free account.
  Widget _buildTransactionHistorySection() {
    final historyAsync = ref.watch(billingHistoryProvider);

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
          padding: const EdgeInsets.all(16),
          child: historyAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: lime, strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => _buildHistoryNotice(
              icon: Icons.error_outline,
              title: 'Could not load transactions',
              subtitle: err.toString(),
              onRetry: () => ref.invalidate(billingHistoryProvider),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return _buildHistoryNotice(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                );
              }
              // The full list lives behind "VIEW ALL"; this is a preview.
              final preview = transactions.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < preview.length; i++) ...[
                    if (i > 0)
                      Divider(color: white.withValues(alpha: 0.05), height: 20),
                    _buildTransactionRow(preview[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryNotice({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: white.withValues(alpha: 0.3), size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: white.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                color: white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'RETRY',
                style: GoogleFonts.spaceGrotesk(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BillingTransaction txn) {
    final statusColor = txn.isSettled
        ? lime
        : (txn.status == BillingEntryStatus.pendingRedemption
            ? const Color(0xFFFFD700)
            : Colors.red);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            txn.kind == BillingEntryKind.gift
                ? Icons.card_giftcard
                : Icons.workspace_premium_outlined,
            color: statusColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                txn.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd, yyyy').format(txn.date),
                style: GoogleFonts.spaceMono(
                  color: white.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              txn.amountLabel,
              style: GoogleFonts.spaceGrotesk(
                color: white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              txn.statusLabel,
              style: GoogleFonts.spaceMono(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _cancelSubscription();
            },
            child: Text('Cancel Anyway', style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      await client
          .from('subscriptions')
          .update({'cancel_at_period_end': true})
          .eq('user_id', user.id)
          .eq('status', 'active');

      ref.invalidate(subscriptionProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription will cancel at end of billing period.',
              style: GoogleFonts.spaceGrotesk(color: black),
            ),
            backgroundColor: lime,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRedeemDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GlassRedeemDialog(
          onSuccess: () {
            ref.invalidate(subscriptionProvider);
          },
        ),
      ),
    );
  }
}

class GlassRedeemDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const GlassRedeemDialog({super.key, required this.onSuccess});

  @override
  State<GlassRedeemDialog> createState() => _GlassRedeemDialogState();
}

class _GlassRedeemDialogState extends State<GlassRedeemDialog> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  bool _hasText = false;
  String _unlockedPlan = '';
  int _durationDays = 0;
  DateTime? _expiryDate;

  late AnimationController _animController;
  late Animation<double> _spinAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _spinAnimation = Tween<double>(begin: 0.0, end: 4 * pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeIn),
      ),
    );
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!AppConfig.hasApiBaseUrl) {
        throw Exception("API Base URL not configured.");
      }

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception("Authentication required. Please sign in again.");
      }

      final token = client.auth.currentSession?.accessToken ?? "";
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl.endsWith('/')
            ? AppConfig.apiBaseUrl
            : '${AppConfig.apiBaseUrl}/',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.post('premium/redeem', data: {
        'code': code.toUpperCase(),
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as String;
        final durationDays = responseData['duration_days'] as int;

        setState(() {
          _unlockedPlan = plan;
          _durationDays = durationDays;
          _expiryDate = DateTime.now().add(Duration(days: durationDays));
          _isSuccess = true;
          _isLoading = false;
        });

        await _showSuccessNotification(plan, durationDays);
        _animController.forward();
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = "Voucher is invalid or already claimed.";
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String errMsg = "Voucher is invalid or already claimed.";
      if (e.response != null && e.response!.data is Map) {
        final responseData = e.response!.data as Map;
        if (responseData.containsKey('error')) {
          errMsg = responseData['error'].toString();
        }
      }
      setState(() {
        _errorMessage = errMsg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  Future<void> _showSuccessNotification(String plan, int duration) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await plugin.initialize(settings: settings);

      const androidDetails = AndroidNotificationDetails(
        'flicko_claims_channel',
        'Claims',
        channelDescription: 'Flicko gift redemption success notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      final planName = plan == 'nitro_full' ? 'FLICKO PRO' : 'FLICKO PLUS';
      
      await plugin.show(
        id: 9999,
        title: 'Redemption Successful! 🎉',
        body: 'You have unlocked $planName for $duration days. Enjoy your premium benefits!',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[NOTIFICATION_ERROR] Failed to show system notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: SingleChildScrollView(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              width: 380,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: lime.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: _isSuccess ? _buildSuccessState() : _buildInputState(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lime.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_outlined, color: lime, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'REDEEM CODE',
              style: GoogleFonts.spaceGrotesk(
                color: white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Enter your premium voucher code to instantly unlock exclusive subscription tiers and enjoy high-fidelity streaming.',
          style: GoogleFonts.spaceGrotesk(
            color: white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasText ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: _hasText
                ? [
                    BoxShadow(
                      color: lime.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: GoogleFonts.spaceGrotesk(
              color: white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'e.g. FLICKO-PRO-30DAYS',
              hintStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.25),
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.spaceGrotesk(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.spaceGrotesk(
                  color: white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _redeemCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: lime,
                disabledBackgroundColor: lime.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 4,
                shadowColor: lime.withValues(alpha: 0.2),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(black),
                      ),
                    )
                  : Text(
                      'Redeem',
                      style: GoogleFonts.spaceGrotesk(
                        color: black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(_spinAnimation.value)
              ..scale(_scaleAnimation.value, _scaleAnimation.value, 1.0);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: _buildMembershipCard(),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          'MEMBERSHIP ACTIVATED!',
          style: GoogleFonts.spaceGrotesk(
            color: lime,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Your premium pass has been successfully claim-locked. Enjoy unlimited high-fidelity features!',
            style: GoogleFonts.spaceGrotesk(
              color: white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.spaceGrotesk(
                color: black,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipCard() {
    final isPro = _unlockedPlan == 'nitro_full';
    final planTitle = isPro ? 'FLICKO PRO' : 'FLICKO PLUS';
    final cardId = Supabase.instance.client.auth.currentUser?.id.substring(0, 8).toUpperCase() ?? '00000000';
    final formattedDate = _expiryDate != null ? DateFormat('MM/yy').format(_expiryDate!) : '--/--';

    return Container(
      width: 320,
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [
                  const Color(0xFF1E3A1A).withValues(alpha: 0.9),
                  const Color(0xFF0F1A0D).withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFF1A1F38).withValues(alpha: 0.9),
                  const Color(0xFF0D101D).withValues(alpha: 0.9),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: white.withValues(alpha: 0.16),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: lime.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.stars,
              size: 150,
              color: white.withValues(alpha: 0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FLICKO',
                      style: GoogleFonts.spaceGrotesk(
                        color: lime,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 3.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: white.withValues(alpha: 0.1), width: 0.5),
                      ),
                      child: Text(
                        'VIP',
                        style: GoogleFonts.spaceGrotesk(
                          color: white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE5C158), Color(0xFFF5E4B7), Color(0xFFC09B30)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5), width: 0.5),
                      ),
                      child: CustomPaint(painter: _ChipPainter()),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.contactless_outlined,
                      color: Colors.white24,
                      size: 22,
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planTitle,
                      style: GoogleFonts.spaceGrotesk(
                        color: white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            offset: const Offset(1, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MEMBER: #$cardId',
                          style: GoogleFonts.spaceGrotesk(
                            color: white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'EXP: $formattedDate',
                          style: GoogleFonts.spaceGrotesk(
                            color: white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
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
