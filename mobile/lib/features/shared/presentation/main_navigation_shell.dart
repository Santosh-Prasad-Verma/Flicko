import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';

/// Flicko main navigation shell — Discord-style bottom tab bar.
///
/// Wraps the current tab page in a [Scaffold] with a custom-styled
/// [BottomNavigationBar] that matches the React Native tab layout:
///   - Servers (index 0)
///   - Notifications (index 1)
///   - You / Profile (index 2)
///
/// The [child] and [currentIndex] are driven by [GoRouter]'s
/// [StatefulShellRoute]. The shell itself only renders the chrome
/// (bottom bar); the active page comes from the router.
class MainNavigationShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final avatarUrl = authState.maybeWhen(
      authenticated: (user, profile) => profile?.avatarUrl,
      orElse: () => null,
    );

    return Scaffold(
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
                // Add a small spacer if needed, but the HUD has its own margins
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(FlickoColors.bgTertiary),
          // Subtle top border matching Discord mobile
          border: Border(
            top: BorderSide(
              color: Color(FlickoColors.bgTertiary),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTab(
                  index: 0,
                  activeIndex: currentIndex,
                  icon: Icons.dns_outlined,
                  activeIcon: Icons.dns,
                  label: 'Servers',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 1,
                  activeIndex: currentIndex,
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Messages',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 2,
                  activeIndex: currentIndex,
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Notifications',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 3,
                  activeIndex: currentIndex,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'You',
                  onTap: onTabSelected,
                  avatarUrl: avatarUrl,
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

  final String? avatarUrl;

  const _NavTab({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.avatarUrl,
  });

  bool get _isActive => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    final color = _isActive
        ? const Color(FlickoColors.textPrimary)
        : const Color(FlickoColors.textMuted);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pill background + icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 28,
              decoration: BoxDecoration(
                color: _isActive
                    ? const Color(FlickoColors.blurple).withAlpha(38)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: index == 3
                    ? Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isActive 
                              ? const Color(FlickoColors.textPrimary) 
                              : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: UserAvatar(
                          imageUrl: avatarUrl,
                          size: 20,
                          showStatus: false,
                        ),
                      )
                    : Icon(
                        _isActive ? activeIcon : icon,
                        key: ValueKey(_isActive),
                        size: 22,
                        color: color,
                      ),
            ),
            const SizedBox(height: 2),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
