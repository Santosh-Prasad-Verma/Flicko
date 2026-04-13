/**
 * Theme Accessibility Validator
 * 
 * Validates that all theme color combinations meet WCAG accessibility standards.
 * Generates comprehensive accessibility reports for light, dark, and amoled themes.
 */

import { colors, ThemeName, ThemeColors } from '../../constants/Colors';
import {
  validateContrast,
  ContrastValidationResult,
  TextSize,
  WCAGLevel,
} from './contrastRatio';

/**
 * Color pair to validate
 */
interface ColorPair {
  name: string;
  foreground: keyof ThemeColors;
  background: keyof ThemeColors;
  textSize: TextSize;
  description: string;
}

/**
 * Critical color pairs that must meet WCAG AA standards
 * These are the most important text/background combinations in the app
 */
const CRITICAL_COLOR_PAIRS: ColorPair[] = [
  {
    name: 'Primary Text on Primary Background',
    foreground: 'textPrimary',
    background: 'bgPrimary',
    textSize: TextSize.Normal,
    description: 'Main chat messages and content',
  },
  {
    name: 'Secondary Text on Primary Background',
    foreground: 'textSecondary',
    background: 'bgPrimary',
    textSize: TextSize.Normal,
    description: 'Subtitles and descriptions',
  },
  {
    name: 'Muted Text on Primary Background',
    foreground: 'textMuted',
    background: 'bgPrimary',
    textSize: TextSize.Normal,
    description: 'Timestamps and placeholders',
  },
  {
    name: 'Primary Text on Secondary Background',
    foreground: 'textPrimary',
    background: 'bgSecondary',
    textSize: TextSize.Normal,
    description: 'Sidebar content',
  },
  {
    name: 'Primary Text on Tertiary Background',
    foreground: 'textPrimary',
    background: 'bgTertiary',
    textSize: TextSize.Normal,
    description: 'Server list and title bar',
  },
  {
    name: 'Primary Text on Card Background',
    foreground: 'textPrimary',
    background: 'cardBg',
    textSize: TextSize.Normal,
    description: 'Card components',
  },
  {
    name: 'Interactive Text on Primary Background',
    foreground: 'interactive',
    background: 'bgPrimary',
    textSize: TextSize.Normal,
    description: 'Default interactive elements',
  },
  {
    name: 'Channel Icon on Tertiary Background',
    foreground: 'channelIcon',
    background: 'bgTertiary',
    textSize: TextSize.Large,
    description: 'Channel icons in sidebar',
  },
];

/**
 * Result for a single theme validation
 */
export interface ThemeValidationResult {
  themeName: ThemeName;
  totalChecks: number;
  passedAA: number;
  passedAAA: number;
  failedAA: ColorPairResult[];
  allResults: ColorPairResult[];
}

/**
 * Result for a single color pair check
 */
export interface ColorPairResult {
  pair: ColorPair;
  validation: ContrastValidationResult;
}

/**
 * Complete accessibility report for all themes
 */
export interface AccessibilityReport {
  generatedAt: string;
  themes: ThemeValidationResult[];
  summary: {
    totalThemes: number;
    allThemesPassAA: boolean;
    themesPassingAA: string[];
    themesFailingAA: string[];
  };
}

/**
 * Validates a single theme's color combinations
 * @param themeName - Name of the theme to validate
 * @returns Validation result for the theme
 */
export function validateTheme(themeName: ThemeName): ThemeValidationResult {
  const theme = colors[themeName];
  const allResults: ColorPairResult[] = [];
  const failedAA: ColorPairResult[] = [];
  let passedAA = 0;
  let passedAAA = 0;

  for (const pair of CRITICAL_COLOR_PAIRS) {
    const foregroundColor = theme[pair.foreground];
    const backgroundColor = theme[pair.background];

    const validation = validateContrast(
      foregroundColor,
      backgroundColor,
      pair.textSize
    );

    const result: ColorPairResult = { pair, validation };
    allResults.push(result);

    if (validation.meetsAA) {
      passedAA++;
    } else {
      failedAA.push(result);
    }

    if (validation.meetsAAA) {
      passedAAA++;
    }
  }

  return {
    themeName,
    totalChecks: CRITICAL_COLOR_PAIRS.length,
    passedAA,
    passedAAA,
    failedAA,
    allResults,
  };
}

/**
 * Validates all themes and generates a comprehensive accessibility report
 * @returns Complete accessibility report
 */
export function generateAccessibilityReport(): AccessibilityReport {
  const themeNames: ThemeName[] = ['light', 'dark', 'amoled'];
  const themes = themeNames.map((name) => validateTheme(name));

  const themesPassingAA = themes
    .filter((t) => t.failedAA.length === 0)
    .map((t) => t.themeName);

  const themesFailingAA = themes
    .filter((t) => t.failedAA.length > 0)
    .map((t) => t.themeName);

  return {
    generatedAt: new Date().toISOString(),
    themes,
    summary: {
      totalThemes: themes.length,
      allThemesPassAA: themesFailingAA.length === 0,
      themesPassingAA,
      themesFailingAA,
    },
  };
}

/**
 * Formats the accessibility report as a human-readable string
 * @param report - Accessibility report to format
 * @returns Formatted report string
 */
export function formatAccessibilityReport(report: AccessibilityReport): string {
  let output = '═══════════════════════════════════════════════════════\n';
  output += '  WCAG ACCESSIBILITY REPORT - THEME VALIDATION\n';
  output += '═══════════════════════════════════════════════════════\n\n';
  output += `Generated: ${new Date(report.generatedAt).toLocaleString()}\n\n`;

  // Summary
  output += '─────────────────────────────────────────────────────\n';
  output += 'SUMMARY\n';
  output += '─────────────────────────────────────────────────────\n';
  output += `Total Themes Tested: ${report.summary.totalThemes}\n`;
  output += `All Themes Pass WCAG AA: ${report.summary.allThemesPassAA ? '✓ YES' : '✗ NO'}\n`;
  output += `Themes Passing AA: ${report.summary.themesPassingAA.join(', ') || 'None'}\n`;
  output += `Themes Failing AA: ${report.summary.themesFailingAA.join(', ') || 'None'}\n\n`;

  // Individual theme results
  for (const theme of report.themes) {
    output += '═════════════════════════════════════════════════════\n';
    output += `THEME: ${theme.themeName.toUpperCase()}\n`;
    output += '═════════════════════════════════════════════════════\n';
    output += `Total Checks: ${theme.totalChecks}\n`;
    output += `Passed WCAG AA: ${theme.passedAA}/${theme.totalChecks} (${((theme.passedAA / theme.totalChecks) * 100).toFixed(1)}%)\n`;
    output += `Passed WCAG AAA: ${theme.passedAAA}/${theme.totalChecks} (${((theme.passedAAA / theme.totalChecks) * 100).toFixed(1)}%)\n\n`;

    if (theme.failedAA.length > 0) {
      output += '⚠️  FAILED CHECKS (WCAG AA):\n';
      output += '─────────────────────────────────────────────────────\n';
      for (const failed of theme.failedAA) {
        const { pair, validation } = failed;
        output += `\n❌ ${pair.name}\n`;
        output += `   Description: ${pair.description}\n`;
        output += `   Foreground: ${validation.foreground} (${String(pair.foreground)})\n`;
        output += `   Background: ${validation.background} (${String(pair.background)})\n`;
        output += `   Contrast Ratio: ${validation.ratio?.toFixed(2) || 'N/A'}:1\n`;
        output += `   Required (AA): ${pair.textSize === TextSize.Large ? '3.0' : '4.5'}:1\n`;
        output += `   Status: FAIL\n`;
      }
      output += '\n';
    }

    output += 'DETAILED RESULTS:\n';
    output += '─────────────────────────────────────────────────────\n';
    for (const result of theme.allResults) {
      const { pair, validation } = result;
      const status = validation.meetsAA ? '✓' : '✗';
      const aaaStatus = validation.meetsAAA ? ' (AAA ✓)' : '';
      output += `${status} ${pair.name}: ${validation.ratio?.toFixed(2) || 'N/A'}:1${aaaStatus}\n`;
    }
    output += '\n';
  }

  output += '═══════════════════════════════════════════════════════\n';
  output += 'WCAG STANDARDS REFERENCE\n';
  output += '═══════════════════════════════════════════════════════\n';
  output += 'WCAG AA (Minimum):\n';
  output += '  • Normal text: 4.5:1 contrast ratio\n';
  output += '  • Large text: 3.0:1 contrast ratio\n\n';
  output += 'WCAG AAA (Enhanced):\n';
  output += '  • Normal text: 7.0:1 contrast ratio\n';
  output += '  • Large text: 4.5:1 contrast ratio\n';
  output += '═══════════════════════════════════════════════════════\n';

  return output;
}

/**
 * Validates specific color pairs for all themes
 * Convenience function for quick validation of textPrimary and textSecondary
 * @returns Object with validation results for each theme
 */
export function validateCriticalTextContrast() {
  const results: Record<ThemeName, {
    textPrimaryOnBgPrimary: ContrastValidationResult;
    textSecondaryOnBgPrimary: ContrastValidationResult;
  }> = {
    light: {
      textPrimaryOnBgPrimary: validateContrast(
        colors.light.textPrimary,
        colors.light.bgPrimary,
        TextSize.Normal
      ),
      textSecondaryOnBgPrimary: validateContrast(
        colors.light.textSecondary,
        colors.light.bgPrimary,
        TextSize.Normal
      ),
    },
    dark: {
      textPrimaryOnBgPrimary: validateContrast(
        colors.dark.textPrimary,
        colors.dark.bgPrimary,
        TextSize.Normal
      ),
      textSecondaryOnBgPrimary: validateContrast(
        colors.dark.textSecondary,
        colors.dark.bgPrimary,
        TextSize.Normal
      ),
    },
    amoled: {
      textPrimaryOnBgPrimary: validateContrast(
        colors.amoled.textPrimary,
        colors.amoled.bgPrimary,
        TextSize.Normal
      ),
      textSecondaryOnBgPrimary: validateContrast(
        colors.amoled.textSecondary,
        colors.amoled.bgPrimary,
        TextSize.Normal
      ),
    },
  };

  return results;
}
