import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Notifications tab — displays real-time notifications with filter tabs.
///
/// Mirrors the React Native NotificationsTabScreen with filter
/// tabs (All, Mentions, DMs, Friends) and a notification list.
///
/// Current: structural placeholder with filter tabs and empty state.
/// TODO (Phase 5): Wire up Supabase `notifications` table query,
///   real-time subscription, and mark-as-read actions.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _activeTabIndex = 0;
  static const _tabs = ['All', 'Mentions', 'DMs', 'Friends'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 24),
                    color: const Color(FlickoColors.textPrimary),
                    onPressed: () {
                      // TODO: Navigate to search
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // TODO: Mark all as read
                    },
                    child: Text(
                      'Mark all read',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(FlickoColors.blurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter Tabs ──
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(FlickoColors.bgTertiary),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final isActive = _activeTabIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isActive
                                  ? const Color(FlickoColors.blurple)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _tabs[index],
                          style: textTheme.titleSmall?.copyWith(
                            color: isActive
                                ? const Color(FlickoColors.textPrimary)
                                : const Color(FlickoColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Content / Empty State ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgTertiary),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.notifications_off_outlined,
                        size: 40,
                        color: Color(FlickoColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: textTheme.titleLarge?.copyWith(
                        color: const Color(FlickoColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You're all caught up!\nNotifications will appear here.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(FlickoColors.textMuted),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
