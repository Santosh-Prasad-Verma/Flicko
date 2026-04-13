/**
 * Tests for theme validation utility
 */

import {
  isValidColorFormat,
  checkAllTokensExist,
  checkNonEmptyValues,
  checkValidColorFormats,
  validateColorToken,
  validateThemePalette,
  validateAllThemes,
} from '../themeValidation';
import { colors } from '@constants/Colors';

describe('themeValidation', () => {
  describe('isValidColorFormat', () => {
    it('should validate hex colors', () => {
      expect(isValidColorFormat('#FFF')).toBe(true);
      expect(isValidColorFormat('#FFFFFF')).toBe(true);
      expect(isValidColorFormat('#FFFFFFFF')).toBe(true);
      expect(isValidColorFormat('#36393F')).toBe(true);
    });

    it('should validate rgb/rgba colors', () => {
      expect(isValidColorFormat('rgb(255, 255, 255)')).toBe(true);
      expect(isValidColorFormat('rgba(0, 0, 0, 0.75)')).toBe(true);
      expect(isValidColorFormat('rgba(88, 101, 242, 0.3)')).toBe(true);
    });

    it('should validate named colors', () => {
      expect(isValidColorFormat('transparent')).toBe(true);
      expect(isValidColorFormat('black')).toBe(true);
      expect(isValidColorFormat('white')).toBe(true);
    });

    it('should reject invalid formats', () => {
      expect(isValidColorFormat('')).toBe(false);
      expect(isValidColorFormat('invalid')).toBe(false);
      expect(isValidColorFormat('#GGG')).toBe(false);
      expect(isValidColorFormat('rgb(300, 300, 300)')).toBe(false);
    });

    it('should reject non-string values', () => {
      expect(isValidColorFormat(null as any)).toBe(false);
      expect(isValidColorFormat(undefined as any)).toBe(false);
      expect(isValidColorFormat(123 as any)).toBe(false);
    });
  });

  describe('checkAllTokensExist', () => {
    it('should pass for complete palettes', () => {
      const darkResult = checkAllTokensExist(colors.dark);
      expect(darkResult.allExist).toBe(true);
      expect(darkResult.missingTokens).toHaveLength(0);

      const lightResult = checkAllTokensExist(colors.light);
      expect(lightResult.allExist).toBe(true);
      expect(lightResult.missingTokens).toHaveLength(0);

      const amoledResult = checkAllTokensExist(colors.amoled);
      expect(amoledResult.allExist).toBe(true);
      expect(amoledResult.missingTokens).toHaveLength(0);
    });

    it('should detect missing tokens', () => {
      const incompletePalette = { ...colors.dark };
      delete (incompletePalette as any).bgPrimary;
      delete (incompletePalette as any).textPrimary;

      const result = checkAllTokensExist(incompletePalette);
      expect(result.allExist).toBe(false);
      expect(result.missingTokens).toContain('bgPrimary');
      expect(result.missingTokens).toContain('textPrimary');
    });
  });

  describe('checkNonEmptyValues', () => {
    it('should pass for palettes with all non-empty values', () => {
      const darkResult = checkNonEmptyValues(colors.dark);
      expect(darkResult.allNonEmpty).toBe(true);
      expect(darkResult.emptyTokens).toHaveLength(0);

      const lightResult = checkNonEmptyValues(colors.light);
      expect(lightResult.allNonEmpty).toBe(true);
      expect(lightResult.emptyTokens).toHaveLength(0);

      const amoledResult = checkNonEmptyValues(colors.amoled);
      expect(amoledResult.allNonEmpty).toBe(true);
      expect(amoledResult.emptyTokens).toHaveLength(0);
    });

    it('should detect empty values', () => {
      const paletteWithEmpty = {
        ...colors.dark,
        bgPrimary: '',
        textPrimary: '   ',
      };

      const result = checkNonEmptyValues(paletteWithEmpty);
      expect(result.allNonEmpty).toBe(false);
      expect(result.emptyTokens).toContain('bgPrimary');
      expect(result.emptyTokens).toContain('textPrimary');
    });
  });

  describe('checkValidColorFormats', () => {
    it('should pass for palettes with valid color formats', () => {
      const darkResult = checkValidColorFormats(colors.dark);
      expect(darkResult.allValid).toBe(true);
      expect(darkResult.invalidTokens).toHaveLength(0);

      const lightResult = checkValidColorFormats(colors.light);
      expect(lightResult.allValid).toBe(true);
      expect(lightResult.invalidTokens).toHaveLength(0);

      const amoledResult = checkValidColorFormats(colors.amoled);
      expect(amoledResult.allValid).toBe(true);
      expect(amoledResult.invalidTokens).toHaveLength(0);
    });

    it('should detect invalid color formats', () => {
      const paletteWithInvalid = {
        ...colors.dark,
        bgPrimary: 'not-a-color',
        textPrimary: '#GGGGGG',
      };

      const result = checkValidColorFormats(paletteWithInvalid);
      expect(result.allValid).toBe(false);
      expect(result.invalidTokens).toContain('bgPrimary');
      expect(result.invalidTokens).toContain('textPrimary');
    });
  });

  describe('validateColorToken', () => {
    it('should validate existing valid tokens', () => {
      const result = validateColorToken(colors.dark, 'bgPrimary');
      expect(result.exists).toBe(true);
      expect(result.isEmpty).toBe(false);
      expect(result.isValidFormat).toBe(true);
      expect(result.value).toBe('#36393F');
      expect(result.error).toBeUndefined();
    });

    it('should detect missing tokens', () => {
      const incompletePalette = { ...colors.dark };
      delete (incompletePalette as any).bgPrimary;

      const result = validateColorToken(incompletePalette, 'bgPrimary');
      expect(result.exists).toBe(false);
      expect(result.error).toBe('Token does not exist in palette');
    });

    it('should detect empty tokens', () => {
      const paletteWithEmpty = { ...colors.dark, bgPrimary: '' };

      const result = validateColorToken(paletteWithEmpty, 'bgPrimary');
      expect(result.exists).toBe(true);
      expect(result.isEmpty).toBe(true);
      expect(result.error).toBe('Token value is empty');
    });

    it('should detect invalid format tokens', () => {
      const paletteWithInvalid = { ...colors.dark, bgPrimary: 'invalid' };

      const result = validateColorToken(paletteWithInvalid, 'bgPrimary');
      expect(result.exists).toBe(true);
      expect(result.isEmpty).toBe(false);
      expect(result.isValidFormat).toBe(false);
      expect(result.error).toBe('Invalid color format: invalid');
    });
  });

  describe('validateThemePalette', () => {
    it('should validate dark theme as valid', () => {
      const result = validateThemePalette('dark');
      expect(result.theme).toBe('dark');
      expect(result.isValid).toBe(true);
      expect(result.totalTokens).toBe(45);
      expect(result.validTokens).toBe(45);
      expect(result.missingTokens).toHaveLength(0);
      expect(result.emptyTokens).toHaveLength(0);
      expect(result.invalidFormatTokens).toHaveLength(0);
    });

    it('should validate light theme as valid', () => {
      const result = validateThemePalette('light');
      expect(result.theme).toBe('light');
      expect(result.isValid).toBe(true);
      expect(result.totalTokens).toBe(45);
      expect(result.validTokens).toBe(45);
      expect(result.missingTokens).toHaveLength(0);
      expect(result.emptyTokens).toHaveLength(0);
      expect(result.invalidFormatTokens).toHaveLength(0);
    });

    it('should validate amoled theme as valid', () => {
      const result = validateThemePalette('amoled');
      expect(result.theme).toBe('amoled');
      expect(result.isValid).toBe(true);
      expect(result.totalTokens).toBe(45);
      expect(result.validTokens).toBe(45);
      expect(result.missingTokens).toHaveLength(0);
      expect(result.emptyTokens).toHaveLength(0);
      expect(result.invalidFormatTokens).toHaveLength(0);
    });

    it('should provide detailed token results', () => {
      const result = validateThemePalette('dark');
      expect(result.tokenResults).toHaveLength(45);
      
      const bgPrimaryResult = result.tokenResults.find(
        (r) => r.token === 'bgPrimary'
      );
      expect(bgPrimaryResult).toBeDefined();
      expect(bgPrimaryResult?.exists).toBe(true);
      expect(bgPrimaryResult?.isValidFormat).toBe(true);
    });
  });

  describe('validateAllThemes', () => {
    it('should validate all three themes', () => {
      const results = validateAllThemes();
      
      expect(results.dark).toBeDefined();
      expect(results.light).toBeDefined();
      expect(results.amoled).toBeDefined();

      expect(results.dark.isValid).toBe(true);
      expect(results.light.isValid).toBe(true);
      expect(results.amoled.isValid).toBe(true);
    });

    it('should return consistent results for all themes', () => {
      const results = validateAllThemes();
      
      expect(results.dark.totalTokens).toBe(45);
      expect(results.light.totalTokens).toBe(45);
      expect(results.amoled.totalTokens).toBe(45);
    });
  });
});
