import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'invoice_pdf_generator.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/settings/data/billing_history_repository.dart';

class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color darkGrey = Color(0xFF0D0D0D);
  static const Color borderGrey = Color(0xFF262626);
  static const Color purple = Color(0xFF9B84EE);
  static const Color gold = Color(0xFFFFD700);

  /// Payments all go through Razorpay, but nothing links an entitlement back to
  /// a specific saved card, so the card brand and last four are not shown. They
  /// used to be — as a hardcoded "VISA •••• 4242" printed onto the invoice PDF.
  static const String _paymentMethodLabel = 'RAZORPAY';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userEmail = authState.maybeWhen(
      authenticated: (authUser, userProfile) => authUser.email ?? '',
      orElse: () => '',
    );
    final username = authState.maybeWhen(
      authenticated: (authUser, userProfile) => userProfile?.username ?? '',
      orElse: () => '',
    );

    final historyAsync = ref.watch(billingHistoryProvider);

    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        backgroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: IconButton(
              icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              'TRANSACTIONS',
              style: GoogleFonts.spaceGrotesk(
                color: white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'BILLING_HISTORY // INVOICES',
              style: GoogleFonts.spaceMono(
                color: white.withValues(alpha: 0.3),
                fontSize: 8,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: lime, size: 20),
            onPressed: () => ref.invalidate(billingHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: lime)),
        error: (err, _) => _buildErrorState(ref, err.toString()),
        data: (transactions) => RefreshIndicator(
          color: lime,
          backgroundColor: darkGrey,
          onRefresh: () async => ref.invalidate(billingHistoryProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTelemetrySummary(transactions),
                const SizedBox(height: 28),
                Text(
                  '[HISTORY_LOGS]',
                  style: GoogleFonts.spaceMono(
                    color: lime,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (transactions.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildTransactionCard(
                      context,
                      transactions[index],
                      userEmail,
                      username,
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: lime, size: 44),
            const SizedBox(height: 12),
            Text(
              'COULD NOT LOAD TRANSACTIONS',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: black,
                elevation: 0,
              ),
              onPressed: () => ref.invalidate(billingHistoryProvider),
              child: Text(
                'RETRY',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: darkGrey,
        border: Border.all(color: borderGrey, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: white.withValues(alpha: 0.25), size: 44),
          const SizedBox(height: 12),
          Text(
            'NO TRANSACTIONS YET',
            style: GoogleFonts.spaceGrotesk(
              color: white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Purchases and gifts will appear here once you make one.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              color: white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySummary(List<BillingTransaction> transactions) {
    final hasIssue = transactions.any((t) =>
        t.status == BillingEntryStatus.revoked ||
        t.status == BillingEntryStatus.refunded);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkGrey,
        border: Border.all(color: borderGrey, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT STATUS',
                style: GoogleFonts.spaceMono(
                  color: white.withValues(alpha: 0.4),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      // Was unconditionally lime + "GOOD STANDING", even for an
                      // account with a refund in the list.
                      color: hasIssue ? gold : lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasIssue ? 'NEEDS REVIEW' : 'GOOD STANDING',
                    style: GoogleFonts.spaceGrotesk(
                      color: white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            height: 40,
            width: 1.5,
            color: borderGrey,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL TRANSACTIONS',
                style: GoogleFonts.spaceMono(
                  color: white.withValues(alpha: 0.4),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${transactions.length} ENTRIES',
                style: GoogleFonts.spaceGrotesk(
                  color: gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    BillingTransaction txn,
    String userEmail,
    String username,
  ) {
    final statusColor = switch (txn.status) {
      BillingEntryStatus.settled => lime,
      BillingEntryStatus.pendingRedemption => gold,
      BillingEntryStatus.refunded ||
      BillingEntryStatus.revoked ||
      BillingEntryStatus.expired =>
        Colors.red,
    };

    return Container(
      decoration: BoxDecoration(
        color: darkGrey,
        border: Border.all(color: borderGrey, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: white.withValues(alpha: 0.5),
          iconColor: lime,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.productName.toUpperCase(),
                      style: GoogleFonts.epilogue(
                        color: white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy // HH:mm')
                          .format(txn.date)
                          .toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: white.withValues(alpha: 0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      txn.statusLabel,
                      style: GoogleFonts.spaceMono(
                        color: statusColor,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              child: Column(
                children: [
                  Divider(color: borderGrey, height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    txn.kind == BillingEntryKind.gift
                        ? 'GIFT CODE'
                        : 'PAYMENT ID',
                    txn.id,
                    true,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('PAYMENT METHOD', _paymentMethodLabel, false),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                      'STATUS', txn.statusDetailLabel, false, statusColor),
                  if (txn.amountIsListPrice) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 10, color: white.withValues(alpha: 0.3)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Amount shown is the current plan price; the '
                            'charged amount is not stored per grant.',
                            style: GoogleFonts.spaceMono(
                              color: white.withValues(alpha: 0.3),
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lime,
                              foregroundColor: black,
                              elevation: 0,
                              disabledBackgroundColor:
                                  lime.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.file_download_rounded, size: 16),
                            label: Text(
                              'DOWNLOAD',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            // No recorded amount means no invoice worth
                            // generating — the PDF's totals would be blank.
                            onPressed: txn.amountMinorUnits == null
                                ? null
                                : () => _downloadInvoice(
                                      context,
                                      txn,
                                      userEmail,
                                      username,
                                    ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: white,
                              side: const BorderSide(color: borderGrey, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16, color: lime),
                            label: Text(
                              'COPY DETAILS',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () {
                              final details = 'Transaction: ${txn.productName}\n'
                                  'ID: ${txn.id}\n'
                                  'Amount: ${txn.amountLabel}\n'
                                  'Date: ${txn.date}';
                              Clipboard.setData(ClipboardData(text: details));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction details copied to clipboard!'),
                                  backgroundColor: lime,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
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
      ),
    );
  }

  Future<void> _downloadInvoice(
    BuildContext context,
    BillingTransaction txn,
    String userEmail,
    String username,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await InvoicePdfGenerator.generateAndDownloadInvoice(
        txnId: txn.id,
        productName: txn.productName,
        amountStr: txn.amountLabel,
        date: txn.date,
        paymentMethod: _paymentMethodLabel,
        status: txn.statusLabel,
        userEmail: userEmail,
        username: username,
      );

      if (savedPath != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Downloaded successfully to $savedPath'),
            backgroundColor: lime,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, bool copyable, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: white.withValues(alpha: 0.3),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    color: valueColor ?? white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (copyable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 10, color: lime),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
