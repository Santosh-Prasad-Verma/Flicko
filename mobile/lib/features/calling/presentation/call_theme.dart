import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared cyberpunk design tokens and painters for all call screens.
class CallTheme {
  CallTheme._();

  // ── Colors ──
  static const bg = Color(0xFF0A0A0A);
  static const neonGreen = Color(0xFFCBEF17);
  static const gridColor = Color(0xFF1A1A1A);
  static const surfaceDark = Color(0xFF151515);
  static const borderDim = Color(0xFF2A2A2A);
  static const textDim = Color(0xFF555555);
  static const textMid = Color(0xFF888888);
  static const red = Color(0xFFFF3B3B);
  static const white = Colors.white;
  static const cyan = Color(0xFF00E5FF);
  static const amber = Color(0xFFFFAB00);

  // ── Typography ──
  static TextStyle monoLabel({
    Color color = textMid,
    double size = 11,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
      );

  static TextStyle heading({
    Color color = white,
    double size = 64,
  }) =>
      GoogleFonts.spaceGrotesk(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        height: 1,
      );

  // ── Common Action Button ──
  static Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = neonGreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.2) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? activeColor : borderDim,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Icon(icon, color: isActive ? activeColor : white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: isActive ? activeColor : textDim,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tech Label ──
  static Widget techLabel(String text, {Color color = textMid}) {
    return Text(text, style: monoLabel(color: color));
  }

  // ── Bottom Stat ──
  static Widget bottomStat(String text, {Color color = textDim}) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget bottomSeparator() {
    return Text(
      '|',
      style: GoogleFonts.jetBrainsMono(
        color: borderDim,
        fontSize: 10,
      ),
    );
  }

  // ── Security Tag ──
  static Widget tag(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? neonGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlighted ? neonGreen : textDim,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          color: highlighted ? bg : textMid,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ── GRID PAINTER ──
// ═══════════════════════════════════════════
class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  GridPainter({this.color = const Color(0xFF1A1A1A), this.spacing = 32});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════
// ── CORNER BRACKET PAINTER ──
// ═══════════════════════════════════════════
class CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isTop;
  final bool isLeft;

  CornerBracketPainter({
    required this.color,
    this.strokeWidth = 3,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════
// ── RADAR SWEEP PAINTER ──
// ═══════════════════════════════════════════
class RadarSweepPainter extends CustomPainter {
  final double angle;
  final Color color;

  RadarSweepPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Concentric circles
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ringPaint);
    }

    // Cross lines
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crossPaint,
    );

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crossPaint,
    );

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.8,
        endAngle: angle,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.3),
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Sweep line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;

    final endX = center.dx + radius * cos(angle);
    final endY = center.dy + radius * sin(angle);

    canvas.drawLine(center, Offset(endX, endY), linePaint);
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) => oldDelegate.angle != angle;
}
