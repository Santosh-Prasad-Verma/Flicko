import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'en';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color _limeColor = const Color(0xFFC8FF00);

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          backgroundColor: _limeColor,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Text(
                'Language updated to ${_languages.firstWhere((l) => l.code == languageCode).name}',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  final List<_Language> _languages = const [
    _Language(code: 'en', name: 'English (US)', native: 'English', prefix: 'EN'),
    _Language(code: 'ja', name: 'Japanese (日本語)', native: '日本語', prefix: 'JP'),
    _Language(code: 'ko', name: 'Korean (한국어)', native: '한국어', prefix: 'KR'),
    _Language(code: 'fr', name: 'French (Français)', native: 'Français', prefix: 'FR'),
    _Language(code: 'de', name: 'German (Deutsch)', native: 'Deutsch', prefix: 'DE'),
    _Language(code: 'es', name: 'Spanish (Español)', native: 'Español', prefix: 'ES'),
    _Language(code: 'it', name: 'Italian (Italiano)', native: 'Italiano', prefix: 'IT'),
    _Language(code: 'zh', name: 'Chinese (中文)', native: '中文', prefix: 'ZH'),
    _Language(code: 'pt', name: 'Portuguese (Português)', native: 'Português', prefix: 'PT'),
    _Language(code: 'ru', name: 'Russian (Русский)', native: 'Русский', prefix: 'RU'),
    _Language(code: 'hi', name: 'Hindi (हिन्दी)', native: 'हिन्दी', prefix: 'HI'),
  ];

  List<_Language> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _languages;
    return _languages.where((l) {
      return l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.native.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: _limeColor, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: _limeColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'LANGUAGE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search for a language...',
                  hintStyle: GoogleFonts.inter(
                      color: Colors.white24,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: _limeColor, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredLanguages.length,
              itemBuilder: (context, index) {
                final lang = _filteredLanguages[index];
                final isSelected = _selectedLanguage == lang.code;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _saveLanguage(lang.code),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _limeColor
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _limeColor.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _limeColor.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isSelected
                                      ? _limeColor.withValues(alpha: 0.2)
                                      : Colors.transparent),
                            ),
                            child: Center(
                              child: Text(
                                lang.prefix,
                                style: GoogleFonts.inter(
                                  color: isSelected ? _limeColor : Colors.white24,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.name,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                if (lang.native != lang.name) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    lang.native,
                                    style: GoogleFonts.inter(
                                      color: Colors.white24,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _limeColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _limeColor.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.black, size: 14),
                            )
                          else
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/Flicko-for-black-background.png',
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.1),
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                const SizedBox(height: 40),
              ],
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
  final String prefix;

  const _Language({
    required this.code,
    required this.name,
    required this.native,
    required this.prefix,
  });
}
