import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'en';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<_Language> _languages = const [
    _Language(code: 'en', name: 'English (US)', subText: 'Default Protocol // Active', abbrev: 'EN'),
    _Language(code: 'ja', name: 'Japanese (日本語)', subText: 'Protocol // JP-19', abbrev: 'JP'),
    _Language(code: 'ko', name: 'Korean (한국어)', subText: 'Protocol // KR-82', abbrev: 'KR'),
    _Language(code: 'fr', name: 'French (Français)', subText: 'Protocol // FR-33', abbrev: 'FR'),
    _Language(code: 'de', name: 'German (Deutsch)', subText: 'Protocol // DE-49', abbrev: 'DE'),
    _Language(code: 'es', name: 'Spanish (Español)', subText: 'Protocol // ES-34', abbrev: 'ES'),
    _Language(code: 'it', name: 'Italian (Italiano)', subText: 'Protocol // IT-39', abbrev: 'IT', isBeta: true),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = _languages.where((lang) {
      final q = _searchQuery.toLowerCase();
      return lang.name.toLowerCase().contains(q) ||
             lang.subText.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(
              color: Color(0xFF0E0E0E),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1F1F1F)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SYS',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF5F5F5F),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'V1.2',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF0E0E0E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Faded Background Watermark at the bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B1B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'FLICKO',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LANGUAGE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                    height: 0.9,
                  ),
                ),
                Text(
                  'REGION',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 42,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5E6164),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SELECT PRIMARY INTERFACE DIALECT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF494C50),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Neo-Brutalist Search Bar
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF050505),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF141517), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.search, color: Color(0xFF4D5156), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Find dialect...',
                            hintStyle: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF373A3F),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF191B1D)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.keyboard, color: Color(0xFF2D3035), size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Available Protocols Header Row
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF141517), thickness: 1.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'AVAILABLE PROTOCOLS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: const Color(0xFF3F4247),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF141517), thickness: 1.5)),
                  ],
                ),
                const SizedBox(height: 24),
                
                // List of languages
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = filteredLanguages[index];
                    final isSelected = _selectedLanguage == lang.code;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedLanguage = lang.code),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFF040405),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF202226) : const Color(0xFF0C0D0E),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Left Edge white thick highlight for Active
                                if (isSelected)
                                  Positioned(
                                    left: 0,
                                    top: 16,
                                    bottom: 16,
                                    child: Container(
                                      width: 4,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(4),
                                          bottomRight: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: Row(
                                    children: [
                                      // Initials bubble
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.white : const Color(0xFF212429),
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          lang.abbrev,
                                          style: GoogleFonts.spaceGrotesk(
                                            color: isSelected ? Colors.black : const Color(0xFF4A4F55),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      
                                      // Language details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              lang.name,
                                              style: GoogleFonts.spaceGrotesk(
                                                color: isSelected ? Colors.white : const Color(0xFF9EA4AB),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  lang.subText,
                                                  style: GoogleFonts.spaceGrotesk(
                                                    color: isSelected ? const Color(0xFF5B6067) : const Color(0xFF323539),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (lang.isBeta) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF151719),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      'BETA',
                                                      style: GoogleFonts.spaceGrotesk(
                                                        color: const Color(0xFF50545A),
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Brutalist Radio Widget
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.white : const Color(0xFF1A1D20),
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: isSelected
                                            ? Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100),
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
  final String subText;
  final String abbrev;
  final bool isBeta;

  const _Language({
    required this.code,
    required this.name,
    required this.subText,
    required this.abbrev,
    this.isBeta = false,
  });
}
