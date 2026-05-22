import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/store/data/badge_service.dart';

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
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(),
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
          if (decoration == 'verified' && (badgeAsync == null || badgeAsync.value == null))
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

  Widget _buildAvatar() {
    final hasDecoration = decoration != null && decoration != 'none';
    if (hasDecoration) {
      Color ringColor = Colors.transparent;
      List<BoxShadow> shadows = [];
      
      switch (decoration) {
        case 'neon-ring':
          ringColor = const Color(0xFF52B788);
          shadows = [
            BoxShadow(
              color: const Color(0xFF52B788).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'gold-ring':
          ringColor = const Color(0xFFFFD700);
          shadows = [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'blurple-ring':
          ringColor = const Color(0xFF5865F2);
          shadows = [
            BoxShadow(
              color: const Color(0xFF5865F2).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'red-ring':
          ringColor = const Color(0xFFED4245);
          shadows = [
            BoxShadow(
              color: const Color(0xFFED4245).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'pink-ring':
          ringColor = const Color(0xFFEB459E);
          shadows = [
            BoxShadow(
              color: const Color(0xFFEB459E).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'purple-ring':
          ringColor = const Color(0xFF9B59B6);
          shadows = [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'orange-ring':
          ringColor = const Color(0xFFE67E22);
          shadows = [
            BoxShadow(
              color: const Color(0xFFE67E22).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        case 'glow-fx':
        case 'green-glow':
          ringColor = const Color(0xFF57F287);
          shadows = [
            BoxShadow(
              color: const Color(0xFF57F287).withValues(alpha: 0.8),
              blurRadius: size * 0.25,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: const Color(0xFF57F287).withValues(alpha: 0.4),
              blurRadius: size * 0.1,
              spreadRadius: 1,
            )
          ];
          break;
        case 'cyan-glow':
          ringColor = const Color(0xFF00CECE);
          shadows = [
            BoxShadow(
              color: const Color(0xFF00CECE).withValues(alpha: 0.8),
              blurRadius: size * 0.25,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: const Color(0xFF00CECE).withValues(alpha: 0.4),
              blurRadius: size * 0.1,
              spreadRadius: 1,
            )
          ];
          break;
        case 'verified':
          ringColor = const Color(0xFF3897F0);
          shadows = [
            BoxShadow(
              color: const Color(0xFF3897F0).withValues(alpha: 0.4),
              blurRadius: size * 0.15,
              spreadRadius: 2,
            )
          ];
          break;
        default:
          break;
      }

      final ringThickness = size * 0.08;
      final innerSize = size - (ringThickness * 2);
      
      Widget innerAvatar;
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        innerAvatar = Container(
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            width: innerSize,
            height: innerSize,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildFallbackOfSize(innerSize),
            errorWidget: (context, url, error) => _buildFallbackOfSize(innerSize),
          ),
        );
      } else {
        innerAvatar = _buildFallbackOfSize(innerSize);
      }

      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ringThickness),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: ringThickness),
          boxShadow: shadows,
        ),
        child: innerAvatar,
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallback(),
          errorWidget: (context, url, error) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
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

  Widget _buildFallback() {
    return _buildFallbackOfSize(size);
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

/// Badge icon widget for displaying equipped badges on avatars
class _BadgeIcon extends StatefulWidget {
  final BadgeDefinition badge;
  final double size;

  const _BadgeIcon({required this.badge, required this.size});

  @override
  State<_BadgeIcon> createState() => _BadgeIconState();
}

class _BadgeIconState extends State<_BadgeIcon>
    with SingleTickerProviderStateMixin {
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
        final scale = widget.badge.isAnimated
            ? 1.0 + 0.1 * (0.5 + 0.5 * _controller.value)
            : 1.0;

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

/// AnimatedBuilder helper
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
