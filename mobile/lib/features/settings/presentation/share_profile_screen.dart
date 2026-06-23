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
import 'package:gal/gal.dart';

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

class _ShareQrSheetState extends State<_ShareQrSheet> {
  bool _isSaving = false;
  final GlobalKey _qrCardKey = GlobalKey();

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
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) throw Exception('Gallery access permission denied');
      }

      final bytes = await _captureQrCard();
      if (bytes == null) throw Exception('Capture failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/flicko_qr_${widget.username}.png');
      await file.writeAsBytes(bytes);

      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR CARD SECURED IN GALLERY!',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: const Color(0xFF52B788),
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
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
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
                        const SizedBox(height: 24),
                        _buildQrCard(),
                        const SizedBox(height: 32),
                        _buildPrimaryShareBtn(),
                        const SizedBox(height: 16),
                        _buildActionsRow(),
                        const SizedBox(height: 16),
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
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF52B788), strokeWidth: 3),
                    const SizedBox(height: 18),
                    Text(
                      'GENERATING QR CARD...',
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF52B788),
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
          bottom: BorderSide(color: Colors.white.withOpacity(0.02)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'FLICKO BEACON',
                  style: GoogleFonts.spaceMono(
                    color: Colors.white.withOpacity(0.3),
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
          color: const Color(0xFF0F0F12),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Heading Details
            Text(
              widget.displayName,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '@${widget.username}',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF52B788),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            
            // Simple flat QR code box with capsule badge underneath
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050505),
                    border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: widget.link,
                    version: QrVersions.auto,
                    size: 180,
                    gapless: true,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF52B788),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF52B788),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Simplified, elegant, flat pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'CONNECT ON FLICKO',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF52B788),
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 20),
            
            // Simple status row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF52B788),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SECURE DIGITAL IDENTITY',
                  style: GoogleFonts.spaceMono(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF52B788),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Share Profile',
            style: GoogleFonts.outfit(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
                    'LINK COPIED!',
                    style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFF52B788),
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
          color: const Color(0xFF0F0F12),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
                'LINK COPIED!',
                style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF52B788),
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
          color: const Color(0xFF0F0F12),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF52B788), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.link,
                style: GoogleFonts.spaceMono(
                  color: Colors.white54,
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
                color: const Color(0xFF52B788).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COPY',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF52B788),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
