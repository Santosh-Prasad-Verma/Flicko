/// Flicko color palette constants.
///
/// Neon Lime & Pitch Black theme system.
/// Primary accent: #52B788 (Neon Lime)
/// Background: Pure black / near-black
class FlickoColors {
  FlickoColors._();

  // ── Primary Brand ──
  static const int brandLime = 0xFF52B788; // Soft emerald/sage green — primary accent
  static const int brandLimeDim = 0xFF40916C; // Dimmed soft green for subtle accents
  static const int emeraldGreen = 0xFF10B981; // Emerald Green — used in activity/notifications and softer message screens

  // Legacy aliases → mapped to soft green for backward compat
  static const int blurple = brandLime;
  static const int blurpleLight = brandLimeDim;
  static const int black = 0xFF000000;
  static const int green = 0xFF52B788;
  static const int greenDark = 0xFF2D6A4F;
  static const int neonGreen = 0xFF52B788;
  static const int yellow = 0xFFFEE75C;
  static const int red = 0xFFED4245;
  static const int fuchsia = 0xFFF47FFF;
  static const int gold = 0xFFFAA61A;
  static const int pink = 0xFFEB459E;

  // ── Background ──
  static const int bgPrimary = 0xFF050505; // Near-pure black
  static const int bgSecondary = 0xFF0F0F0F; // Slightly lighter
  static const int bgTertiary = 0xFF1A1A1A; // Card / elevated surface
  static const int bgFloating = 0xFF0A0A0A; // Floating panels

  // ── Dark Theme Text ──
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFB0B0B0;
  static const int textMuted = 0xFF666666;
  static const int textLink = brandLime;

  // ── Status ──
  static const int statusOnline = 0xFF22C55E;
  static const int statusIdle = 0xFFF0B232;
  static const int statusDnd = 0xFFED4245;
  static const int statusOffline = 0xFF555555;

  // ── Semantic ──
  static const int success = 0xFF22C55E;
  static const int warning = 0xFFFEE75C;
  static const int danger = 0xFFED4245;
  static const int info = brandLime;

  // ── Accent / Aliases ──
  static const int accentPrimary = brandLime;
  static const int accentSecondary = brandLimeDim;
  static const int textDanger = danger;

  // ── Border ──
  static const int border = 0xFF222222;
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
