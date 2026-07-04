import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Flicko application theme — Discord-inspired dark-first design.
///
/// Uses [GoogleFonts] for typography (Inter as the closest match
/// to Discord's gg-sans) and the [FlickoColors] palette for all
/// color decisions.
class AppTheme {
  AppTheme._();

  // ──────────────────────────────────────────────────────────
  // Text Theme (shared base, tinted per brightness)
  // ──────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Dark Theme (primary)
  // ──────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    const primary = Color(FlickoColors.brandLime);
    const bgPrimary = Color(FlickoColors.bgPrimary);
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const textPrimary = Color(FlickoColors.textPrimary);
    const textSecondary = Color(FlickoColors.textSecondary);
    const textMuted = Color(FlickoColors.textMuted);
    const onPrimary = Color(FlickoColors.black);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: const Color(FlickoColors.green),
        surface: bgSecondary,
        error: const Color(FlickoColors.danger),
        onPrimary: onPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      textTheme: _buildTextTheme(textPrimary, textSecondary),
      cardColor: bgSecondary,
      canvasColor: bgTertiary,
      dividerColor: bgTertiary,
      appBarTheme: AppBarTheme(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: Color(FlickoColors.brandLime)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgSecondary,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF52B788),
        selectionColor: Color(0x4052B788),
        selectionHandleColor: Color(0xFF52B788),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgTertiary,
        hintStyle: GoogleFonts.inter(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(FlickoColors.border)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(FlickoColors.border)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: Color(0xFF52B788),
            width: 1.4,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      splashColor: primary.withAlpha(25),
      highlightColor: primary.withAlpha(15),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    const primary = Color(FlickoColors.blurple);
    const bgPrimary = Color(0xFFF2F3F5);
    const bgSecondary = Colors.white;
    const bgTertiary = Color(0xFFEBEDF0);
    const textPrimary = Color(0xFF2E3338);
    const textSecondary = Color(0xFF4F5660);
    const textMuted = Color(0xFF747F8D);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: const Color(FlickoColors.pink),
        surface: bgSecondary,
        error: const Color(FlickoColors.danger),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(textPrimary, textSecondary),
      cardColor: bgSecondary,
      canvasColor: bgTertiary,
      dividerColor: bgTertiary,
      appBarTheme: AppBarTheme(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgTertiary,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgTertiary,
        hintStyle: GoogleFonts.inter(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      splashColor: primary.withAlpha(25),
      highlightColor: primary.withAlpha(15),
    );
  }

  // ──────────────────────────────────────────────────────────
  // AMOLED Theme (true black for OLED screens)
  // ──────────────────────────────────────────────────────────

  static ThemeData get amoledTheme {
    final dark = darkTheme;
    return dark.copyWith(
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF0D0D0D),
      canvasColor: Colors.black,
      colorScheme: dark.colorScheme.copyWith(
        surface: const Color(0xFF0D0D0D),
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: dark.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Flicko Plus Theme
  // ──────────────────────────────────────────────────────────

  static ThemeData get plusTheme {
    final dark = darkTheme;
    const plusPrimary = Color(FlickoColors.brandLime);
    const bgPrimary = Color(FlickoColors.bgPrimary);
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const textPrimary = Color(FlickoColors.textPrimary);
    const textSecondary = Color(FlickoColors.textSecondary);

    return dark.copyWith(
      primaryColor: plusPrimary,
      scaffoldBackgroundColor: bgPrimary,
      cardColor: bgSecondary,
      canvasColor: bgTertiary,
      colorScheme: dark.colorScheme.copyWith(
        primary: plusPrimary,
        secondary: plusPrimary,
        surface: bgSecondary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: dark.appBarTheme.copyWith(
        backgroundColor: bgPrimary,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
      ),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(
        backgroundColor: bgPrimary,
        selectedItemColor: plusPrimary,
        unselectedItemColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: plusPrimary,
          foregroundColor: const Color(FlickoColors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(
        fillColor: bgTertiary,
        hintStyle: GoogleFonts.inter(color: textSecondary.withAlpha(128)),
      ),
    );
  }
}
