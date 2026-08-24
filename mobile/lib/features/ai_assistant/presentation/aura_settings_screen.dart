import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_assistant/data/aura_settings_provider.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_onboarding_screen.dart';

class AuraSettingsScreen extends ConsumerStatefulWidget {
  const AuraSettingsScreen({super.key});

  @override
  ConsumerState<AuraSettingsScreen> createState() => _AuraSettingsScreenState();
}

class _AuraSettingsScreenState extends ConsumerState<AuraSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  Color get _bgBlack => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _glassBorder => Theme.of(context).dividerColor.withOpacity(0.12);
  Color get _textMuted => Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF8E8E9F);
  Color get _textDimmed => Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? const Color(0xFF5D5D74);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

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
    final settings = ref.read(auraSettingsProvider);
    double tempTemp = settings.temperature;
    bool tempAutoplay = settings.autoVoiceAutoplay;
    final rawAccent = settings.accentColor;
    final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: accent, width: 1.5),
              ),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Chat Settings',
                      style: GoogleFonts.inter(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Response Creativity (Temperature)',
                      style: GoogleFonts.inter(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: tempTemp,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      activeColor: accent,
                      inactiveColor: _textColor.withOpacity(0.1),
                      label: tempTemp == 0.1
                          ? 'Precise (0.1)'
                          : tempTemp == 0.7
                              ? 'Balanced (0.7)'
                              : tempTemp == 1.0
                                  ? 'Creative (1.0)'
                                  : tempTemp.toStringAsFixed(1),
                      onChanged: (val) {
                        setDialogState(() => tempTemp = val);
                      },
                    ),
                    Text(
                      'Lower values are precise and deterministic; higher values are creative.',
                      style: GoogleFonts.inter(
                        color: _textMuted,
                        fontSize: 10,
                      ),
                    ),
                    Divider(height: 24, color: _textColor.withOpacity(0.05)),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice Autoplay',
                                style: GoogleFonts.inter(
                                  color: _textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Read responses aloud',
                                style: GoogleFonts.inter(
                                  color: _textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: tempAutoplay,
                          activeThumbColor: accent,
                          onChanged: (val) {
                            setDialogState(() => tempAutoplay = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          // Save to provider on dismiss
                          ref.read(auraSettingsProvider.notifier).setTemperature(tempTemp);
                          ref.read(auraSettingsProvider.notifier).setAutoVoiceAutoplay(tempAutoplay);
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          'Done',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWhatsNew() {
    final rawAccent = ref.read(auraSettingsProvider).accentColor;
    final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
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
                      controller: scrollController,
                      children: [
                        _buildTimelineItem(
                          accent: accent,
                          version: "v3.2.0",
                          date: "June 2026",
                          title: "Web Search & Private Compute Integration",
                          description:
                              "Integrated DuckDuckGo web search to retrieve real-time facts, 0G Private Computer engine for secure offline processing, and voice fixes resolving Oppo recording issue.",
                        ),
                        _buildTimelineItem(
                          accent: accent,
                          version: "v3.0.0",
                          date: "June 2026",
                          title: "Multi-Model AI via OpenRouter",
                          description:
                              "Aura now routes through OpenRouter with Nvidia Nemotron 3 Ultra (550B) as the high-intelligence engine, ensuring massive 1M context windows, superior reasoning, and ultra-high reliability.",
                        ),
                        _buildTimelineItem(
                          accent: accent,
                          version: "v2.8.0",
                          date: "June 2026",
                          title: "Persistent Settings & Theme Engine",
                          description:
                              "All settings — theme, language, temperature — now persist across sessions. Choose from 6 stunning accent themes that apply globally across the entire Aura experience.",
                        ),
                        _buildTimelineItem(
                          accent: accent,
                          version: "v2.6.0",
                          date: "May 2026",
                          title: "Live Tool Execution",
                          description:
                              "Aura can now execute real actions: play music on Sonic Drip, send DMs to friends, and list your servers — all from natural language commands in chat.",
                        ),
                        _buildTimelineItem(
                          accent: accent,
                          version: "v2.4.0",
                          date: "May 2026",
                          title: "Server-Side AI Integration",
                          description:
                              "Migrated full backend logic to secure server-side API endpoints. Direct frontend keys have been completely phased out for production-grade safety.",
                        ),
                        _buildTimelineItem(
                          accent: accent,
                          version: "v2.2.0",
                          date: "April 2026",
                          title: "Multimodal Domain Engines",
                          description:
                              "Specialized model routing launched: Text Writer, AI Image Generator, and Code Tutor — each optimized for its domain.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required Color accent,
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
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  version,
                  style: GoogleFonts.inter(
                    color: accent,
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
                  style: GoogleFonts.inter(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFAQ() {
    final rawAccent = ref.read(auraSettingsProvider).accentColor;
    final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Frequently Asked Questions",
                          style: GoogleFonts.inter(
                            color: _textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                      controller: scrollController,
                      children: [
                        _buildFAQItem(
                          accent: accent,
                          question: "What is DuckDuckGo Web Search integration?",
                          answer:
                              "Aura can now search the web using DuckDuckGo to answer questions requiring real-time information or current events.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "How does the 0G Private Computer engine work?",
                          answer:
                              "0G Private Computer provides high-performance, private computing environments where your personal queries are processed securely without third-party exposure.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "Are there fixes for voice recording on certain devices?",
                          answer:
                              "Yes, we have resolved voice recording and audio routing bugs specifically affecting Oppo and other Android devices to ensure crystal-clear conversations.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "What is Aura AI?",
                          answer:
                              "Aura is your personalized AI assistant built inside Flicko. She can write content, generate code, create images, play music, send messages, and engage with you via natural conversations — all powered by cutting-edge AI models.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "Which AI models does Aura use?",
                          answer:
                              "Aura uses OpenRouter powered by Nvidia Nemotron 3 Ultra (550B) with support for multi-model fallback — ensuring state-of-the-art conversational quality with a 1M token memory.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "Is my data secure?",
                          answer:
                              "Absolutely. All API requests are routed through verified backend endpoints using production-grade JWT session authentication. No API keys are ever exposed on the client side.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "How do I use voice commands?",
                          answer:
                              "You can trigger actions by typing natural commands like 'play [song name]', 'message [username]: [text]', or 'list servers' directly in Aura's chat.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "How do I change the theme?",
                          answer:
                              "Go to Settings > Theme and choose from 6 available accent themes. Your selection persists across sessions and applies throughout the entire Aura experience.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "What is the Temperature setting?",
                          answer:
                              "Temperature controls how creative vs. precise Aura's responses are. Low values (0.1) give factual, deterministic answers. High values (1.0) give more creative, varied responses. The default (0.7) is a balanced middle ground.",
                        ),
                        _buildFAQItem(
                          accent: accent,
                          question: "Can I use Aura offline?",
                          answer:
                              "Aura requires an internet connection to communicate with AI models. However, your chat history and settings are stored locally and will be available offline.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFAQItem({
    required Color accent,
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: accent,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (sheetContext, sheetRef, _) {
            final settings = sheetRef.watch(auraSettingsProvider);
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
                    children: auraThemes.map((t) {
                      final isSelected = settings.themeName == t.name;
                      final themeCol = t.color == Colors.transparent
                          ? Theme.of(context).primaryColor
                          : t.color;
                      return InkWell(
                        onTap: () {
                          sheetRef
                              .read(auraSettingsProvider.notifier)
                              .setTheme(t.name, t.color);
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? themeCol.withOpacity(0.1)
                                : _textColor.withOpacity(0.02),
                            border: Border.all(
                              color: isSelected
                                  ? themeCol
                                  : _textColor.withOpacity(0.05),
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
                                  color: themeCol,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: themeCol.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                t.name,
                                style: GoogleFonts.inter(
                                  color: _textColor,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: themeCol,
                                  size: 18,
                                ),
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
      },
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (sheetContext, sheetRef, _) {
            final settings = sheetRef.watch(auraSettingsProvider);
            final rawAccent = settings.accentColor;
            final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;
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
                    children: auraLanguages.map((lang) {
                      final isSelected = settings.language == lang;
                      return InkWell(
                        onTap: () {
                          sheetRef
                              .read(auraSettingsProvider.notifier)
                              .setLanguage(lang);
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.withOpacity(0.1)
                                : _textColor.withOpacity(0.02),
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : _textColor.withOpacity(0.05),
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: accent,
                                  size: 18,
                                ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(auraSettingsProvider);
    final rawAccent = settings.accentColor;
    final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;

    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // Twinkling background
          Positioned.fill(
            child: CustomPaint(
              painter: DeepSpaceBackgroundPainter(
                animationValue: 0.0,
                accentColor: accent,
                isLight: _isLight,
              ),
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
                            'Settings',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Unlimited Card
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_cardBg, Color(0xFF080811)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _glassBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: HoloWavePainter(
                                    animationValue: _waveController.value,
                                    accentColor: accent,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
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
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.35),
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
                  _buildListCardGroup(accent, [
                    _buildSettingsItem(
                      accent: accent,
                      icon: Icons.auto_awesome_outlined,
                      title: "What's New",
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showWhatsNew();
                      },
                    ),
                    _buildSettingsItem(
                      accent: accent,
                      icon: Icons.help_outline_rounded,
                      title: "FAQ",
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showFAQ();
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Settings Group 2
                  _buildListCardGroup(accent, [
                    _buildSettingsItem(
                      accent: accent,
                      icon: Icons.palette_outlined,
                      title: "Theme",
                      trailingText: settings.themeName,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showThemeSelector();
                      },
                    ),
                    _buildSettingsItem(
                      accent: accent,
                      icon: Icons.tune_rounded,
                      title: "Default Chat Settings",
                      trailingText: 'T: ${settings.temperature.toStringAsFixed(1)}',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showChatSettingsDialog(context);
                      },
                    ),
                    _buildSettingsItem(
                      accent: accent,
                      icon: Icons.translate_rounded,
                      title: "Language",
                      trailingText: settings.language,
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
                        'AURA V3.0.0',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Powered by OpenRouter (Nvidia Nemotron 3 Ultra)',
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

  Widget _buildListCardGroup(Color accent, List<Widget> items) {
    List<Widget> childrenWithDividers = [];
    for (int i = 0; i < items.length; i++) {
      childrenWithDividers.add(items[i]);
      if (i < items.length - 1) {
        childrenWithDividers.add(
          Divider(
            height: 1,
            color: _textColor.withOpacity(0.04),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _textColor.withOpacity(0.015),
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
    required Color accent,
    required IconData icon,
    required String title,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                border: Border.all(
                  color: accent.withOpacity(0.15),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: accent.withOpacity(0.8),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (trailingText != null)
              Flexible(
                child: Text(
                  trailingText,
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class HoloWavePainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;

  HoloWavePainter({
    required this.animationValue,
    this.accentColor = const Color(0xFF7B4FFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        accentColor.withOpacity(0.8),
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

    final path1 = Path();
    paint.strokeWidth = 3.5;
    for (double x = 0; x <= size.width; x++) {
      final double env = math.sin((x / size.width) * math.pi);
      final double y =
          size.height * 0.5 + 25.0 * math.sin(phase + (x * 0.02)) * env;
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }
    canvas.drawPath(path1, paint);

    final path2 = Path();
    final paint2 = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    for (double x = 0; x <= size.width; x++) {
      final double env = math.sin((x / size.width) * math.pi);
      final double y =
          size.height * 0.5 + 15.0 * math.sin(-phase + (x * 0.035)) * env;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    canvas.drawPath(path2, paint2..color = paint2.color.withOpacity(0.6));

    final path3 = Path();
    final paint3 = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (double x = 0; x <= size.width; x++) {
      final double env = math.sin((x / size.width) * math.pi);
      final double y =
          size.height * 0.5 + 8.0 * math.sin(phase * 1.5 + (x * 0.05)) * env;
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
      oldDelegate.animationValue != animationValue ||
      oldDelegate.accentColor != accentColor;
}
