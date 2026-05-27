import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'invoice_pdf_generator.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

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

  // High-fidelity mockup historical transactions in INR
  static final List<Map<String, dynamic>> _mockTransactions = [
    {
      'id': 'TXN_FLK_9281A4',
      'productName': 'FLICKO PRO (MONTHLY)',
      'amount': '₹799.00',
      'date': DateTime.now().subtract(const Duration(days: 4)),
      'paymentMethod': 'VISA •••• 4242',
      'status': 'SUCCESS',
      'type': 'subscription',
    },
    {
      'id': 'TXN_FLK_8172B8',
      'productName': 'WARP DRIP COSMETIC FUSION',
      'amount': '₹399.00',
      'date': DateTime.now().subtract(const Duration(days: 18)),
      'paymentMethod': 'VISA •••• 4242',
      'status': 'SUCCESS',
      'type': 'purchase',
    },
    {
      'id': 'TXN_FLK_7162C3',
      'productName': 'AVATAR DECORATION (NEON SHIELD)',
      'amount': '₹199.00',
      'date': DateTime.now().subtract(const Duration(days: 32)),
      'paymentMethod': 'MASTERCARD •••• 9876',
      'status': 'SUCCESS',
      'type': 'purchase',
    },
    {
      'id': 'TXN_FLK_6152D4',
      'productName': 'FLICKO PRO (MONTHLY)',
      'amount': '₹799.00',
      'date': DateTime.now().subtract(const Duration(days: 34)),
      'paymentMethod': 'VISA •••• 4242',
      'status': 'SUCCESS',
      'type': 'subscription',
    },
    {
      'id': 'TXN_FLK_5142E9',
      'productName': 'SOUND STUDIO CREATOR SOUNDPACK',
      'amount': '₹649.00',
      'date': DateTime.now().subtract(const Duration(days: 42)),
      'paymentMethod': 'PAYPAL (clay@flicko.app)',
      'status': 'SUCCESS',
      'type': 'purchase',
    },
    {
      'id': 'TXN_FLK_4132F2',
      'productName': 'FLICKO PLUS (MONTHLY)',
      'amount': '₹399.00',
      'date': DateTime.now().subtract(const Duration(days: 64)),
      'paymentMethod': 'MASTERCARD •••• 9876',
      'status': 'REFUNDED',
      'type': 'refund',
    },
  ];

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
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTelemetrySummary(),
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mockTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final txn = _mockTransactions[index];
                return _buildTransactionCard(context, txn, userEmail, username);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySummary() {
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
                    decoration: const BoxDecoration(
                      color: lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GOOD STANDING',
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
                '${_mockTransactions.length} ENTRIES',
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
    Map<String, dynamic> txn,
    String userEmail,
    String username,
  ) {
    final status = txn['status'] as String;
    final isSuccess = status == 'SUCCESS';
    final statusColor = isSuccess ? lime : Colors.red;

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
                      txn['productName'].toUpperCase(),
                      style: GoogleFonts.epilogue(
                        color: white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy // HH:mm').format(txn['date']).toUpperCase(),
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
                    txn['amount'],
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
                      status,
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
                  _buildDetailRow('TRANSACTION ID', txn['id'], true),
                  const SizedBox(height: 8),
                  _buildDetailRow('PAYMENT METHOD', txn['paymentMethod'], false),
                  const SizedBox(height: 8),
                  _buildDetailRow('STATUS', isSuccess ? 'SETTLED & CAPTURED' : 'REFUNDED TO CARD', false, statusColor),
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
                            onPressed: () async {
                              try {
                                final savedPath = await InvoicePdfGenerator.generateAndDownloadInvoice(
                                  txnId: txn['id'],
                                  productName: txn['productName'],
                                  amountStr: txn['amount'],
                                  date: txn['date'],
                                  paymentMethod: txn['paymentMethod'],
                                  status: txn['status'],
                                  userEmail: userEmail,
                                  username: username,
                                );
                                
                                if (savedPath != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Downloaded successfully to $savedPath'),
                                      backgroundColor: lime,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to generate PDF: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
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
                              final details = 'Transaction: ${txn['productName']}\nID: ${txn['id']}\nAmount: ${txn['amount']}\nDate: ${txn['date']}';
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
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: valueColor ?? white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.copy, size: 10, color: lime),
            ],
          ],
        ),
      ],
    );
  }
}
