import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EntranceWarpOverlay extends StatefulWidget {
  final String warpId;
  final VoidCallback onComplete;

  const EntranceWarpOverlay({
    super.key,
    required this.warpId,
    required this.onComplete,
  });

  @override
  State<EntranceWarpOverlay> createState() => _EntranceWarpOverlayState();
}

class _EntranceWarpOverlayState extends State<EntranceWarpOverlay> with TickerProviderStateMixin {
  late AnimationController _warpController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // 1.2 seconds transition sweep
    _warpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Fade out smoothly towards the end
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
    ]).animate(_warpController);

    _warpController.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _warpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _warpController,
      builder: (context, child) {
        final opacity = _opacityAnimation.value;
        if (opacity <= 0.0) return const SizedBox.shrink();

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
              child: CustomPaint(
                painter: EntranceWarpPainter(
                  warpId: widget.warpId,
                  progress: _warpController.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EntranceWarpPainter extends CustomPainter {
  final String warpId;
  final double progress;
  final math.Random _random = math.Random(12345); // Seeded to maintain deterministic grid/column layouts

  EntranceWarpPainter({
    required this.warpId,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (warpId) {
      case 'cyber-matrix-warp':
        _paintMatrixRain(canvas, size);
        break;
      case 'grid-explosion-warp':
        _paintGridExpansion(canvas, size);
        break;
      case 'neon-rift-warp':
        _paintNeonRiftSplit(canvas, size);
        break;
      default:
        break;
    }
  }

  void _paintMatrixRain(Canvas canvas, Size size) {
    // Solid base dark backdrop sweeping in and fading
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.85 * (1.0 - progress));
    canvas.drawRect(Offset.zero & size, bgPaint);

    final fontColor = const Color(0xFF00FF66);
    final textStyle = GoogleFonts.shareTechMono(
      color: fontColor,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    // Grid columns
    const int columnWidth = 18;
    final int cols = (size.width / columnWidth).ceil();

    for (int i = 0; i < cols; i++) {
      // Column configurations seeded deterministically
      final double speedMultiplier = 1.0 + _random.nextDouble() * 1.5;
      final double offsetDelay = _random.nextDouble() * 0.4;
      
      // Calculate column's current vertical sweep progress
      double colProgress = (progress - offsetDelay) * speedMultiplier;
      if (colProgress < 0) continue;
      if (colProgress > 1.0) colProgress = 1.0;

      final double colX = i * columnWidth.toDouble();
      final double sweepY = colProgress * size.height;

      // Draw descending matrix code lines
      final int chars = (sweepY / 18).floor();
      for (int c = 0; c <= chars; c++) {
        final double charY = c * 18.0;
        final double distanceToSweep = (sweepY - charY).abs();
        
        // Fading intensity based on distance from head sweep
        double charOpacity = 1.0 - (distanceToSweep / (size.height * 0.45));
        if (charOpacity < 0) charOpacity = 0.0;
        if (charOpacity > 1) charOpacity = 1.0;

        // Flash neon light at the head of columns
        final isHead = c == chars;
        final Color charColor = isHead 
            ? Colors.white 
            : fontColor.withOpacity(charOpacity * (1.0 - progress));

        final String binaryChar = _random.nextBool() ? '0' : '1';

        final textSpan = TextSpan(
          text: binaryChar,
          style: textStyle.copyWith(color: charColor),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(colX, charY));
      }
    }
  }

  void _paintGridExpansion(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.9 * (1.0 - progress));
    canvas.drawRect(Offset.zero & size, bgPaint);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Outer grid line neon neon paint
    final cyanPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final magentaPaint = Paint()
      ..color = const Color(0xFFFF007F).withOpacity(0.8 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw perspective lines exploding from the center
    const int numRadialLines = 24;
    for (int i = 0; i < numRadialLines; i++) {
      final angle = (i * 2 * math.pi) / numRadialLines;
      
      // Expand outer points dynamically
      final double endRadius = math.max(size.width, size.height) * progress * 1.5;
      final double outerX = centerX + math.cos(angle) * endRadius;
      final double outerY = centerY + math.sin(angle) * endRadius;

      // Inner points contract or scale
      final double startRadius = math.max(size.width, size.height) * progress * 0.1;
      final double innerX = centerX + math.cos(angle) * startRadius;
      final double innerY = centerY + math.sin(angle) * startRadius;

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), i % 2 == 0 ? cyanPaint : magentaPaint);
    }

    // Draw concentric wobbly wireframe grid squares or circles expanding outwards
    const int numRings = 6;
    for (int r = 1; r <= numRings; r++) {
      // Scale dynamic ring radius
      final double ringProgress = (progress + (r / numRings)) % 1.0;
      final double radius = math.max(size.width, size.height) * ringProgress * 0.8;

      if (radius <= 0) continue;

      final path = Path();
      const int numSteps = 16;
      for (int s = 0; s <= numSteps; s++) {
        final angle = (s * 2 * math.pi) / numSteps;
        
        // Add wobbly synthwave modulation based on progress
        final double wobble = 6.0 * math.sin(angle * 4 + progress * 2 * math.pi);
        final double x = centerX + math.cos(angle) * (radius + wobble);
        final double y = centerY + math.sin(angle) * (radius + wobble);

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, r % 2 == 0 ? cyanPaint : magentaPaint);
    }
  }

  void _paintNeonRiftSplit(Canvas canvas, Size size) {
    final double splitProgress = Curves.easeInOut.transform(progress);

    // Left and Right dark solid curtains moving apart
    final curtainPaint = Paint()..color = Colors.black.withOpacity(0.95 * (1.0 - progress));
    
    // Left side
    final double leftWidth = (size.width / 2) * (1.0 - splitProgress);
    canvas.drawRect(Rect.fromLTWH(0, 0, leftWidth, size.height), curtainPaint);

    // Right side
    final double rightStart = (size.width / 2) + (size.width / 2) * splitProgress;
    canvas.drawRect(Rect.fromLTWH(rightStart, 0, size.width - rightStart, size.height), curtainPaint);

    // Draw electrical sparks and neon lighting arcs along the splitting rifts
    if (progress < 0.95) {
      final double leftEdge = leftWidth;
      final double rightEdge = rightStart;

      final cyanRiftPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      final magentaRiftPaint = Paint()
        ..color = const Color(0xFFFF007F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      final cyanPath = Path();
      final magentaPath = Path();

      cyanPath.moveTo(leftEdge, 0);
      magentaPath.moveTo(rightEdge, 0);

      // Generating wobbly lightning arc coordinates
      const double segments = 12;
      final double segmentHeight = size.height / segments;
      
      for (int i = 1; i <= segments; i++) {
        final double y = i * segmentHeight;
        
        // Add random horizontal offsets to simulate electrical spark arcs
        final double wobbleLeft = (i % 2 == 0 ? 10.0 : -10.0) * _random.nextDouble() * (1.0 - progress);
        final double wobbleRight = (i % 2 == 0 ? -10.0 : 10.0) * _random.nextDouble() * (1.0 - progress);

        cyanPath.lineTo(leftEdge + wobbleLeft, y);
        magentaPath.lineTo(rightEdge + wobbleRight, y);
      }

      // Draw glowing overlays
      canvas.drawPath(cyanPath, cyanRiftPaint);
      canvas.drawPath(magentaPath, magentaRiftPaint);

      // Electrical cross-sparks jumping across rifts occasionally
      if (_random.nextDouble() < 0.5) {
        final sparkPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final sparkPath = Path();
        final double startY = _random.nextDouble() * size.height;
        sparkPath.moveTo(leftEdge, startY);
        sparkPath.lineTo((leftEdge + rightEdge) / 2 + (_random.nextDouble() * 20 - 10), startY + (_random.nextDouble() * 30 - 15));
        sparkPath.lineTo(rightEdge, startY + (_random.nextDouble() * 50 - 25));
        canvas.drawPath(sparkPath, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EntranceWarpPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
