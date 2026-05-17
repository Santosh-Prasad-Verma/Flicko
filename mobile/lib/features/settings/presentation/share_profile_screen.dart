import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class ShareProfileScreen extends ConsumerWidget {
  const ShareProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final Color limeColor = const Color(0xFFC8FF00);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: limeColor, size: 24),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'SHARE PROFILE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
      body: authState.maybeWhen(
        authenticated: (user, profile) =>
            _buildBody(context, profile, limeColor),
        orElse: () => const Center(
            child: Text('Not authenticated',
                style: TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic profile, Color limeColor) {
    final username = profile?.username ?? 'user';
    final displayName = profile?.displayName ?? username;
    final shareUrl = 'https://flicko.app/u/$username';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // QR Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  limeColor,
                  Colors.white.withValues(alpha: 0.05),
                  limeColor.withValues(alpha: 0.5)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: limeColor.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: -10,
                )
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: limeColor,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          imageUrl: profile?.avatarUrl,
                          size: 90,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(Icons.verified_rounded, color: limeColor, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    displayName.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: GoogleFonts.inter(
                      color: limeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: QrImageView(
                      data: shareUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'SCAN TO CONNECT ON FLICKO',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Actions
          _buildActionButton(
            context,
            'COPY PROFILE LINK',
            Icons.link_rounded,
            () {
              Clipboard.setData(ClipboardData(text: shareUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied to clipboard!',
                    style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                  backgroundColor: limeColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(20),
                ),
              );
            },
            limeColor: limeColor,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            'SHARE PROFILE',
            Icons.share_rounded,
            () {},
            isPrimary: true,
            limeColor: limeColor,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
    required Color limeColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isPrimary ? limeColor : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: isPrimary
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: limeColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isPrimary ? Colors.black : Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isPrimary ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
