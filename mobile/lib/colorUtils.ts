/**
 * Color Utilities
 *
 * Pure JS helpers for extracting, manipulating, and generating
 * color palettes from hex colors. Used by dynamic profile theming.
 */

/** Parse a hex color into [r, g, b] (supports #RGB and #RRGGBB) */
export function hexToRgb(hex: string): [number, number, number] {
  let h = hex.replace('#', '');
  if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** Convert [r, g, b] to hex string */
export function rgbToHex(r: number, g: number, b: number): string {
  return (
    '#' +
    [r, g, b]
      .map((c) => Math.max(0, Math.min(255, Math.round(c))).toString(16).padStart(2, '0'))
      .join('')
  );
}

/** Convert [r, g, b] (0-255) to [h, s, l] (h: 0-360, s/l: 0-100) */
export function rgbToHsl(r: number, g: number, b: number): [number, number, number] {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r:
        h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        break;
      case g:
        h = ((b - r) / d + 2) / 6;
        break;
      case b:
        h = ((r - g) / d + 4) / 6;
        break;
    }
  }
  return [Math.round(h * 360), Math.round(s * 100), Math.round(l * 100)];
}

/** Convert [h, s, l] to [r, g, b] */
export function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  h /= 360;
  s /= 100;
  l /= 100;

  if (s === 0) {
    const v = Math.round(l * 255);
    return [v, v, v];
  }

  const hue2rgb = (p: number, q: number, t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };

  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;

  return [
    Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
    Math.round(hue2rgb(p, q, h) * 255),
    Math.round(hue2rgb(p, q, h - 1 / 3) * 255),
  ];
}

/** Lighten a hex color by a percentage (0-100) */
export function lighten(hex: string, amount: number): string {
  const [r, g, b] = hexToRgb(hex);
  const [h, s, l] = rgbToHsl(r, g, b);
  const [nr, ng, nb] = hslToRgb(h, s, Math.min(100, l + amount));
  return rgbToHex(nr, ng, nb);
}

/** Darken a hex color by a percentage (0-100) */
export function darken(hex: string, amount: number): string {
  const [r, g, b] = hexToRgb(hex);
  const [h, s, l] = rgbToHsl(r, g, b);
  const [nr, ng, nb] = hslToRgb(h, s, Math.max(0, l - amount));
  return rgbToHex(nr, ng, nb);
}

/** Set the opacity of a hex color → "rgba(...)" string */
export function withOpacity(hex: string, opacity: number): string {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}

/** Compute relative luminance (0–1) of a hex color */
export function luminance(hex: string): number {
  const [r, g, b] = hexToRgb(hex);
  const toLinear = (c: number) => {
    c /= 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

/** Returns true if the color is "dark" (use white text on it) */
export function isDark(hex: string): boolean {
  return luminance(hex) < 0.35;
}

/**
 * Generate a full dynamic profile palette from a single accent color.
 * Designed for dark theme backgrounds.
 */
export interface ProfilePalette {
  /** The original accent color */
  accent: string;
  /** Very dark version for card backgrounds (blended with dark bg) */
  cardBg: string;
  /** Slightly lighter card surface */
  cardSurface: string;
  /** Subtle tint for section headers */
  sectionBg: string;
  /** Border color with accent tint */
  border: string;
  /** Muted accent for secondary text / icons */
  accentMuted: string;
  /** Bright accent for buttons / highlights */
  accentBright: string;
  /** Text color that contrasts well on `accent` */
  accentText: string;
  /** Very subtle banner overlay gradient color */
  bannerOverlay: string;
}

export function generateProfilePalette(accentHex: string): ProfilePalette {
  const accent = accentHex || '#5865F2';
  const dark = isDark(accent);

  return {
    accent,
    cardBg: withOpacity(accent, 0.18),
    cardSurface: withOpacity(accent, 0.24),
    sectionBg: withOpacity(accent, 0.14),
    border: withOpacity(accent, 0.30),
    accentMuted: withOpacity(accent, 0.65),
    accentBright: dark ? lighten(accent, 20) : accent,
    accentText: dark ? '#FFFFFF' : '#000000',
    bannerOverlay: withOpacity(darken(accent, 15), 0.45),
  };
}
