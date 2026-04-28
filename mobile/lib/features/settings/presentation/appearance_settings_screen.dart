import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Appearance Settings Screen
///
/// Theme switching between Dark, Light, and AMOLED modes.
/// Font scaling and other visual preferences.
class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  String _selectedTheme = 'dark';
  double _fontScale = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('theme') ?? 'dark';
      _fontScale = prefs.getDouble('fontScale') ?? 1.0;
      _isLoading = false;
    });
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    setState(() => _selectedTheme = theme);
  }

  Future<void> _saveFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', scale);
    setState(() => _fontScale = scale);
  }

  static final List<Map<String, dynamic>> _themes = [
    {'id': 'dark', 'label': 'Dark', 'icon': Icons.dark_mode, 'color': 0xFF313338},
    {'id': 'light', 'label': 'Light', 'icon': Icons.light_mode, 'color': 0xFFFFFFFF},
    {'id': 'amoled', 'label': 'AMOLED', 'icon': Icons.brightness_3, 'color': 0xFF000000},
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(FlickoColors.bgPrimary),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Appearance',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('THEME'),
          _buildThemeSelector(),
          const SizedBox(height: 24),

          _buildSectionHeader('DISPLAY'),
          _buildSettingsCard([
            _buildSliderSetting(
              'Chat Font Scaling',
              'Adjust the size of text in messages',
              _fontScale,
              min: 0.75,
              max: 1.5,
              divisions: 3,
              labels: const ['Small', 'Normal', 'Large', 'Extra Large'],
              onChanged: (value) {
                _saveFontScale(value);
              },
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('ACCESSIBILITY'),
          _buildSettingsCard([
            _buildToggleSetting('Saturation', 'Reduce saturation for accessibility', false),
            _buildToggleSetting('High Contrast', 'Increase contrast for better visibility', false),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Row(
      children: _themes.map((theme) {
        final isSelected = _selectedTheme == theme['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => _saveTheme(theme['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(FlickoColors.blurple), width: 2)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    theme['icon'] as IconData,
                    color: isSelected
                        ? const Color(FlickoColors.blurple)
                        : const Color(FlickoColors.textSecondary),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme['label'] as String,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? const Color(FlickoColors.blurple)
                          : const Color(FlickoColors.textPrimary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(theme['color'] as int),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(FlickoColors.textMuted),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSliderSetting(
    String title,
    String subtitle,
    double value, {
    required double min,
    required double max,
    required int divisions,
    required List<String> labels,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((label) {
              return Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 10,
                ),
              );
            }).toList(),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(FlickoColors.blurple),
            inactiveColor: const Color(FlickoColors.bgTertiary),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting(String title, String subtitle, bool value) {
    return SwitchListTile(
      value: value,
      onChanged: (_) {},
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      activeThumbColor: const Color(FlickoColors.blurple),
    );
  }
}
