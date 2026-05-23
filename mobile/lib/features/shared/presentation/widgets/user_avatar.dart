import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/store/data/badge_service.dart' hide AnimatedBuilder;
import 'package:mobile/features/store/data/avatar_decoration_service.dart';

enum UserStatus { online, idle, dnd, offline }

class UserAvatar extends ConsumerWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Object? status;
  final bool showStatus;
  final String? decoration;
  final String? userId;
  final bool showBadge;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name = 'User',
    this.size = 40,
    this.status = UserStatus.offline,
    this.showStatus = true,
    this.decoration,
    this.userId,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = showBadge ? ref.watch(equippedBadgeProvider) : null;
    final decorationAsync = ref.watch(equippedDecorationProvider);

    // If widget has explicit decoration param, use it. Otherwise resolve dynamic equipped decoration
    final activeDecoration = decoration ?? decorationAsync.value?.id;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(activeDecoration),
          if (showStatus)
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildStatusIndicator(),
            ),
          // Show equipped badge if available
          if (badgeAsync != null)
            badgeAsync.when(
              data: (badge) {
                if (badge == null) return const SizedBox.shrink();
                return Positioned(
                  right: -size * 0.15,
                  top: -size * 0.1,
                  child: _BadgeIcon(badge: badge, size: size * 0.4),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          // Legacy verified decoration fallback
          if (activeDecoration == 'verified' && (badgeAsync == null || badgeAsync.value == null))
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: size * 0.22, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? activeDec) {
    final hasDecoration = activeDec != null && activeDec != 'none';

    final ringThickness = size * 0.08;
    final innerSize = size - (ringThickness * 2);

    Widget innerAvatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      innerAvatar = Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: hasDecoration ? innerSize : size,
          height: hasDecoration ? innerSize : size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallbackOfSize(hasDecoration ? innerSize : size),
          errorWidget: (context, url, error) => _buildFallbackOfSize(hasDecoration ? innerSize : size),
        ),
      );
    } else {
      innerAvatar = _buildFallbackOfSize(hasDecoration ? innerSize : size);
    }

    if (hasDecoration) {
      return AnimatedAvatarDecoration(
        size: size,
        decorationId: activeDec!,
        child: innerAvatar,
      );
    }

    return innerAvatar;
  }

  Widget _buildFallbackOfSize(double s) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: s,
      height: s,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.blurple),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: s * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final resolvedStatus = _resolveStatus(status);
    final Color color;
    switch (resolvedStatus) {
      case UserStatus.online:
        color = const Color(FlickoColors.statusOnline);
      case UserStatus.idle:
        color = const Color(FlickoColors.statusIdle);
      case UserStatus.dnd:
        color = const Color(FlickoColors.statusDnd);
      case UserStatus.offline:
        color = const Color(FlickoColors.statusOffline);
    }

    return Container(
      width: size * 0.35,
      height: size * 0.35,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(FlickoColors.bgSecondary),
          width: size * 0.05,
        ),
      ),
    );
  }

  UserStatus _resolveStatus(Object? value) {
    if (value is UserStatus) return value;
    if (value is String) {
      return UserStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => UserStatus.offline,
      );
    }
    return UserStatus.offline;
  }
}

/// Dynamic, hardware-accelerated wrapper for animated profile borders
class AnimatedAvatarDecoration extends StatefulWidget {
  final Widget child;
  final double size;
  final String decorationId;

  const AnimatedAvatarDecoration({
    super.key,
    required this.child,
    required this.size,
    required this.decorationId,
  });

  @override
  State<AnimatedAvatarDecoration> createState() => _AnimatedAvatarDecorationState();
}

class _AnimatedAvatarDecorationState extends State<AnimatedAvatarDecoration> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringThickness = widget.size * 0.075;
    final innerAvatarSize = widget.size - (ringThickness * 2);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (ctx, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating animated border painter
              Positioned.fill(
                child: CustomPaint(
                  painter: _DecorationPainter(
                    progress: _animationController.value,
                    decorationId: widget.decorationId,
                  ),
                ),
              ),
              // Inner avatar clipped to neat round shape
              Container(
                width: innerAvatarSize,
                height: innerAvatarSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                alignment: Alignment.center,
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DecorationPainter extends CustomPainter {
  final double progress;
  final String decorationId;

  _DecorationPainter({required this.progress, required this.decorationId});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.075;

    final cleanId = decorationId.toLowerCase();

    // 1. NEON CYBER BORDER
    if (cleanId.contains('cyber') || cleanId.contains('neon-ring') || cleanId.contains('glow-fx')) {
      final borderPaint = Paint()
        ..shader = SweepGradient(
          colors: const [Color(0xFF52B788), Color(0xFF00E5FF), Color(0xFF52B788)],
          transform: GradientRotation(progress * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius - strokeWidth / 2, borderPaint);
    }
    // 2. GLITCH MATRIX BORDER
    else if (cleanId.contains('glitch') || cleanId.contains('matrix')) {
      // Draw static binary background ring
      final bgPaint = Paint()
        ..color = const Color(0xFF00FF66).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

      // Flickering green and magenta glitches
      final isFlicker = (progress * 100).round() % 7 == 0;
      final glitchPaint = Paint()
        ..color = isFlicker ? const Color(0xFFFF007F) : const Color(0xFF00FF66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      // Draw dashed arcs representing matrix flow
      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
      for (int i = 0; i < 4; i++) {
        final startAngle = (progress * 2 * math.pi) + (i * math.pi / 2);
        canvas.drawArc(rect, startAngle, 0.45, false, glitchPaint);
      }
    }
    // 3. COSMIC ORBIT BORDER
    else if (cleanId.contains('orbit') || cleanId.contains('cosmic') || cleanId.contains('purple-ring')) {
      // Draws a subtle orbiting coordinate orbit
      final orbitPaint = Paint()
        ..color = const Color(0xFF9B84EE).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius - strokeWidth / 2, orbitPaint);

      // Satellite Moons revolving at different coordinates
      final moonPaint1 = Paint()..color = const Color(0xFF9B84EE);
      final moonPaint2 = Paint()..color = const Color(0xFF00E5FF);

      // Moon 1
      final theta1 = progress * 2 * math.pi;
      final dx1 = center.dx + (radius - strokeWidth / 2) * math.cos(theta1);
      final dy1 = center.dy + (radius - strokeWidth / 2) * math.sin(theta1);
      canvas.drawCircle(Offset(dx1, dy1), strokeWidth * 0.7, moonPaint1);

      // Moon 2
      final theta2 = -progress * 4 * math.pi; // revolves opposite and faster!
      final dx2 = center.dx + (radius - strokeWidth / 2) * math.cos(theta2);
      final dy2 = center.dy + (radius - strokeWidth / 2) * math.sin(theta2);
      canvas.drawCircle(Offset(dx2, dy2), strokeWidth * 0.5, moonPaint2);
    }
    // 4. FIRE AURA BORDER
    else if (cleanId.contains('fire') || cleanId.contains('gold-ring')) {
      // Soft breathing warmth gradient ring
      final scale = 1.0 + 0.1 * math.sin(progress * 4 * math.pi);
      final auraPaint = Paint()
        ..color = const Color(0xFFFAA61A).withValues(alpha: 0.35 * (0.8 + 0.2 * math.sin(progress * 4 * math.pi)))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * scale;

      canvas.drawCircle(center, radius - strokeWidth / 2, auraPaint);

      final corePaint = Paint()
        ..color = const Color(0xFFED4245)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5;
      canvas.drawCircle(center, radius - strokeWidth / 2, corePaint);
    }
    // 5. RAINBOW PULSE BORDER
    else {
      final borderPaint = Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFF007F),
            Color(0xFF9B84EE),
            Color(0xFF00E5FF),
            Color(0xFF00FF66),
            Color(0xFFFF007F),
          ],
          transform: GradientRotation(progress * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius - strokeWidth / 2, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DecorationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.decorationId != decorationId;
  }
}

/// Badge icon widget for displaying equipped badges on avatars
class _BadgeIcon extends StatefulWidget {
  final BadgeDefinition badge;
  final double size;

  const _BadgeIcon({required this.badge, required this.size});

  @override
  State<_BadgeIcon> createState() => _BadgeIconState();
}

class _BadgeIconState extends State<_BadgeIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.badge.isAnimated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.badge.isAnimated ? 1.0 + 0.1 * (0.5 + 0.5 * _controller.value) : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.badge.primaryColor, widget.badge.secondaryColor],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: widget.size * 0.08),
              boxShadow: widget.badge.hasGlow
                  ? [
                      BoxShadow(
                        color: widget.badge.primaryColor.withValues(alpha: 0.6),
                        blurRadius: widget.size * 0.5,
                        spreadRadius: widget.size * 0.15,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.badge.icon,
              color: Colors.white,
              size: widget.size * 0.55,
            ),
          ),
        );
      },
    );
  }
}
