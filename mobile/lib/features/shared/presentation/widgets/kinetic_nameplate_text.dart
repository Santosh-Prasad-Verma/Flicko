import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/store/data/nameplate_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class KineticNameplateText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final String? decorationId; // Override for store previews
  final String? userId; // For global dynamic lookup in chat
  final TextAlign? textAlign;

  const KineticNameplateText({
    super.key,
    required this.text,
    this.style,
    this.decorationId,
    this.userId,
    this.textAlign,
  });

  @override
  ConsumerState<KineticNameplateText> createState() => _KineticNameplateTextState();
}

class _KineticNameplateTextState extends ConsumerState<KineticNameplateText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  
  // Glitch values
  double _glitchOffsetMultiplier = 0.0;
  bool _showGlitchSplit = false;
  int _glitchTickCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _controller.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    // Periodically trigger a quick dramatic text glitch
    _glitchTickCount++;
    if (_glitchTickCount % 35 == 0) {
      if (mounted) {
        setState(() {
          _showGlitchSplit = _random.nextDouble() > 0.3;
          _glitchOffsetMultiplier = _random.nextDouble() * 2.5;
        });
      }
    } else if (_glitchTickCount % 35 == 3 || _glitchTickCount % 35 == 6) {
      if (mounted) {
        setState(() {
          _showGlitchSplit = false;
          _glitchOffsetMultiplier = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final targetUserId = widget.userId ?? currentUserId;

    // 1. Resolve Nameplate Selection
    if (widget.decorationId != null) {
      final spec = BuiltInNameplates.getById(widget.decorationId!);
      if (spec != null) {
        return _buildStyledText(spec);
      }
    } else if (targetUserId != null) {
      final activeNameplateAsync = ref.watch(equippedNameplateProvider);
      return activeNameplateAsync.maybeWhen(
        data: (spec) {
          if (spec != null) {
            return _buildStyledText(spec);
          }
          return _buildDefaultText();
        },
        orElse: () => _buildDefaultText(),
      );
    }

    return _buildDefaultText();
  }

  Widget _buildDefaultText() {
    final defaultStyle = widget.style ?? GoogleFonts.spaceGrotesk(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 14,
    );
    return Text(
      widget.text,
      style: defaultStyle,
      textAlign: widget.textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStyledText(NameplateDefinition spec) {
    final baseStyle = (widget.style ?? GoogleFonts.spaceGrotesk()).copyWith(
      fontWeight: FontWeight.w900,
      fontSize: widget.style?.fontSize ?? 14,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        switch (spec.id) {
          case 'glitch-matrix-tag':
            return _buildGlitchText(baseStyle);
          case 'neon-cyber-tag':
            return _buildNeonText(baseStyle, spec.primaryColor, spec.secondaryColor);
          case 'fire-pulse-tag':
            return _buildFireText(baseStyle, spec.primaryColor, spec.secondaryColor);
          case 'gold-spark-tag':
            return _buildGoldSpecularText(baseStyle);
          case 'rainbow-drip-tag':
            return _buildRainbowDripText(baseStyle);
          default:
            return _buildDefaultText();
        }
      },
    );
  }

  // Effect 1: Glitch Matrix (Green/Magenta Flicker & Aberrations)
  Widget _buildGlitchText(TextStyle baseStyle) {
    final textStyle = baseStyle.copyWith(color: Colors.white);
    
    if (!_showGlitchSplit) {
      return Text(
        widget.text,
        style: textStyle,
        textAlign: widget.textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final double splitShift = _glitchOffsetMultiplier;
    return Stack(
      children: [
        // Magenta aberration
        Transform.translate(
          offset: Offset(-splitShift, splitShift * 0.5),
          child: Text(
            widget.text,
            style: textStyle.copyWith(color: const Color(0xFFFF007F)),
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Green aberration
        Transform.translate(
          offset: Offset(splitShift, -splitShift * 0.5),
          child: Text(
            widget.text,
            style: textStyle.copyWith(color: const Color(0xFF00FF66)),
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Main text (slightly shifted white)
        Transform.translate(
          offset: Offset(splitShift * 0.2, splitShift * 0.1),
          child: Text(
            widget.text,
            style: textStyle,
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Effect 2: Neon Cyber (Breathing glowing outline shadow overlay)
  Widget _buildNeonText(TextStyle baseStyle, Color primary, Color secondary) {
    final double pulse = (math.sin(_controller.value * 2 * math.pi) + 1.0) / 2.0; // 0 to 1
    final double blurRadius = 4.0 + (pulse * 10.0); // 4 to 14

    return Text(
      widget.text,
      style: baseStyle.copyWith(
        color: Colors.white,
        shadows: [
          Shadow(
            color: primary.withValues(alpha: 0.8),
            blurRadius: blurRadius,
          ),
          Shadow(
            color: secondary.withValues(alpha: 0.6),
            blurRadius: blurRadius * 1.5,
          ),
        ],
      ),
      textAlign: widget.textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Effect 3: Fire Aura (Orange radial heat pulse behind text)
  Widget _buildFireText(TextStyle baseStyle, Color primary, Color secondary) {
    final double scale = 1.0 + ((math.sin(_controller.value * 4 * math.pi) + 1.0) / 2.0) * 0.12;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Glow backdrop
        Transform.scale(
          scale: scale,
          child: Text(
            widget.text,
            style: baseStyle.copyWith(
              color: Colors.transparent,
              shadows: [
                Shadow(
                  color: secondary.withValues(alpha: 0.7),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
                Shadow(
                  color: primary.withValues(alpha: 0.9),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Main text layered over
        Text(
          widget.text,
          style: baseStyle.copyWith(
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1.5, 1.5)),
            ],
          ),
          textAlign: widget.textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Effect 4: Gold Specular Tag (Sweeping gold linear highlight)
  Widget _buildGoldSpecularText(TextStyle baseStyle) {
    final double sweep = _controller.value;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFF7C2), // Specular Peak
            Color(0xFFFFA500), // Orange-Gold
            Color(0xFFFFD700), // Gold
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
          begin: Alignment(-2.0 + (sweep * 4.0), -1.0),
          end: Alignment(-1.0 + (sweep * 4.0), 1.0),
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        widget.text,
        style: baseStyle.copyWith(color: Colors.white),
        textAlign: widget.textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Effect 5: Rainbow Drip Tag (Sweeping full color spectrum)
  Widget _buildRainbowDripText(TextStyle baseStyle) {
    final double offset = _controller.value;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [
            Color(0xFFFF007F), // Magenta
            Color(0xFF7F00FF), // Violet
            Color(0xFF00E5FF), // Cyan
            Color(0xFF00FF66), // Green
            Color(0xFFFFEE00), // Yellow
            Color(0xFFFF007F), // Magenta
          ],
          begin: Alignment(-1.5 + offset, 0.0),
          end: Alignment(1.5 + offset, 0.0),
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        widget.text,
        style: baseStyle.copyWith(color: Colors.white),
        textAlign: widget.textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
