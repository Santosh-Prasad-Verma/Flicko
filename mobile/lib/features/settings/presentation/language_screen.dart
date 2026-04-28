import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Language Settings Screen
///
/// Language selection with native names.
/// Route: /u/settings/language
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'en';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en';
      _isLoading = false;
    });
  }

  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    setState(() => _selectedLanguage = languageCode);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language changed to ${_languages.firstWhere((l) => l.code == languageCode).name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  final List<_Language> _languages = const [
    _Language(code: 'en', name: 'English', native: 'English'),
    _Language(code: 'es', name: 'Spanish', native: 'Español'),
    _Language(code: 'fr', name: 'French', native: 'Français'),
    _Language(code: 'de', name: 'German', native: 'Deutsch'),
    _Language(code: 'ja', name: 'Japanese', native: '日本語'),
    _Language(code: 'ko', name: 'Korean', native: '한국어'),
    _Language(code: 'zh', name: 'Chinese', native: '中文'),
    _Language(code: 'pt', name: 'Portuguese', native: 'Português'),
    _Language(code: 'ru', name: 'Russian', native: 'Русский'),
    _Language(code: 'ar', name: 'Arabic', native: 'العربية'),
    _Language(code: 'hi', name: 'Hindi', native: 'हिन्दी'),
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
          'Language',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'SELECT LANGUAGE',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _languages.asMap().entries.map((entry) {
                final index = entry.key;
                final lang = entry.value;
                final isSelected = _selectedLanguage == lang.code;
                final isLast = index == _languages.length - 1;
                return InkWell(
                  onTap: () => _saveLanguage(lang.code),
                  borderRadius: isLast ? BorderRadius.circular(12) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : const Border(
                        bottom: BorderSide(color: Color(0xFF232428)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.name,
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textPrimary),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                lang.native,
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textMuted),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 22, color: Color(FlickoColors.blurple)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Language {
  final String code;
  final String name;
  final String native;

  const _Language({
    required this.code,
    required this.name,
    required this.native,
  });
}
