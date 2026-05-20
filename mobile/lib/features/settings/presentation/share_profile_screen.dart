import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ShareProfileScreen extends ConsumerWidget {
  const ShareProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.maybeWhen(
      authenticated: (user, profile) {
        final username = profile?.username ?? 'user';
        final link = 'https://flicko.app/@$username';
        return _ShareSheet(username: username, link: link);
      },
      orElse: () => const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final String username;
  final String link;

  const _ShareSheet({required this.username, required this.link});

  static const _neonGreen = Color(0xFFCCFF00);
  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Gradient top
          Positioned(
            top: 0, left: 0, right: 0, height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF52B788).withValues(alpha: 0.25),
                    _bg,
                  ],
                  center: Alignment.center,
                  radius: 1.0,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Bottom card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text('SHARE THE VIBE',
                                style: GoogleFonts.epilogue(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    fontStyle: FontStyle.italic)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _neonGreen,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: _neonGreen.withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: Row(
                              children: [
                                Text('VIP INVITE',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                                const SizedBox(width: 4),
                                const Icon(Icons.star_border, color: Colors.black, size: 13),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('QUICK SEND',
                          style: GoogleFonts.spaceMono(
                              color: Colors.white38, fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _avatar('Alex', 'A', const Color(0xFF52B788)),
                          _avatar('Jordan', 'J', Colors.white),
                          _avatar('Sam', 'S', const Color(0xFF00E5FF)),
                          _actionIcon('More', Icons.search),
                        ],
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile link copied!')));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.link, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text('COPY LINK',
                                  style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _actionIcon('Email', Icons.email_outlined),
                          _actionIcon('Message', Icons.chat_bubble_outline),
                          _actionIcon('QR Code', Icons.qr_code_scanner),
                          _actionIcon('More', Icons.more_horiz),
                        ],
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

  Widget _avatar(String name, String letter, Color color) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          ),
          child: Center(
            child: Text(letter,
                style: GoogleFonts.epilogue(
                    color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12)),
      ],
    );
  }

  Widget _actionIcon(String label, IconData icon) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF111113),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 26)),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white54, fontWeight: FontWeight.w500, fontSize: 12),
            textAlign: TextAlign.center),
      ],
    );
  }
}
