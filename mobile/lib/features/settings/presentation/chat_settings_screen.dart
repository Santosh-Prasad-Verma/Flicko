import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chat Settings Screen (Sleek Brutalist Black/Neon Theme)
class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _showEmojiReactions = true;
  bool _showStickers = true;
  bool _showGifPreviews = true;
  bool _compactMode = false;
  bool _enterToSend = true;
  bool _quickReactions = true;
  bool _sendWithSound = false;

  static const Color _neonGreen = Color(0xFFC0F500);
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
            _buildHeader(),
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
                      _buildDisplaySection(),
                      const SizedBox(height: 40),
                      _buildInputSection(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _neonGreen.withValues(alpha: 0.1),
            width: 1,
          ),
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
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.transparent),
                ),
              ),
              child: const Icon(Icons.arrow_back, color: _textWhite, size: 20),
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
                  'MESSAGING PREFERENCES',
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
          'CHAT',
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
                'MESSAGING',
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
                    'CONFIGURE CHAT BEHAVIOR',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Display, input & reaction preferences',
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

  Widget _buildDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISPLAY',
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
        _buildAccessCard(
          title: 'EMOJI REACTIONS',
          subtitle: 'Display emoji reactions on messages.',
          badge: 'UI',
          toggleWidget: _buildHardwareToggle(_showEmojiReactions, (val) {
            setState(() => _showEmojiReactions = val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'STICKERS',
          subtitle: 'Show stickers in chat conversations.',
          badge: 'MEDIA',
          toggleWidget: _buildHardwareToggle(_showStickers, (val) {
            setState(() => _showStickers = val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'GIF PREVIEWS',
          subtitle: 'Preview GIFs before sending them.',
          badge: 'MEDIA',
          toggleWidget: _buildHardwareToggle(_showGifPreviews, (val) {
            setState(() => _showGifPreviews = val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'COMPACT MODE',
          subtitle: 'Reduce spacing between messages for density.',
          badge: 'LAYOUT',
          usePrimaryBadge: true,
          toggleWidget: _buildHardwareToggle(_compactMode, (val) {
            setState(() => _compactMode = val);
          }),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INPUT',
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
        _buildAccessCard(
          title: 'ENTER TO SEND',
          subtitle: 'Press Enter to send messages.',
          badge: 'KEY',
          toggleWidget: _buildHardwareToggle(_enterToSend, (val) {
            setState(() => _enterToSend = val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'QUICK REACTIONS',
          subtitle: 'Double-tap to add quick reactions.',
          badge: 'GESTURE',
          toggleWidget: _buildHardwareToggle(_quickReactions, (val) {
            setState(() => _quickReactions = val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'SEND WITH SOUND',
          subtitle: 'Play sound when sending messages.',
          badge: 'AUDIO',
          toggleWidget: _buildHardwareToggle(_sendWithSound, (val) {
            setState(() => _sendWithSound = val);
          }),
        ),
      ],
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
              horizontal: BorderSide(
                color: _textWhite.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Center(
            child: Text(
              'FLICKO // PREFERENCES SECURE',
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

  Widget _buildAccessCard({
    required String title,
    required String subtitle,
    required String badge,
    required Widget toggleWidget,
    bool usePrimaryBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(
          color: usePrimaryBadge ? _neonGreen.withValues(alpha: 0.4) : _textWhite.withValues(alpha: 0.05),
          width: usePrimaryBadge ? 1.5 : 1,
        ),
        boxShadow: usePrimaryBadge
            ? [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: usePrimaryBadge ? _neonGreen : Colors.transparent,
                        border: usePrimaryBadge ? null : Border.all(color: _textWhite.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.spaceMono(
                          color: usePrimaryBadge ? Colors.black : _textWhite.withValues(alpha: 0.4),
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
          toggleWidget,
        ],
      ),
    );
  }

  Widget _buildHardwareToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? _neonGreen : const Color(0xFF141416),
          border: Border.all(
            color: value ? _neonGreen : _textWhite.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 26 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? Colors.black : const Color(0xFF71717A),
                ),
                child: Center(
                  child: Container(
                    width: 2,
                    height: 8,
                    color: value
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
