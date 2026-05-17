import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class BillingSettingsScreen extends ConsumerStatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  ConsumerState<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends ConsumerState<BillingSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            margin: const EdgeInsets.all(8.0),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'BILLING',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveSubscriptionCard(),
            const SizedBox(height: 36),
            _buildPaymentMethodsSection(),
            const SizedBox(height: 36),
            _buildTransactionHistorySection(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    return Container(
      width: double.infinity,
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF373535), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Diagonal background watermark TEXT "FLICKO"
            Positioned(
              right: -40,
              bottom: 10,
              child: Opacity(
                opacity: 0.08,
                child: RotatedBox(
                  quarterTurns: 0,
                  child: Text(
                    'FLICKO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2.0,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ACTIVE SUBSCRIPTION pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A532E).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8F9952).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFBAE82C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVE SUBSCRIPTION',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFFBAE82C),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'FLICKO PLUS',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlimited access to exclusive drops, high-res\ndownloads, and early access features.',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFFAFAFB0),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '\$14.99',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' /mo',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF838385),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'RENEWS OCT 12, 2024',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF6B6B6D),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
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
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3E3E40), width: 1.5),
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
                            color: const Color(0xFFCFCECE),
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

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.credit_card, color: Color(0xFF8B8E93), size: 18),
            const SizedBox(width: 10),
            Text(
              'PAYMENT METHODS',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Primary Card info container
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF090909),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C1D1F), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B1E),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2D33), width: 1),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'VISA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '•••• 4242',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EXPIRES 12/25',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF696D73),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              // Active/Default Lime Green target circle
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC3F53B), width: 4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dotted Add Button
        CustomPaint(
          painter: _DottedBorderPainter(),
          child: Container(
            height: 50,
            width: double.infinity,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Color(0xFF6C7077), size: 18),
                const SizedBox(width: 8),
                Text(
                  'ADD PAYMENT METHOD',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF787C84),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionHistorySection() {
    final transactions = [
      _Txn(
        icon: Icons.autorenew,
        title: 'Flicko Plus - Monthly',
        price: '\$14.99',
        date: 'SEP 12, 2024',
        status: 'PAID',
      ),
      _Txn(
        icon: Icons.bolt,
        title: 'Drop: Neon Synthesis',
        price: '\$29.00',
        date: 'AUG 28, 2024',
        status: 'PAID',
        customIconBg: const Color(0xFF232428),
        iconColor: const Color(0xFFCCF442),
      ),
      _Txn(
        icon: Icons.autorenew,
        title: 'Flicko Plus - Monthly',
        price: '\$14.99',
        date: 'AUG 12, 2024',
        status: 'PAID',
      ),
      _Txn(
        icon: Icons.palette,
        title: 'Drop: Brutalist Echoes',
        price: '\$45.00',
        date: 'JUL 05, 2024',
        status: 'PAID',
        customIconBg: const Color(0xFF232428),
        iconColor: const Color(0xFF439BEE),
      ),
    ];

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
                  'TRANSACTION\nHISTORY',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'DOWNLOAD\nALL',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF696D73),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.download_outlined, color: Color(0xFF696D73), size: 18),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF141517), width: 1.5),
          ),
          child: Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  color: Color(0xFF141517),
                  thickness: 1.5,
                ),
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.customIconBg ?? const Color(0xFF141517),
                          ),
                          child: Icon(
                            t.icon,
                            color: t.iconColor ?? Colors.white54,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.date,
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF50535A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              t.price,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.status,
                              style: GoogleFonts.spaceGrotesk(
                                color: const Color(0xFF4CAF50),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(
                height: 1,
                color: Color(0xFF141517),
                thickness: 1.5,
              ),
              // Bottom View Older button
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 48,
                  color: const Color(0xFF0A0A0A),
                  alignment: Alignment.center,
                  child: Text(
                    'VIEW OLDER TRANSACTIONS',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF80848C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Txn {
  final IconData icon;
  final String title;
  final String price;
  final String date;
  final String status;
  final Color? customIconBg;
  final Color? iconColor;

  _Txn({
    required this.icon,
    required this.title,
    required this.price,
    required this.date,
    required this.status,
    this.customIconBg,
    this.iconColor,
  });
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF23262A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final RRect outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    var path = Path()..addRRect(outerRect);
    var dashWidth = 5.0;
    var dashSpace = 4.0;
    
    var dashedPath = Path();
    for (var metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
