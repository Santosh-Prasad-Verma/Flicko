import 'dart:io';
import 'dart:math';
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

// ─── QR Theme Presets (Redesigned with Premium Frosted Gradients & Glowing Accents) ─────
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
    label: 'EMERALD GLOW',
    bgStart: Color(0xFF030704),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFF52B788),
    accent: Color(0xFF52B788),
    textColor: Color(0xFFFBF9FA),
    cardGradients: [Color(0xFF0E1A12), Color(0xFF050B07)],
  ),
  _QrTheme(
    id: 'cyber',
    label: 'MAGENTA GLOW',
    bgStart: Color(0xFF070308),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFFF007F),
    accent: Color(0xFFFF007F),
    textColor: Color(0xFFFFF5FB),
    cardGradients: [Color(0xFF1E0C16), Color(0xFF0C0308)],
  ),
  _QrTheme(
    id: 'midnight',
    label: 'CYAN GLOW',
    bgStart: Color(0xFF03070A),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFF00E5FF),
    accent: Color(0xFF00E5FF),
    textColor: Color(0xFFE0F7FA),
    cardGradients: [Color(0xFF0A1820), Color(0xFF03080A)],
  ),
  _QrTheme(
    id: 'gold',
    label: 'GOLD GLOW',
    bgStart: Color(0xFF070603),
    bgEnd: Color(0xFF000000),
    qrColor: Color(0xFFFFD700),
    accent: Color(0xFFFFD700),
    textColor: Color(0xFFFFF8DC),
    cardGradients: [Color(0xFF1F1A0A), Color(0xFF0B0A05)],
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

class _ShareQrSheetState extends State<_ShareQrSheet> with TickerProviderStateMixin {
  int _selectedThemeIndex = 0;
  _QrDotStyle _dotStyle = _QrDotStyle.rounded;
  bool _showCustomizer = false;
  bool _isSaving = false;
  final GlobalKey _qrCardKey = GlobalKey();

  // Animation controllers for organic visual states
  late AnimationController _pulseCtrl;
  late AnimationController _particlesCtrl;
  final List<_StarParticle> _stars = [];

  _QrTheme get _theme => _themes[_selectedThemeIndex];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Star drift/constellation animation controller
    _particlesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate drift star coordinates
    final random = Random();
    for (int i = 0; i < 40; i++) {
      _stars.add(
        _StarParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: 1.0 + random.nextDouble() * 2.0,
          speed: 0.05 + random.nextDouble() * 0.05,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _particlesCtrl.dispose();
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
          text: 'Scan to connect with me on Flicko: ${widget.link}',
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
            duration: const Duration(milliseconds: 800),
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

          // Glowing space constellation particle field (slowly drifting)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particlesCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SpaceParticlesPainter(
                    stars: _stars,
                    progress: _particlesCtrl.value,
                    color: _theme.accent.withValues(alpha: 0.35),
                  ),
                );
              },
            ),
          ),

          // Ambient Glow Aura behind card
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final double scale = 1.0 + 0.1 * _pulseCtrl.value;
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.18,
                left: MediaQuery.of(context).size.width * 0.1,
                child: Opacity(
                  opacity: 0.18 + 0.08 * _pulseCtrl.value,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildQrCard(),
                        const SizedBox(height: 28),
                        _buildPrimaryShareBtn(),
                        const SizedBox(height: 16),
                        _buildActionsRow(),
                        const SizedBox(height: 20),
                        _buildCustomizeToggle(),
                        
                        // Customizer Panel (Frosted glassmorphic card accordion)
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
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _theme.accent, strokeWidth: 3),
                    const SizedBox(height: 18),
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
                color: _theme.accent.withValues(alpha: 0.03),
                border: Border.all(color: _theme.accent.withValues(alpha: 0.15), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
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
                    color: _theme.accent.withValues(alpha: 0.4),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance spacer
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return RepaintBoundary(
      key: _qrCardKey,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.2), width: 1.5),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: _theme.accent.withValues(alpha: 0.08),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Soft background grid texture
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: CustomPaint(
                  painter: _GridTexturePainter(_theme.accent.withValues(alpha: 0.02)),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Heading Details (Big, Beautiful Green Outfit font like the vision board reference)
                  Text(
                    widget.displayName,
                    style: GoogleFonts.outfit(
                      color: _theme.qrColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FLICKO SYSTEM PROFILE',
                    style: GoogleFonts.spaceMono(
                      color: _theme.textColor.withValues(alpha: 0.4),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // QR Enclosure with Slanted Pill Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 1),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: QrImageView(
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
                      ),
                      
                      // Slanted Badge over QR Corner ("JOIN ME!" styled purple pill like reference's "JOIN US!")
                      Positioned(
                        bottom: -10,
                        right: 8,
                        child: Transform.rotate(
                          angle: -0.08,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2CBF), // Gorgeous reference purple
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'JOIN ME!',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 38),
                  
                  // Location details layout matching reference
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            'IDENTITY ADDRESS',
                            style: GoogleFonts.spaceMono(
                              color: _theme.textColor.withValues(alpha: 0.35),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${widget.username}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      Column(
                        children: [
                          Text(
                            'BEACON BROADCAST',
                            style: GoogleFonts.spaceMono(
                              color: _theme.textColor.withValues(alpha: 0.35),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Online & Secure',
                            style: GoogleFonts.outfit(
                              color: _theme.qrColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryShareBtn() {
    return GestureDetector(
      onTap: _shareQr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _theme.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _theme.accent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Share Profile',
            style: GoogleFonts.outfit(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSecondaryBtn(Icons.download_rounded, 'SAVE CARD', _saveToGallery),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSecondaryBtn(Icons.copy_all_rounded, 'COPY LINK', () async {
            await Clipboard.setData(ClipboardData(text: widget.link));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'PROFILE LINK COPY SUCCESS!',
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

  Widget _buildSecondaryBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isSaving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _theme.textColor.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: _theme.textColor.withValues(alpha: 0.8),
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: _theme.accent.withValues(alpha: 0.25), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showCustomizer ? Icons.palette_rounded : Icons.tune_rounded,
              color: _theme.accent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _showCustomizer ? 'CLOSE PANEL' : 'CUSTOMIZE DESIGN',
              style: GoogleFonts.spaceMono(
                color: _theme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.0,
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
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
        borderRadius: BorderRadius.circular(20),
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
          'SELECT DESIGN PALETTE',
          style: GoogleFonts.spaceMono(
            color: _theme.textColor.withValues(alpha: 0.4),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 74,
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
                  width: 74,
                  decoration: BoxDecoration(
                    color: t.bgStart,
                    border: Border.all(
                      color: isSelected ? t.accent : t.accent.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: t.accent.withValues(alpha: 0.2), blurRadius: 10)]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.qrColor,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.label.split(' ')[0],
                        style: GoogleFonts.spaceMono(
                          color: t.textColor.withValues(alpha: isSelected ? 1.0 : 0.6),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
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
            color: _theme.textColor.withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? _theme.accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _theme.accent : _theme.accent.withValues(alpha: 0.15),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.spaceMono(
                          color: isSelected ? Colors.black : _theme.textColor.withValues(alpha: 0.8),
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
                'LINK COPIED TO CLIPBOARD!',
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.01),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: _theme.accent, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.link,
                style: GoogleFonts.spaceMono(
                  color: _theme.textColor.withValues(alpha: 0.5),
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
                color: _theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COPY',
                style: GoogleFonts.spaceGrotesk(
                  color: _theme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glowing Star Particle definition ──────────────────────────────
class _StarParticle {
  double x;
  double y;
  final double size;
  final double speed;

  _StarParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

// ─── Custom Star Particles Painter for Space Backdrop ───────────────
class _SpaceParticlesPainter extends CustomPainter {
  final List<_StarParticle> stars;
  final double progress;
  final Color color;

  const _SpaceParticlesPainter({
    required this.stars,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      // Slow downward drift
      double currentY = (star.y + progress * star.speed) % 1.0;
      final px = star.x * size.width;
      final py = currentY * size.height;

      // Draw particle dot
      canvas.drawCircle(Offset(px, py), star.size, paint);

      // Faint lines to neighbor stars (creating space constellation look)
      if (i < stars.length - 1) {
        final nextStar = stars[i + 1];
        double nextY = (nextStar.y + progress * nextStar.speed) % 1.0;
        final npx = nextStar.x * size.width;
        final npy = nextY * size.height;
        
        final double dist = sqrt(pow(px - npx, 2) + pow(py - npy, 2));
        if (dist < 110) {
          canvas.drawLine(Offset(px, py), Offset(npx, npy), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Custom Paint for Background Card Grid Texture ──────────────────
class _GridTexturePainter extends CustomPainter {
  final Color gridColor;
  const _GridTexturePainter(this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double step = 24.0;
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
