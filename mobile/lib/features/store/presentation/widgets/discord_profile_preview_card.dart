import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Interactive Live Discord Profile Card Preview Widget
/// Shows how avatar decorations, banners, themes, nameplates, profile effects,
/// and badges look to OTHER users in real time before and after purchase!
class DiscordProfilePreviewCard extends ConsumerStatefulWidget {
  final StoreProduct? previewProduct;
  final bool showLiveLabel;

  const DiscordProfilePreviewCard({
    super.key,
    this.previewProduct,
    this.showLiveLabel = true,
  });

  @override
  ConsumerState<DiscordProfilePreviewCard> createState() =>
      _DiscordProfilePreviewCardState();
}

class _DiscordProfilePreviewCardState
    extends ConsumerState<DiscordProfilePreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _effectController;

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equippedAsync = ref.watch(equippedItemsProvider);
    final equipped = equippedAsync.value ?? {};

    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (user, profile) => profile,
      orElse: () => null,
    );

    final displayName = user?.displayName ?? user?.username ?? 'Flicko User';
    final username = user?.username ?? 'flicko_user';
    final avatarUrl = user?.avatarUrl;

    // Resolve active cosmetic tokens (Preview overrides Equipped)
    final p = widget.previewProduct;
    final pType = p?.type.toUpperCase();

    // 1. Decoration
    final activeDecoration = (pType == 'AVATAR_DECORATION' || pType == 'DECORATION')
        ? p?.id
        : (equipped['avatar_decoration']?.productId ?? equipped['decoration']?.productId);

    // 2. Banner
    final activeBanner = (pType == 'PROFILE_BANNER' || pType == 'BANNER')
        ? p?.id
        : (equipped['profile_banner']?.productId ?? equipped['banner']?.productId);

    // 3. Theme / Gradient
    final activeTheme = (pType == 'THEME' || pType == 'PROFILE_THEME' || pType == 'GRADIENT')
        ? p?.id
        : (equipped['theme']?.productId ?? equipped['profile_theme']?.productId);

    // 4. Profile Effect / Intro
    final activeEffect = (pType == 'PROFILE_EFFECT' || pType == 'EFFECT')
        ? p?.id
        : (equipped['profile_effect']?.productId ?? equipped['effect']?.productId);

    // 5. Nameplate
    final activeNameplate = (pType == 'NAMEPLATE')
        ? p?.id
        : (equipped['nameplate']?.productId);

    // 6. Badge
    final activeBadge = (pType == 'BADGE')
        ? p?.id
        : (equipped['badge']?.productId);

    // Resolve theme colors
    final themeColors = _getThemeGradient(activeTheme);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColors.first.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Header Tag
          if (widget.showLiveLabel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF111214),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF23A55A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE PROFILE PREVIEW — HOW OTHERS SEE YOU',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF949BA4),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

          // Banner Area with Effect Overlay
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner Box
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _getBannerGradient(activeBanner),
                ),
                child: CustomPaint(
                  painter: _BannerPatternPainter(bannerId: activeBanner),
                ),
              ),

              // Animated Profile Effect Particles (Sakura, Matrix, Sparks, Stardust)
              if (activeEffect != null)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _effectController,
                    builder: (ctx, child) {
                      return CustomPaint(
                        painter: _ProfileEffectPainter(
                          effectId: activeEffect,
                          progress: _effectController.value,
                        ),
                      );
                    },
                  ),
                ),

              // Avatar overlapping banner
              Positioned(
                left: 16,
                bottom: -32,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1F22),
                    shape: BoxShape.circle,
                  ),
                  child: UserAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    size: 68,
                    decoration: activeDecoration,
                    showStatus: true,
                    status: 'online',
                    showBadge: false,
                  ),
                ),
              ),

              // Badges Container at top right of banner
              Positioned(
                right: 12,
                bottom: 8,
                child: _buildBadgesRow(activeBadge),
              ),
            ],
          ),

          const SizedBox(height: 38),

          // User Info Section with Theme Gradient background
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  themeColors.first.withValues(alpha: 0.15),
                  themeColors.last.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Nameplate
                _buildNameplateWidget(displayName, activeNameplate),

                const SizedBox(height: 2),

                // Username & Pronouns
                Text(
                  '@$username • he/him',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF949BA4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Custom Status & Bio Preview
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'vibing on Flicko • customization equipped!',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesRow(String? activeBadge) {
    final badgeList = <String>[];
    if (activeBadge != null && activeBadge.isNotEmpty) {
      badgeList.add(activeBadge);
    }
    badgeList.addAll(['og-badge', 'verified-plus']);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badgeList.take(3).map((b) => _buildBadgePill(b)).toList(),
    );
  }

  Widget _buildBadgePill(String badgeId) {
    final iconData = _getBadgeIcon(badgeId);
    final color = _getBadgeColor(badgeId);

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: Icon(iconData, color: color, size: 14),
    );
  }

  IconData _getBadgeIcon(String badgeId) {
    if (badgeId.contains('og')) return Icons.shield_rounded;
    if (badgeId.contains('verified')) return Icons.verified_rounded;
    if (badgeId.contains('star')) return Icons.star_rounded;
    if (badgeId.contains('bolt')) return Icons.bolt_rounded;
    if (badgeId.contains('diamond')) return Icons.diamond_rounded;
    return Icons.auto_awesome_rounded;
  }

  Color _getBadgeColor(String badgeId) {
    if (badgeId.contains('og')) return const Color(0xFF9B84EE);
    if (badgeId.contains('verified')) return const Color(0xFF5865F2);
    if (badgeId.contains('star')) return const Color(0xFF57F287);
    if (badgeId.contains('bolt')) return const Color(0xFFFEE75C);
    if (badgeId.contains('diamond')) return const Color(0xFFEB459E);
    return const Color(0xFF00E5FF);
  }

  Widget _buildNameplateWidget(String name, String? nameplateId) {
    if (nameplateId == null || nameplateId.isEmpty) {
      return Text(
        name,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final id = nameplateId.toLowerCase();

    if (id.contains('glitch')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF66).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00FF66), width: 1),
        ),
        child: Text(
          name.toUpperCase(),
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF00FF66),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      );
    } else if (id.contains('neon') || id.contains('cyber')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0xFF00E5FF), blurRadius: 8),
          ],
        ),
        child: Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (id.contains('fire') || id.contains('aura')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFED4245), Color(0xFFFAA61A)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (id.contains('gold')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEE75C), Color(0xFFF7971E)],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFEE75C), blurRadius: 10),
          ],
        ),
        child: Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF007F), Color(0xFF00E5FF)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
  }

  LinearGradient _getBannerGradient(String? bannerId) {
    if (bannerId == null) {
      return const LinearGradient(
        colors: [Color(0xFF5865F2), Color(0xFF381F68)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final id = bannerId.toLowerCase();
    if (id.contains('nebula')) {
      return const LinearGradient(
        colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (id.contains('synthwave')) {
      return const LinearGradient(
        colors: [Color(0xFF240B36), Color(0xFFC31432)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else if (id.contains('cybercity') || id.contains('cyber')) {
      return const LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (id.contains('sea') || id.contains('abyss')) {
      return const LinearGradient(
        colors: [Color(0xFF000046), Color(0xFF1CB5E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (id.contains('pixel') || id.contains('dungeon')) {
      return const LinearGradient(
        colors: [Color(0xFF141E30), Color(0xFF243B55)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (id.contains('gold')) {
      return const LinearGradient(
        colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (id.contains('sakura')) {
      return const LinearGradient(
        colors: [Color(0xFF2C3E50), Color(0xFFFD746C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return const LinearGradient(
      colors: [Color(0xFF5865F2), Color(0xFF381F68)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  List<Color> _getThemeGradient(String? themeId) {
    if (themeId == null) {
      return [const Color(0xFF5865F2), const Color(0xFF1E1F22)];
    }

    final id = themeId.toLowerCase();
    if (id.contains('violet')) return [const Color(0xFF7B2CBF), const Color(0xFF3A0CA3)];
    if (id.contains('pink') || id.contains('cyber')) return [const Color(0xFFFF007F), const Color(0xFF00E5FF)];
    if (id.contains('sunset') || id.contains('blaze')) return [const Color(0xFFED4245), const Color(0xFFFAA61A)];
    if (id.contains('emerald') || id.contains('matrix')) return [const Color(0xFF00FF66), const Color(0xFF0B2B1B)];
    if (id.contains('platinum')) return [const Color(0xFFE0E0E0), const Color(0xFF757575)];
    if (id.contains('sonic')) return [const Color(0xFF52B788), const Color(0xFF111214)];

    return [const Color(0xFF5865F2), const Color(0xFF1E1F22)];
  }
}

class _BannerPatternPainter extends CustomPainter {
  final String? bannerId;

  _BannerPatternPainter({this.bannerId});

  @override
  void paint(Canvas canvas, Size size) {
    if (bannerId == null) return;
    final id = bannerId!.toLowerCase();

    if (id.contains('synthwave')) {
      // Draw grid lines
      final paint = Paint()
        ..color = const Color(0xFFFF007F).withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      for (double i = 0; i < size.width; i += 20) {
        canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
      }
      for (double j = 0; j < size.height; j += 15) {
        canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BannerPatternPainter oldDelegate) =>
      oldDelegate.bannerId != bannerId;
}

class _ProfileEffectPainter extends CustomPainter {
  final String effectId;
  final double progress;

  _ProfileEffectPainter({required this.effectId, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final id = effectId.toLowerCase();

    if (id.contains('sakura') || id.contains('cherry')) {
      // Floating pink petals
      final petalPaint = Paint()..color = const Color(0xFFFFB7C5).withValues(alpha: 0.7);
      for (int i = 0; i < 12; i++) {
        final x = (size.width * 0.1 * i + progress * 80) % size.width;
        final y = (size.height * 0.2 * (i % 5) + progress * size.height) % size.height;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 4),
          petalPaint,
        );
      }
    } else if (id.contains('matrix') || id.contains('code')) {
      // Matrix binary code stream
      final codePaint = Paint()..color = const Color(0xFF00FF66).withValues(alpha: 0.6);
      for (int i = 0; i < 10; i++) {
        final x = (size.width / 10) * i + 10;
        final y = (progress * size.height * 1.5 + (i * 20)) % size.height;
        canvas.drawCircle(Offset(x, y), 2.5, codePaint);
      }
    } else if (id.contains('spark') || id.contains('electric')) {
      // Lightning arcs
      final sparkPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 1.5;
      final x1 = (progress * size.width) % size.width;
      canvas.drawLine(Offset(x1, 0), Offset(x1 + 10, size.height * 0.5), sparkPaint);
      canvas.drawLine(Offset(x1 + 10, size.height * 0.5), Offset(x1 - 5, size.height), sparkPaint);
    } else {
      // Cosmic stardust
      final dustPaint = Paint()..color = const Color(0xFFFEE75C).withValues(alpha: 0.8);
      for (int i = 0; i < 15; i++) {
        final x = (size.width * 0.15 * i + math.sin(progress * math.pi * 2 + i) * 15) % size.width;
        final y = (size.height - (progress * size.height + (i * 12)) % size.height);
        canvas.drawCircle(Offset(x, y), 1.8, dustPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileEffectPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.effectId != effectId;
}
