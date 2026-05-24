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
import 'package:mobile/features/settings/presentation/notifications_settings_screen.dart';
import 'package:mobile/features/settings/presentation/accessibility_settings_screen.dart';
import 'package:mobile/features/settings/presentation/voice_settings_screen.dart';
import 'package:mobile/features/settings/presentation/help_screen.dart';
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
import 'package:mobile/features/store/presentation/badge_alchemy_screen.dart';
import 'package:mobile/features/creator/presentation/creator_screen.dart';
import 'package:mobile/features/creator/presentation/screens/creator_profile_screen.dart';
import 'package:mobile/features/creator/presentation/screens/creator_thread_screen.dart';

// Friends
import 'package:mobile/features/friends/presentation/friend_requests_screen.dart';
import 'package:mobile/features/friends/presentation/friends_list_screen.dart';

// Server Settings
import 'package:mobile/features/server_settings/presentation/server_settings_hub_screen.dart';
import 'package:mobile/features/server_settings/presentation/server_overview_screen.dart';
import 'package:mobile/features/server_settings/presentation/placeholder_settings_screens.dart' hide BotsSettingsScreen, WebhooksSettingsScreen, OnboardingSettingsScreen, TemplatesSettingsScreen, EmojisSettingsScreen, ModerationSettingsScreen;
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

// Voice
import 'package:mobile/features/server_channels/voice/presentation/screens/voice_activities_screen.dart';
import 'package:mobile/features/server_channels/voice/presentation/screens/voice_channel_screen.dart';
import 'package:mobile/features/sonic_music/Screens/Home/home.dart';

// Gaming
import 'package:mobile/features/gaming/presentation/screens/gaming_hub_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/matchmaking_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/chess_game_screen.dart';
import 'package:mobile/features/gaming/presentation/screens/ludo_game_screen.dart';

// Forum
import 'package:mobile/features/server_channels/forum/presentation/screens/forum_channel_screen.dart' hide ThreadViewScreen;

// Stage
import 'package:mobile/features/server_channels/stage/presentation/screens/stage_channel_screen.dart';

// Thread
import 'package:mobile/features/server_channels/thread/presentation/screens/thread_view_screen.dart';

// Aura AI Assistant
import 'package:mobile/features/ai_assistant/presentation/aura_dashboard_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_chat_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_voice_screen.dart';

/// The global navigation key for the root navigator.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provides the [GoRouter] instance to the entire app via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
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
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ServersScreen(),
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
            routes: [
              GoRoute(
                path: '/dms',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DMListScreen(),
                ),
                routes: [
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
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: NotificationsScreen(),
                ),
              ),
            ],
          ),
          // Tab 3 — You (Profile)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: _CurrentUserProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(path: 'account', builder: (context, state) => const AccountSettingsScreen()),
                      GoRoute(path: 'edit-profile', builder: (context, state) => const EditProfileScreen()),
                      GoRoute(path: 'share-profile', builder: (context, state) => const ShareProfileScreen()),
                      GoRoute(path: 'appearance', builder: (context, state) => const AppearanceSettingsScreen()),
                      GoRoute(path: 'privacy', builder: (context, state) => const PrivacySettingsScreen()),
                      GoRoute(path: 'chat', builder: (context, state) => const ChatSettingsScreen()),
                      GoRoute(path: 'notifications', builder: (context, state) => const NotificationsSettingsScreen()),
                      GoRoute(path: 'voice', builder: (context, state) => const VoiceSettingsScreen()),
                      GoRoute(path: 'accessibility', builder: (context, state) => const AccessibilitySettingsScreen()),
                      GoRoute(path: 'help', builder: (context, state) => const HelpScreen()),
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
                      GoRoute(path: 'sonic-drip', builder: (context, state) => HomePage()),
                      GoRoute(path: 'encryption', builder: (context, state) => const E2EESettingsScreen()),
                      GoRoute(path: 'add-card', builder: (context, state) => const AddCardScreen()),
                      GoRoute(path: 'about-developer', builder: (context, state) => const AboutDeveloperScreen()),
                      GoRoute(
                        path: 'aura',
                        builder: (context, state) => const AuraDashboardScreen(),
                        routes: [
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
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) => ProfileViewScreen(
                      userId: state.pathParameters['userId']!,
                    ),
                  ),
                ],
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
        builder: (context, state) => const ServerDetailScreen(),
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
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: '/advanced-search',
        builder: (context, state) => AdvancedSearchScreen(
          serverId: state.uri.queryParameters['serverId'],
          channelId: state.uri.queryParameters['channelId'],
        ),
      ),

      // Notifications
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

      // Profile
      GoRoute(path: '/profile/:userId', builder: (context, state) => ProfileViewScreen(userId: state.pathParameters['userId']!)),

      // Friends
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsListScreen(),
        routes: [
          GoRoute(path: 'requests', builder: (context, state) => const FriendRequestsScreen()),
        ],
      ),

      // Direct Messages
      GoRoute(
        path: '/dm',
        builder: (context, state) => const DMListScreen(),
        routes: [
          GoRoute(path: ':conversationId', builder: (context, state) => DMChatScreen(userId: state.pathParameters['conversationId']!)),
          GoRoute(
            path: 'groups',
            builder: (context, state) => const GroupDMListScreen(),
          ),
        ],
      ),

      // Premium
      GoRoute(path: '/premium/plus', builder: (context, state) => const PremiumBillingScreen()),
      GoRoute(path: '/premium/nitro', builder: (context, state) => const PremiumBillingScreen()),

      // Store & Creator
      GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
      GoRoute(path: '/store/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/store/inventory', builder: (context, state) => const InventoryScreen()),
      GoRoute(path: '/store/themes', builder: (context, state) => const ThemePickerScreen()),
      GoRoute(path: '/store/myinstants', builder: (context, state) => const MyInstantsExplorerScreen()),
      GoRoute(path: '/store/sound-studio', builder: (context, state) => const SoundboardCreatorStudio()),
      GoRoute(path: '/store/fusion', builder: (context, state) => const CosmeticFusionScreen()),
      GoRoute(path: '/store/gacha', builder: (context, state) => const GachaUnboxingScreen()),
      GoRoute(path: '/store/decorations', builder: (context, state) => const AvatarDecorationStoreScreen()),
      GoRoute(path: '/store/nameplates', builder: (context, state) => const NameplateStoreScreen()),
      GoRoute(path: '/store/voice-skins', builder: (context, state) => const VoiceSkinStoreScreen()),
      GoRoute(path: '/store/warp-drips', builder: (context, state) => const WarpDripStoreScreen()),
      GoRoute(path: '/store/badge-alchemy', builder: (context, state) => const BadgeAlchemyScreen()),
      GoRoute(
        path: '/store/product/:productId',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(
        path: '/creator',
        builder: (context, state) => const CreatorScreen(),
        routes: [
          GoRoute(
            path: 'posts/:id',
            builder: (context, state) => CreatorThreadScreen(
              postId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'profile/:id',
            builder: (context, state) => CreatorProfileScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Gaming
      GoRoute(path: '/gaming', builder: (context, state) => const GamingHubScreen()),
      GoRoute(
        path: '/gaming/matchmaking',
        builder: (context, state) => MatchmakingScreen(
          activityName: state.uri.queryParameters['activity'] ?? 'Chess',
        ),
      ),
      GoRoute(
        path: '/gaming/chess/:gameId',
        builder: (context, state) => ChessGameScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/gaming/ludo/:gameId',
        builder: (context, state) => LudoGameScreen(
          gameId: state.pathParameters['gameId']!,
        ),
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
        path: '/u/:userId',
        redirect: (context, state) =>
            '/profile/${state.pathParameters['userId']}',
      ),
      GoRoute(
        path: '/u/profile/:userId',
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
