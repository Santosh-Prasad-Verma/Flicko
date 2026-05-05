import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Server Settings Hub Screen
///
/// Main navigation hub for all server settings.
/// Mirrors the React Native Server Settings index screen.
/// Supports permission-based filtering of settings options.
class ServerSettingsHubScreen extends ConsumerWidget {
  final String serverId;

  const ServerSettingsHubScreen({
    super.key,
    required this.serverId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Fetch server data and user permissions
    final serverName = 'My Server'; // Placeholder
    final isOwner = true; // Placeholder
    final hasPermission = (String permission) => true; // Placeholder

    // All settings sections with their items
    final sections = _buildSettingsSections(
      context: context,
      serverId: serverId,
      isOwner: isOwner,
      hasPermission: hasPermission,
    );

    // Filter sections based on permissions
    final visibleSections = sections.map((section) {
      final visibleItems = section.items.where((item) {
        // Server delete is owner-only
        if (item.id == 'delete') return isOwner;
        // Check required permission
        if (item.requiredPermission == null) return true;
        return hasPermission(item.requiredPermission!);
      }).toList();
      return section.copyWith(items: visibleItems);
    }).where((s) => s.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: const Color(FlickoColors.bgSecondary),
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Settings',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  serverName,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Settings sections
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = visibleSections[index];
                return _buildSection(context, section);
              },
              childCount: visibleSections.length,
            ),
          ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<SettingsSection> _buildSettingsSections({
    required BuildContext context,
    required String serverId,
    required bool isOwner,
    required Function(String) hasPermission,
  }) {
    return [
      // Server Basics
      SettingsSection(
        title: 'Server Basics',
        items: [
          SettingsItem(
            id: 'overview',
            icon: Icons.info_outline,
            label: 'Overview',
            route: '/server/$serverId/settings/overview',
            description: 'Server name, icon, and basic info',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'channels',
            icon: Icons.folder_outlined,
            label: 'Channels',
            route: '/server/$serverId/settings/channels',
            description: 'Create, edit, and organize channels',
            requiredPermission: 'MANAGE_CHANNELS',
          ),
          SettingsItem(
            id: 'roles',
            icon: Icons.badge_outlined,
            label: 'Roles',
            route: '/server/$serverId/settings/roles',
            description: 'Manage server roles and permissions',
            requiredPermission: 'MANAGE_ROLES',
          ),
          SettingsItem(
            id: 'emojis',
            icon: Icons.emoji_emotions_outlined,
            label: 'Emoji',
            route: '/server/$serverId/settings/emojis',
            description: 'Upload and manage custom emojis',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
          SettingsItem(
            id: 'stickers',
            icon: Icons.image_outlined,
            label: 'Stickers',
            route: '/server/$serverId/settings/stickers',
            description: 'Upload and manage stickers',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
        ],
      ),

      // Moderation
      SettingsSection(
        title: 'Moderation',
        items: [
          SettingsItem(
            id: 'moderation',
            icon: Icons.shield_outlined,
            label: 'Safety Setup',
            route: '/server/$serverId/settings/moderation',
            description: 'Verification level, content filter',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'automod',
            icon: Icons.auto_fix_high,
            label: 'AutoMod',
            route: '/server/$serverId/settings/automod',
            description: 'Automated moderation rules',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'audit-log',
            icon: Icons.receipt_long_outlined,
            label: 'Audit Log',
            route: '/server/$serverId/settings/audit-log',
            description: 'View all administrative actions',
            requiredPermission: 'VIEW_AUDIT_LOG',
          ),
          SettingsItem(
            id: 'bans',
            icon: Icons.gavel_outlined,
            label: 'Bans',
            route: '/server/$serverId/settings/bans',
            description: 'View and manage banned members',
            requiredPermission: 'BAN_MEMBERS',
          ),
          SettingsItem(
            id: 'invites',
            icon: Icons.link_outlined,
            label: 'Invites',
            route: '/server/$serverId/settings/invites',
            description: 'View and manage server invites',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),

      // Integrations
      SettingsSection(
        title: 'Integrations',
        items: [
          SettingsItem(
            id: 'bots',
            icon: Icons.memory_outlined,
            label: 'Bots',
            route: '/server/$serverId/settings/bots',
            description: 'Manage server bots and automation',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'webhooks',
            icon: Icons.code_outlined,
            label: 'Webhooks',
            route: '/server/$serverId/settings/webhooks',
            description: 'Manage incoming webhooks',
            requiredPermission: 'MANAGE_WEBHOOKS',
          ),
          SettingsItem(
            id: 'events',
            icon: Icons.event_outlined,
            label: 'Events',
            route: '/server/$serverId/settings/events',
            description: 'Create and manage scheduled events',
            requiredPermission: 'MANAGE_EVENTS',
          ),
        ],
      ),

      // Community
      SettingsSection(
        title: 'Community',
        items: [
          SettingsItem(
            id: 'onboarding',
            icon: Icons.rocket_launch_outlined,
            label: 'Onboarding',
            route: '/server/$serverId/settings/onboarding',
            description: 'Welcome screen and onboarding questions',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'templates',
            icon: Icons.description_outlined,
            label: 'Server Template',
            route: '/server/$serverId/settings/templates',
            description: 'Pre-made layouts and saves',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),

      // Danger Zone
      SettingsSection(
        title: 'Danger Zone',
        items: [
          SettingsItem(
            id: 'delete',
            icon: Icons.delete_outline,
            label: 'Delete Server',
            route: '/server/$serverId/settings/delete',
            description: 'Permanently delete this server',
            isDanger: true,
          ),
        ],
      ),
    ];
  }

  Widget _buildSection(BuildContext context, SettingsSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
          child: Text(
            section.title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Section items
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: section.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == section.items.length - 1;

              return Column(
                children: [
                  _buildSettingsItem(context, item),
                  if (!isLast)
                    const Divider(
                      color: Color(FlickoColors.bgTertiary),
                      height: 1,
                      indent: 56,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(BuildContext context, SettingsItem item) {
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 24,
              color: item.isDanger
                  ? const Color(FlickoColors.danger)
                  : const Color(FlickoColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      color: item.isDanger
                          ? const Color(FlickoColors.danger)
                          : const Color(FlickoColors.textPrimary),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(FlickoColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings Section Data Model
class SettingsSection {
  final String title;
  final List<SettingsItem> items;

  SettingsSection({
    required this.title,
    required this.items,
  });

  SettingsSection copyWith({String? title, List<SettingsItem>? items}) {
    return SettingsSection(
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}

/// Settings Item Data Model
class SettingsItem {
  final String id;
  final IconData icon;
  final String label;
  final String route;
  final String? description;
  final String? requiredPermission;
  final bool isDanger;

  SettingsItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.description,
    this.requiredPermission,
    this.isDanger = false,
  });
}
