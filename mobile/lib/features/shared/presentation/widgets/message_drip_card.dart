import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/store/data/drip_card_service.dart';

class MessageDripCard extends ConsumerStatefulWidget {
  final Widget child;
  final String? dripCardId;
  final String? authorId;
  final bool forcePreview; // If true, always renders the effect even if animations are paused

  const MessageDripCard({
    super.key,
    required this.child,
    this.dripCardId,
    this.authorId,
    this.forcePreview = false,
  });

  @override
  ConsumerState<MessageDripCard> createState() => _MessageDripCardState();
}

class _MessageDripCardState extends ConsumerState<MessageDripCard> with TickerProviderStateMixin {
  late AnimationController _glintController;
  late AnimationController _glitchController;
  Timer? _glitchTimer;
  double _glitchIntensity = 0.0;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Continuous loop for specular gold sweep
    _glintController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Glitch trigger controller
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Periodically trigger a quick wobbly glitch effect
    _glitchTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _glitchIntensity = 1.0;
        });
        _glitchController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _glitchIntensity = 0.0;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _glintController.dispose();
    _glitchController.dispose();
    _glitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the active drip card ID
    String? resolvedId = widget.dripCardId;
    if (resolvedId == null && widget.authorId != null) {
      final currentUserId = ref.watch(currentUserIdProvider);
      if (currentUserId != null && widget.authorId == currentUserId) {
        final equippedCard = ref.watch(equippedDripCardProvider).value;
        resolvedId = equippedCard?.id;
      }
    }

    if (resolvedId == null) {
      return widget.child;
    }

    // Render based on custom style
    switch (resolvedId) {
      case 'toxic-hazard-card':
        return _buildToxicHazardCard();
      case 'cyber-glitch-card':
        return _buildCyberGlitchCard();
      case 'specular-gold-card':
        return _buildSpecularGoldCard();
      default:
        return widget.child;
    }
  }

  Widget _buildToxicHazardCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF66).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00FF66).withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF66).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        painter: ToxicHazardBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildCyberGlitchCard() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        // Calculate offset twitch when glitching
        double offsetX = 0.0;
        double offsetY = 0.0;
        if (_glitchIntensity > 0) {
          final t = _glitchController.value;
          if (t < 0.3) {
            offsetX = _random.nextDouble() * 4 - 2;
            offsetY = _random.nextDouble() * 3 - 1.5;
          } else if (t < 0.6) {
            offsetX = _random.nextDouble() * -4 + 2;
            offsetY = _random.nextDouble() * -3 + 1.5;
          } else if (t < 0.9) {
            offsetX = _random.nextDouble() * 2 - 1;
            offsetY = _random.nextDouble() * 1.5 - 0.75;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Magenta Shadow Offset Background
            Positioned(
              left: 2 + offsetX,
              top: 2 + offsetY,
              right: -2 + offsetX,
              bottom: -2 + offsetY,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFFFF007F),
                    width: 2.5,
                  ),
                ),
              ),
            ),
            // Cyan Shadow Offset Background
            Positioned(
              left: -2 - offsetX,
              top: -2 - offsetY,
              right: 2 - offsetX,
              bottom: 2 - offsetY,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFF00E5FF),
                    width: 2.5,
                  ),
                ),
              ),
            ),
            // Front container
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: widget.child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpecularGoldCard() {
    return AnimatedBuilder(
      animation: _glintController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A4500).withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomPaint(
            painter: GoldGlintPainter(progress: _glintController.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class ToxicHazardBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFAA61A) // Warning Gold/Yellow
      ..style = PaintingStyle.fill;

    final stripePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw hazard blocks on corners
    // Top-Left corner block
    const blockWidth = 14.0;
    const blockHeight = 14.0;

    // TL
    _drawHazardStripes(canvas, const Rect.fromLTWH(0, 0, blockWidth, blockHeight), paint, stripePaint);

    // TR
    _drawHazardStripes(canvas, Rect.fromLTWH(size.width - blockWidth, 0, blockWidth, blockHeight), paint, stripePaint);

    // BL
    _drawHazardStripes(canvas, Rect.fromLTWH(0, size.height - blockHeight, blockWidth, blockHeight), paint, stripePaint);

    // BR
    _drawHazardStripes(canvas, Rect.fromLTWH(size.width - blockWidth, size.height - blockHeight, blockWidth, blockHeight), paint, stripePaint);
  }

  void _drawHazardStripes(Canvas canvas, Rect rect, Paint bgPaint, Paint stripePaint) {
    canvas.drawRect(rect, bgPaint);

    // Draw diagonal warning lines inside the block
    canvas.save();
    canvas.clipRect(rect);
    
    final path = Path();
    const stripeWidth = 3.0;
    const spacing = 6.0;
    
    for (double i = -rect.height; i < rect.width + rect.height; i += spacing) {
      path.moveTo(rect.left + i, rect.top);
      path.lineTo(rect.left + i + stripeWidth, rect.top);
      path.lineTo(rect.left + i - rect.height + stripeWidth, rect.bottom);
      path.lineTo(rect.left + i - rect.height, rect.bottom);
      path.close();
    }
    
    canvas.drawPath(path, stripePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoldGlintPainter extends CustomPainter {
  final double progress;

  GoldGlintPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Loop specular sweep: diagonal light source from left to right
    // Starts at -size.width and goes up to 2 * size.width
    final sweepX = -rect.width + (progress * rect.width * 2.5);

    final glintGradient = ui.Gradient.linear(
      Offset(sweepX, 0),
      Offset(sweepX + 60, rect.height),
      [
        Colors.transparent,
        const Color(0x33FFFFFF),
        const Color(0xBBFFFFFF), // Glint shine
        const Color(0x33FFFFFF),
        Colors.transparent,
      ],
      [0.0, 0.35, 0.5, 0.65, 1.0],
    );

    final glintPaint = Paint()
      ..shader = glintGradient
      ..style = PaintingStyle.fill;

    // Paint shine sweep across card face
    canvas.drawRect(rect, glintPaint);

    // Paint dynamic golden glint overlays along border paths to accentuate specular edges
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(sweepX, 0),
        Offset(sweepX + 40, 0),
        [
          Colors.transparent,
          const Color(0xFFFFFFFF),
          Colors.transparent,
        ],
      )
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant GoldGlintPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
