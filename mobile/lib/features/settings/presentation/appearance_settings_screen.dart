import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/theme/theme_provider.dart';
import 'package:mobile/features/settings/application/user_settings_notifier.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  double _fontScale = 1.0;
  bool _isLoading = true;
  String _tempThemeId = 'dark';
  Color _tempAccentColor = const Color(0xFF52B788);
  final Color _limeColor = const Color(0xFF52B788);

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value != null ? Color(value) : const Color(0xFF52B788);
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = ref.read(userSettingsNotifierProvider);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScale = prefs.getDouble('fontScale') ?? settings.fontScale;
      _tempThemeId = ref.read(themeProvider);
      _tempAccentColor = _hexToColor(settings.accentColor);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _limeColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'APPEARANCE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('THEME ENGINE'),
            _buildThemeGrid(),
            const SizedBox(height: 32),
            _buildSectionHeader('TYPOGRAPHY'),
            _buildTypographyCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('ACCENT COLORS'),
            _buildAccentSection(),
            const SizedBox(height: 48),
            _buildActionButtons(),
            const SizedBox(height: 40),
            Center(
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/Flicko-for-black-background.png',
                  height: 30,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _limeColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: _limeColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGrid() {
    return Column(
      children: [
        _buildThemeOption(
            'STUDIO LIGHT', 'light', Icons.wb_sunny_rounded, 'Classic clean aesthetic'),
        const SizedBox(height: 12),
        _buildThemeOption(
            'DARKROOM', 'dark', Icons.nightlight_round_rounded, 'Optimized for focus'),
        const SizedBox(height: 12),
        _buildThemeOption(
            'RAW INDUSTRIAL', 'amoled', Icons.flash_on_rounded, 'Pure black performance',
            isPremium: true),
      ],
    );
  }

  Widget _buildThemeOption(
      String label, String id, IconData icon, String subtitle,
      {bool isPremium = false}) {
    final isSelected = _tempThemeId == id;

    return GestureDetector(
      onTap: () => setState(() => _tempThemeId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111111) : const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _limeColor : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _limeColor.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _limeColor.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon,
                  color: isSelected ? _limeColor : Colors.white.withValues(alpha: 0.3),
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _limeColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                  color: _limeColor.withValues(alpha: 0.3),
                                  blurRadius: 8),
                            ],
                          ),
                          child: Text(
                            'PLUS',
                            style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _limeColor : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 7 : 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypographyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Text(
                  'FLICKO PREMIUM UI',
                  style: GoogleFonts.inter(
                    fontSize: 16 * _fontScale,
                    fontWeight: FontWeight.w900,
                    color: _limeColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A new standard in communication',
                  style: GoogleFonts.inter(
                    fontSize: 14 * _fontScale,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aa',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white24,
                      fontWeight: FontWeight.w900)),
              Text('Aa',
                  style: GoogleFonts.inter(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _limeColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: Colors.white,
              overlayColor: _limeColor.withValues(alpha: 0.1),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12, elevation: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: _fontScale,
              min: 0.8,
              max: 1.2,
              divisions: 4,
              onChanged: (val) => setState(() => _fontScale = val),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSliderLabel('COMPACT', _fontScale < 1.0),
                _buildSliderLabel('STANDARD', _fontScale == 1.0),
                _buildSliderLabel('RELAXED', _fontScale > 1.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String label, bool active) {
    return Text(label,
        style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: active ? _limeColor : Colors.white.withValues(alpha: 0.2),
            letterSpacing: 1.5));
  }

  Widget _buildAccentSection() {
    final List<Color> accents = [
      const Color(0xFF52B788),
      const Color(0xFF00E5FF),
      const Color(0xFFFF3D00),
      const Color(0xFFE040FB),
      const Color(0xFFFFFFFF),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: accents.map((color) {
        final isSelected = color.toARGB32() == _tempAccentColor.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _tempAccentColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2)
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 32)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                color: Colors.white.withValues(alpha: 0.03),
              ),
              child: Center(
                child: Text(
                  'DISCARD',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('fontScale', _fontScale);
              ref.read(themeProvider.notifier).setTheme(_tempThemeId);
              ref.read(userSettingsNotifierProvider.notifier)
                ..setDouble('appearance_font_scale', _fontScale)
                ..setString('appearance_theme', _tempThemeId)
                ..setString('appearance_accent_color', _colorToHex(_tempAccentColor));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _limeColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.all(20),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.black, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'SETTINGS UPDATED',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                context.pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _limeColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: _limeColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Center(
                child: Text(
                  'SAVE CHANGES',
                  style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
