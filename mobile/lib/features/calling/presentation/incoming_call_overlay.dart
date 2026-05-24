import 'package:flutter/material.dart';
import 'incoming_call_screen.dart';
import 'outgoing_call_screen.dart';
import 'active_call_screen.dart';
import 'call_transitions.dart';

/// Unified call overlay helper.
///
/// Use this to show any call screen as a fullscreen overlay
/// from anywhere in the app — push notifications, WebSocket events, etc.
///
/// ```dart
/// // Incoming voice call
/// CallOverlay.showIncoming(context, callerName: 'Clay', ...);
///
/// // Start outgoing call
/// CallOverlay.showOutgoing(context, calleeName: 'Jake', callType: 'video');
///
/// // Transition to active call with pickup animation
/// CallOverlay.acceptCall(context, peerName: 'Clay', isVideo: false);
/// ```
class CallOverlay {
  CallOverlay._();

  // ══════════════════════════
  // ── INCOMING CALL ──
  // ══════════════════════════
  /// Show the cyberpunk incoming call screen.
  static Future<void> showIncoming(
    BuildContext context, {
    required String callerName,
    String? callerAvatarUrl,
    String callType = 'voice',
    VoidCallback? onAccept,
    VoidCallback? onDecline,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, _) {
          return IncomingCallScreen(
            callerName: callerName,
            callerAvatarUrl: callerAvatarUrl,
            callType: callType,
            onAccept: onAccept ??
                () => acceptCall(
                      context,
                      peerName: callerName,
                      peerAvatarUrl: callerAvatarUrl,
                      isVideo: callType == 'video',
                    ),
            onDecline: onDecline,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ══════════════════════════
  // ── INCOMING VIDEO CALL ──
  // ══════════════════════════
  /// Shorthand for incoming video call.
  static Future<void> showIncomingVideo(
    BuildContext context, {
    required String callerName,
    String? callerAvatarUrl,
    VoidCallback? onAccept,
    VoidCallback? onDecline,
  }) {
    return showIncoming(
      context,
      callerName: callerName,
      callerAvatarUrl: callerAvatarUrl,
      callType: 'video',
      onAccept: onAccept,
      onDecline: onDecline,
    );
  }

  // ══════════════════════════
  // ── OUTGOING CALL ──
  // ══════════════════════════
  /// Show the outgoing call screen with radar sweep.
  static Future<void> showOutgoing(
    BuildContext context, {
    required String calleeName,
    String? calleeAvatarUrl,
    String callType = 'voice',
    VoidCallback? onCancel,
    VoidCallback? onConnected,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, _) {
          return OutgoingCallScreen(
            calleeName: calleeName,
            calleeAvatarUrl: calleeAvatarUrl,
            callType: callType,
            onCancel: onCancel,
            onConnected: onConnected,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          // Slide up from bottom
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Shorthand for outgoing video call.
  static Future<void> showOutgoingVideo(
    BuildContext context, {
    required String calleeName,
    String? calleeAvatarUrl,
    VoidCallback? onCancel,
    VoidCallback? onConnected,
  }) {
    return showOutgoing(
      context,
      calleeName: calleeName,
      calleeAvatarUrl: calleeAvatarUrl,
      callType: 'video',
      onCancel: onCancel,
      onConnected: onConnected,
    );
  }

  // ══════════════════════════
  // ── ACCEPT / PICKUP ──
  // ══════════════════════════
  /// Accept an incoming call with the pickup lock-on animation,
  /// then transition into the active call screen.
  static Future<void> acceptCall(
    BuildContext context, {
    required String peerName,
    String? peerAvatarUrl,
    bool isVideo = false,
    String? roomName,
    String? myUserId,
    String? peerUserId,
    bool isCaller = false,
    VoidCallback? onHangUp,
  }) {
    // Pop the incoming/outgoing screen first
    Navigator.of(context, rootNavigator: true).pop();

    // Play pickup animation -> active call
    return CallTransitions.playPickup(
      context,
      callerName: peerName,
      destination: ActiveCallScreen(
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        isVideo: isVideo,
        roomName: roomName,
        myUserId: myUserId,
        peerUserId: peerUserId,
        isCaller: isCaller,
        onHangUp: onHangUp,
      ),
    );
  }

  // ══════════════════════════
  // ── HANGUP ──
  // ══════════════════════════
  /// End the current call with the hangup animation.
  static Future<void> hangUp(BuildContext context) async {
    // Pop the active call screen
    Navigator.of(context, rootNavigator: true).pop();

    // Play hangup animation
    await CallTransitions.playHangup(context);
  }

  // ══════════════════════════
  // ── DISMISS ──
  // ══════════════════════════
  /// Dismiss any call overlay immediately (no animation).
  static void dismiss(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
