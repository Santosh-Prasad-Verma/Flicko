/**
 * Layout Constants
 *
 * Screen dimensions, safe area defaults, and common layout values.
 */
import { Dimensions, Platform, StatusBar } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

/** Minimum touch target per Apple/Google HIG */
export const MINIMUM_TOUCH_TARGET = 44;

/** Header heights */
export const HEADER_HEIGHT = Platform.select({ ios: 44, android: 56 }) ?? 50;

/** Tab bar */
export const TAB_BAR_HEIGHT = Platform.select({ ios: 83, android: 64 }) ?? 70;

/** Status bar height (Android) */
export const STATUS_BAR_HEIGHT = StatusBar.currentHeight ?? 0;

/** Common layout values */
export const layout = {
  screenWidth: SCREEN_WIDTH,
  screenHeight: SCREEN_HEIGHT,
  headerHeight: HEADER_HEIGHT,
  tabBarHeight: TAB_BAR_HEIGHT,
  statusBarHeight: STATUS_BAR_HEIGHT,
  /** Standard horizontal padding for screen content */
  screenPaddingHorizontal: 16,
  /** Standard vertical padding for screen content */
  screenPaddingVertical: 16,
  /** Maximum content width (for readability on tablets) */
  maxContentWidth: 600,
  /** Input field height */
  inputHeight: 48,
  /** Avatar sizes */
  avatarSizes: {
    xs: 24,
    sm: 32,
    md: 40,
    lg: 56,
    xl: 80,
  },
  /** Server icon size */
  serverIconSize: 48,
  /** Channel item height */
  channelItemHeight: 42,
  /** Message item estimated height (for FlashList) */
  messageItemEstimatedHeight: 80,
  /** Bottom sheet handle height */
  bottomSheetHandleHeight: 24,
} as const;
