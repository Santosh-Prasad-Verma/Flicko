/**
 * Theme Validation Utility
 * 
 * Validates color palettes for completeness, format correctness, and non-empty values.
 * Used for testing and development to ensure all themes have complete and valid color tokens.
 */

import { colors, ThemeColors, ThemeName } from '@constants/Colors';

/**
 * List of all 38 required color tokens
 */
const REQUIRED_COLOR_TOKENS: (keyof ThemeColors)[] = [
  // Backgrounds
  'bgPrimary',
  'bgSecondary',
  'bgTertiary',
  'bgFloating',
  'inputBg',
  'messageHover',
  'cardBg',
  // Text
  'textPrimary',
  'textSecondary',
  'textMuted',
  'textLink',
  'textPositive',
  'textDanger',
  'textWarning',
  // Interactive
  'interactive',
  'interactiveHover',
  'interactiveActive',
  // Brand
  'accentPrimary',
  'accentSecondary',
  'success',
  'successHover',
  'danger',
  'dangerHover',
  'warning',
  'fuchsia',
  // Status
  'statusOnline',
  'statusIdle',
  'statusDnd',
  'statusOffline',
  'statusStreaming',
  // Specific UI
  'channelIcon',
  'border',
  'divider',
  'mentionBg',
  'mentionText',
  'codeBlockBg',
  'spoilerBg',
  'embedBorder',
  'scrollbarThumb',
  'scrollbarTrack',
  'buttonSecondary',
  'badgeRed',
  'unreadIndicator',
  'overlay',
];

/**
 * Validation result for a single color token
 */
export interface ColorTokenValidation {
  token: string;
  exists: boolean;
  isEmpty: boolean;
  isValidFormat: boolean;
  value?: string;
  error?: string;
}

/**
 * Validation result for an entire theme palette
 */
export interface ThemeValidationResult {
  theme: ThemeName;
  isValid: boolean;
  totalTokens: number;
  validTokens: number;
  missingTokens: string[];
  emptyTokens: string[];
  invalidFormatTokens: string[];
  tokenResults: ColorTokenValidation[];
}

/**
 * Validates if a color value is a valid CSS color string
 * Supports: hex (#RGB, #RRGGBB, #RRGGBBAA), rgb(), rgba(), named colors
 */
export function isValidColorFormat(value: string): boolean {
  if (!value || typeof value !== 'string') {
    return false;
  }

  const trimmed = value.trim();

  // Hex color: #RGB, #RRGGBB, #RRGGBBAA
  const hexPattern = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/;
  if (hexPattern.test(trimmed)) {
    return true;
  }

  // RGB/RGBA: rgb(r, g, b) or rgba(r, g, b, a) with component bounds.
  const rgbMatch = trimmed.match(
    /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$/
  );
  if (rgbMatch) {
    const r = Number(rgbMatch[1]);
    const g = Number(rgbMatch[2]);
    const b = Number(rgbMatch[3]);
    const a = rgbMatch[4] !== undefined ? Number(rgbMatch[4]) : undefined;
    const inByteRange = [r, g, b].every((n) => Number.isInteger(n) && n >= 0 && n <= 255);
    const alphaValid = a === undefined || (!Number.isNaN(a) && a >= 0 && a <= 1);
    return inByteRange && alphaValid;
  }

  // Named colors (basic set - extend if needed)
  const namedColors = [
    'transparent',
    'black',
    'white',
    'red',
    'green',
    'blue',
    'yellow',
    'cyan',
    'magenta',
    'gray',
    'grey',
  ];
  if (namedColors.includes(trimmed.toLowerCase())) {
    return true;
  }

  return false;
}

/**
 * Checks if all 38 required color tokens exist in a palette
 */
export function checkAllTokensExist(palette: ThemeColors): {
  allExist: boolean;
  missingTokens: string[];
} {
  const missingTokens: string[] = [];

  for (const token of REQUIRED_COLOR_TOKENS) {
    if (!(token in palette)) {
      missingTokens.push(token);
    }
  }

  return {
    allExist: missingTokens.length === 0,
    missingTokens,
  };
}

/**
 * Validates that all color values are non-empty strings
 */
export function checkNonEmptyValues(palette: ThemeColors): {
  allNonEmpty: boolean;
  emptyTokens: string[];
} {
  const emptyTokens: string[] = [];

  for (const token of REQUIRED_COLOR_TOKENS) {
    const value = palette[token];
    if (!value || (typeof value === 'string' && value.trim() === '')) {
      emptyTokens.push(token);
    }
  }

  return {
    allNonEmpty: emptyTokens.length === 0,
    emptyTokens,
  };
}

/**
 * Validates that all color values are valid CSS color formats
 */
export function checkValidColorFormats(palette: ThemeColors): {
  allValid: boolean;
  invalidTokens: string[];
} {
  const invalidTokens: string[] = [];

  for (const token of REQUIRED_COLOR_TOKENS) {
    const value = palette[token];
    if (value && !isValidColorFormat(value)) {
      invalidTokens.push(token);
    }
  }

  return {
    allValid: invalidTokens.length === 0,
    invalidTokens,
  };
}

/**
 * Validates a single color token
 */
export function validateColorToken(
  palette: ThemeColors,
  token: keyof ThemeColors
): ColorTokenValidation {
  const exists = token in palette;
  const value = palette[token];
  const isEmpty = !value || (typeof value === 'string' && value.trim() === '');
  const isValidFormat = exists && !isEmpty ? isValidColorFormat(value) : false;

  const result: ColorTokenValidation = {
    token,
    exists,
    isEmpty,
    isValidFormat,
  };

  if (exists) {
    result.value = value;
  }

  if (!exists) {
    result.error = 'Token does not exist in palette';
  } else if (isEmpty) {
    result.error = 'Token value is empty';
  } else if (!isValidFormat) {
    result.error = `Invalid color format: ${value}`;
  }

  return result;
}

/**
 * Validates an entire theme palette
 */
export function validateThemePalette(theme: ThemeName): ThemeValidationResult {
  const palette = colors[theme];
  const tokenResults: ColorTokenValidation[] = [];

  // Validate each token
  for (const token of REQUIRED_COLOR_TOKENS) {
    tokenResults.push(validateColorToken(palette, token));
  }

  // Aggregate results
  const { allExist, missingTokens } = checkAllTokensExist(palette);
  const { allNonEmpty, emptyTokens } = checkNonEmptyValues(palette);
  const { allValid, invalidTokens } = checkValidColorFormats(palette);

  const validTokens = tokenResults.filter(
    (r) => r.exists && !r.isEmpty && r.isValidFormat
  ).length;

  const isValid = allExist && allNonEmpty && allValid;

  return {
    theme,
    isValid,
    totalTokens: REQUIRED_COLOR_TOKENS.length,
    validTokens,
    missingTokens,
    emptyTokens,
    invalidFormatTokens: invalidTokens,
    tokenResults,
  };
}

/**
 * Validates all three theme palettes (light, dark, amoled)
 */
export function validateAllThemes(): Record<ThemeName, ThemeValidationResult> {
  const themes: ThemeName[] = ['light', 'dark', 'amoled'];
  const results: Record<string, ThemeValidationResult> = {};

  for (const theme of themes) {
    results[theme] = validateThemePalette(theme);
  }

  return results as Record<ThemeName, ThemeValidationResult>;
}

/**
 * Prints a validation report to console
 */
export function printValidationReport(
  results: Record<ThemeName, ThemeValidationResult>
): void {
  console.log('\n=== Theme Palette Validation Report ===\n');

  for (const [theme, result] of Object.entries(results)) {
    console.log(`Theme: ${theme.toUpperCase()}`);
    console.log(`Status: ${result.isValid ? '✓ VALID' : '✗ INVALID'}`);
    console.log(`Valid Tokens: ${result.validTokens}/${result.totalTokens}`);

    if (result.missingTokens.length > 0) {
      console.log(`Missing Tokens: ${result.missingTokens.join(', ')}`);
    }

    if (result.emptyTokens.length > 0) {
      console.log(`Empty Tokens: ${result.emptyTokens.join(', ')}`);
    }

    if (result.invalidFormatTokens.length > 0) {
      console.log(
        `Invalid Format Tokens: ${result.invalidFormatTokens.join(', ')}`
      );
    }

    console.log('');
  }
}

/**
 * Runs validation and returns whether all themes are valid
 */
export function runValidation(): boolean {
  const results = validateAllThemes();
  printValidationReport(results);

  return Object.values(results).every((r) => r.isValid);
}
