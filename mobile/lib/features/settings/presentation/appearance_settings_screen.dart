import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  String _selectedTheme = 'raw_industrial';
  Color _accentColor = const Color(0xFFBAE82C); // Starting accent: Lime
  int _fontScaleIndex = 1; // 0 = Compact, 1 = Standard, 2 = Gallery

  final List<Color> _accents = [
    const Color(0xFFBAE82C), // Lime Green
    const Color(0xFF0F62FE), // Royal Blue
    const Color(0xFFFF4200), // Vibrant Orange/Red
    const Color(0xFFF3F3F3), // Off White
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Appearance',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF1A1A1D),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize your gallery experience.\nAdjust lighting, typography, and\naccents to suit your creative flow.',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF8B8E93),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _buildThemeCardSection(),
            const SizedBox(height: 20),
            _buildTypographySection(),
            const SizedBox(height: 20),
            _buildAccentToneSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCardSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A1B1F), width: 1.5),
      ),
      child: Stack(
        children: [
          // NEW ENGINE Badge
          Positioned(
            top: 20,
            right: 20,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBAE82C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  'NEW ENGINE',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interface\nTheme',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the foundational lighting for your canvas.',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF6B6E74),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Card 1: STUDIO LIGHT
                _buildThemeOption(
                  id: 'studio_light',
                  title: 'STUDIO LIGHT',
                  previewWidget: Container(
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.wb_sunny_outlined, color: Colors.black, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Card 2: DARKROOM
                _buildThemeOption(
                  id: 'darkroom',
                  title: 'DARKROOM',
                  previewWidget: Container(
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131416),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF232428), width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.dark_mode_outlined, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Card 3: RAW INDUSTRIAL (BETA)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildThemeOption(
                      id: 'raw_industrial',
                      title: 'RAW INDUSTRIAL',
                      previewWidget: Container(
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333336), width: 1.5),
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.architecture, color: const Color(0xFFBAE82C), size: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'BETA',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                            letterSpacing: 0.5,
                          ),
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
    );
  }

  Widget _buildThemeOption({
    required String id,
    required String title,
    required Widget previewWidget,
  }) {
    final isSelected = _selectedTheme == id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111215),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFBAE82C) : const Color(0xFF1E1F23),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            previewWidget,
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFBAE82C) : const Color(0xFF33353B),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 10, color: Color(0xFFBAE82C))
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypographySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A1B1F), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tₜ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Typography Scale',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the global typographic hierarchy for better readability.',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF6B6E74),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111215),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E1F23), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aa',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Aa',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF282B31),
                    inactiveTrackColor: const Color(0xFF1E1F23),
                    thumbColor: Colors.black,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const _CustomThumbShape(),
                  ),
                  child: Slider(
                    value: _fontScaleIndex.toDouble(),
                    min: 0,
                    max: 2,
                    divisions: 2,
                    onChanged: (val) {
                      setState(() {
                        _fontScaleIndex = val.round();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScaleLabel('COMPACT', _fontScaleIndex == 0),
                    _buildScaleLabel('STANDARD', _fontScaleIndex == 1),
                    _buildScaleLabel('GALLERY', _fontScaleIndex == 2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleLabel(String label, bool isActive) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 8,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w900,
        color: isActive ? Colors.white : const Color(0xFF53565C),
      ),
    );
  }

  Widget _buildAccentToneSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A1B1F), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'Accent Tone',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Define the highlight color used across interactive elements and tags.',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF6B6E74),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          // Accent color list Row
          Row(
            children: _accents.map((color) {
              final isSelected = _accentColor == color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _accentColor = color;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(color: const Color(0xFF1A1B1F), width: 1.5),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: color == const Color(0xFFF3F3F3) ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Preview Bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1C1D22), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PREVIEW',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ACTIVE BUTTON',
                    style: GoogleFonts.spaceGrotesk(
                      color: _accentColor == const Color(0xFFF3F3F3) ? Colors.black : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF2A2B30), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'DISCARD',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Changes Applied Successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'APPLY CHANGES',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  const _CustomThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw outer lime green stroke circle
    final Paint outerPaint = Paint()
      ..color = const Color(0xFFBAE82C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, 9.0, outerPaint);

    // Draw inner black circle
    final Paint innerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 7.5, innerPaint);
  }
}
