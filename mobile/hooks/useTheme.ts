/**
 * useTheme Hook
 *
 * Provides current theme colors based on user preference or system theme.
 * Integrates with Zustand settings store.
 *
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.5, 7.2, 9.1, 9.2, 13.1, 13.2
 */
import { useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { colors, type ThemeName, type ThemeColors } from '../constants/Colors';
import { useSettingsStore } from '@stores/settingsStore';

/**
 * Return type for useTheme hook
 */
export interface UseThemeReturn {
  theme: ThemeName;
  themeColors: ThemeColors;
  isDark: boolean;
  isLight: boolean;
  isAmoled: boolean;
}

/**
 * Returns the current theme colors based on user preference.
 * Reads from settings store; falls back to system scheme when set to 'auto'.
 * 
 * @param override - Optional theme override for testing/preview purposes
 * @returns Object containing resolved theme, colors, and boolean flags
 */
export function useTheme(override?: ThemeName): UseThemeReturn {
  const systemScheme = useColorScheme();
  const storedTheme = useSettingsStore((s) => s.theme);

  // Memoize theme resolution
  const resolved = useMemo(() => {
    if (override) return override;
    if (storedTheme === 'auto') {
      return systemScheme === 'light' ? 'light' : 'dark';
    }
    return storedTheme;
  }, [override, storedTheme, systemScheme]);

  // Memoize theme colors to prevent unnecessary re-renders
  const themeColors = useMemo(() => colors[resolved], [resolved]);

  return {
    theme: resolved,
    themeColors,
    isDark: resolved === 'dark',
    isLight: resolved === 'light',
    isAmoled: resolved === 'amoled',
  };
}
