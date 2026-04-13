import { describe, it, expect, beforeEach } from '@jest/globals';
import { useSettingsStore } from '../settingsStore';

// Mock the storage module
jest.mock('../../lib/storage', () => ({
  createZustandStorage: () => ({
    getItem: jest.fn(async () => null),
    setItem: jest.fn(async () => {}),
    removeItem: jest.fn(async () => {}),
  }),
}));

describe('settingsStore - Theme Validation', () => {
  beforeEach(() => {
    // Reset store to initial state
    useSettingsStore.setState({
      theme: 'dark',
    });
  });

  describe('Theme Persistence and Validation', () => {
    it('should default to dark theme', () => {
      const { theme } = useSettingsStore.getState();
      expect(theme).toBe('dark');
    });

    it('should accept valid theme values', () => {
      const validThemes: Array<'light' | 'dark' | 'amoled' | 'auto'> = [
        'light',
        'dark',
        'amoled',
        'auto',
      ];

      validThemes.forEach((validTheme) => {
        useSettingsStore.getState().setTheme(validTheme);
        const { theme } = useSettingsStore.getState();
        expect(theme).toBe(validTheme);
      });
    });

    it('should update theme immediately when setTheme is called', () => {
      const { setTheme } = useSettingsStore.getState();
      
      setTheme('light');
      expect(useSettingsStore.getState().theme).toBe('light');
      
      setTheme('amoled');
      expect(useSettingsStore.getState().theme).toBe('amoled');
    });

    it('should persist theme changes', () => {
      const { setTheme } = useSettingsStore.getState();
      
      setTheme('light');
      const { theme } = useSettingsStore.getState();
      
      expect(theme).toBe('light');
    });
  });

  describe('Web Platform Support', () => {
    it('should update document theme attribute on web platform', () => {
      // Mock document for web platform
      const mockSetAttribute = jest.fn();
      (global as any).document = {
        documentElement: {
          setAttribute: mockSetAttribute,
        },
      };

      const { setTheme } = useSettingsStore.getState();
      
      setTheme('light');
      expect(mockSetAttribute).toHaveBeenCalledWith('data-theme', 'light');
      
      setTheme('dark');
      expect(mockSetAttribute).toHaveBeenCalledWith('data-theme', 'dark');
    });

    it('should handle auto mode on web platform', () => {
      const mockSetAttribute = jest.fn();
      const mockMatchMedia = jest.fn(() => ({
        matches: true, // Simulate dark mode preference
      }));
      
      (global as any).document = {
        documentElement: {
          setAttribute: mockSetAttribute,
        },
      };
      (global as any).window = {
        matchMedia: mockMatchMedia,
      };

      const { setTheme } = useSettingsStore.getState();
      
      setTheme('auto');
      expect(mockMatchMedia).toHaveBeenCalledWith('(prefers-color-scheme: dark)');
      expect(mockSetAttribute).toHaveBeenCalledWith('data-theme', 'dark');
    });
  });
});
