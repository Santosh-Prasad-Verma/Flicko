import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/gaming/providers/gaming_stats_provider.dart';

// ---------------------------------------------------------------------------
// Screen 3 — Redesigned Statistics Dashboard (Cyberpunk Brutalist)
// ---------------------------------------------------------------------------

class GamingStatsScreen extends ConsumerStatefulWidget {
  const GamingStatsScreen({super.key});

  @override
  ConsumerState<GamingStatsScreen> createState() => _GamingStatsScreenState();
}

class _GamingStatsScreenState extends ConsumerState<GamingStatsScreen> {
  // ── Color Palette (Flat Minimalist Theme) ─────────────────────────────
  static const _bgDark = Color(0xFF0C0C0F);
  static const _bgMid = Color(0xFF17171C);
  static const _border = Color(0xFF25252E);
  static const _brandLime = Color(0xFF52B788); // Neon Lime
  static const _emeraldGreen = Color(0xFF10B981); // Emerald Green

  // heatmap intensity palette
  static const _heatEmpty = Color(0xFF17171C);
  static const _heatLow = Color(0xFF133A27);
  static const _heatMed = Color(0xFF1F5F3E);
  static const _heatHigh = Color(0xFF52B788);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(gamingStatsProvider);

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: _bgDark,
      appBar: _buildAppBar(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgDark, _bgMid, _bgDark],
          ),
        ),
        child: SafeArea(
          child: statsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _brandLime),
            ),
            error: (err, _) => _buildErrorState(err.toString()),
            data: (stats) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDonutSection(stats.totalHours, stats.trend),
                  const SizedBox(height: 32),
                  _buildStatsGrid(stats),
                  const SizedBox(height: 32),
                  _buildTopGamesList(stats.topGames),
                  const SizedBox(height: 32),
                  _buildRecentCampaigns(stats.recentCampaigns),
                  const SizedBox(height: 32),
                  _buildXpHeatmap(stats.activityHeatmap),
                  const SizedBox(height: 60), // bottom-nav clearance
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _brandLime, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load stats',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _brandLime),
              onPressed: () => ref.invalidate(gamingStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () {
          if (context.canPop()) context.pop();
        },
      ),
      title: Text(
        'STATS HUB',
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: _brandLime, size: 22),
          onPressed: () {
            ref.invalidate(gamingStatsProvider);
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: _border,
          height: 1.0,
        ),
      ),
    );
  }

  // ── Playtime HUD Donut Ring ───────────────────────────────────────────────
  Widget _buildDonutSection(String totalHours, String trend) {
    return Center(
      child: SizedBox(
        width: 230,
        height: 230,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Static clean flat outline ring
            const CustomPaint(
              size: Size(220, 220),
              painter: DashedHudPainter(color: _border),
            ),
            // Solid donut ring sweep
            const CustomPaint(
              size: Size(180, 180),
              painter: DonutRingPainter(value: 0.72),
            ),
            // Inner content panel
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL PLAYTIME',
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalHours,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brandLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _brandLime.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    '$trend win rate',
                    style: GoogleFonts.spaceMono(
                      color: _brandLime,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Detailed Ludo Stats Grid ──────────────────────────────────────────────
  Widget _buildStatsGrid(GamingStats stats) {
    final winRate = stats.ludoPlayed > 0 ? (stats.ludoWon * 100 ~/ stats.ludoPlayed) : 0;
    final playtimeHours = (stats.ludoMinutes / 60.0).toStringAsFixed(1);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: [
        _buildStatGridCard(
          title: 'MATCHES PLAYED',
          value: '${stats.ludoPlayed}',
          icon: Icons.casino_outlined,
          color: const Color(0xFF8B5CF6), // Neon Purple
        ),
        _buildStatGridCard(
          title: 'VICTORIES',
          value: '${stats.ludoWon}',
          icon: Icons.emoji_events_outlined,
          color: const Color(0xFFFBBF24), // Gold
        ),
        _buildStatGridCard(
          title: 'WIN RATIO',
          value: '$winRate%',
          icon: Icons.pie_chart_outline_rounded,
          color: const Color(0xFF52B788), // Neon Lime
        ),
        _buildStatGridCard(
          title: 'PLAY TIME',
          value: '${playtimeHours}h',
          icon: Icons.hourglass_empty_rounded,
          color: const Color(0xFF3B82F6), // Blue
        ),
      ],
    );
  }

  Widget _buildStatGridCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Corner Notch Accent
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(8),
                ),
                border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.3), width: 1.0),
                  left: BorderSide(color: color.withValues(alpha: 0.3), width: 1.0),
                ),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 12),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Games List ────────────────────────────────────────────────────────
  Widget _buildTopGamesList(List<TopGame> games) {
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Games',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...games.map((g) {
          final color = _parseHexColor(g.color, fallback: _brandLime);
          final initials = g.name.isNotEmpty
              ? g.name.split(' ').map((e) => e[0]).join().toUpperCase()
              : 'G';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _border,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Game Badge Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.spaceMono(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title and Progress representation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: g.hours.contains('0.0') ? 0.05 : 0.85,
                          backgroundColor: const Color(0xFF16161A),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Hours Label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      g.hours,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PLAYED',
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF94A3B8),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Recent Campaigns ────────────────────────────────────────────────────
  Widget _buildRecentCampaigns(List<Campaign> campaigns) {
    if (campaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Campaigns',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...campaigns.map((c) {
          final progress = (c.progress.clamp(0, 100)) / 100.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _border,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _brandLime.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _brandLime.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.spaceMono(
                          color: _brandLime,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF16161A),
                          valueColor: const AlwaysStoppedAnimation<Color>(_brandLime),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${c.progress}%',
                      style: GoogleFonts.orbitron(
                        color: _brandLime,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── XP Activity Heatmap ─────────────────────────────────────────────────
  Widget _buildXpHeatmap(List<int> intensities) {
    final cells = List<int>.generate(
      60,
      (i) => i < intensities.length ? intensities[i].clamp(0, 3) : 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Telemetry XP Log',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _border,
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: cells.map((i) {
                  final color = [_heatEmpty, _heatLow, _heatMed, _heatHigh][i];
                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Dormant',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF94A3B8),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ...[_heatEmpty, _heatLow, _heatMed, _heatHigh].map(
                    (c) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hyperactive',
                    style: GoogleFonts.spaceMono(
                      color: _brandLime,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom Navigation Bar ───────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    const activeIndex = 3; // Leaderboard

    final items = <_NavItem>[
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.explore_rounded, 'Explore'),
      _NavItem(Icons.sports_esports_rounded, 'Play'),
      _NavItem(Icons.leaderboard_rounded, 'Leaderboard'),
      _NavItem(Icons.person_rounded, 'Profile'),
    ];

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _bgMid,
        border: Border(
          top: BorderSide(color: _border, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (idx) {
          final isActive = idx == activeIndex;
          final item = items[idx];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (idx == 0) context.go('/');
              if (idx == 1) {
                context.push('/discover');
              }
              if (idx == 2) context.go('/gaming');
              if (idx == 4) {
                final userId = ref.read(currentUserIdProvider);
                if (userId != null) {
                  context.push('/profile/$userId');
                }
              }
            },
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isActive)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _brandLime.withValues(alpha: 0.15),
                          ),
                        ),
                          Icon(
                            item.icon,
                            color: isActive ? _brandLime : Colors.white38,
                            size: 24,
                          ),
                        ],
                      ),

                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      color: isActive ? _brandLime : Colors.white38,
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────
  static Color _parseHexColor(String hex, {required Color fallback}) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }
}

// ── Dashed circular outline HUD rotating painter ──
class DashedHudPainter extends CustomPainter {
  final Color color;
  const DashedHudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 5.0;
    const dashSpace = 8.0;

    final circumference = 2 * pi * radius;
    final numDashes = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < numDashes; i++) {
      final angle = (i * (dashWidth + dashSpace)) / radius;
      final sweep = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedHudPainter oldDelegate) => oldDelegate.color != color;
}

// ── 3-colour sweep-gradient arc at ~72% fill ──
class DonutRingPainter extends CustomPainter {
  final double value;
  const DonutRingPainter({this.value = 0.72});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 16.0;
    final sweepAngle = 2 * pi * value;
    const startAngle = -pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF16161A);
    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF10B981), // Emerald
          Color(0xFF52B788), // Neon Lime
          Color(0xFF34D399), // Mint
          Color(0xFF10B981), // Emerald
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant DonutRingPainter oldDelegate) => oldDelegate.value != value;
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
