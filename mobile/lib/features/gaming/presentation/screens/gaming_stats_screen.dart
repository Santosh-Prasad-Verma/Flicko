import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/gaming/providers/gaming_stats_provider.dart';

// ---------------------------------------------------------------------------
// Screen 3 — Statistics Dashboard
// ---------------------------------------------------------------------------

class GamingStatsScreen extends ConsumerWidget {
  const GamingStatsScreen({super.key});

  // ── palette ──────────────────────────────────────────────────────────────
  static const _bgDark = Color(0xFF050505);
  static const _bgMid = Color(0xFF0F0F0F);
  static const _brandLime = Color(0xFF52B788); // brand Neon Lime
  static const _emeraldGreen = Color(0xFF10B981); // Emerald Green
  static const _dimmedGreen = Color(0xFF40916C); // Dimmed Green
  static const _successGreen = Color(0xFF22C55E); // Success Green

  // heatmap intensity palette (0=empty .. 3=high)
  static const _heatEmpty = Color(0xFF1A1A1A);
  static const _heatLow = Color(0xFF1B3D2F);
  static const _heatMed = Color(0xFF2D6A4F);
  static const _heatHigh = Color(0xFF52B788);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gamingStatsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
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
            error: (err, _) => _buildErrorState(ref, err.toString()),
            data: (stats) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildDonutSection(stats.totalHours, stats.trend),
                  const SizedBox(height: 32),
                  _buildPodiumRow(stats.topGames),
                  const SizedBox(height: 32),
                  _buildRecentCampaigns(stats.recentCampaigns),
                  const SizedBox(height: 32),
                  _buildXpHeatmap(stats.activityHeatmap),
                  const SizedBox(height: 100), // bottom-nav clearance
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
  Widget _buildErrorState(WidgetRef ref, String message) {
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
      backgroundColor: const Color(0xFF050505),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () {
          if (context.canPop()) context.pop();
        },
      ),
      title: Text(
        'My Stats',
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded,
              color: Colors.white70, size: 22),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── 3‑D Tilted Donut Ring ───────────────────────────────────────────────
  Widget _buildDonutSection(String totalHours, String trend) {
    final isPositive = trend.startsWith('+');
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(-0.4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _brandLime.withValues(alpha: 0.25),
                        blurRadius: 60,
                        spreadRadius: 10),
                    BoxShadow(
                        color: _dimmedGreen.withValues(alpha: 0.15),
                        blurRadius: 80,
                        spreadRadius: 20),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(200, 200),
                painter: DonutRingPainter(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalHours,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$trend ${isPositive ? '↑' : '↓'}',
                    style: GoogleFonts.inter(
                      color: isPositive ? _successGreen : _brandLime,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top‑3 Podium Row ───────────────────────────────────────────────────
  Widget _buildPodiumRow(List<TopGame> games) {
    if (games.isEmpty) return const SizedBox.shrink();
    final emojis = {
      'Ludo Royale': '🎲',
      'Ludo': '🎲',
      'Cyber Arena': '🎮',
      'Cyber Ninja': '🥷',
      'Star Commander': '🚀',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: games.take(3).map((g) {
        final emoji = emojis[g.name] ?? '🎮';
        final color = _parseHexColor(g.color, fallback: _brandLime);
        return _podiumItem(emoji, g.name, g.hours, color);
      }).toList(),
    );
  }

  Widget _podiumItem(String emoji, String name, String hours, Color color) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.3), Colors.transparent],
              radius: 0.85,
            ),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2),
            ],
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hours,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
        ),
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
          'Recent Campaigns',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...campaigns.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _campaignCard(c),
            )),
      ],
    );
  }

  Widget _campaignCard(Campaign c) {
    final progress = (c.progress.clamp(0, 100)) / 100.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${c.progress}%',
                    style: GoogleFonts.orbitron(
                      color: _emeraldGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_brandLime, _dimmedGreen],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                              color: _brandLime.withValues(alpha: 0.4), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── XP Activity Heatmap ─────────────────────────────────────────────────
  Widget _buildXpHeatmap(List<int> intensities) {
    // Defensive normalisation: ensure 60 cells, clamp to 0..3
    final cells = List<int>.generate(
      60,
      (i) => i < intensities.length ? intensities[i].clamp(0, 3) : 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'XP Activity',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: GridView.count(
                crossAxisCount: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                children: cells.map((i) {
                  final color = [_heatEmpty, _heatLow, _heatMed, _heatHigh][i];
                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: i >= 2
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 6),
                            ]
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less ',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
            ...[_heatEmpty, _heatLow, _heatMed, _heatHigh].map(
              (c) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text(' More',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
          ],
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

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: _bgDark.withValues(alpha: 0.85),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (idx) {
              final isActive = idx == activeIndex;
              final item = items[idx];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (idx == 2) context.go('/gaming');
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
                                color: _brandLime.withValues(alpha: 0.18),
                                boxShadow: [
                                  BoxShadow(
                                      color: _brandLime.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      spreadRadius: 1),
                                ],
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
        ),
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

// ═══════════════════════════════════════════════════════════════════════════
// DonutRingPainter — 3‑colour sweep‑gradient arc at ~75 % fill
// ═══════════════════════════════════════════════════════════════════════════

class DonutRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 28.0;
    const sweepAngle = 4.7; // ~75 % of 2π
    const startAngle = -pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          Color(0xFF2D6A4F), // deep green
          Color(0xFF10B981), // emerald green
          Color(0xFF52B788), // neon lime
          Color(0xFF2D6A4F), // loop back
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
