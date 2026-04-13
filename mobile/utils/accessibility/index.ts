/**
 * Accessibility Utilities
 * 
 * Exports contrast ratio calculation and theme validation utilities
 * for WCAG compliance checking.
 */

export {
  calculateContrastRatio,
  meetsWCAGStandard,
  validateContrast,
  WCAGLevel,
  TextSize,
  type ContrastValidationResult,
} from './contrastRatio';

export {
  validateTheme,
  generateAccessibilityReport,
  formatAccessibilityReport,
  validateCriticalTextContrast,
  type ThemeValidationResult,
  type ColorPairResult,
  type AccessibilityReport,
} from './themeValidator';
