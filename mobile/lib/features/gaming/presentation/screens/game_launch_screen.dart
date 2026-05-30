import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Ember particle data
// ---------------------------------------------------------------------------

class _Ember {
  _Ember({required Random rng, required Size bounds}) {
    x = rng.nextDouble() * bounds.width;
    y = rng.nextDouble() * bounds.height;
    size = 1.0 + rng.nextDouble() * 3.0;
    opacity = 0.3 + rng.nextDouble() * 0.7;
    speed = 0.3 + rng.nextDouble() * 1.2;
    drift = rng.nextDouble() * 2.0 * pi; // phase for sine drift
    colorIndex = rng.nextInt(3); // 0 = neon lime, 1 = emerald green, 2 = dimmed green
  }

  late double x;
  late double y;
  late double size;
  late double opacity;
  late double speed;
  late double drift;
  late int colorIndex;
}

// ---------------------------------------------------------------------------
// EmbersPainter – draws ~40 rising, drifting particles
// ---------------------------------------------------------------------------

class _EmbersPainter extends CustomPainter {
  _EmbersPainter({
    required this.animation,
    required this.embers,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Ember> embers;

  static const List<Color> _colors = [
    Color(0xFF52B788), // neon lime
    Color(0xFF10B981), // emerald green
    Color(0xFF40916C), // dimmed green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value; // 0 → 1 repeating

    for (final ember in embers) {
      // Vertical rise – wraps around
      final double dy = (ember.y - ember.speed * t * size.height) % size.height;
      // Horizontal sine drift
      final double dx =
          ember.x + sin(ember.drift + t * 2.0 * pi) * 18.0;

      final paint = Paint()
        ..color = _colors[ember.colorIndex].withValues(alpha: ember.opacity * (0.5 + 0.5 * sin(t * 2 * pi + ember.drift)))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(Offset(dx % size.width, dy), ember.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// GameLaunchScreen
// ---------------------------------------------------------------------------

class GameLaunchScreen extends StatefulWidget {
  const GameLaunchScreen({super.key});

  @override
  State<GameLaunchScreen> createState() => _GameLaunchScreenState();
}

class _GameLaunchScreenState extends State<GameLaunchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _emberController;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();

    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // We initialise embers with a placeholder size; positions are normalised
    // relative to screen size inside the painter, but we seed with a large
    // virtual canvas so the distribution looks natural on first frame.
    final rng = Random(42);
    _embers = List.generate(
      40,
      (_) => _Ember(rng: rng, bounds: const Size(400, 900)),
    );
  }

  @override
  void dispose() {
    _emberController.dispose();
    super.dispose();
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Full-screen hero background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/gaming/armored_warrior.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2) Dramatic vertical gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF050505).withValues(alpha: 0.4),
                    const Color(0xFF050505).withValues(alpha: 0.85),
                    const Color(0xFF0F0F0F),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // 3) Floating embers / particles
          Positioned.fill(
            child: CustomPaint(
              painter: _EmbersPainter(
                animation: _emberController,
                embers: _embers,
              ),
            ),
          ),

          // 4) Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ── App icon monogram ──
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F0F0F).withValues(alpha: 0.7),
                      border: Border.all(
                        color: const Color(0xFF52B788).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF52B788).withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'N',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF52B788),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Username greeting ──
                  Text(
                    'Good evening, Valkyrie!',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Large heading ──
                  Text(
                    'Ready for\nBattle?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),

                  const Spacer(),

                  // ── START EXPEDITION button ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        context.push('/gaming/matchmaking?activity=Chess');
                      },
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF52B788),
                              Color(0xFF10B981),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF52B788).withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'START EXPEDITION',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '»',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),

      // 5) Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050505).withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavIcon(icon: Icons.home_outlined, label: 'Home'),
                _NavIcon(icon: Icons.explore_outlined, label: 'Explore'),
                _NavIcon(
                  icon: Icons.sports_esports,
                  label: 'Play',
                  isActive: true,
                ),
                _NavIcon(
                  icon: Icons.leaderboard_outlined,
                  label: 'Leaderboard',
                ),
                _NavIcon(icon: Icons.person_outline, label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav icon helper
// ---------------------------------------------------------------------------

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isActive ? 10 : 6),
          decoration: isActive
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF52B788).withValues(alpha: 0.18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF52B788).withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                )
              : null,
          child: Icon(
            icon,
            color: isActive
                ? const Color(0xFF52B788)
                : Colors.white.withValues(alpha: 0.45),
            size: isActive ? 28 : 22,
          ),
        ),
        if (!isActive) const SizedBox(height: 2),
        if (!isActive)
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}
