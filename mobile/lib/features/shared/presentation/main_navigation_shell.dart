import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';

/// Flicko main navigation shell — Discord-style bottom tab bar.
///
/// Wraps the current tab page in a [Scaffold] with a custom-styled
/// [BottomNavigationBar] that matches the new UI (dark theme with purple active states).
class MainNavigationShell extends StatelessWidget {
  /// The routed child widget for the selected tab.
  final Widget child;

  /// Current tab index (0 = Servers, 1 = Notifications, 2 = You).
  final int currentIndex;

  /// Callback fired when user taps a tab.
  final ValueChanged<int> onTabSelected;

  const MainNavigationShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      body: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VoiceHUD(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0812), // Same as sidebar bg
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1.5,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65, // Matches CSS height:65px
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTab(
                  index: 0,
                  activeIndex: currentIndex,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_filled,
                  label: 'Home',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 1,
                  activeIndex: currentIndex,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 2,
                  activeIndex: currentIndex,
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Activity',
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

/// Individual tab item with an animated pill background on selection.
class _NavTab extends StatelessWidget {
  final int index;
  final int activeIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavTab({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  bool get _isActive => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    // Obsidian Dark Violet UI colors
    const activeColor = Color(0xFF8B5CF6); // Main purple
    final inactiveColor = Colors.white.withValues(alpha: 0.35);

    final color = _isActive ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isActive ? activeIcon : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
