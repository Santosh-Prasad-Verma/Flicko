import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_onboarding_screen.dart';

class AuraSettingsScreen extends ConsumerStatefulWidget {
  const AuraSettingsScreen({super.key});

  @override
  ConsumerState<AuraSettingsScreen> createState() => _AuraSettingsScreenState();
}

class _AuraSettingsScreenState extends ConsumerState<AuraSettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLightMode = false;
  Color _primaryAccent = const Color(0xFF7B4FFF);
  String _currentTheme = "Neon Glow";
  String _currentLanguage = "English";
  double _temperature = 0.7;
  bool _autoVoiceAutoplay = false;

  late AnimationController _waveController;

  Color get _bgBlack => _isLightMode ? const Color(0xFFF5F5FA) : const Color(0xFF06060E);
  Color get _cardBg => _isLightMode ? const Color(0xFFE8E8F3) : const Color(0xFF131326);
  Color get _glassBorder => _isLightMode ? const Color(0x1F0D0D1A) : const Color(0x12FFFFFF);
  Color get _textMuted => _isLightMode ? const Color(0xFF5D5D74) : const Color(0xFF8E8E9F);
  Color get _textDimmed => _isLightMode ? const Color(0xFF7E7E95) : const Color(0xFF5D5D74);
  Color get _textColor => _isLightMode ? const Color(0xFF0F0F1A) : Colors.white;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _showChatSettingsDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isLightMode ? Colors.white : const Color(0xFF0F0F1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _primaryAccent, width: 1.5),
              ),
              title: Text(
                'Default Chat Settings',
                style: GoogleFonts.inter(
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response Creativity (Temperature)',
                    style: GoogleFonts.inter(
                      color: _textColor, 
                      fontSize: 13, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _temperature,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: _primaryAccent,
                    inactiveColor: _textColor.withOpacity(0.1),
                    label: _temperature == 0.1
                        ? 'Precise (0.1)'
                        : _temperature == 0.7
                            ? 'Balanced (0.7)'
                            : _temperature == 1.0
                                ? 'Creative (1.0)'
                                : _temperature.toStringAsFixed(1),
                    onChanged: (val) {
                      setDialogState(() {
                        _temperature = val;
                      });
                      setState(() {});
                    },
                  ),
                  Text(
                    'Configure Grok\'s response balance: lower values are precise and deterministic; higher values are creative.',
                    style: GoogleFonts.inter(color: _textMuted, fontSize: 10),
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Autoplay',
                            style: GoogleFonts.inter(
                              color: _textColor, 
                              fontSize: 13, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Read responses aloud automatically',
                            style: GoogleFonts.inter(color: _textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                      Switch(
                        value: _autoVoiceAutoplay,
                        activeColor: _primaryAccent,
                        onChanged: (val) {
                          setDialogState(() {
                            _autoVoiceAutoplay = val;
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(color: _primaryAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWhatsNew() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isLightMode ? Colors.white : const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "What's New in Aura",
                    style: GoogleFonts.inter(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: _textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildTimelineItem(
                      version: "v2.4.0",
                      date: "May 2026",
                      title: "xAI Grok-beta Server Integration",
                      description: "Migrated full backend logic to secure server-side Supabase Edge Functions communicating with xAI. Direct frontend keys have been completely phased out for flawless safety.",
                    ),
                    _buildTimelineItem(
                      version: "v2.3.0",
                      date: "April 2026",
                      title: "EKG Waveform & Speech Synthesis",
                      description: "Added rich real-time EKG listening audio feedback with fluid vector orbits for interactive conversation.",
                    ),
                    _buildTimelineItem(
                      version: "v2.2.0",
                      date: "March 2026",
                      title: "Multimodal Domain Engines",
                      description: "Specialized model routing launched: Text Writer, AI Image Generator, and software engineering Code Tutor.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String version,
    required String date,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryAccent.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  version,
                  style: GoogleFonts.inter(
                    color: _primaryAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: GoogleFonts.inter(color: _textDimmed, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: _textColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(color: _textMuted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFAQ() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isLightMode ? Colors.white : const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Frequently Asked Questions",
                    style: GoogleFonts.inter(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: _textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildFAQItem(
                      question: "What is Aura AI?",
                      answer: "Aura is your personalized AI assistant built inside Flicko. She can write, generate code, mock up visuals, or engage with you directly via natural voice conversations.",
                    ),
                    _buildFAQItem(
                      question: "Is my conversations/API key secure?",
                      answer: "Absolutely. All API requests are routed through verified Supabase Deno Edge Functions using production-grade JWT session authentication. Key management is 100% secure server-side.",
                    ),
                    _buildFAQItem(
                      question: "How do I trigger local actions?",
                      answer: "You can trigger client tools by simply typing commands such as 'play [song]', 'message [username]: [text]', or 'list servers' directly in Aura's text chat.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _primaryAccent,
          collapsedIconColor: _textMuted,
          title: Text(
            question,
            style: GoogleFonts.inter(
              color: _textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Text(
                answer,
                style: GoogleFonts.inter(
                  color: _textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector() {
    final themes = [
      {"name": "Neon Glow", "color": const Color(0xFF7B4FFF)},
      {"name": "Cyberpunk Violet", "color": const Color(0xFFFF00F5)},
      {"name": "Emerald Aurora", "color": const Color(0xFF00FFCC)},
      {"name": "Sunset Gold", "color": const Color(0xFFFFB300)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _isLightMode ? Colors.white : const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Select Theme Style",
                style: GoogleFonts.inter(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: themes.map((t) {
                  final isSelected = _currentTheme == t["name"];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentTheme = t["name"] as String;
                        _primaryAccent = t["color"] as Color;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (t["color"] as Color).withOpacity(0.1)
                            : Colors.white.withOpacity(0.02),
                        border: Border.all(
                          color: isSelected
                              ? (t["color"] as Color)
                              : Colors.white.withOpacity(0.05),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t["color"] as Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            t["name"] as String,
                            style: GoogleFonts.inter(
                              color: _textColor,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: _primaryAccent, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSelector() {
    final languages = ["English", "Deutsch", "Español", "Français"];

    showModalBottomSheet(
      context: context,
      backgroundColor: _isLightMode ? Colors.white : const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Select Language",
                style: GoogleFonts.inter(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: languages.map((lang) {
                  final isSelected = _currentLanguage == lang;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentLanguage = lang;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryAccent.withOpacity(0.1)
                            : Colors.white.withOpacity(0.02),
                        border: Border.all(
                          color: isSelected
                              ? _primaryAccent
                              : Colors.white.withOpacity(0.05),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang,
                            style: GoogleFonts.inter(
                              color: _textColor,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: _primaryAccent, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // Twinkling background
          Positioned.fill(
            child: CustomPaint(
              painter: DeepSpaceBackgroundPainter(animationValue: 0.0),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar / Header Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _textColor.withOpacity(0.03),
                            border: Border.all(
                              color: _textColor.withOpacity(0.07),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _textColor,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Setting',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Spacer balancing the back button
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Unlimited Card
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _cardBg,
                          _isLightMode ? const Color(0xFFD6D6E6) : const Color(0xFF080811),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _glassBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(_isLightMode ? 0.08 : 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Holo Wave graphic custom painter
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: HoloWavePainter(
                                    animationValue: _waveController.value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Text content
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Go Unlimited',
                                style: GoogleFonts.inter(
                                  color: _textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Unlock all features of\nthe full version',
                                style: GoogleFonts.inter(
                                  color: _textMuted,
                                  fontSize: 11,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action button (arrow up right)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _primaryAccent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryAccent.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.north_east_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Group 1
                  _buildListCardGroup([
                    _buildSettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: "What's new",
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showWhatsNew();
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.help_outline_rounded,
                      title: "FAQ",
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showFAQ();
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.wb_sunny_outlined,
                      title: "Light Mood",
                      isToggle: true,
                      toggleValue: _isLightMode,
                      onToggle: (val) {
                        setState(() {
                          _isLightMode = val;
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Settings Group 2
                  _buildListCardGroup([
                    _buildSettingsItem(
                      icon: Icons.grid_view_rounded,
                      title: "Theme",
                      trailingText: _currentTheme,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showThemeSelector();
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.tune_rounded,
                      title: "Default chat settings",
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showChatSettingsDialog(context);
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.favorite_outline_rounded,
                      title: "Language",
                      trailingText: _currentLanguage,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showLanguageSelector();
                      },
                    ),
                  ]),

                  const Spacer(),

                  // Settings Footer
                  Column(
                    children: [
                      Text(
                        'AURA V2.4.0',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Powered by Advanced Deep Neural Network',
                        style: GoogleFonts.inter(
                          color: _textDimmed,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCardGroup(List<Widget> items) {
    List<Widget> childrenWithDividers = [];
    for (int i = 0; i < items.length; i++) {
      childrenWithDividers.add(items[i]);
      if (i < items.length - 1) {
        childrenWithDividers.add(
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.04),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        border: Border.all(color: _glassBorder, width: 1.0),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: childrenWithDividers,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? trailingText,
    bool isToggle = false,
    bool toggleValue = false,
    ValueChanged<bool>? onToggle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isToggle ? null : onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            // Left icon container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryAccent.withOpacity(0.1),
                border: Border.all(
                  color: _primaryAccent.withOpacity(0.15),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: const Color(0xFFCBBAFF),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isToggle)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (onToggle != null) onToggle(!toggleValue);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 24,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: toggleValue
                        ? _primaryAccent
                        : Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: toggleValue
                          ? Colors.white.withOpacity(0.15)
                          : _glassBorder,
                      width: 1.0,
                    ),
                    boxShadow: toggleValue
                        ? [
                            BoxShadow(
                              color: _primaryAccent.withOpacity(0.4),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                  child: Align(
                    alignment: toggleValue
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: toggleValue ? Colors.white : _textMuted,
                      ),
                    ),
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailingText != null)
                    Text(
                      trailingText,
                      style: GoogleFonts.inter(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _textDimmed,
                    size: 14,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class HoloWavePainter extends CustomPainter {
  final double animationValue;

  HoloWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        const Color(0xFF7B4FFF).withOpacity(0.8),
        const Color(0xFF00F0FF).withOpacity(0.9),
        const Color(0xFFFF00F5).withOpacity(0.6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double phase = animationValue * 2 * math.pi;

    // Draw Wave 1 (thick primary)
    final path1 = Path();
    paint.strokeWidth = 3.5;
    for (double x = 0; x <= size.width; x++) {
      // Wave equation with amplitude modulating along width to taper off
      final double env = math.sin((x / size.width) * math.pi);
      final double y = size.height * 0.5 +
          25.0 * math.sin(phase + (x * 0.02)) * env;
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }
    canvas.drawPath(path1, paint);

    // Draw Wave 2 (medium background)
    final path2 = Path();
    paint.strokeWidth = 2.0;
    final paint2 = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    for (double x = 0; x <= size.width; x++) {
      final double env = math.sin((x / size.width) * math.pi);
      final double y = size.height * 0.5 +
          15.0 * math.sin(-phase + (x * 0.035)) * env;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    canvas.drawPath(path2, paint2..color = paint2.color.withOpacity(0.6));

    // Draw Wave 3 (thin backdrop)
    final path3 = Path();
    final paint3 = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (double x = 0; x <= size.width; x++) {
      final double env = math.sin((x / size.width) * math.pi);
      final double y = size.height * 0.5 +
          8.0 * math.sin(phase * 1.5 + (x * 0.05)) * env;
      if (x == 0) {
        path3.moveTo(x, y);
      } else {
        path3.lineTo(x, y);
      }
    }
    canvas.drawPath(path3, paint3..color = paint3.color.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(covariant HoloWavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
