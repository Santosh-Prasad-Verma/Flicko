import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/calling/presentation/call_signal_listener.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';
import 'package:mobile/features/notifications/application/unread_notifications_provider.dart';

/// Flicko main navigation shell — premium edge-to-edge rectangular glassmorphic bottom bar.
class MainNavigationShell extends ConsumerWidget {
  /// The routed child widget for the selected tab.
  final Widget child;

  /// Current tab index (0 = Home, 1 = Messages, 2 = Activity, 3 = Profile).
  final int currentIndex;

  /// Callback fired when user taps a tab.
  final ValueChanged<int> onTabSelected;

  /// Current matched route path to decide whether to show the bottom bar.
  final String currentLocation;

  const MainNavigationShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch unread notifications count in real-time
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
    final unreadCount = unreadCountAsync.value ?? 0;

    // Get the current location dynamically from GoRouterState to ensure reactive updates on navigation
    String activeLocation;
    try {
      activeLocation = GoRouterState.of(context).uri.path;
    } catch (_) {
      activeLocation = currentLocation;
    }

    // Only show the bottom navigation bar on top-level root pages of each tab.
    final bool showNavBar = const [
      '/',
      '/dms',
      '/notifications',
      '/profile',
    ].contains(activeLocation);

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 64.0 + bottomPadding;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: Stack(
        children: [
          // Content screen with animated padding to reclaim screen space when navbar is hidden
          AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutQuart,
            padding: EdgeInsets.only(
              bottom: showNavBar ? navBarHeight : 0,
            ),
            child: CallSignalListener(child: child),
          ),

          // Voice HUD - animated position so it floats perfectly above the navbar or at screen bottom
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutQuart,
            left: 0,
            right: 0,
            bottom: showNavBar ? (navBarHeight + 8.0) : (bottomPadding + 16.0),
            child: const VoiceHUD(),
          ),

          // Pinned rectangular glassmorphic navbar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutQuart,
            left: 0,
            right: 0,
            bottom: showNavBar ? 0 : -navBarHeight, // slide down offscreen
            child: _buildRectNavBar(context, bottomPadding, unreadCount),
          ),
        ],
      ),
    );
  }

  Widget _buildRectNavBar(BuildContext context, double bottomPadding, int unreadCount) {
    return Container(
      height: 64.0 + bottomPadding,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFBF9FA).withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTab(
                  index: 0,
                  activeIndex: currentIndex,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 1,
                  activeIndex: currentIndex,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 2,
                  activeIndex: currentIndex,
                  icon: Icons.notifications_none_rounded,
                  activeIcon: Icons.notifications_rounded,
                  label: 'Alerts',
                  badgeCount: unreadCount,
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 3,
                  activeIndex: currentIndex,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  onTap: onTabSelected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual tab with animated active state.
class _NavTab extends StatelessWidget {
  final int index;
  final int activeIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;
  final int badgeCount;

  static const Color _neonGreen = Color(0xFF52B788);

  const _NavTab({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  bool get _isActive => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_isActive) {
          HapticFeedback.selectionClick();
        }
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutExpo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isActive
              ? _neonGreen.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    _isActive ? activeIcon : icon,
                    key: ValueKey(_isActive),
                    size: 24,
                    color: _isActive
                        ? _neonGreen
                        : const Color(0xFF71717A), // textMuted
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B3B), // neon red
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutExpo,
              child: SizedBox(
                width: _isActive ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label,
                    style: GoogleFonts.spaceMono(
                      color: _neonGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
