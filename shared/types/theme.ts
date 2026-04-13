export type Theme = 'light' | 'dark' | 'amoled' | 'auto';
export type ResolvedTheme = 'light' | 'dark' | 'amoled';

export interface ThemeContextValue {
  theme: Theme;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: Theme) => void;
}
