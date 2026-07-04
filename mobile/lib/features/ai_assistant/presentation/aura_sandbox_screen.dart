import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AuraSandboxScreen extends StatefulWidget {
  final String code;

  const AuraSandboxScreen({super.key, required this.code});

  @override
  State<AuraSandboxScreen> createState() => _AuraSandboxScreenState();
}

class _AuraSandboxScreenState extends State<AuraSandboxScreen> {
  double _opacity = 0.05;
  double _blur = 10.0;
  double _borderRadius = 16.0;
  double _borderWidth = 1.5;
  Color _accentColor = const Color(0xFFFF007F); // Cyber Pink

  Color get _bgBlack => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardGrey => Theme.of(context).cardColor;
  Color get _borderGrey => Theme.of(context).dividerColor;
  Color get _textWhite => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFFFBF9FA);
  Color get _textMuted => Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF8E8E93);
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  final List<Color> _availableColors = [
    const Color(0xFFFF007F), // Cyber Pink
    const Color(0xFF8B00FF), // Neon Purple
    const Color(0xFF00FFCC), // Toxic Green
    const Color(0xFF00E5FF), // Cyber Cyan
    const Color(0xFFFFAB00), // Amber Gold
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: AppBar(
        backgroundColor: _bgBlack,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _textWhite),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'WIDGET SANDBOX PLAYGROUND',
          style: GoogleFonts.spaceGrotesk(
            color: _textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderGrey, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.black38,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildLivePreviewWidget(),
                  ),
                ),
              ),
            ),
            Container(color: _borderGrey, height: 1),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Interactive Controls'),
                      const SizedBox(height: 16),
                      _buildSliderRow('Card Opacity', _opacity, 0.01, 0.3, (val) {
                        setState(() => _opacity = val);
                      }, valueFormatter: (v) => '${(v * 100).round()}%'),
                      _buildSliderRow('Glass Blur', _blur, 0.0, 25.0, (val) {
                        setState(() => _blur = val);
                      }, valueFormatter: (v) => '${v.round()} px'),
                      _buildSliderRow('Corner Radius', _borderRadius, 0.0, 40.0, (val) {
                        setState(() => _borderRadius = val);
                      }, valueFormatter: (v) => '${v.round()} px'),
                      _buildSliderRow('Border Thickness', _borderWidth, 0.5, 4.0, (val) {
                        setState(() => _borderWidth = val);
                      }, valueFormatter: (v) => '${v.toStringAsFixed(1)} px'),
                      const SizedBox(height: 20),
                      _buildAccentColorPicker(),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Sandbox Code Source'),
                      const SizedBox(height: 12),
                      _buildCodeViewerPanel(),
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

  Widget _buildLivePreviewWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: Container(
          width: 280,
          height: 180,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _opacity),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.3),
              width: _borderWidth,
            ),
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SANDBOX PREVIEW',
                      style: GoogleFonts.spaceMono(
                        color: _accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Icon(Icons.blur_circular_rounded, color: _accentColor, size: 22),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AURA CYBER CARD',
                    style: GoogleFonts.spaceGrotesk(
                      color: _textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opacity: ${(_opacity * 100).round()}% · Blur: ${_blur.round()}px',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        color: _textWhite,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required String Function(double) valueFormatter,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 11),
              ),
              Text(
                valueFormatter(value),
                style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accentColor,
              inactiveTrackColor: _borderGrey,
              thumbColor: _textWhite,
              overlayColor: _accentColor.withValues(alpha: 0.2),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Glow Tint Accent',
              style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 11),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _availableColors.map((color) {
            final isSelected = _accentColor == color;
            return GestureDetector(
              onTap: () => setState(() => _accentColor = color),
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : color.withValues(alpha: 0.4),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 14),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCodeViewerPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardGrey,
        border: Border.all(color: _borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        widget.code,
        style: GoogleFonts.spaceMono(
          color: const Color(0xFF00FFCC), // Hacker green code color
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
