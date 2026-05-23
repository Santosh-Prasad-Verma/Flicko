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

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF000000);
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
          'THEMES_CATALOG',
          style: GoogleFonts.spaceGrotesk(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Container(
            color: _lime,
            height: 2.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/store'),
            child: Text(
              'GET MORE',
              style: GoogleFonts.spaceGrotesk(
                color: _lime,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current theme preview
          _buildCurrentPreview(activeTheme),
          const SizedBox(height: 8),
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

    final primaryCol = previewTheme?.primaryColor ?? _lime;
    final secondaryCol = previewTheme?.secondaryColor ?? _muted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      height: 160,
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(
          color: primaryCol,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: secondaryCol,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brutalist background patterns
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: _ThemePatternPainter(primaryCol),
              ),
            ),
          ),
          
          // Sample Chat/UI elements in brutalist style
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: primaryCol, width: 1.5),
                  ),
                  child: Icon(Icons.person, color: primaryCol, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 90,
                        decoration: BoxDecoration(
                          color: primaryCol.withValues(alpha: 0.4),
                          border: Border.all(color: primaryCol, width: 1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 8,
                        width: 50,
                        decoration: BoxDecoration(
                          color: secondaryCol.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat box simulation
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: primaryCol, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PREVIEW_STREAM_TEXT_BOX_OK',
                      style: GoogleFonts.spaceMono(
                        color: primaryCol.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.send_rounded, color: primaryCol, size: 14),
                ],
              ),
            ),
          ),
          
          // Top right theme indicator badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryCol,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                (previewTheme?.name ?? 'DEFAULT').toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
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
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
    final borderCol = isActive ? _lime : (isPreviewing ? theme.accentColor : theme.primaryColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(
            color: borderCol,
            width: isActive ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? _lime : theme.secondaryColor,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Micro patterns in background
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: _ThemePatternPainter(theme.primaryColor),
                ),
              ),
            ),
            
            // Content Card overlay
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: borderCol, width: 1),
                          ),
                          child: Text(
                            theme.name.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 10),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Color swatches (squares instead of circles)
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
                  
                  // Locked indicator style
                  if (!isOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED4245),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'OWN_TO_USE',
                            style: GoogleFonts.spaceMono(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
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
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
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
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.primaryColor, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: theme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                width: double.infinity,
                child: Text(
                  'ACCESS_LOCKED',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You do not own the ${theme.name} theme yet. Purchase it from the Flicko Store catalog to customize your interface.',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.spaceMono(
                              color: _muted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/store/product/${theme.id}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _lime,
                            foregroundColor: Colors.black,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'GO_TO_STORE',
                            style: GoogleFonts.spaceMono(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyTheme(StoreTheme theme) async {
    try {
      await ref.read(activeStoreThemeProvider.notifier).setTheme(theme);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${theme.name.toUpperCase()} THEME APPLIED!'),
            backgroundColor: _lime,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('FAILED TO APPLY THEME: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
