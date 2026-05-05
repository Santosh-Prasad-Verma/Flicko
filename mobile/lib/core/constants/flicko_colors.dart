/// Flicko color palette constants.
///
/// Mirrors the Discord-like theme system from the React Native app
/// (`constants/Colors.ts`). All values use the same hex codes.
class FlickoColors {
  FlickoColors._();

  // ── Primary Brand ──
  static const int blurple = 0xFF5865F2;
  static const int blurpleLight = 0xFF7289DA;
  static const int pink = 0xFFEB459E;
  static const int green = 0xFF57F287;
  static const int greenDark = 0xFF248046;
  static const int yellow = 0xFFFEE75C;
  static const int red = 0xFFED4245;
  static const int fuchsia = 0xFFF47FFF;
  static const int gold = 0xFFFAA61A;

  // ── Dark Theme Backgrounds ──
  static const int bgPrimary = 0xFF313338;
  static const int bgSecondary = 0xFF2B2D31;
  static const int bgTertiary = 0xFF1E1F22;
  static const int bgFloating = 0xFF232428;

  // ── Dark Theme Text ──
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFB5BAC1;
  static const int textMuted = 0xFF80848E;
  static const int textLink = 0xFF00A8FC;

  // ── Status ──
  static const int statusOnline = 0xFF23A559;
  static const int statusIdle = 0xFFF0B232;
  static const int statusDnd = 0xFFED4245;
  static const int statusOffline = 0xFF80848E;

  // ── Semantic ──
  static const int success = 0xFF57F287;
  static const int warning = 0xFFFEE75C;
  static const int danger = 0xFFED4245;
  static const int info = 0xFF5865F2;
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
