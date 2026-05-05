import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'call_theme.dart';

/// Call transition animations — pickup, hangup, connecting.
///
/// These are full-screen animated overlays that play during
/// call state transitions to create a cinematic feel.
class CallTransitions {
  CallTransitions._();

  /// ── PICKUP ANIMATION ──
  /// Plays when a call is accepted. Shows a "LINK LOCKED" flash,
  /// viewfinder lock-on, and zooms into the call screen.
  static Future<T?> playPickup<T>(
    BuildContext context, {
    required Widget destination,
    String? callerName,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        opaque: true,
        transitionDuration: duration,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) {
          return _PickupTransition(
            animation: animation,
            callerName: callerName ?? '',
            destination: destination,
          );
        },
      ),
    );
  }

  /// ── HANGUP ANIMATION ──
  /// Plays when a call ends. Shows signal cutoff, static noise,
  /// and "LINK TERMINATED" status.
  static Future<void> playHangup(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 1500),
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, _) {
          return _HangupTransition(animation: animation);
        },
      ),
    );
  }

  /// ── CONNECTING ANIMATION ──
  /// Short overlay that plays while establishing connection.
  static OverlayEntry showConnecting(BuildContext context) {
    final overlay = OverlayEntry(
      builder: (context) => const _ConnectingOverlay(),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
    return overlay;
  }
}

// ═══════════════════════════════════════════
// ── PICKUP TRANSITION ──
// ═══════════════════════════════════════════
class _PickupTransition extends StatefulWidget {
  final Animation<double> animation;
  final String callerName;
  final Widget destination;

  const _PickupTransition({
    required this.animation,
    required this.callerName,
    required this.destination,
  });

  @override
  State<_PickupTransition> createState() => _PickupTransitionState();
}

class _PickupTransitionState extends State<_PickupTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Trigger flash at mid-point
    widget.animation.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _flashController.forward().then((_) {
              if (mounted) _flashController.reverse();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;

        // Phase 1 (0-0.4): HUD lock-on
        // Phase 2 (0.4-0.7): Flash + "LINK LOCKED"
        // Phase 3 (0.7-1.0): Zoom into destination

        if (t < 0.7) {
          return _buildLockOnPhase(t);
        } else {
          final zoomT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
          return Stack(
            children: [
              // Destination fading in
              Opacity(
                opacity: zoomT,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * zoomT,
                  child: widget.destination,
                ),
              ),
              // Lock-on fading out
              if (zoomT < 0.5)
                Opacity(
                  opacity: 1.0 - zoomT * 2,
                  child: _buildLockOnPhase(0.7),
                ),
            ],
          );
        }
      },
    );
  }

  Widget _buildLockOnPhase(double t) {
    final lockProgress = (t / 0.4).clamp(0.0, 1.0);
    final showText = t > 0.35;

    return Scaffold(
      backgroundColor: CallTheme.bg,
      body: Stack(
        children: [
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: GridPainter(),
          ),
          // Converging corner brackets
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  _animatedBracket(Alignment.topLeft, lockProgress),
                  _animatedBracket(Alignment.topRight, lockProgress),
                  _animatedBracket(Alignment.bottomLeft, lockProgress),
                  _animatedBracket(Alignment.bottomRight, lockProgress),
                  // Crosshair
                  Center(
                    child: Opacity(
                      opacity: lockProgress,
                      child: Container(
                        width: 200,
                        height: 1,
                        color: CallTheme.neonGreen
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: lockProgress,
                      child: Container(
                        width: 1,
                        height: 200,
                        color: CallTheme.neonGreen
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  // Center circle
                  Center(
                    child: Opacity(
                      opacity: lockProgress,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CallTheme.neonGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Flash overlay
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) {
              return Container(
                color: CallTheme.neonGreen
                    .withValues(alpha: _flashController.value * 0.4),
              );
            },
          ),
          // "LINK LOCKED" text
          if (showText)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 180),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    color: CallTheme.bg.withValues(alpha: 0.8),
                    child: Text(
                      '■ LINK LOCKED',
                      style: GoogleFonts.jetBrainsMono(
                        color: CallTheme.neonGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  if (widget.callerName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.callerName.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: CallTheme.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _animatedBracket(Alignment alignment, double progress) {
    const bracketSize = 40.0;
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    // Start from edges, converge toward center
    final offset = 80 * (1 - progress);

    return Positioned(
      top: isTop ? 30 + offset : null,
      bottom: isTop ? null : 30 + offset,
      left: isLeft ? 30 + offset : null,
      right: isLeft ? null : 30 + offset,
      child: SizedBox(
        width: bracketSize,
        height: bracketSize,
        child: CustomPaint(
          painter: CornerBracketPainter(
            color: CallTheme.neonGreen,
            strokeWidth: 3,
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ── HANGUP TRANSITION ──
// ═══════════════════════════════════════════
class _HangupTransition extends StatelessWidget {
  final Animation<double> animation;

  const _HangupTransition({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        // Phase 1 (0-0.3): Red flash
        // Phase 2 (0.3-0.7): Static noise + "LINK TERMINATED"
        // Phase 3 (0.7-1.0): Fade to black, then pop

        if (t > 0.95) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          });
        }

        return Scaffold(
          backgroundColor: CallTheme.bg,
          body: Stack(
            children: [
              // Static noise
              if (t > 0.2 && t < 0.8)
                CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _StaticNoisePainter(
                    density: ((t - 0.2) / 0.6).clamp(0.0, 1.0),
                  ),
                ),
              // Red flash
              if (t < 0.3)
                Container(
                  color: CallTheme.red
                      .withValues(alpha: (t / 0.3) * 0.3),
                ),
              // Scan lines
              if (t > 0.2 && t < 0.8)
                ...List.generate(10, (i) {
                  final y = (i * 80.0 + t * 200) %
                      MediaQuery.of(context).size.height;
                  return Positioned(
                    top: y,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: CallTheme.red.withValues(alpha: 0.1),
                    ),
                  );
                }),
              // "LINK TERMINATED" text
              if (t > 0.3 && t < 0.85)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: CallTheme.red
                            .withValues(alpha: (1 - t).clamp(0.0, 1.0)),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '■ LINK TERMINATED',
                        style: GoogleFonts.jetBrainsMono(
                          color: CallTheme.red
                              .withValues(alpha: (1 - t).clamp(0.0, 1.0)),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SESSION CLOSED',
                        style: GoogleFonts.jetBrainsMono(
                          color: CallTheme.textDim
                              .withValues(alpha: (1 - t).clamp(0.0, 1.0)),
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              // Fade to black
              if (t > 0.75)
                Container(
                  color: CallTheme.bg
                      .withValues(alpha: ((t - 0.75) / 0.25).clamp(0.0, 1.0)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// ── CONNECTING OVERLAY ──
// ═══════════════════════════════════════════
class _ConnectingOverlay extends StatefulWidget {
  const _ConnectingOverlay();

  @override
  State<_ConnectingOverlay> createState() => _ConnectingOverlayState();
}

class _ConnectingOverlayState extends State<_ConnectingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _controller.addListener(() {
      final newDots = (_controller.value * 4).floor() % 4;
      if (newDots != _dotCount) {
        setState(() => _dotCount = newDots);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CallTheme.bg.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning ring
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _controller.value * 2 * pi,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CallTheme.gridColor,
                        width: 3,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CallTheme.neonGreen,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'CONNECTING${'.' * (_dotCount + 1)}',
              style: GoogleFonts.jetBrainsMono(
                color: CallTheme.neonGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ESTABLISHING SECURE TUNNEL',
              style: GoogleFonts.jetBrainsMono(
                color: CallTheme.textDim,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ── STATIC NOISE PAINTER ──
// ═══════════════════════════════════════════
class _StaticNoisePainter extends CustomPainter {
  final double density;

  _StaticNoisePainter({required this.density});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()..style = PaintingStyle.fill;
    final count = (density * 2000).toInt();

    for (int i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextDouble();
      paint.color = Colors.white.withValues(alpha: brightness * 0.08 * density);
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticNoisePainter oldDelegate) => true;
}
