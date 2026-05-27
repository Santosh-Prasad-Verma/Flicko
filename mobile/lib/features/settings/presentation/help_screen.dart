import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' show ImageFilter;

/// Help & Support Screen (Sleek Brutalist Black/Neon Theme)
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeroSection(),
                      const SizedBox(height: 48),
                      _buildResourcesSection(context),
                      const SizedBox(height: 40),
                      _buildLegalSection(context),
                      const SizedBox(height: 40),
                      _buildAppInfoSection(context),
                      const SizedBox(height: 48),
                      _buildFooterData(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border.fromBorderSide(BorderSide(color: Colors.transparent)),
              ),
              child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'APP SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'HELP & SUPPORT',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'BUG\nREPORT',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 0.9,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(color: _neonGreen),
              child: Text(
                'SUPPORT',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HELP & DOCUMENTATION',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'FAQ, community, legal & bug reports',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESOURCES',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildLinkCard(
          context: context,
          title: 'FAQ',
          subtitle: 'Frequently asked questions and answers.',
          badge: 'DOCS',
          icon: Icons.book_outlined,
          onTap: () => context.push('/profile/settings/help/faq'),
        ),
        const SizedBox(height: 14),
        _buildLinkCard(
          context: context,
          title: 'COMMUNITY',
          subtitle: 'Join the Flicko community server.',
          badge: 'SOCIAL',
          icon: Icons.forum_outlined,
          usePrimaryBadge: true,
          onTap: () => _launchUrl('https://github.com/Santosh-Prasad-Verma/Flicko'),
        ),
        const SizedBox(height: 14),
        _buildLinkCard(
          context: context,
          title: 'REPORT A BUG',
          subtitle: 'Help us fix issues and improve Flicko.',
          badge: 'FEEDBACK',
          icon: Icons.bug_report_outlined,
          onTap: () => _launchUrl('mailto:support@flicko.dev?subject=Bug%20Report'),
        ),
      ],
    );
  }

  Widget _buildLegalSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LEGAL',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildLinkCard(
          context: context,
          title: 'TERMS OF SERVICE',
          subtitle: 'Read the Flicko terms of service.',
          badge: 'LEGAL',
          icon: Icons.description_outlined,
          onTap: () => context.push('/profile/settings/help/terms'),
        ),
        const SizedBox(height: 14),
        _buildLinkCard(
          context: context,
          title: 'PRIVACY POLICY',
          subtitle: 'Read the Flicko privacy policy.',
          badge: 'LEGAL',
          icon: Icons.privacy_tip_outlined,
          onTap: () => context.push('/profile/settings/help/privacy-policy'),
        ),
      ],
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APP INFO',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        GestureDetector(
          onTap: () => _showAppInfoDialog(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              border: Border.all(color: _neonGreen.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'APP VERSION',
                            style: GoogleFonts.epilogue(
                              color: _textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(color: _neonGreen),
                            child: Text(
                              'LATEST',
                              style: GoogleFonts.spaceMono(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Flicko v1.0.0',
                        style: GoogleFonts.spaceMono(
                          color: _neonGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: _textWhite.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.info_outline, color: _neonGreen, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required VoidCallback onTap,
    bool usePrimaryBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          border: Border.all(
            color: usePrimaryBadge
                ? _neonGreen.withValues(alpha: 0.4)
                : _textWhite.withValues(alpha: 0.05),
            width: usePrimaryBadge ? 1.5 : 1,
          ),
          boxShadow: usePrimaryBadge
              ? [
                  BoxShadow(
                      color: _neonGreen.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.epilogue(
                          color: _textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: usePrimaryBadge ? _neonGreen : Colors.transparent,
                          border: usePrimaryBadge
                              ? null
                              : Border.all(
                                  color: _textWhite.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.spaceMono(
                            color: usePrimaryBadge
                                ? Colors.black
                                : _textWhite.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(icon, color: _textWhite.withValues(alpha: 0.2), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          color: _neonGreen.withValues(alpha: 0.2),
          margin: const EdgeInsets.only(bottom: 24),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _neonGreen.withValues(alpha: 0.05),
            border: Border.symmetric(
              horizontal: BorderSide(color: _textWhite.withValues(alpha: 0.05)),
            ),
          ),
          child: Center(
            child: Text(
              'FLICKO // SUPPORT CENTER',
              style: GoogleFonts.spaceMono(
                color: _textWhite.withValues(alpha: 0.3),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[HELP_SCREEN] Failed to launch URL: $url ($e)');
    }
  }

  // ── Custom In-App Overlay Dialogs ──

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(0.08)
              ..rotateY(-0.06),
            alignment: Alignment.center,
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.25),
                    blurRadius: 40,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _neonGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_outline, color: _neonGreen, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'SYSTEM INFO',
                            style: GoogleFonts.epilogue(
                              color: _textWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSystemRow('APPLICATION', 'Flicko Studio'),
                      _buildSystemRow('BUILD VERSION', 'v1.0.0-Stable'),
                      _buildSystemRow('RELEASE DATE', '25 May 2026'),
                      _buildSystemRow('ENGINE SOURCE', 'Flutter 3.22.2 (Dart 3.4.3)'),
                      _buildSystemRow('SECURITY RATIO', 'Sealed Sender E2EE Active'),
                      _buildSystemRow('COSMETICS API', 'Supabase Realtime v2'),
                      const SizedBox(height: 20),
                      Text(
                        'Designed by tech.focko under MIT License. All rights reserved.',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _neonGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'DISMISS',
                              style: GoogleFonts.spaceMono(
                                color: _neonGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Text(
            val,
            style: GoogleFonts.spaceGrotesk(color: _textWhite, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
