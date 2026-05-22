import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'dart:developer' as dev;

/// Badge definition with styling
class BadgeDefinition {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final bool isAnimated;
  final bool hasGlow;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    this.icon = Icons.verified,
    this.isAnimated = true,
    this.hasGlow = true,
  });

  factory BadgeDefinition.fromJson(Map<String, dynamic> json) {
    return BadgeDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? json['id'],
      primaryColor: _parseColor(json['primary_color'] as String?),
      secondaryColor: _parseColor(json['secondary_color'] as String?),
      icon: _parseIcon(json['icon_name'] as String?),
      isAnimated: json['is_animated'] as bool? ?? true,
      hasGlow: json['has_glow'] as bool? ?? true,
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFFFD700);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFFD700);
    }
  }

  static IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'verified':
        return Icons.verified;
      case 'star':
        return Icons.star;
      case 'bolt':
        return Icons.bolt;
      case 'diamond':
        return Icons.diamond;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'whatshot':
        return Icons.whatshot;
      default:
        return Icons.verified;
    }
  }
}

/// Built-in badges for fallback
class BuiltInBadges {
  static const ogBadge = BadgeDefinition(
    id: 'og-badge',
    name: 'OG Badge',
    slug: 'og-badge',
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFFF8C00),
    icon: Icons.verified,
    isAnimated: true,
    hasGlow: true,
  );

  static const verifiedPlus = BadgeDefinition(
    id: 'verified-plus',
    name: 'Verified+',
    slug: 'verified-plus',
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFF9B84EE),
    icon: Icons.verified,
    isAnimated: true,
    hasGlow: true,
  );

  static const premiumStar = BadgeDefinition(
    id: 'premium-star',
    name: 'Premium Star',
    slug: 'premium-star',
    primaryColor: Color(0xFF52B788),
    secondaryColor: Color(0xFF38EF7D),
    icon: Icons.star,
    isAnimated: true,
    hasGlow: true,
  );

  static const boltMaster = BadgeDefinition(
    id: 'bolt-master',
    name: 'Bolt Master',
    slug: 'bolt-master',
    primaryColor: Color(0xFFFF6B6B),
    secondaryColor: Color(0xFFFFE66D),
    icon: Icons.bolt,
    isAnimated: true,
    hasGlow: true,
  );

  static const diamondElite = BadgeDefinition(
    id: 'diamond-elite',
    name: 'Diamond Elite',
    slug: 'diamond-elite',
    primaryColor: Color(0xFF9B84EE),
    secondaryColor: Color(0xFF00E5FF),
    icon: Icons.diamond,
    isAnimated: true,
    hasGlow: true,
  );

  static const all = [ogBadge, verifiedPlus, premiumStar, boltMaster, diamondElite];

  static BadgeDefinition? getById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Service for managing badges
final badgeServiceProvider = Provider<BadgeService>((ref) {
  return BadgeService();
});

/// Provider for user's equipped badge
final equippedBadgeProvider = FutureProvider<BadgeDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      final badgeItem = equipped['badge'] ?? equipped['nameplate'];
      if (badgeItem != null) {
        return BuiltInBadges.getById(badgeItem.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

class BadgeService {
  /// Get all available badges
  Future<List<BadgeDefinition>> getAllBadges() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('cosmetic_catalog')
          .select()
          .eq('cosmetic_type', 'nameplate')
          .eq('is_active', true);

      final dbBadges = (response as List).map((j) => BadgeDefinition.fromJson(j)).toList();

      // Merge with built-in badges
      final allBadges = <String, BadgeDefinition>{};
      for (final b in BuiltInBadges.all) {
        allBadges[b.id] = b;
      }
      for (final b in dbBadges) {
        allBadges[b.id] = b;
      }

      return allBadges.values.toList();
    } catch (e) {
      dev.log('[BADGE] Error fetching badges: $e');
      return BuiltInBadges.all;
    }
  }
}

/// Widget to display a user's equipped badge
class UserBadgeWidget extends ConsumerWidget {
  final String? userId;
  final double size;
  final bool showIfNone;

  const UserBadgeWidget({
    super.key,
    this.userId,
    this.size = 16,
    this.showIfNone = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(equippedBadgeProvider);

    return badgeAsync.when(
      data: (badge) {
        if (badge == null && !showIfNone) {
          return const SizedBox.shrink();
        }

        if (badge == null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, size: size * 0.6, color: Colors.grey),
          );
        }

        return _BadgeIcon(badge: badge, size: size);
      },
      loading: () => SizedBox(width: size, height: size),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

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
              border: Border.all(color: Colors.white, width: widget.size * 0.06),
              boxShadow: widget.badge.hasGlow
                  ? [
                      BoxShadow(
                        color: widget.badge.primaryColor.withValues(alpha: 0.5),
                        blurRadius: widget.size * 0.5,
                        spreadRadius: widget.size * 0.1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.badge.icon,
              color: Colors.white,
              size: widget.size * 0.6,
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
