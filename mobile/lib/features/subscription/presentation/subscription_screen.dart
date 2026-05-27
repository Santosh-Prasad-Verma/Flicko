import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isAnnual = true;

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);
  static const _gold = Color(0xFFFFD700);

  final _features = [
    {'icon': Icons.hd_rounded, 'title': 'HD Video Calls', 'desc': 'Crystal clear 1080p video'},
    {'icon': Icons.emoji_events_rounded, 'title': 'Exclusive Badges', 'desc': 'Stand out with Pro badge'},
    {'icon': Icons.palette_rounded, 'title': 'Custom Themes', 'desc': 'Unlock all premium themes'},
    {'icon': Icons.cloud_upload_rounded, 'title': 'Larger Uploads', 'desc': '100MB file uploads'},
    {'icon': Icons.gif_box_rounded, 'title': 'Animated Avatar', 'desc': 'Use GIF profile pictures'},
    {'icon': Icons.support_agent_rounded, 'title': 'Priority Support', 'desc': '24/7 dedicated help'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.black, size: 16),
                  const SizedBox(width: 4),
                  Text('PRO',
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('Flicko Pro',
                style: GoogleFonts.epilogue(
                    color: _white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_gold, Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bolt, color: Colors.black, size: 48),
                  const SizedBox(height: 12),
                  Text('UNLOCK EVERYTHING',
                      style: GoogleFonts.epilogue(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 6),
                  Text('Premium features for power users',
                      style: GoogleFonts.inter(
                          color: Colors.black87, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Billing toggle
            Row(
              children: [
                Expanded(
                  child: _buildToggle('MONTHLY', !_isAnnual, () => setState(() => _isAnnual = false)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggle('ANNUAL', _isAnnual, () => setState(() => _isAnnual = true), badge: '-17%'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Price
            Center(
              child: Column(
                children: [
                  Text(_isAnnual ? '₹329' : '₹399',
                      style: GoogleFonts.epilogue(
                          color: _white, fontSize: 48, fontWeight: FontWeight.w900)),
                  Text(_isAnnual ? '/month, billed annually' : '/month',
                      style: GoogleFonts.inter(color: _muted, fontSize: 14)),
                  if (_isAnnual) ...[
                    const SizedBox(height: 4),
                    Text('Save ₹840/year',
                        style: GoogleFonts.spaceGrotesk(
                            color: _neon, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Features
            Text('PRO FEATURES',
                style: GoogleFonts.epilogue(
                    color: _white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            ...(_features.map((f) => _buildFeatureItem(f))),
            const SizedBox(height: 32),

            // Subscribe button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stripe checkout coming soon!')));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_gold, Color(0xFFFF8C00)]),
                ),
                child: Center(
                  child: Text('SUBSCRIBE NOW',
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('Cancel anytime • No hidden fees',
                  style: GoogleFonts.inter(color: _muted, fontSize: 12)),
            ),
            const SizedBox(height: 32),

            // Terms
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text(
                'By subscribing to Flicko Pro, you agree to our Terms of Service and Privacy Policy. '
                'Your subscription will auto-renew unless cancelled at least 24 hours before the end of the current period.',
                style: GoogleFonts.inter(color: _muted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool selected, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _neon : _surface,
          border: Border.all(color: selected ? _neon : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      color: selected ? Colors.black : _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: selected ? Colors.black : _neon,
                  child: Text(badge,
                      style: GoogleFonts.spaceMono(
                          color: selected ? _neon : Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(Map<String, dynamic> feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              border: Border.all(color: _gold.withValues(alpha: 0.2)),
            ),
            child: Icon(feature['icon'] as IconData, color: _gold, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature['title'] as String,
                    style: GoogleFonts.spaceGrotesk(
                        color: _white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(feature['desc'] as String,
                    style: GoogleFonts.inter(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: _neon, size: 20),
        ],
      ),
    );
  }
}
