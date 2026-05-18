/// Flicko color palette constants.
///
/// Mirrors the Discord-like theme system from the React Native app
/// (`constants/Colors.ts`). All values use the same hex codes.
class FlickoColors {
  FlickoColors._();

  // ── Primary Brand ──
  static const int blurple = 0xFF8B5CF6; // Rebranded to Purple
  static const int blurpleLight = 0xFFA78BFA; // Rebranded to light violet
  static const int pink = 0xFFEB459E;
  static const int green = 0xFF57F287;
  static const int greenDark = 0xFF248046;
  static const int neonGreen = 0xFFC8FF00;
  static const int yellow = 0xFFFEE75C;
  static const int red = 0xFFED4245;
  static const int fuchsia = 0xFFF47FFF;
  static const int gold = 0xFFFAA61A;

  static const int brandLime = 0xFF8B5CF6; // Rebranded to Purple
  static const int black = 0xFF000000;
  static const int bgPrimary = 0xFF0D0B14; // Rebranded Background
  static const int bgSecondary = 0xFF141124;
  static const int bgTertiary = 0xFF1A1730;
  static const int bgFloating = 0xFF0D0B14;

  // ── Dark Theme Text ──
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFC4B5FD; // Rebranded to light violet
  static const int textMuted = 0xFF7A7593;
  static const int textLink = 0xFFC4B5FD;

  // ── Status ──
  static const int statusOnline = 0xFF22C55E; // Green for online
  static const int statusIdle = 0xFFF0B232;
  static const int statusDnd = 0xFFED4245;
  static const int statusOffline = 0xFF80848E;

  // ── Semantic ──
  static const int success = 0xFF22C55E; // Green for success
  static const int warning = 0xFFFEE75C;
  static const int danger = 0xFFED4245;
  static const int info = 0xFF8B5CF6;

  // ── Accent / Aliases ──
  static const int accentPrimary = brandLime;
  static const int accentSecondary = 0xFFA78BFA; // Rebranded to light violet
  static const int textDanger = danger;

  // ── Border ──
  static const int border = 0xFF2A2540; // Rebranded border
}

/// Standard spacing values used throughout the app.
class FlickoSpacing {
  FlickoSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Standard border radius values.
class FlickoRadius {
  FlickoRadius._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double round = 999.0;
}
