import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'dart:developer' as dev;

/// Store theme definition
class StoreTheme {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isGradient;
  final bool hasAnimations;

  const StoreTheme({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    this.isGradient = true,
    this.hasAnimations = true,
  });

  factory StoreTheme.fromJson(Map<String, dynamic> json) {
    return StoreTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? json['id'],
      primaryColor: _parseColor(json['primary_color'] as String?),
      secondaryColor: _parseColor(json['secondary_color'] as String?),
      accentColor: _parseColor(json['accent_color'] as String?),
      backgroundColor: _parseColor(json['background_color'] as String?),
      surfaceColor: _parseColor(json['surface_color'] as String?),
      textPrimary: _parseColor(json['text_primary'] as String?),
      textSecondary: _parseColor(json['text_secondary'] as String?),
      isGradient: json['is_gradient'] as bool? ?? true,
      hasAnimations: json['has_animations'] as bool? ?? true,
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(FlickoColors.brandLime);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(FlickoColors.brandLime);
    }
  }
}

/// Built-in themes for fallback
class BuiltInThemes {
  static const neonPulse = StoreTheme(
    id: 'neon-pulse',
    name: 'Neon Pulse',
    slug: 'neon-pulse',
    primaryColor: Color(0xFF9B84EE),
    secondaryColor: Color(0xFF00E5FF),
    accentColor: Color(0xFF52B788),
    backgroundColor: Color(0xFF050505),
    surfaceColor: Color(0xFF0C0C0E),
    textPrimary: Color(0xFFFBF9FA),
    textSecondary: Color(0xFF71717A),
    isGradient: true,
    hasAnimations: true,
  );

  static const cyberGlow = StoreTheme(
    id: 'cyber-glow',
    name: 'Cyber Glow',
    slug: 'cyber-glow',
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFF9B84EE),
    accentColor: Color(0xFF00CECE),
    backgroundColor: Color(0xFF0A0A0A),
    surfaceColor: Color(0xFF111113),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF6B7280),
    isGradient: true,
    hasAnimations: true,
  );

  static const midnight = StoreTheme(
    id: 'midnight',
    name: 'Midnight',
    slug: 'midnight',
    primaryColor: Color(0xFF9B84EE),
    secondaryColor: Color(0xFF1E1B4B),
    accentColor: Color(0xFF52B788),
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF0A0A0A),
    textPrimary: Color(0xFFFBF9FA),
    textSecondary: Color(0xFF71717A),
    isGradient: false,
    hasAnimations: false,
  );

  static const auroraBorealis = StoreTheme(
    id: 'aurora-borealis',
    name: 'Aurora Borealis',
    slug: 'aurora-borealis',
    primaryColor: Color(0xFF00E676),
    secondaryColor: Color(0xFF00BCD4),
    accentColor: Color(0xFFAB47BC),
    backgroundColor: Color(0xFF050510),
    surfaceColor: Color(0xFF0A0A14),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    isGradient: true,
    hasAnimations: true,
  );

  static const synthwave = StoreTheme(
    id: 'synthwave',
    name: 'Synthwave',
    slug: 'synthwave',
    primaryColor: Color(0xFFFF0080),
    secondaryColor: Color(0xFF00FFFF),
    accentColor: Color(0xFFFFD700),
    backgroundColor: Color(0xFF0D0221),
    surfaceColor: Color(0xFF150431),
    textPrimary: Color(0xFFFFF0F5),
    textSecondary: Color(0xFFE0AADD),
    isGradient: true,
    hasAnimations: true,
  );

  static const fire = StoreTheme(
    id: 'fire',
    name: 'Fire',
    slug: 'fire',
    primaryColor: Color(0xFFF12711),
    secondaryColor: Color(0xFFF5AF19),
    accentColor: Color(0xFFFF6B6B),
    backgroundColor: Color(0xFF1A0A00),
    surfaceColor: Color(0xFF2D1400),
    textPrimary: Color(0xFFFFF8F0),
    textSecondary: Color(0xFFFFB380),
    isGradient: true,
    hasAnimations: true,
  );

  /// Premium Theme: AMOLED-Cord
  /// Ultra-dark AMOLED true-black with soft purple accents
  static const amoledCord = StoreTheme(
    id: 'amoled-cord',
    name: 'AMOLED Cord',
    slug: 'amoled-cord',
    primaryColor: Color(0xFF9B84EE),
    secondaryColor: Color(0xFF7B68C4),
    accentColor: Color(0xFF00E5FF),
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF080808),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8A8A8A),
    isGradient: false,
    hasAnimations: true,
  );

  /// Premium Theme: Dark Discord
  /// Official Discord blurple on ultra-dark base
  static const darkDiscord = StoreTheme(
    id: 'dark-discord',
    name: 'Dark Discord',
    slug: 'dark-discord',
    primaryColor: Color(0xFF5865F2),
    secondaryColor: Color(0xFF4752C4),
    accentColor: Color(0xFF23A55A),
    backgroundColor: Color(0xFF0C0C0C),
    surfaceColor: Color(0xFF141414),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF949BA4),
    isGradient: false,
    hasAnimations: true,
  );

  /// Premium Theme: PM Theme Discord
  /// Warm orange-amber tones on dark brown base
  static const pmTheme = StoreTheme(
    id: 'pm-theme',
    name: 'PM Theme',
    slug: 'pm-theme',
    primaryColor: Color(0xFFE88D48),
    secondaryColor: Color(0xFFD4783A),
    accentColor: Color(0xFFF28C38),
    backgroundColor: Color(0xFF0F0D0C),
    surfaceColor: Color(0xFF1A1715),
    textPrimary: Color(0xFFFFF5EB),
    textSecondary: Color(0xFFB8A68E),
    isGradient: false,
    hasAnimations: true,
  );

  /// Premium Theme: Sonic Drip
  /// Pure black background with lime green accents and brutalist elements
  static const sonicDrip = StoreTheme(
    id: 'sonic-drip',
    name: 'Sonic Drip',
    slug: 'sonic-drip',
    primaryColor: Color(0xFF52B788),
    secondaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFF52B788),
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF0A0A0A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF71717A),
    isGradient: false,
    hasAnimations: true,
  );

  static const all = [
    neonPulse,
    cyberGlow,
    midnight,
    auroraBorealis,
    synthwave,
    fire,
    amoledCord,
    darkDiscord,
    pmTheme,
    sonicDrip,
  ];

  static StoreTheme? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Service for managing store themes
final storeThemeServiceProvider = Provider<StoreThemeService>((ref) {
  return StoreThemeService();
});

/// Provider for the currently active store theme
final activeStoreThemeProvider = NotifierProvider<ActiveThemeNotifier, StoreTheme?>(ActiveThemeNotifier.new);

class ActiveThemeNotifier extends Notifier<StoreTheme?> {
  @override
  StoreTheme? build() {
    _loadTheme();
    return null;
  }

  Future<void> _loadTheme() async {
    // Check for equipped theme first
    final equippedAsync = ref.watch(equippedItemsProvider);
    final equipped = equippedAsync.value;
    if (equipped != null) {
      final themeItem = equipped['theme'] ?? equipped['avatar_decoration'];
      if (themeItem != null) {
        final theme = BuiltInThemes.getById(themeItem.productId);
        if (theme != null) {
          state = theme;
          return;
        }
      }
    }

    // Fall back to saved preference
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString('active_store_theme');
    if (savedThemeId != null) {
      state = BuiltInThemes.getById(savedThemeId);
    }
  }

  Future<void> setTheme(StoreTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_store_theme', theme.id);
  }

  Future<void> clearTheme() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_store_theme');
  }
}

/// Provider that converts a StoreTheme to Flutter ThemeData
final storeThemeDataProvider = Provider<ThemeData?>((ref) {
  final storeTheme = ref.watch(activeStoreThemeProvider);
  if (storeTheme == null) return null;
  return _buildThemeData(storeTheme);
});

ThemeData _buildThemeData(StoreTheme theme) {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: theme.primaryColor,
    scaffoldBackgroundColor: theme.backgroundColor,
    colorScheme: ColorScheme.dark(
      primary: theme.primaryColor,
      secondary: theme.secondaryColor,
      surface: theme.surfaceColor,
      error: const Color(FlickoColors.danger),
      onPrimary: theme.textPrimary,
      onSecondary: theme.textPrimary,
      onSurface: theme.textPrimary,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: theme.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: theme.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: theme.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: theme.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.textPrimary,
      ),
    ),
    cardColor: theme.surfaceColor,
    canvasColor: theme.surfaceColor,
    dividerColor: theme.textSecondary.withValues(alpha: 0.1),
    appBarTheme: AppBarTheme(
      backgroundColor: theme.backgroundColor,
      foregroundColor: theme.textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      iconTheme: IconThemeData(color: theme.primaryColor),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: theme.surfaceColor,
      selectedItemColor: theme.primaryColor,
      unselectedItemColor: theme.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: theme.surfaceColor,
      hintStyle: GoogleFonts.inter(color: theme.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.textSecondary.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.textSecondary.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    ),
    iconTheme: IconThemeData(color: theme.textSecondary),
    splashColor: theme.primaryColor.withAlpha(25),
    highlightColor: theme.primaryColor.withAlpha(15),
  );
}

class StoreThemeService {
  /// Get all available themes (built-in + from Supabase)
  Future<List<StoreTheme>> getAllThemes() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('cosmetic_catalog')
          .select()
          .eq('cosmetic_type', 'theme')
          .eq('is_active', true);

      final dbThemes = (response as List).map((j) => StoreTheme.fromJson(j)).toList();

      // Merge with built-in themes, DB themes take precedence
      final allThemes = <String, StoreTheme>{};
      for (final t in BuiltInThemes.all) {
        allThemes[t.id] = t;
      }
      for (final t in dbThemes) {
        allThemes[t.id] = t;
      }

      return allThemes.values.toList();
    } catch (e) {
      dev.log('[STORE_THEME] Error fetching themes: $e');
      return BuiltInThemes.all;
    }
  }
}
