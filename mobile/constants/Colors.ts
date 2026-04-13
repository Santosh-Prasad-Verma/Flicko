/**
 * Flicko Design Tokens — Discord-Accurate Theme
 *
 * Central source of truth for all visual design values.
 * Colors match Discord's mobile app exactly.
 */

/** Dark theme palette — Discord-exact dark theme */
const dark = {
  // ─── BACKGROUNDS ───
  bgPrimary: '#36393F',      // Primary chat area
  bgSecondary: '#292B2F',    // Sidebar profile/info area
  bgTertiary: '#202225',     // Server list/title bar
  bgFloating: '#18191C',     // Tooltips, menus, popovers
  inputBg: '#40444B',        // Message bar / text inputs
  messageHover: '#32353B',   // Message row on hover/press
  cardBg: '#292B2F',         // Cards

  // ─── TEXT ───
  textPrimary: '#DCDDDE',    // Main text (messages, titles)
  textSecondary: '#B9BBBE',  // Subtitles, descriptions
  textMuted: '#72767D',      // Timestamps, placeholders
  textLink: '#00A8FC',       // Clickable links
  textPositive: '#23A559',   // Success text
  textDanger: '#DA373C',     // Error/danger text
  textWarning: '#F0B232',    // Warning text

  // ─── INTERACTIVE ───
  interactive: '#B9BBBE',    // Default icon/text state
  interactiveHover: '#DCDDDE', // Hovered
  interactiveActive: '#FFFFFF', // Active/selected

  // ─── BRAND ───
  accentPrimary: '#5865F2',  // Discord blurple
  accentSecondary: '#4752C4', // Blurple hover
  success: '#23A559',        // Online, success, positive buttons
  successHover: '#1A7D41',   // Green button hover
  danger: '#DA373C',         // DND, danger, destructive buttons
  dangerHover: '#A12828',    // Red button hover
  warning: '#F0B232',        // Idle status
  fuchsia: '#EB459F',        // Boost pink

  // ─── STATUS ───
  statusOnline: '#23A559',
  statusIdle: '#F0B232',
  statusDnd: '#F23F43',
  statusOffline: '#80848E',
  statusStreaming: '#593695',

  // ─── SPECIFIC UI ───
  channelIcon: '#B9BBBE',    // # icon color
  border: '#262729',         // Separator lines / borders
  divider: '#262729',        // Separator lines
  mentionBg: 'rgba(88, 101, 242, 0.3)', // @mention highlight
  mentionText: '#C9CDFB',    // @mention text color
  codeBlockBg: '#2B2D31',    // Code block background
  spoilerBg: '#232428',      // Spoiler hidden state
  embedBorder: '#1E1F22',    // Embed left border default
  scrollbarThumb: '#1A1B1E',
  scrollbarTrack: '#2B2D31',
  buttonSecondary: '#4E5058', // Secondary/grey buttons
  badgeRed: '#DA373C',       // Notification badges
  unreadIndicator: '#F2F3F5', // Unread channel indicator
  overlay: 'rgba(0, 0, 0, 0.75)',
} as const;

/** Light theme palette — matches Discord light theme */
const light = {
  bgPrimary: '#FFFFFF',
  bgSecondary: '#F2F3F5',
  bgTertiary: '#E3E5E8',
  bgFloating: '#FFFFFF',
  inputBg: '#E3E5E8',
  messageHover: '#F2F3F5',
  cardBg: '#FFFFFF',
  textPrimary: '#060607',
  textSecondary: '#4E5058',
  textMuted: '#80848E',
  textLink: '#006CE7',
  textPositive: '#248046',
  textDanger: '#DA373C',
  textWarning: '#D69E2E',
  interactive: '#4E5058',
  interactiveHover: '#313338',
  interactiveActive: '#060607',
  accentPrimary: '#5865F2',
  accentSecondary: '#4752C4',
  success: '#248046',
  successHover: '#1A6334',
  danger: '#DA373C',
  dangerHover: '#A12828',
  warning: '#D69E2E',
  fuchsia: '#EB459F',
  statusOnline: '#248046',
  statusIdle: '#D69E2E',
  statusDnd: '#DA373C',
  statusOffline: '#80848E',
  statusStreaming: '#593695',
  channelIcon: '#6D6F78',
  border: '#E1E1E4',
  divider: '#E1E1E4',
  mentionBg: 'rgba(88, 101, 242, 0.15)',
  mentionText: '#5865F2',
  codeBlockBg: '#F2F3F5',
  spoilerBg: '#E3E5E8',
  embedBorder: '#E1E1E4',
  scrollbarThumb: '#C4C9CE',
  scrollbarTrack: '#F2F3F5',
  buttonSecondary: '#6D6F78',
  badgeRed: '#DA373C',
  unreadIndicator: '#060607',
  overlay: 'rgba(0, 0, 0, 0.3)',
} as const;

/** AMOLED / Midnight theme — true black Discord */
const amoled = {
  ...dark,
  bgPrimary: '#000000',
  bgSecondary: '#0A0A0A',
  bgTertiary: '#000000',
  bgFloating: '#000000',
  inputBg: '#0A0A0A',
  cardBg: '#0A0A0A',
  messageHover: '#0A0A0A',
} as const;

export type ThemeColors = { readonly [K in keyof typeof dark]: string };
export type ThemeName = 'dark' | 'light' | 'amoled';

export const colors: Record<ThemeName, ThemeColors> = {
  dark,
  light,
  amoled,
};

/** Alias for cleaner component imports: Colors.dark.textPrimary */
export const Colors = colors;

/** Spacing scale (multiples of 4) */
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  xxxxl: 40,
} as const;

/** Border radius scale — Discord uses softer radii */
export const borderRadius = {
  xs: 3,
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  xxl: 24,
  full: 9999,
} as const;

/** Typography scale — GG Sans font family (Discord's font)
 *  NOTE: Do NOT add fontWeight — it conflicts with custom fonts on Android.
 *  The weight is baked into each font file (Regular/Medium/SemiBold/Bold).
 */
export const typography = {
  headingXL: {
    fontSize: 24,
    fontFamily: 'gg-sans-bold',
    lineHeight: 30,
  },
  headingL: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
    lineHeight: 26,
  },
  headingM: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
    lineHeight: 22,
  },
  headingS: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    lineHeight: 18,
  },
  body: {
    fontSize: 16,
    fontFamily: 'gg-sans',
    lineHeight: 22,
  },
  bodyBold: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
    lineHeight: 22,
  },
  bodySmall: {
    fontSize: 14,
    fontFamily: 'gg-sans',
    lineHeight: 18,
  },
  caption: {
    fontSize: 12,
    fontFamily: 'gg-sans-medium',
    lineHeight: 16,
  },
  micro: {
    fontSize: 10,
    fontFamily: 'gg-sans-semibold',
    lineHeight: 14,
  },
  overline: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.24,
    textTransform: 'uppercase' as const,
    lineHeight: 16,
  },
} as const;

/** Shadow elevation levels */
export const shadows = {
  subtle: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
    elevation: 1,
  },
  medium: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.25,
    shadowRadius: 8,
    elevation: 4,
  },
  heavy: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 16,
    elevation: 8,
  },
} as const;

/** Minimum touch target per Apple/Google HIG */
export const MINIMUM_TOUCH_TARGET = 44;

/** Animation durations in ms */
export const animations = {
  fast: 100,
  normal: 200,
  slow: 300,
} as const;
