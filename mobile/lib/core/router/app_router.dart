import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/spike/spike_dashboard_screen.dart';
import 'package:mobile/features/spike/livekit_spike_screen.dart';
import 'package:mobile/features/spike/supabase_spike_screen.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/home/presentation/servers_screen.dart';
// NotificationsScreen imported from features/notifications instead
import 'package:mobile/features/shared/presentation/main_navigation_shell.dart';
import 'package:mobile/features/server_channels/chat/presentation/screens/chat_screen.dart';
import 'package:mobile/features/direct_messages/presentation/screens/dm_list_screen.dart';
import 'package:mobile/features/direct_messages/presentation/screens/dm_chat_screen.dart';
import 'package:mobile/features/direct_messages/presentation/screens/new_dm_screen.dart';
import 'package:mobile/features/direct_messages/presentation/screens/group_dm_list_screen.dart';
import 'package:mobile/features/server/presentation/create_server_screen.dart';
import 'package:mobile/features/server/presentation/discover_servers_screen.dart';
import 'package:mobile/features/server/presentation/server_members_screen.dart';
import 'package:mobile/features/search/presentation/search_screen.dart';
import 'package:mobile/features/settings/presentation/settings_screen.dart';
import 'package:mobile/features/settings/presentation/account_settings_screen.dart';
import 'package:mobile/features/settings/presentation/edit_profile_screen.dart';
import 'package:mobile/features/settings/presentation/appearance_settings_screen.dart';
import 'package:mobile/features/settings/presentation/privacy_settings_screen.dart';
import 'package:mobile/features/settings/presentation/chat_settings_screen.dart';
import 'package:mobile/features/ai_assistant/translate/presentation/translate_settings_screen.dart';
import 'package:mobile/features/settings/presentation/notifications_settings_screen.dart';
import 'package:mobile/features/settings/presentation/accessibility_settings_screen.dart';
import 'package:mobile/features/settings/presentation/voice_settings_screen.dart';
import 'package:mobile/features/settings/presentation/help_screen.dart';
import 'package:mobile/features/settings/presentation/faq_screen.dart';
import 'package:mobile/features/settings/presentation/terms_screen.dart';
import 'package:mobile/features/settings/presentation/privacy_policy_screen.dart';
import 'package:mobile/features/settings/presentation/language_screen.dart';
import 'package:mobile/features/settings/presentation/status_screen.dart';
import 'package:mobile/features/settings/presentation/server_profiles_screen.dart';
import 'package:mobile/features/settings/presentation/change_email_screen.dart';
import 'package:mobile/features/settings/presentation/change_username_screen.dart';
import 'package:mobile/features/settings/presentation/change_password_screen.dart';
import 'package:mobile/features/settings/presentation/billing_settings_screen.dart';
import 'package:mobile/features/settings/presentation/billing_history_screen.dart';
import 'package:mobile/features/e2ee/presentation/e2ee_settings_screen.dart';
import 'package:mobile/features/settings/presentation/share_profile_screen.dart';
import 'package:mobile/features/settings/presentation/about_developer_screen.dart';

// Premium
import 'package:mobile/features/premium/presentation/premium_billing_screen.dart';
import 'package:mobile/features/premium/presentation/add_card_screen.dart';

// Store & Creator
import 'package:mobile/features/store/presentation/store_screen.dart';
import 'package:mobile/features/store/presentation/cart_screen.dart';
import 'package:mobile/features/store/presentation/product_detail_screen.dart';
import 'package:mobile/features/store/presentation/inventory_screen.dart';
import 'package:mobile/features/store/presentation/theme_picker_screen.dart';
import 'package:mobile/features/store/presentation/myinstants_explorer_screen.dart';
import 'package:mobile/features/store/presentation/soundboard_creator_studio.dart';
import 'package:mobile/features/store/presentation/cosmetic_fusion_screen.dart';
import 'package:mobile/features/store/presentation/gacha_unboxing_screen.dart';
import 'package:mobile/features/store/presentation/avatar_decoration_store_screen.dart';
import 'package:mobile/features/store/presentation/nameplate_store_screen.dart';
import 'package:mobile/features/store/presentation/voice_skin_store_screen.dart';
import 'package:mobile/features/store/presentation/warp_drip_store_screen.dart';
import 'package:mobile/features/newz/presentation/news_feed_screen.dart';
import 'package:mobile/features/newz/presentation/news_detail_screen.dart';


// Friends
import 'package:mobile/features/friends/presentation/friend_requests_screen.dart';
import 'package:mobile/features/friends/presentation/friends_list_screen.dart';

// Server Settings
import 'package:mobile/features/server_settings/presentation/server_settings_hub_screen.dart';
import 'package:mobile/features/server_settings/presentation/server_overview_screen.dart';
import 'package:mobile/features/server_settings/presentation/placeholder_settings_screens.dart';
import 'package:mobile/features/server_settings/presentation/events_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/safety_setup_screen.dart';
import 'package:mobile/features/server_settings/presentation/emoji_management_screen.dart';
import 'package:mobile/features/server_settings/presentation/channels_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/roles_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/audit_log_screen.dart';
import 'package:mobile/features/server_settings/presentation/automod_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bans_screen.dart';
import 'package:mobile/features/server_settings/presentation/role_editor_screen.dart';
import 'package:mobile/features/server_settings/presentation/bots_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_welcome_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_ticket_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_starboard_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_poll_settings_screen.dart';
import 'package:mobile/features/server_channels/voice/presentation/screens/voice_activities_route_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_music_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_moderation_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_leveling_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_automod_settings_screen.dart';
import 'package:mobile/features/settings/presentation/storage_settings_screen.dart';
import 'package:mobile/features/search/presentation/advanced_search_screen.dart';
import 'package:mobile/features/server/presentation/server_onboarding_screen.dart';
import 'package:mobile/features/server/presentation/server_options_screen.dart';
import 'package:mobile/features/server_channels/presentation/create_channel_screen.dart';
import 'package:mobile/features/server_settings/presentation/boosts_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/invites_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/leaderboard_settings_screen.dart';
import 'package:mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:mobile/features/profile/presentation/profile_view_screen.dart';
import 'package:mobile/features/server_settings/presentation/webhooks_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/templates_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/onboarding_settings_screen.dart';
import 'package:mobile/features/server_settings/presentation/stickers_management_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_marketplace_screen.dart';
import 'package:mobile/features/server_settings/presentation/bot_developer_portal_screen.dart';

// Voice
import 'package:mobile/features/server_channels/voice/presentation/screens/voice_activities_screen.dart';
import 'package:mobile/features/server_channels/voice/presentation/screens/voice_channel_screen.dart';
import 'package:mobile/features/activities/watch_together/presentation/standalone_room_screen.dart';
import 'package:mobile/features/activities/watch_together/presentation/public_lobbies_screen.dart';
import 'package:mobile/features/activities/music_party/presentation/music_party_screen.dart';
import 'package:mobile/features/sonic_music/Screens/Home/home.dart' as sonic_music;
import 'package:mobile/features/sonic_music/theme/app_theme.dart' as sonic_theme;

// Gaming
import 'package:mobile/features/store/presentation/badge_alchemy_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/gaming_hub_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/matchmaking_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/ludo_game_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/game_launch_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/gaming_stats_screen.dart';

// Ludo (full feature)
import 'package:mobile/features/ludo/domain/ludo_state.dart' as ludo_dom;
import 'package:mobile/features/ludo/presentation/screens/ludo_home_screen.dart';
import 'package:mobile/features/ludo/presentation/screens/ludo_board_screen.dart';
import 'package:mobile/features/ludo/presentation/screens/ludo_matchmaking_screen.dart';
import 'package:mobile/features/ludo/presentation/screens/ludo_leaderboard_screen.dart';

// Forum
import 'package:mobile/features/server_channels/forum/presentation/screens/forum_channel_screen.dart' hide ThreadViewScreen;

// Stage
import 'package:mobile/features/server_channels/stage/presentation/screens/stage_channel_screen.dart';

// Thread
import 'package:mobile/features/server_channels/thread/presentation/screens/thread_view_screen.dart';

// Aura AI Assistant
import 'package:mobile/features/ai_assistant/presentation/aura_onboarding_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_dashboard_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_settings_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_chat_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_voice_screen.dart';

/// A [Listenable] that triggers when the Riverpod provider changes.
/// This allows [GoRouter] to rebuild/redirect without recreating the router provider itself,
/// which avoids duplicate [GlobalKey] conflicts.
class RiverpodRefreshListenable extends ChangeNotifier {
  RiverpodRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authNotifierProvider,
      (previous, next) {
        final wasAuthenticated = previous?.maybeWhen(
          authenticated: (_, __) => true,
          orElse: () => false,
        ) ?? false;

        final isAuthenticated = next.maybeWhen(
          authenticated: (_, __) => true,
          orElse: () => false,
        );

        if (wasAuthenticated != isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final serversNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'servers');
final dmsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dms');
final notificationsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'notifications');
final profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Provides the [GoRouter] instance to the entire app via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = RiverpodRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final isAuthRoute = [
        '/login',
        '/signup',
        '/register',
        '/forgot-password',
        '/reset-password'
      ].contains(location);
      final isSpikeRoute = location.startsWith('/spike');

      if (isSpikeRoute) return null;

      return authState.maybeWhen(
        authenticated: (_, __) {
          if (location == '/reset-password') return null;
          return isAuthRoute ? '/' : null;
        },
        unauthenticated: () => isAuthRoute ? null : '/login',
        orElse: () => null,
      );
    },
    routes: [
      // ── Main Tab Shell ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(
            currentIndex: navigationShell.currentIndex,
            onTabSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            currentLocation: state.matchedLocation,
            child: navigationShell,
          );
        },
        branches: [
          // Tab 0 — Servers (Home)
          StatefulShellBranch(
            navigatorKey: serversNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: const ValueKey('servers_tab_root'),
                  child: const ServersScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'server/:serverId/channel/:channelId',
                    builder: (context, state) => ChatScreen(
                      serverId: state.pathParameters['serverId']!,
                      channelId: state.pathParameters['channelId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'activities',
                        builder: (context, state) => VoiceActivitiesScreen(
                          serverId: state.pathParameters['serverId']!,
                          channelId: state.pathParameters['channelId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'forum',
                        builder: (context, state) => ForumChannelScreen(
                          serverId: state.pathParameters['serverId']!,
                          channelId: state.pathParameters['channelId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'stage',
                        builder: (context, state) => StageChannelScreen(
                          serverId: state.pathParameters['serverId']!,
                          channelId: state.pathParameters['channelId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'voice',
                        builder: (context, state) => VoiceChannelScreen(
                          serverId: state.pathParameters['serverId']!,
                          channelId: state.pathParameters['channelId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'activities',
                            builder: (context, state) => VoiceActivitiesRouteScreen(
                              serverId: state.pathParameters['serverId']!,
                              channelId: state.pathParameters['channelId']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'thread/:threadId',
                        builder: (context, state) => ThreadViewScreen(
                          serverId: state.pathParameters['serverId']!,
                          channelId: state.pathParameters['channelId']!,
                          threadId: state.pathParameters['threadId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'discover',
                    builder: (context, state) => const DiscoverServersScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Tab 1 — Messages
          StatefulShellBranch(
            navigatorKey: dmsNavigatorKey,
            routes: [
              GoRoute(
                path: '/dms',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: const ValueKey('dms_tab_root'),
                  child: const DMListScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewDMScreen(),
                  ),
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) => DMChatScreen(
                      userId: state.pathParameters['userId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'groups',
                    builder: (context, state) => const GroupDMListScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2 — Notifications
          StatefulShellBranch(
            navigatorKey: notificationsNavigatorKey,
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: const ValueKey('notifications_tab_root'),
                  child: const NotificationsScreen(),
                ),
              ),
            ],
          ),
          // Tab 3 — You (Profile)
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: const ValueKey('profile_tab_root'),
                  child: const _CurrentUserProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Auth Routes ──
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),

      // ── Server Routes ──
      GoRoute(path: '/server/create', builder: (context, state) => const CreateServerScreen()),
      GoRoute(
        path: '/server/:serverId',
        builder: (context, state) => ServerDetailScreen(serverId: state.pathParameters['serverId']!),
        routes: [
          GoRoute(
            path: 'members',
            builder: (context, state) => ServerMembersScreen(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => ServerSettingsHubScreen(
              serverId: state.pathParameters['serverId']!,
            ),
            routes: [
              GoRoute(path: 'overview', builder: (context, state) => ServerOverviewScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'channels', builder: (context, state) => ChannelsSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'roles', builder: (context, state) => RolesSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'roles/:roleId', builder: (context, state) => RoleEditorScreen(serverId: state.pathParameters['serverId']!, roleId: state.pathParameters['roleId']!)),
              GoRoute(path: 'emojis', builder: (context, state) => EmojiManagementScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'stickers', builder: (context, state) => StickersManagementScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'moderation', builder: (context, state) => SafetySetupScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'automod', builder: (context, state) => AutomodSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'audit-log', builder: (context, state) => AuditLogScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bans', builder: (context, state) => BansScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bots', builder: (context, state) => BotsSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bots/marketplace', builder: (context, state) => BotMarketplaceScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-welcome', builder: (context, state) => BotWelcomeSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-ticket', builder: (context, state) => BotTicketSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-starboard', builder: (context, state) => BotStarboardSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-poll', builder: (context, state) => BotPollSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-music', builder: (context, state) => BotMusicSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-moderation', builder: (context, state) => BotModerationSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-leveling', builder: (context, state) => BotLevelingSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'bot-automod', builder: (context, state) => BotAutomodSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'webhooks', builder: (context, state) => WebhooksSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'events', builder: (context, state) => EventsSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'onboarding', builder: (context, state) => OnboardingSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'templates', builder: (context, state) => TemplatesSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'delete', builder: (context, state) => DeleteServerScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'boosts', builder: (context, state) => BoostsSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'invites', builder: (context, state) => InvitesSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'leaderboard', builder: (context, state) => LeaderboardSettingsScreen(serverId: state.pathParameters['serverId']!)),
              GoRoute(path: 'developer-portal', builder: (context, state) => BotDeveloperPortalScreen(serverId: state.pathParameters['serverId']!)),
            ],
          ),
          GoRoute(
            path: 'channel/create',
            builder: (context, state) => CreateChannelScreen(serverId: state.pathParameters['serverId']!),
          ),
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => ServerOnboardingScreen(serverId: state.pathParameters['serverId']!),
          ),
          GoRoute(
            path: 'server-options',
            builder: (context, state) => ServerOptionsScreen(serverId: state.pathParameters['serverId']!),
          ),
        ],
      ),

      // Search
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/advanced-search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AdvancedSearchScreen(
          serverId: state.uri.queryParameters['serverId'],
          channelId: state.uri.queryParameters['channelId'],
        ),
      ),

      // Profile Settings — pinned to root navigator to prevent duplicate navigator key conflicts
      GoRoute(
        path: '/profile/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'account', builder: (context, state) => const AccountSettingsScreen()),
          GoRoute(path: 'edit-profile', builder: (context, state) => const EditProfileScreen()),
          GoRoute(path: 'share-profile', builder: (context, state) => const ShareProfileScreen()),
          GoRoute(path: 'appearance', builder: (context, state) => const AppearanceSettingsScreen()),
          GoRoute(path: 'privacy', builder: (context, state) => const PrivacySettingsScreen()),
          GoRoute(path: 'chat', builder: (context, state) => const ChatSettingsScreen()),
          GoRoute(path: 'translate', builder: (context, state) => const TranslateSettingsScreen()),
          GoRoute(path: 'notifications', builder: (context, state) => const NotificationsSettingsScreen()),
          GoRoute(path: 'voice', builder: (context, state) => const VoiceSettingsScreen()),
          GoRoute(path: 'accessibility', builder: (context, state) => const AccessibilitySettingsScreen()),
          GoRoute(
            path: 'help',
            builder: (context, state) => const HelpScreen(),
            routes: [
              GoRoute(path: 'faq', builder: (context, state) => const FAQScreen()),
              GoRoute(path: 'terms', builder: (context, state) => const TermsOfServiceScreen()),
              GoRoute(path: 'privacy-policy', builder: (context, state) => const PrivacyPolicyScreen()),
            ],
          ),
          GoRoute(path: 'language', builder: (context, state) => const LanguageScreen()),
          GoRoute(path: 'storage', builder: (context, state) => const StorageSettingsScreen()),
          GoRoute(path: 'status', builder: (context, state) => const StatusScreen()),
          GoRoute(path: 'server-profiles', builder: (context, state) => const ServerProfilesScreen()),
          GoRoute(path: 'change-email', builder: (context, state) => const ChangeEmailScreen()),
          GoRoute(path: 'change-username', builder: (context, state) => const ChangeUsernameScreen()),
          GoRoute(path: 'change-password', builder: (context, state) => const ChangePasswordScreen()),
          GoRoute(
            path: 'billing',
            builder: (context, state) => const BillingSettingsScreen(),
            routes: [
              GoRoute(path: 'history', builder: (context, state) => const BillingHistoryScreen()),
            ],
          ),
          GoRoute(
            path: 'sonic-drip',
            builder: (context, state) => Theme(
              data: sonic_theme.AppTheme.darkTheme(context: context),
              child: sonic_music.HomePage(),
            ),
          ),
          GoRoute(path: 'encryption', builder: (context, state) => const E2EESettingsScreen()),
          GoRoute(path: 'add-card', builder: (context, state) => const AddCardScreen()),
          GoRoute(path: 'about-developer', builder: (context, state) => const AboutDeveloperScreen()),
          GoRoute(
            path: 'aura',
            builder: (context, state) => const AuraOnboardingScreen(),
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const AuraDashboardScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const AuraSettingsScreen(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) {
                  final category = state.uri.queryParameters['category'] ?? 'Text Writer';
                  final sessionId = state.uri.queryParameters['sessionId'];
                  return AuraChatScreen(category: category, sessionId: sessionId);
                },
              ),
              GoRoute(
                path: 'voice',
                builder: (context, state) => const AuraVoiceScreen(),
              ),
            ],
          ),
        ],
      ),

      // Profile — pinned to root navigator to avoid collision with shell /profile branch
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ProfileViewScreen(userId: state.pathParameters['userId']!),
      ),

      // Friends
      GoRoute(
        path: '/friends',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FriendsListScreen(),
        routes: [
          GoRoute(path: 'requests', builder: (context, state) => const FriendRequestsScreen()),
        ],
      ),

      // Direct Messages - legacy /dm routes redirected to tab-based /dms
      GoRoute(
        path: '/dm',
        redirect: (context, state) => '/dms',
        routes: [
          GoRoute(
            path: ':conversationId',
            redirect: (context, state) => '/dms/${state.pathParameters['conversationId']}',
          ),
          GoRoute(
            path: 'groups',
            redirect: (context, state) => '/dms/groups',
          ),
        ],
      ),

      // Premium
      GoRoute(path: '/premium/plus', builder: (context, state) => const PremiumBillingScreen()),
      GoRoute(path: '/premium/nitro', builder: (context, state) => const PremiumBillingScreen()),

      // Watch Together
      GoRoute(path: '/watch-together/standalone', builder: (context, state) => const StandaloneRoomScreen()),
      GoRoute(path: '/watch-together/lobbies', builder: (context, state) => const PublicLobbiesScreen()),

      // Music Party
      GoRoute(
        path: '/music-party',
        builder: (context, state) {
          final roomId = state.uri.queryParameters['roomId'] ?? '';
          final sessionId = state.uri.queryParameters['sessionId'];
          return MusicPartyScreen(roomId: roomId, sessionId: sessionId);
        },
      ),

      // Store & Creator
      GoRoute(
        path: '/store',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const StoreScreen(),
        ),
      ),
      GoRoute(
        path: '/store/cart',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const CartScreen(),
        ),
      ),
      GoRoute(
        path: '/store/inventory',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const InventoryScreen(),
        ),
      ),
      GoRoute(
        path: '/store/themes',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const ThemePickerScreen(),
        ),
      ),
      GoRoute(
        path: '/store/myinstants',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const MyInstantsExplorerScreen(),
        ),
      ),
      GoRoute(
        path: '/store/sound-studio',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const SoundboardCreatorStudio(),
        ),
      ),
      GoRoute(
        path: '/store/fusion',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const CosmeticFusionScreen(),
        ),
      ),
      GoRoute(
        path: '/store/gacha',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const GachaUnboxingScreen(),
        ),
      ),
      GoRoute(
        path: '/store/decorations',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const AvatarDecorationStoreScreen(),
        ),
      ),
      GoRoute(
        path: '/store/nameplates',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const NameplateStoreScreen(),
        ),
      ),
      GoRoute(
        path: '/store/voice-skins',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const VoiceSkinStoreScreen(),
        ),
      ),
      GoRoute(
        path: '/store/warp-drips',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const WarpDripStoreScreen(),
        ),
      ),
      GoRoute(
        path: '/store/badge-alchemy',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const BadgeAlchemyScreen(),
        ),
      ),
      GoRoute(
        path: '/store/product/:productId',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: ProductDetailScreen(
            productId: state.pathParameters['productId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/news',
        redirect: (context, state) => '/newz',
      ),
      GoRoute(
        path: '/newz',
        builder: (context, state) => Theme(
          data: sonic_theme.AppTheme.darkTheme(context: context),
          child: const NewsFeedScreen(),
        ),
        routes: [
          GoRoute(
            path: 'article/:id',
            builder: (context, state) => Theme(
              data: sonic_theme.AppTheme.darkTheme(context: context),
              child: NewsDetailScreen(
                articleId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
      // Gaming
      GoRoute(path: '/gaming', builder: (context, state) => const GamingHubScreen()),
      GoRoute(path: '/gaming/launch', builder: (context, state) => const GameLaunchScreen()),
      GoRoute(path: '/gaming/stats', builder: (context, state) => const GamingStatsScreen()),
      GoRoute(
        path: '/gaming/matchmaking',
        builder: (context, state) => MatchmakingScreen(
          activityName: state.uri.queryParameters['activity'] ?? 'Ludo',
        ),
      ),
      GoRoute(
        path: '/gaming/ludo/:gameId',
        builder: (context, state) => LudoGameScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),

      // Ludo full feature (RN port)
      GoRoute(path: '/ludo', builder: (context, state) => const LudoHomeScreen()),
      GoRoute(
        path: '/ludo/play',
        builder: (context, state) {
          final modeName = state.uri.queryParameters['mode'] ?? 'localPass';
          final mode = ludo_dom.LudoMode.values.firstWhere(
            (m) => m.name == modeName,
            orElse: () => ludo_dom.LudoMode.localPass,
          );
          final seats = state.extra is List<ludo_dom.SeatConfig>
              ? state.extra as List<ludo_dom.SeatConfig>
              : null;
          return LudoBoardScreen(
            mode: mode,
            seats: seats,
            gameId: state.uri.queryParameters['gameId'],
          );
        },
      ),
      GoRoute(
        path: '/ludo/matchmaking',
        builder: (context, state) {
          final players =
              int.tryParse(state.uri.queryParameters['players'] ?? '2') ?? 2;
          final team = state.uri.queryParameters['team'] == 'true';
          return LudoMatchmakingScreen(players: players, team: team);
        },
      ),
      GoRoute(
        path: '/ludo/leaderboard',
        builder: (context, state) => const LudoLeaderboardScreen(),
      ),

      // ── Legacy /u/* alias routes — redirect to /profile/* ──
      // Some screens still link to /u/settings, /u/<userId>, etc. Keep them
      // working without duplicating the route tree.
      GoRoute(
        path: '/u',
        redirect: (context, state) => '/profile',
      ),
      GoRoute(
        path: '/u/settings',
        redirect: (context, state) => '/profile/settings',
      ),
      GoRoute(
        path: '/u/settings/:section',
        redirect: (context, state) =>
            '/profile/settings/${state.pathParameters['section']}',
      ),
      GoRoute(
        path: '/u/profile/:userId',
        redirect: (context, state) =>
            '/profile/${state.pathParameters['userId']}',
      ),
      GoRoute(
        path: '/u/:userId',
        redirect: (context, state) =>
            '/profile/${state.pathParameters['userId']}',
      ),

      // ── Spike / Dev Routes ──
      GoRoute(path: '/spike', builder: (context, state) => const SpikeDashboardScreen()),
      GoRoute(path: '/spike/livekit', builder: (context, state) => const LiveKitSpikeScreen()),
      GoRoute(path: '/spike/supabase', builder: (context, state) => const SupabaseSpikeScreen()),
    ],
  );
});

/// Wrapper that shows ProfileViewScreen for the currently logged-in user.
/// Used as the profile tab root so the new UI is shown instead of the old ProfileScreen.
class _CurrentUserProfileScreen extends ConsumerWidget {
  const _CurrentUserProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ProfileViewScreen(userId: userId);
  }
}
