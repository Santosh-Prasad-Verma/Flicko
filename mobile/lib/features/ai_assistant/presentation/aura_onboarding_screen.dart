import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuraOnboardingScreen extends StatefulWidget {
  const AuraOnboardingScreen({super.key});

  @override
  State<AuraOnboardingScreen> createState() => _AuraOnboardingScreenState();
}

class _AuraOnboardingScreenState extends State<AuraOnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _bgAnimationController;

  static const Color _bgBlack = Color(0xFF06060E);
  static const Color _primaryAccent = Color(0xFF7B4FFF);

  @override
  void initState() {
    super.initState();
    _checkOnboardedStatus();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24), // common multiple for orbit speeds
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  Future<void> _checkOnboardedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('aura_onboarded') ?? false;
    if (onboarded && mounted) {
      context.go('/profile/settings/aura/dashboard');
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // 1. Deep Space background (Nebulas & twinkling stars)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: DeepSpaceBackgroundPainter(
                    animationValue: _bgAnimationController.value,
                  ),
                );
              },
            ),
          ),

          // 2. Pulse ambient glow behind mascot
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double pulse = _pulseController.value;
                return Container(
                  width: 280 + (40 * pulse),
                  height: 280 + (40 * pulse),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryAccent.withOpacity(0.20 + 0.10 * pulse),
                        _primaryAccent.withOpacity(0.05 * (1.0 - pulse)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Main interactive content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Header Row with back arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primaryAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _primaryAccent.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          'AI ASSISTANT',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFCBBAFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balanced spacer
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Mascot & Rotating Light Trails Stack
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Orbit 2: Back layer
                        _buildOrbit(
                          width: 270,
                          height: 100,
                          rotX: 65,
                          rotY: -20,
                          speedFactor: -3.0, // negative for reverse
                          border: Border(
                            bottom: BorderSide(
                                color: _primaryAccent.withOpacity(0.9),
                                width: 2),
                            right: BorderSide(
                                color: Colors.white.withOpacity(0.6),
                                width: 2.5),
                          ),
                        ),

                        // Orbit 3: Middle back layer
                        _buildOrbit(
                          width: 250,
                          height: 80,
                          rotX: 75,
                          rotY: 5,
                          speedFactor: 4.8,
                          border: Border(
                            top: BorderSide(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5),
                            right: BorderSide(
                                color: _primaryAccent.withOpacity(0.7),
                                width: 2),
                          ),
                        ),

                        // Glowing sphere element
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 140 * (1.0 + 0.1 * _pulseController.value),
                              height: 140 * (1.0 + 0.1 * _pulseController.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _primaryAccent.withOpacity(0.12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryAccent.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Mascot image with bobbing animation
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final double offset = 12.0 *
                                math.sin(_pulseController.value * math.pi);
                            return Transform.translate(
                              offset: Offset(0, -offset),
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/images/happy-robot-assistant.png',
                            width: 230,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Orbit 1: Front layer
                        _buildOrbit(
                          width: 260,
                          height: 90,
                          rotX: 70,
                          rotY: 15,
                          speedFactor: 4.0, // base speed multiplier
                          border: Border(
                            top: BorderSide(
                                color: Colors.white.withOpacity(0.85),
                                width: 3),
                            left: BorderSide(
                                color: _primaryAccent.withOpacity(0.4),
                                width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Text content: Title & Subtitle
                  Column(
                    children: [
                      Text(
                        'Ask Me\nAnything!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Welcome to your intelligent virtual assistant here to make your life easier',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8E8E9F),
                            fontSize: 13,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),

                  const Spacer(flex: 1),

                  // CTA Button: Get Started
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('aura_onboarded', true);
                      if (context.mounted) {
                        context.pushReplacement('/profile/settings/aura/dashboard');
                      }
                    },
                    child: Container(
                      height: 64,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _primaryAccent,
                            Color(0xFF5931CC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryAccent.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left icon in circular glass
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.send_rounded,
                                color: _primaryAccent,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Get Started',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              '»',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -2.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbit({
    required double width,
    required double height,
    required double rotX,
    required double rotY,
    required double speedFactor,
    required Border border,
  }) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final double rotationAngle =
            _rotationController.value * 2 * math.pi * speedFactor;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective projection
            ..rotateX(rotX * math.pi / 180)
            ..rotateY(rotY * math.pi / 180)
            ..rotateZ(rotationAngle),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: border,
          borderRadius: BorderRadius.all(
            Radius.elliptical(width / 2, height / 2),
          ),
        ),
      ),
    );
  }
}

class DeepSpaceBackgroundPainter extends CustomPainter {
  final double animationValue;

  DeepSpaceBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nebula 1: Purple Glow top-left
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7B4FFF).withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.25),
          radius: size.width * 0.9));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.25),
        size.width * 0.9, paint1);

    // 2. Nebula 2: Deep Indigo/Blue Glow bottom-right
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3A1599).withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.8, size.height * 0.75),
          radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.75),
        size.width * 0.8, paint2);
  }

  @override
  bool shouldRepaint(covariant DeepSpaceBackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
