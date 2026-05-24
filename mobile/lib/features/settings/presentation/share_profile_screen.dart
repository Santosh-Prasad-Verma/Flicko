import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

// ─── QR Theme Presets (Upgraded with Premium Gradients & Glows) ─────
class _QrTheme {
  final String id;
  final String label;
  final Color bgStart;
  final Color bgEnd;
  final Color qrColor;
  final Color accent;
  final Color textColor;
  final List<Color> cardGradients;

  const _QrTheme({
    required this.id,
    required this.label,
    required this.bgStart,
    required this.bgEnd,
    required this.qrColor,
    required this.accent,
    required this.textColor,
    required this.cardGradients,
  });
}

const _themes = <_QrTheme>[
  _QrTheme(
    id: 'neon',
    label: 'NEON',
    bgStart: Color(0xFF030A05),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFF52B788),
    accent: Color(0xFF52B788),
    textColor: Color(0xFFFBF9FA),
    cardGradients: [Color(0xFF0D1E15), Color(0xFF040A06)],
  ),
  _QrTheme(
    id: 'cyber',
    label: 'CYBERPUNK',
    bgStart: Color(0xFF0B0514),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFFF007F),
    accent: Color(0xFFFF007F),
    textColor: Color(0xFFFFF5FB),
    cardGradients: [Color(0xFF240414), Color(0xFF080006)],
  ),
  _QrTheme(
    id: 'midnight',
    label: 'MIDNIGHT',
    bgStart: Color(0xFF050B14),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFF00E5FF),
    accent: Color(0xFF00E5FF),
    textColor: Color(0xFFE0F7FA),
    cardGradients: [Color(0xFF041824), Color(0xFF000508)],
  ),
  _QrTheme(
    id: 'sunset',
    label: 'SUNSET',
    bgStart: Color(0xFF140707),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFFF6B6B),
    accent: Color(0xFFFF6B6B),
    textColor: Color(0xFFFFF0F0),
    cardGradients: [Color(0xFF240808), Color(0xFF080000)],
  ),
  _QrTheme(
    id: 'gold',
    label: 'GOLD',
    bgStart: Color(0xFF0E0B05),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFFFD700),
    accent: Color(0xFFFFD700),
    textColor: Color(0xFFFFF8DC),
    cardGradients: [Color(0xFF241C04), Color(0xFF080500)],
  ),
  _QrTheme(
    id: 'royal',
    label: 'ROYAL',
    bgStart: Color(0xFF0D0A1A),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFBB86FC),
    accent: Color(0xFFBB86FC),
    textColor: Color(0xFFF3E5F5),
    cardGradients: [Color(0xFF1A1230), Color(0xFF05030A)],
  ),
];

enum _QrDotStyle { square, rounded, circle }

class ShareProfileScreen extends ConsumerWidget {
  const ShareProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.maybeWhen(
      authenticated: (user, profile) {
        final username = profile?.username ?? 'user';
        final displayName = profile?.displayName ?? username;
        final avatarUrl = profile?.avatarUrl;
        final link = 'https://flicko.app/@$username';
        return _ShareQrSheet(
          username: username,
          displayName: displayName,
          avatarUrl: avatarUrl,
          link: link,
        );
      },
      orElse: () => const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF52B788))),
      ),
    );
  }
}

class _ShareQrSheet extends StatefulWidget {
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String link;

  const _ShareQrSheet({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.link,
  });

  @override
  State<_ShareQrSheet> createState() => _ShareQrSheetState();
}

class _ShareQrSheetState extends State<_ShareQrSheet> with SingleTickerProviderStateMixin {
  int _selectedThemeIndex = 0;
  _QrDotStyle _dotStyle = _QrDotStyle.rounded;
  bool _showCustomizer = false;
  bool _isSaving = false;
  final GlobalKey _qrCardKey = GlobalKey();
  late AnimationController _pulseCtrl;

  _QrTheme get _theme => _themes[_selectedThemeIndex];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureQrCard() async {
    try {
      final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureQrCard();
      if (bytes == null) throw Exception('Capture failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/flicko_qr_${widget.username}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR CARD SECURED IN FILE SYSTEM!',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: _theme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareQr() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureQrCard();
      if (bytes == null) throw Exception('Capture failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/flicko_qr_${widget.username}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          text: 'Join me on Flicko: ${widget.link}',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient matching active theme
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_theme.bgStart, _theme.bgEnd],
              ),
            ),
          ),
          
          // Ambient Glow Orb
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final double scale = 1.0 + 0.12 * _pulseCtrl.value;
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.15,
                left: MediaQuery.of(context).size.width * 0.1,
                child: Opacity(
                  opacity: 0.15 + 0.08 * _pulseCtrl.value,
                  child: Container(
                    width: 320 * scale,
                    height: 320 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _theme.accent,
                          _theme.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildQrCard(),
                        const SizedBox(height: 28),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
                        _buildCustomizeToggle(),
                        
                        // Customizer Panel (Sleek accordion with glass border)
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildCustomizerPanel(),
                          ),
                          crossFadeState: _showCustomizer
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                        
                        const SizedBox(height: 24),
                        _buildCopyLinkRow(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Saving Overlay
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _theme.accent, strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'GENERATING HI-RES QR CARD...',
                      style: GoogleFonts.spaceMono(
                        color: _theme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _theme.accent.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _theme.accent.withValues(alpha: 0.04),
                border: Border.all(color: _theme.accent.withValues(alpha: 0.2), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: _theme.textColor, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'SHARE PROFILE',
                  style: GoogleFonts.spaceGrotesk(
                    color: _theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'CYBERNETIC IDENTITY BEACON',
                  style: GoogleFonts.spaceMono(
                    color: _theme.accent.withValues(alpha: 0.5),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balancing spacer
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return RepaintBoundary(
      key: _qrCardKey,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _theme.cardGradients,
          ),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.25), width: 1.5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _theme.accent.withValues(alpha: 0.06),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient grid effect inside card
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPatternPainter(_theme.accent.withValues(alpha: 0.04)),
              ),
            ),
            
            Column(
              children: [
                // User Details Row
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic glowing ring
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, child) {
                            return Container(
                              width: 58 + 4 * _pulseCtrl.value,
                              height: 58 + 4 * _pulseCtrl.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _theme.accent.withValues(alpha: 0.3 + 0.4 * _pulseCtrl.value),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Inner ring
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _theme.accent, width: 1.5),
                          ),
                          child: UserAvatar(
                            imageUrl: widget.avatarUrl,
                            name: widget.displayName,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName.toUpperCase(),
                            style: GoogleFonts.epilogue(
                              color: _theme.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _theme.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _theme.accent.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Text(
                              '@${widget.username}',
                              style: GoogleFonts.spaceMono(
                                color: _theme.accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // High-end Cyber Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _theme.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: _theme.bgStart, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'FLICKO',
                            style: GoogleFonts.spaceGrotesk(
                              color: _theme.bgStart,
                              fontWeight: FontWeight.w900,
                              fontSize: 8.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                
                // QR Enclosure with Corner Brackets
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: _theme.accent.withValues(alpha: 0.12), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Tech Corner Brackets
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CyberBracketsPainter(_theme.accent),
                        ),
                      ),
                      
                      QrImageView(
                        data: widget.link,
                        version: QrVersions.auto,
                        size: 190,
                        gapless: true,
                        eyeStyle: QrEyeStyle(
                          eyeShape: _dotStyle == _QrDotStyle.circle
                              ? QrEyeShape.circle
                              : QrEyeShape.square,
                          color: _theme.qrColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: _dotStyle == _QrDotStyle.square
                              ? QrDataModuleShape.square
                              : QrDataModuleShape.circle,
                          color: _theme.qrColor,
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Command line block at the bottom
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border.all(color: _theme.accent.withValues(alpha: 0.08), width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'VERIFIED SECURE IDENTITY BEACON',
                        style: GoogleFonts.spaceMono(
                          color: _theme.textColor.withValues(alpha: 0.3),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.link.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: _theme.accent.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildActionBtn(Icons.download_rounded, 'SECURE CARD', _saveToGallery)),
        const SizedBox(width: 12),
        Expanded(child: _buildActionBtn(Icons.share_rounded, 'SHARE BEACON', _shareQr)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionBtn(Icons.copy_all_rounded, 'DUPLICATE', () async {
            await Clipboard.setData(ClipboardData(text: widget.link));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'BEACON ADDR DUPLICATED!',
                    style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _theme.accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isSaving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.015),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.2), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: _theme.accent, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: _theme.textColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizeToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showCustomizer = !_showCustomizer),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _showCustomizer ? _theme.accent : Colors.transparent,
          border: Border.all(color: _theme.accent.withValues(alpha: 0.3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showCustomizer ? Icons.palette_rounded : Icons.tune_rounded,
              color: _showCustomizer ? Colors.black : _theme.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              _showCustomizer ? 'CLOSE MOD PANEL' : 'CUSTOMIZE SIGNAL',
              style: GoogleFonts.spaceGrotesk(
                color: _showCustomizer ? Colors.black : _theme.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizerPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: _theme.accent.withValues(alpha: 0.15), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildThemeSelector(),
          const SizedBox(height: 20),
          _buildDotStyleSelector(),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT ENCRYPTION SCHEME (THEME)',
          style: GoogleFonts.spaceMono(
            color: _theme.textColor.withValues(alpha: 0.5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _themes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final t = _themes[i];
              final isSelected = i == _selectedThemeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedThemeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  decoration: BoxDecoration(
                    color: t.bgStart,
                    border: Border.all(
                      color: isSelected ? t.accent : t.accent.withValues(alpha: 0.2),
                      width: isSelected ? 2.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [BoxShadow(color: t.accent.withValues(alpha: 0.25), blurRadius: 10)]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.qrColor,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        style: GoogleFonts.spaceMono(
                          color: t.textColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDotStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIGNAL DENSITY (DOT STYLE)',
          style: GoogleFonts.spaceMono(
            color: _theme.textColor.withValues(alpha: 0.5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _QrDotStyle.values.map((style) {
            final isSelected = _dotStyle == style;
            final label = style.name.toUpperCase();
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _dotStyle = style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: style != _QrDotStyle.circle ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _theme.accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _theme.accent : _theme.accent.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        style == _QrDotStyle.square
                            ? Icons.crop_square_rounded
                            : style == _QrDotStyle.rounded
                                ? Icons.rounded_corner_rounded
                                : Icons.circle_outlined,
                        color: isSelected ? Colors.black : _theme.accent,
                        size: 18,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: GoogleFonts.spaceMono(
                          color: isSelected ? Colors.black : _theme.textColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCopyLinkRow() {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'BEACON ADDR DUPLICATED!',
                style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _theme.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.015),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.12), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: _theme.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.link,
                style: GoogleFonts.spaceMono(
                  color: _theme.textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _theme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'COPY',
                style: GoogleFonts.spaceGrotesk(
                  color: _theme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Grid Pattern Painter for Card Detailing ─────────────────
class _GridPatternPainter extends CustomPainter {
  final Color gridColor;
  const _GridPatternPainter(this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Custom Paint for Cyber Corner Brackets ────────────────────────
class _CyberBracketsPainter extends CustomPainter {
  final Color accentColor;
  const _CyberBracketsPainter(this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double len = 16.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
