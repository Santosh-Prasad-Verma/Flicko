import 'package:flutter/services.dart';

/// Centralized haptics service following iOS/Android vibration conventions.
///
/// Provides categorized haptic feedback triggers that map to common
/// user interactions throughout the app.
class FlickoHaptics {
  FlickoHaptics._();

  // ── Selection / Navigation ──

  /// Light tap for selections, toggles, small switches
  static void selection() => HapticFeedback.selectionClick();

  /// Tab bar changes, picker scrolls
  static void tab() => HapticFeedback.selectionClick();

  // ── Actions ──

  /// Standard interaction: button taps, list item taps
  static void light() => HapticFeedback.lightImpact();

  /// Confirmations: sending messages, saving settings
  static void medium() => HapticFeedback.mediumImpact();

  /// Destructive actions: delete, ban, kick
  static void heavy() => HapticFeedback.heavyImpact();

  // ── Feedback ──

  /// Success haptic after a positive outcome
  static void success() => HapticFeedback.mediumImpact();

  /// Warning haptic before destructive dialog
  static void warning() => HapticFeedback.heavyImpact();

  /// Error haptic on validation failure
  static void error() => HapticFeedback.heavyImpact();

  // ── Context-Specific ──

  /// Message sent
  static void messageSent() => HapticFeedback.lightImpact();

  /// Reaction added
  static void reactionAdded() => HapticFeedback.selectionClick();

  /// Long press (context menu trigger)
  static void longPress() => HapticFeedback.mediumImpact();

  /// Pull to refresh trigger
  static void pullToRefresh() => HapticFeedback.lightImpact();

  /// Drag/reorder item picked up
  static void dragStart() => HapticFeedback.mediumImpact();

  /// Drag/reorder item dropped
  static void dragEnd() => HapticFeedback.lightImpact();

  /// Spoiler reveal
  static void spoilerReveal() => HapticFeedback.mediumImpact();

  /// Voice channel join
  static void voiceJoin() => HapticFeedback.heavyImpact();

  /// Voice channel disconnect
  static void voiceLeave() => HapticFeedback.mediumImpact();

  /// Notification received
  static void notification() => HapticFeedback.selectionClick();
}
