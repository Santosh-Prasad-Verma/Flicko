# Styling Guide
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Theme System
File: `mobile/constants/Colors.ts`

Flicko uses a Discord-inspired dark theme with custom color tokens.

### Color Tokens
```typescript
const colors = {
  dark: {
    bgPrimary: '#1e1f22',     // Main background
    bgSecondary: '#2b2d31',   // Card/panel background
    bgTertiary: '#313338',    // Input/tertiary background
    textPrimary: '#f2f3f5',   // Primary text
    textSecondary: '#b5bac1', // Secondary text
    accentPrimary: '#5865f2', // Blurple (brand color)
    divider: '#3f4147',       // Dividers and borders
  }
};
```

### Typography
Custom fonts loaded in `mobile/app/_layout.tsx`:
- `gg-sans` — Regular (Discord's font family)
- `gg-sans-medium` — Medium weight
- `gg-sans-semibold` — Semi-bold
- `gg-sans-bold` — Bold
- `Pacifico_400Regular` — Decorative (logo)

### Theme Hook
File: `mobile/hooks/useTheme.ts`
```typescript
const { themeColors, isDark } = useTheme();
```

## Styling Approach
- Flutter `StyleSheet.create()` for static styles
- Inline styles for dynamic theme-aware styling
- No external CSS framework (pure Flutter)
