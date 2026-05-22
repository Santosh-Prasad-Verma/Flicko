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

// ─── QR Theme Presets ─────────────────────────────────────────────
class _QrTheme {
  final String id;
  final String label;
  final Color bg;
  final Color qrColor;
  final Color accent;
  final Color textColor;

  const _QrTheme({
    required this.id,
    required this.label,
    required this.bg,
    required this.qrColor,
    required this.accent,
    required this.textColor,
  });
}

const _themes = <_QrTheme>[
  _QrTheme(id: 'neon', label: 'NEON', bg: Color(0xFF050505), qrColor: Color(0xFFC0F500), accent: Color(0xFFC0F500), textColor: Color(0xFFFBF9FA)),
  _QrTheme(id: 'midnight', label: 'MIDNIGHT', bg: Color(0xFF0A0E1A), qrColor: Color(0xFF00E5FF), accent: Color(0xFF00E5FF), textColor: Color(0xFFE0F7FA)),
  _QrTheme(id: 'sunset', label: 'SUNSET', bg: Color(0xFF1A0A0A), qrColor: Color(0xFFFF6B6B), accent: Color(0xFFFF6B6B), textColor: Color(0xFFFFF0F0)),
  _QrTheme(id: 'royal', label: 'ROYAL', bg: Color(0xFF0D0A1A), qrColor: Color(0xFFBB86FC), accent: Color(0xFFBB86FC), textColor: Color(0xFFF3E5F5)),
  _QrTheme(id: 'arctic', label: 'ARCTIC', bg: Color(0xFFF0F4F8), qrColor: Color(0xFF1A1A2E), accent: Color(0xFF0066FF), textColor: Color(0xFF1A1A2E)),
  _QrTheme(id: 'gold', label: 'GOLD', bg: Color(0xFF0F0D08), qrColor: Color(0xFFFFD700), accent: Color(0xFFFFD700), textColor: Color(0xFFFFF8DC)),
];

// ─── QR Dot Styles ────────────────────────────────────────────────
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC0F500))),
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
  _QrDotStyle _dotStyle = _QrDotStyle.square;
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
      duration: const Duration(seconds: 2),
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
            content: Text('QR saved to ${file.path}', style: GoogleFonts.spaceMono(fontSize: 11)),
            backgroundColor: _theme.accent,
            behavior: SnackBarBehavior.floating,
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
          text: 'Check out my Flicko profile: ${widget.link}',
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
      backgroundColor: _theme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildQrCard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildCustomizeToggle(),
                    if (_showCustomizer) ...[
                      const SizedBox(height: 16),
                      _buildThemeSelector(),
                      const SizedBox(height: 16),
                      _buildDotStyleSelector(),
                    ],
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _theme.accent.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _theme.accent.withValues(alpha: 0.08),
                border: Border.all(color: _theme.accent.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.arrow_back, color: _theme.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Text('SHARE PROFILE',
                    style: GoogleFonts.spaceGrotesk(
                        color: _theme.accent.withValues(alpha: 0.8),
                        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('QR_CODE // IDENTITY',
                    style: GoogleFonts.spaceMono(
                        color: _theme.textColor.withValues(alpha: 0.3),
                        fontSize: 8, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return RepaintBoundary(
      key: _qrCardKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _theme.bg,
          border: Border.all(color: _theme.accent.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(color: _theme.accent.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // User identity row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _theme.accent, width: 1.5),
                  ),
                  child: UserAvatar(
                    imageUrl: widget.avatarUrl,
                    name: widget.displayName,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.displayName.toUpperCase(),
                          style: GoogleFonts.epilogue(
                              color: _theme.textColor, fontSize: 16,
                              fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
                              letterSpacing: -0.5)),
                      Text('@${widget.username}',
                          style: GoogleFonts.spaceMono(
                              color: _theme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _theme.accent,
                  child: Text('FLICKO',
                      style: GoogleFonts.spaceGrotesk(
                          color: _theme.bg, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _theme.id == 'arctic' ? Colors.white : _theme.bg,
                border: Border.all(color: _theme.accent.withValues(alpha: 0.15)),
              ),
              child: QrImageView(
                data: widget.link,
                version: QrVersions.auto,
                size: 200,
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
            const SizedBox(height: 16),
            // Profile link
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _theme.accent.withValues(alpha: 0.06),
              child: Text(
                widget.link,
                style: GoogleFonts.spaceMono(
                    color: _theme.accent.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildActionBtn(Icons.download_rounded, 'SAVE', _saveToGallery)),
        const SizedBox(width: 12),
        Expanded(child: _buildActionBtn(Icons.share_rounded, 'SHARE', _shareQr)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionBtn(Icons.copy_rounded, 'COPY LINK', () async {
            await Clipboard.setData(ClipboardData(text: widget.link));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile link copied!', style: GoogleFonts.spaceMono(fontSize: 11)),
                  backgroundColor: _theme.accent,
                  behavior: SnackBarBehavior.floating,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _theme.accent.withValues(alpha: 0.06),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _theme.accent, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color: _theme.textColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
          color: _showCustomizer ? _theme.accent : Colors.transparent,
          border: Border.all(color: _theme.accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showCustomizer ? Icons.palette : Icons.tune_rounded,
              color: _showCustomizer ? _theme.bg : _theme.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              _showCustomizer ? 'CLOSE CUSTOMIZER' : 'CUSTOMIZE QR',
              style: GoogleFonts.spaceGrotesk(
                color: _showCustomizer ? _theme.bg : _theme.accent,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THEME',
            style: GoogleFonts.epilogue(
                color: _theme.textColor, fontSize: 14,
                fontWeight: FontWeight.w900, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, color: _theme.accent),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
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
                  width: 72,
                  decoration: BoxDecoration(
                    color: t.bg,
                    border: Border.all(
                      color: isSelected ? t.accent : t.accent.withValues(alpha: 0.2),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 12)]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 20, height: 20, color: t.qrColor),
                      const SizedBox(height: 6),
                      Text(t.label,
                          style: GoogleFonts.spaceMono(
                              color: t.textColor, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
        Text('DOT STYLE',
            style: GoogleFonts.epilogue(
                color: _theme.textColor, fontSize: 14,
                fontWeight: FontWeight.w900, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, color: _theme.accent),
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
                      color: isSelected ? _theme.accent : _theme.accent.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        style == _QrDotStyle.square
                            ? Icons.square
                            : style == _QrDotStyle.rounded
                                ? Icons.rounded_corner
                                : Icons.circle,
                        color: isSelected ? _theme.bg : _theme.accent,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(label,
                          style: GoogleFonts.spaceMono(
                              color: isSelected ? _theme.bg : _theme.textColor,
                              fontSize: 9, fontWeight: FontWeight.w700)),
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
              content: Text('Link copied!', style: GoogleFonts.spaceMono(fontSize: 11)),
              backgroundColor: _theme.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _theme.accent.withValues(alpha: 0.04),
          border: Border.all(color: _theme.accent.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: _theme.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.link,
                  style: GoogleFonts.spaceMono(
                      color: _theme.textColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: _theme.accent.withValues(alpha: 0.15),
              child: Text('COPY',
                  style: GoogleFonts.spaceGrotesk(
                      color: _theme.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
