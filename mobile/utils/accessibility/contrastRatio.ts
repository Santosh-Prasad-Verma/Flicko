/**
 * WCAG Contrast Ratio Validation Utility
 * 
 * Calculates and validates color contrast ratios according to WCAG 2.1 standards.
 * 
 * WCAG AA Requirements:
 * - Normal text (< 18pt or < 14pt bold): 4.5:1 minimum
 * - Large text (≥ 18pt or ≥ 14pt bold): 3:1 minimum
 * 
 * WCAG AAA Requirements:
 * - Normal text: 7:1 minimum
 * - Large text: 4.5:1 minimum
 */

/**
 * Converts a hex color to RGB values
 * @param hex - Hex color string (e.g., '#FFFFFF', '#FFF', 'FFFFFF')
 * @returns RGB object with r, g, b values (0-255)
 */
function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  // Remove # if present
  const cleanHex = hex.replace('#', '');
  
  // Handle 3-digit hex
  if (cleanHex.length === 3) {
    const r = parseInt(cleanHex[0] + cleanHex[0], 16);
    const g = parseInt(cleanHex[1] + cleanHex[1], 16);
    const b = parseInt(cleanHex[2] + cleanHex[2], 16);
    return { r, g, b };
  }
  
  // Handle 6-digit hex
  if (cleanHex.length === 6) {
    const r = parseInt(cleanHex.substring(0, 2), 16);
    const g = parseInt(cleanHex.substring(2, 4), 16);
    const b = parseInt(cleanHex.substring(4, 6), 16);
    return { r, g, b };
  }
  
  return null;
}

/**
 * Parses rgba() color string to RGB values
 * @param rgba - RGBA color string (e.g., 'rgba(88, 101, 242, 0.3)')
 * @returns RGB object with r, g, b values (0-255), ignoring alpha
 */
function rgbaToRgb(rgba: string): { r: number; g: number; b: number } | null {
  const match = rgba.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*[\d.]+)?\)/);
  if (!match) return null;
  
  return {
    r: parseInt(match[1], 10),
    g: parseInt(match[2], 10),
    b: parseInt(match[3], 10),
  };
}

/**
 * Converts RGB color to relative luminance
 * Formula from WCAG 2.1: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
 * @param r - Red value (0-255)
 * @param g - Green value (0-255)
 * @param b - Blue value (0-255)
 * @returns Relative luminance (0-1)
 */
function getLuminance(r: number, g: number, b: number): number {
  // Convert to 0-1 range
  const [rs, gs, bs] = [r, g, b].map((val) => {
    const sRGB = val / 255;
    // Apply gamma correction
    return sRGB <= 0.03928 ? sRGB / 12.92 : Math.pow((sRGB + 0.055) / 1.055, 2.4);
  });
  
  // Calculate relative luminance
  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
}

/**
 * Calculates the contrast ratio between two colors
 * Formula from WCAG 2.1: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
 * @param color1 - First color (hex or rgba string)
 * @param color2 - Second color (hex or rgba string)
 * @returns Contrast ratio (1-21) or null if colors are invalid
 */
export function calculateContrastRatio(color1: string, color2: string): number | null {
  // Parse colors
  let rgb1 = hexToRgb(color1);
  if (!rgb1) rgb1 = rgbaToRgb(color1);
  
  let rgb2 = hexToRgb(color2);
  if (!rgb2) rgb2 = rgbaToRgb(color2);
  
  if (!rgb1 || !rgb2) {
    console.warn(`Invalid color format: ${color1} or ${color2}`);
    return null;
  }
  
  // Calculate luminance for both colors
  const lum1 = getLuminance(rgb1.r, rgb1.g, rgb1.b);
  const lum2 = getLuminance(rgb2.r, rgb2.g, rgb2.b);
  
  // Calculate contrast ratio (lighter / darker)
  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);
  
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * WCAG compliance levels
 */
export enum WCAGLevel {
  AA = 'AA',
  AAA = 'AAA',
}

/**
 * Text size categories for WCAG
 */
export enum TextSize {
  Normal = 'normal',
  Large = 'large',
}

/**
 * Checks if a contrast ratio meets WCAG standards
 * @param ratio - Contrast ratio to check
 * @param level - WCAG level (AA or AAA)
 * @param textSize - Text size category (normal or large)
 * @returns true if the ratio meets the standard
 */
export function meetsWCAGStandard(
  ratio: number,
  level: WCAGLevel = WCAGLevel.AA,
  textSize: TextSize = TextSize.Normal
): boolean {
  if (level === WCAGLevel.AAA) {
    return textSize === TextSize.Large ? ratio >= 4.5 : ratio >= 7;
  }
  // AA level
  return textSize === TextSize.Large ? ratio >= 3 : ratio >= 4.5;
}

/**
 * Result of a contrast validation check
 */
export interface ContrastValidationResult {
  foreground: string;
  background: string;
  ratio: number | null;
  meetsAA: boolean;
  meetsAAA: boolean;
  textSize: TextSize;
}

/**
 * Validates contrast ratio between foreground and background colors
 * @param foreground - Foreground color (text)
 * @param background - Background color
 * @param textSize - Text size category
 * @returns Validation result with ratio and compliance status
 */
export function validateContrast(
  foreground: string,
  background: string,
  textSize: TextSize = TextSize.Normal
): ContrastValidationResult {
  const ratio = calculateContrastRatio(foreground, background);
  
  return {
    foreground,
    background,
    ratio,
    meetsAA: ratio !== null && meetsWCAGStandard(ratio, WCAGLevel.AA, textSize),
    meetsAAA: ratio !== null && meetsWCAGStandard(ratio, WCAGLevel.AAA, textSize),
    textSize,
  };
}
