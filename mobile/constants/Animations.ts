/**
 * Flicko Animation Presets — Discord-Accurate Motion
 *
 * Centralized animation configuration matching Discord mobile's motion language.
 * Uses react-native-reanimated spring/timing configs throughout.
 *
 * Discord's animation philosophy:
 * - Snappy springs for interactive elements (buttons, icons, modals)
 * - Quick fades for content appearance (150–250ms)
 * - Overdamped springs for layout shifts (no bounce)
 * - Underdamped springs for playful feedback (icon morphs, badge pops)
 */
import {
  withSpring,
  withTiming,
  Easing,
  type WithSpringConfig,
  type WithTimingConfig,
  FadeIn,
  FadeOut,
  FadeInDown,
  FadeInUp,
  FadeOutDown,
  FadeOutUp,
  SlideInDown,
  SlideOutDown,
  SlideInRight,
  SlideOutRight,
  SlideInLeft,
  SlideOutLeft,
  ZoomIn,
  ZoomOut,
  Layout,
} from 'react-native-reanimated';

// ─── Spring Presets ────────────────────────────────────────────────────────────

/** Discord "snappy" spring — used for most interactive elements */
export const SPRING_SNAPPY: WithSpringConfig = {
  damping: 20,
  stiffness: 300,
  mass: 0.8,
  overshootClamping: false,
};

/** Discord "bouncy" spring — used for badge pops, icon morphs */
export const SPRING_BOUNCY: WithSpringConfig = {
  damping: 12,
  stiffness: 200,
  mass: 0.6,
  overshootClamping: false,
};

/** Discord "gentle" spring — modals, sheets, large elements */
export const SPRING_GENTLE: WithSpringConfig = {
  damping: 22,
  stiffness: 180,
  mass: 1,
  overshootClamping: false,
};

/** Discord "stiff" spring — no bounce, snaps into place (layout shifts) */
export const SPRING_STIFF: WithSpringConfig = {
  damping: 28,
  stiffness: 350,
  mass: 0.8,
  overshootClamping: true,
};

// ─── Timing Presets ────────────────────────────────────────────────────────────

/** Ultra-fast timing — hover states, micro-interactions (100ms) */
export const TIMING_INSTANT: WithTimingConfig = {
  duration: 100,
  easing: Easing.out(Easing.cubic),
};

/** Fast timing — press states, tab switches (150ms) */
export const TIMING_FAST: WithTimingConfig = {
  duration: 150,
  easing: Easing.out(Easing.cubic),
};

/** Normal timing — content appearance, color transitions (200ms) */
export const TIMING_NORMAL: WithTimingConfig = {
  duration: 200,
  easing: Easing.inOut(Easing.cubic),
};

/** Slow timing — page transitions, large reveals (300ms) */
export const TIMING_SLOW: WithTimingConfig = {
  duration: 300,
  easing: Easing.inOut(Easing.cubic),
};

/** Emphasis timing — dramatic reveals (400ms) */
export const TIMING_EMPHASIS: WithTimingConfig = {
  duration: 400,
  easing: Easing.bezier(0.4, 0, 0.2, 1),
};

// ─── Layout Animation Presets (entering/exiting) ──────────────────────────────

/** List items fade in from below — stagger-friendly */
export const ENTER_FADE_UP = FadeInUp.duration(200).easing(Easing.out(Easing.cubic));
export const EXIT_FADE_DOWN = FadeOutDown.duration(150).easing(Easing.in(Easing.cubic));

/** Content fade in (channel switch, tab switch) */
export const ENTER_FADE = FadeIn.duration(200).easing(Easing.out(Easing.cubic));
export const EXIT_FADE = FadeOut.duration(150).easing(Easing.in(Easing.cubic));

/** Modal / bottom sheet slide up with spring */
export const ENTER_SHEET = SlideInDown.springify().damping(22).stiffness(200).mass(1);
export const EXIT_SHEET = SlideOutDown.springify().damping(28).stiffness(300);

/** Badge / notification pop in */
export const ENTER_POP = ZoomIn.springify().damping(12).stiffness(200);
export const EXIT_POP = ZoomOut.duration(150);

/** Slide in from right (push navigation feel) */
export const ENTER_SLIDE_RIGHT = SlideInRight.duration(250).easing(Easing.out(Easing.cubic));
export const EXIT_SLIDE_LEFT = SlideOutLeft.duration(200).easing(Easing.in(Easing.cubic));

/** Layout transition — smooth reordering of list items */
export const LAYOUT_SPRING = Layout.springify().damping(20).stiffness(300);

// ─── Scale Presets ─────────────────────────────────────────────────────────────

/** Press-down scale factor (Discord uses 0.95 on buttons, 0.92 on icons) */
export const PRESS_SCALE_BUTTON = 0.95;
export const PRESS_SCALE_ICON = 0.92;
export const PRESS_SCALE_CARD = 0.98;

// ─── Server Icon Pill Constants (Discord sidebar) ─────────────────────────────

/** Pill indicator widths next to server icons */
export const PILL_WIDTH_HOVER = 8;
export const PILL_WIDTH_UNREAD = 8;
export const PILL_WIDTH_ACTIVE = 40;

/** Server icon border radius transition: circle (24) → squircle (16) */
export const ICON_RADIUS_DEFAULT = 24;
export const ICON_RADIUS_ACTIVE = 16;

// ─── Helper Functions ──────────────────────────────────────────────────────────

/** Apply snappy spring to a value */
export const springSnappy = (value: number) => withSpring(value, SPRING_SNAPPY);
/** Apply bouncy spring to a value */
export const springBouncy = (value: number) => withSpring(value, SPRING_BOUNCY);
/** Apply gentle spring to a value */
export const springGentle = (value: number) => withSpring(value, SPRING_GENTLE);
/** Apply stiff spring to a value */
export const springStiff = (value: number) => withSpring(value, SPRING_STIFF);
/** Apply fast timing to a value */
export const timingFast = (value: number) => withTiming(value, TIMING_FAST);
/** Apply normal timing to a value */
export const timingNormal = (value: number) => withTiming(value, TIMING_NORMAL);
