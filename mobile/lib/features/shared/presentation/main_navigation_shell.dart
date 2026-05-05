import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
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
          color: Colors.black, // Sleek black theme
          border: Border(
            top: BorderSide(color: Color(0xFF1A1A1A), width: 1.0),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTab(
                  index: 1, // Messages is index 1
                  activeIndex: currentIndex,
                  activeIcon: Icons.chat_bubble,
                  icon: Icons.chat_bubble_outline,
                  label: 'MESSAGES',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 0, // Spaces is index 0
                  activeIndex: currentIndex,
                  activeIcon: Icons.grid_view_rounded,
                  icon: Icons.grid_view_outlined,
                  label: 'SPACES',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 2, // Notifications/Activity is index 2
                  activeIndex: currentIndex,
                  activeIcon: Icons.notifications,
                  icon: Icons.notifications_none_outlined,
                  label: 'ACTIVITY',
                  onTap: onTabSelected,
                ),
                _NavTab(
                  index: 3, // Profile is index 3
                  activeIndex: currentIndex,
                  activeIcon: Icons.person,
                  icon: Icons.person_outline,
                  label: 'PROFILE',
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
        ? const Color(0xFF10B981) // Neon/emerald green punch accent color
        : const Color(0xFF9CA3AF);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          // For the "SPACES" active glow effect shown in the image
          decoration: BoxDecoration(
            color: _isActive && index == 0
                ? const Color(0x3310B981) // Transparent green punch wash
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isActive && index == 0
                ? [
                    const BoxShadow(
                      color: Color(0x3310B981),
                      blurRadius: 16,
                      spreadRadius: 8,
                    )
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (index == 3)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isActive ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                      width: 1.5,
                    ),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: NetworkImage('https://i.pravatar.cc/100'),
                            fit: BoxFit.cover,
                          ),
                  ),
                )
              else
                Icon(
                  _isActive ? activeIcon : icon,
                  size: 24,
                  color: color,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
