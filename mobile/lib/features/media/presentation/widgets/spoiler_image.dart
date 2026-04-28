import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// SpoilerImage Widget
///
/// Blurred image overlay that reveals on tap, like Discord spoiler images.
/// Tap to reveal, tap again to re-hide.
/// Matches `mobile/components/media/SpoilerImage.tsx`.
class SpoilerImage extends StatefulWidget {
  final String uri;
  final double width;
  final double height;
  final String? alt;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  const SpoilerImage({
    super.key,
    required this.uri,
    this.width = 300,
    this.height = 200,
    this.alt,
    this.onLongPress,
    this.borderRadius,
  });

  @override
  State<SpoilerImage> createState() => _SpoilerImageState();
}

class _SpoilerImageState extends State<SpoilerImage>
    with SingleTickerProviderStateMixin {
  bool _revealed = false;
  late AnimationController _animController;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _blurAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _revealed = !_revealed);
    if (_revealed) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(FlickoRadius.md);

    return GestureDetector(
      onTap: _toggle,
      onLongPress: widget.onLongPress,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.symmetric(vertical: FlickoSpacing.xs),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Actual image ──
              Image.network(
                widget.uri,
                fit: BoxFit.cover,
                width: widget.width,
                height: widget.height,
                semanticLabel: widget.alt ?? 'Spoiler image',
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(FlickoColors.bgTertiary),
                  child: const Center(
                    child: Icon(Icons.broken_image,
                        color: Color(FlickoColors.textMuted), size: 32),
                  ),
                ),
              ),

              // ── Blur overlay ──
              AnimatedBuilder(
                animation: _blurAnimation,
                builder: (context, child) {
                  if (_blurAnimation.value < 0.5) return const SizedBox.shrink();
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _blurAnimation.value,
                      sigmaY: _blurAnimation.value,
                    ),
                    child: Container(
                      color: const Color(FlickoColors.bgTertiary)
                          .withValues(alpha: 0.75),
                    ),
                  );
                },
              ),

              // ── SPOILER label ──
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _revealed ? 0.0 : 1.0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_off,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SPOILER',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small "SPOILER" chip indicator for message previews
class SpoilerBadge extends StatelessWidget {
  const SpoilerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(FlickoRadius.sm),
      ),
      child: Text(
        'SPOILER',
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
