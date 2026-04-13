/**
 * Theme Testing Utilities
 * 
 * Provides helpers for testing components with different themes.
 * Simplifies mocking theme state, rendering with specific themes,
 * and snapshot testing across theme variants.
 * 
 * Requirements: 13.3, 13.4, 13.5
 */

import React, { ReactElement } from 'react';
import { render, RenderOptions } from '@testing-library/react-native';
import { useSettingsStore } from '@stores/settingsStore';
import type { ThemeName } from '@constants/Colors';

/**
 * Mock theme state for testing
 * @param theme - Theme to set as active
 */
export function mockTheme(theme: ThemeName): void {
  const store = useSettingsStore.getState();
  store.setTheme(theme);
}

/**
 * Reset theme to default (dark) for testing
 */
export function resetTheme(): void {
  mockTheme('dark');
}

/**
 * Wrapper component that sets a specific theme
 */
interface ThemeWrapperProps {
  theme: ThemeName;
  children: React.ReactNode;
}

function ThemeWrapper({ theme, children }: ThemeWrapperProps) {
  React.useEffect(() => {
    mockTheme(theme);
  }, [theme]);

  return <>{children}</>;
}

/**
 * Custom render function that wraps component with theme provider
 * @param ui - Component to render
 * @param theme - Theme to use (defaults to 'dark')
 * @param options - Additional render options
 */
export function renderWithTheme(
  ui: ReactElement,
  theme: ThemeName = 'dark',
  options?: Omit<RenderOptions, 'wrapper'>
) {
  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <ThemeWrapper theme={theme}>{children}</ThemeWrapper>
  );

  return render(ui, { wrapper: Wrapper, ...options });
}

/**
 * Render component in all theme variants for snapshot testing
 * @param ui - Component to render
 * @param componentName - Name for snapshot identification
 */
export function renderAllThemes(ui: ReactElement, componentName: string) {
  const themes: ThemeName[] = ['light', 'dark', 'amoled'];
  const snapshots: Record<ThemeName, any> = {} as any;

  themes.forEach((theme) => {
    const { toJSON } = renderWithTheme(ui, theme);
    snapshots[theme] = toJSON();
  });

  return snapshots;
}

/**
 * Test helper to verify component renders in all themes without errors
 * @param ui - Component to test
 */
export function testAllThemes(ui: ReactElement): void {
  const themes: ThemeName[] = ['light', 'dark', 'amoled'];

  themes.forEach((theme) => {
    expect(() => {
      renderWithTheme(ui, theme);
    }).not.toThrow();
  });
}

/**
 * Get current theme from store (useful for assertions)
 */
export function getCurrentTheme(): ThemeName {
  return useSettingsStore.getState().theme;
}

/**
 * Create a test suite that runs the same tests across all themes
 * @param suiteName - Name of the test suite
 * @param testFn - Function containing tests to run for each theme
 */
export function describeAllThemes(
  suiteName: string,
  testFn: (theme: ThemeName) => void
): void {
  const themes: ThemeName[] = ['light', 'dark', 'amoled'];

  themes.forEach((theme) => {
    describe(`${suiteName} (${theme} theme)`, () => {
      beforeEach(() => {
        mockTheme(theme);
      });

      afterEach(() => {
        resetTheme();
      });

      testFn(theme);
    });
  });
}

/**
 * Snapshot matcher for all theme variants
 * Usage: expect(component).toMatchThemeSnapshots()
 */
export function expectThemeSnapshots(ui: ReactElement, name: string) {
  const snapshots = renderAllThemes(ui, name);
  
  return {
    light: expect(snapshots.light).toMatchSnapshot(`${name}-light`),
    dark: expect(snapshots.dark).toMatchSnapshot(`${name}-dark`),
    amoled: expect(snapshots.amoled).toMatchSnapshot(`${name}-amoled`),
  };
}

/**
 * Wait for theme change to propagate
 * Useful when testing theme switching behavior
 */
export async function waitForThemeChange(theme: ThemeName): Promise<void> {
  mockTheme(theme);
  // Small delay to allow React to process state updates
  await new Promise((resolve) => setTimeout(resolve, 0));
}

/**
 * Create a mock theme colors object for testing
 * @param overrides - Partial theme colors to override defaults
 */
export function createMockThemeColors(overrides: Partial<Record<string, string>> = {}) {
  const defaultColors = {
    bgPrimary: '#313338',
    bgSecondary: '#2B2D31',
    bgTertiary: '#1E1F22',
    textPrimary: '#F2F3F5',
    textSecondary: '#B5BAC1',
    textMuted: '#80848E',
    accentPrimary: '#5865F2',
    border: '#3F4147',
    interactive: '#B5BAC1',
    danger: '#DA373C',
    success: '#23A559',
    warning: '#F0B232',
  };

  return { ...defaultColors, ...overrides };
}

/**
 * Test helper to verify theme-dependent styles
 * @param getStyles - Function that returns styles based on theme
 */
export function testThemeStyles(
  getStyles: (theme: ThemeName) => any
): Record<ThemeName, any> {
  const themes: ThemeName[] = ['light', 'dark', 'amoled'];
  const results: Record<ThemeName, any> = {} as any;

  themes.forEach((theme) => {
    mockTheme(theme);
    results[theme] = getStyles(theme);
  });

  resetTheme();
  return results;
}
