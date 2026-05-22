import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_theme_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class ThemePickerScreen extends ConsumerStatefulWidget {
  const ThemePickerScreen({super.key});

  @override
  ConsumerState<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends ConsumerState<ThemePickerScreen> {
  String? _previewThemeId;
  bool _isApplying = false;

  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(activeStoreThemeProvider);
    final equippedAsync = ref.watch(equippedItemsProvider);
    final ownedThemeIds = equippedAsync.value?.values
            .where((e) => e.productType == 'theme' || e.productType == 'avatar_decoration')
            .map((e) => e.productId)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Themes',
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/store'),
            child: Text(
              'GET MORE',
              style: GoogleFonts.spaceGrotesk(
                color: _lime,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current theme preview
          _buildCurrentPreview(activeTheme),
          const SizedBox(height: 16),
          // Theme grid
          Expanded(
            child: _buildThemeGrid(activeTheme, ownedThemeIds),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPreview(StoreTheme? activeTheme) {
    final previewTheme = _previewThemeId != null
        ? BuiltInThemes.getById(_previewThemeId!)
        : activeTheme;

    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        gradient: previewTheme != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  previewTheme.primaryColor,
                  previewTheme.secondaryColor,
                ],
              )
            : null,
        color: previewTheme == null ? _surface : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _white.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        children: [
          // Sample UI elements
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 8,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert, color: Colors.white54, size: 20),
              ],
            ),
          ),
          // Chat preview
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.send, color: Colors.white54, size: 20),
                ],
              ),
            ),
          ),
          // Theme name badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                previewTheme?.name ?? 'Default',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGrid(StoreTheme? activeTheme, List<String> ownedThemeIds) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: BuiltInThemes.all.length,
      itemBuilder: (context, index) {
        final theme = BuiltInThemes.all[index];
        final isActive = activeTheme?.id == theme.id;
        final isOwned = ownedThemeIds.contains(theme.id);
        final isPreviewing = _previewThemeId == theme.id;

        return _buildThemeCard(
          theme: theme,
          isActive: isActive,
          isOwned: isOwned,
          isPreviewing: isPreviewing,
          onTap: () => _handleThemeTap(theme, isOwned, isActive),
        );
      },
    );
  }

  Widget _buildThemeCard({
    required StoreTheme theme,
    required bool isActive,
    required bool isOwned,
    required bool isPreviewing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.secondaryColor,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _lime : (isPreviewing ? theme.accentColor : Colors.transparent),
            width: isActive ? 3 : (isPreviewing ? 2 : 0),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Preview pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _ThemePatternPainter(theme.primaryColor),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          theme.name,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _lime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Color swatches
                  Row(
                    children: [
                      _buildColorSwatch(theme.primaryColor),
                      const SizedBox(width: 4),
                      _buildColorSwatch(theme.secondaryColor),
                      const SizedBox(width: 4),
                      _buildColorSwatch(theme.accentColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'OWN TO USE',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }

  void _handleThemeTap(StoreTheme theme, bool isOwned, bool isActive) {
    if (isActive) return;

    // Preview on tap
    setState(() => _previewThemeId = theme.id);

    if (!isOwned) {
      // Show purchase dialog
      _showPurchaseDialog(theme);
    } else {
      // Apply theme
      _applyTheme(theme);
    }
  }

  void _showPurchaseDialog(StoreTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              theme.name,
              style: GoogleFonts.spaceGrotesk(
                color: _white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You don\'t own this theme yet.',
              style: GoogleFonts.spaceGrotesk(color: _muted),
            ),
            const SizedBox(height: 16),
            Text(
              'Purchase it from the store to unlock it.',
              style: GoogleFonts.spaceGrotesk(color: _white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/store/product/${theme.id}');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _lime),
            child: Text('Go to Store', style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _applyTheme(StoreTheme theme) async {
    setState(() => _isApplying = true);

    try {
      await ref.read(activeStoreThemeProvider.notifier).setTheme(theme);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${theme.name} theme applied!'),
            backgroundColor: _lime,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply theme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }
}

class _ThemePatternPainter extends CustomPainter {
  final Color color;

  _ThemePatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines
    for (int i = -20; i < 20; i++) {
      final x = i * 30.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
