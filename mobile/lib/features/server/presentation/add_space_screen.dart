import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AddSpaceScreen extends StatelessWidget {
  const AddSpaceScreen({super.key});

  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader().animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 40),
                    _buildSectionHeader('INITIATE_CONNECTION'),
                    _buildActionCard(
                      context: context,
                      title: 'CREATE_SPACE',
                      description: 'START A NEW COMMUNITY FROM SCRATCH. TOTAL CONTROL, CUSTOM RULES, ZERO LIMITS.',
                      icon: Icons.add_circle_outline,
                      onTap: () => context.push('/server/build'),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 32),
                    _buildSectionHeader('JOIN_VIA_INVITE'),
                    _buildJoinSection(context).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 48),
                    _buildLegalFooter(),
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

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: black,
        border: Border(bottom: BorderSide(color: lime, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _brutalistIconButton(Icons.arrow_back_ios_new, () => context.pop()),
          Text(
            'ADD_SPACE.CONFIG',
            style: GoogleFonts.spaceGrotesk(
              color: white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 44), // Balanced spacing
        ],
      ),
    );
  }

  Widget _brutalistIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: lime, offset: Offset(3, 3)),
          ],
        ),
        child: Icon(icon, size: 20, color: white),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Text(
              'ADD',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: -2,
                color: lime,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 45),
              child: Text(
                'SPACE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  letterSpacing: -2,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(width: 60, height: 8, color: lime),
        const SizedBox(height: 24),
        Text(
          'EXPAND YOUR REACH. CREATE A NEW HUB OR ACCESS EXISTING COORDINATES. STATUS: READY',
          style: GoogleFonts.robotoMono(
            color: white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, color: lime, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.robotoMono(
                color: white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: white, width: 3),
        boxShadow: const [
          BoxShadow(color: lime, offset: Offset(6, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lime,
                    border: Border.all(color: black, width: 2),
                  ),
                  child: Icon(icon, color: black, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              description,
              style: GoogleFonts.robotoMono(
                color: white.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _brutalistButton(
              text: 'INITIATE_BUILD',
              onTap: onTap,
              color: lime,
              textColor: black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: white, width: 3),
        boxShadow: const [
          BoxShadow(color: white, offset: Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCESS_CODE',
            style: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: grey,
              border: Border.all(color: white, width: 2),
            ),
            child: TextField(
              style: GoogleFonts.robotoMono(
                color: lime,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '> ENTER_CODE...',
                hintStyle: GoogleFonts.robotoMono(
                  color: white.withValues(alpha: 0.2),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _brutalistButton(
            text: 'JOIN_COMMUNITY',
            onTap: () {},
            color: white,
            textColor: black,
          ),
        ],
      ),
    );
  }

  Widget _brutalistButton({
    required String text,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: black, width: 3),
          boxShadow: [
            BoxShadow(
              color: color == lime ? white : lime,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 2, color: grey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'END_PROTOCOL',
                style: GoogleFonts.robotoMono(
                  color: white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(child: Container(height: 2, color: grey)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'FLICKO_CORE_HUB_V4.0.0_STABLE',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: white.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
