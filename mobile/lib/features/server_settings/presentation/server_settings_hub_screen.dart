import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ServerSettingsHubScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerSettingsHubScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerSettingsHubScreen> createState() => _ServerSettingsHubScreenState();
}

class _ServerSettingsHubScreenState extends ConsumerState<ServerSettingsHubScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _serverData;
  bool _isOwner = false;
  String _memberRole = 'member';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServerData();
  }

  Future<void> _loadServerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      final currentUser = authState.maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('servers')
          .select('*, server_members!inner(roles)')
          .eq('id', widget.serverId)
          .eq('server_members.user_id', currentUser.id)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'You are not a member of this server';
          _isLoading = false;
        });
        return;
      }

      final isOwner = response['owner_id'] == currentUser.id;

      // Only the server owner can access server settings
      if (!isOwner && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the server owner can edit server settings'),
            backgroundColor: Color(FlickoColors.danger),
          ),
        );
        context.pop();
        return;
      }

      setState(() {
        _serverData = response;
        _isOwner = isOwner;
        _memberRole = response['server_members'][0]['roles']?.isNotEmpty == true ? 'member' : 'member';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading server: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    if (_isOwner) return true;
    if (_memberRole == 'admin') return true;
    if (_memberRole == 'moderator') {
      // Moderators have limited permissions
      return permission != 'MANAGE_GUILD' && 
             permission != 'MANAGE_ROLES' && 
             permission != 'MANAGE_WEBHOOKS' && 
             permission != 'BAN_MEMBERS' &&
             permission != 'DELETE_SERVER';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        body: const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
              const SizedBox(height: 16),
              Text('Error', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadServerData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final serverName = _serverData?['name'] as String? ?? 'Unknown Server';
    final sections = _buildSettingsSections(serverName);

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSection(context, sections[index]),
              childCount: sections.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<SettingsSection> _buildSettingsSections(String serverName) {
    final sections = <SettingsSection>[
      SettingsSection(
        title: 'Server Basics',
        items: [
          SettingsItem(
            id: 'overview',
            icon: Icons.info_outline,
            label: 'Overview',
            route: '/server/${widget.serverId}/settings/overview',
            description: 'Server name, icon, and basic info',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'channels',
            icon: Icons.folder_outlined,
            label: 'Channels',
            route: '/server/${widget.serverId}/settings/channels',
            description: 'Create, edit, and organize channels',
            requiredPermission: 'MANAGE_CHANNELS',
          ),
          SettingsItem(
            id: 'roles',
            icon: Icons.badge_outlined,
            label: 'Roles',
            route: '/server/${widget.serverId}/settings/roles',
            description: 'Manage server roles and permissions',
            requiredPermission: 'MANAGE_ROLES',
          ),
          SettingsItem(
            id: 'emojis',
            icon: Icons.emoji_emotions_outlined,
            label: 'Emoji',
            route: '/server/${widget.serverId}/settings/emojis',
            description: 'Upload and manage custom emojis',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
          SettingsItem(
            id: 'stickers',
            icon: Icons.image_outlined,
            label: 'Stickers',
            route: '/server/${widget.serverId}/settings/stickers',
            description: 'Upload and manage stickers',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
        ],
      ),
      SettingsSection(
        title: 'Moderation',
        items: [
          SettingsItem(
            id: 'moderation',
            icon: Icons.shield_outlined,
            label: 'Safety Setup',
            route: '/server/${widget.serverId}/settings/moderation',
            description: 'Verification level, content filter',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'automod',
            icon: Icons.auto_fix_high,
            label: 'AutoMod',
            route: '/server/${widget.serverId}/settings/automod',
            description: 'Automated moderation rules',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'audit-log',
            icon: Icons.receipt_long_outlined,
            label: 'Audit Log',
            route: '/server/${widget.serverId}/settings/audit-log',
            description: 'View all administrative actions',
            requiredPermission: 'VIEW_AUDIT_LOG',
          ),
          SettingsItem(
            id: 'bans',
            icon: Icons.gavel_outlined,
            label: 'Bans',
            route: '/server/${widget.serverId}/settings/bans',
            description: 'View and manage banned members',
            requiredPermission: 'BAN_MEMBERS',
          ),
          SettingsItem(
            id: 'invites',
            icon: Icons.link_outlined,
            label: 'Invites',
            route: '/server/${widget.serverId}/settings/invites',
            description: 'View and manage server invites',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),
      SettingsSection(
        title: 'Integrations',
        items: [
          SettingsItem(
            id: 'bots',
            icon: Icons.memory_outlined,
            label: 'Bots',
            route: '/server/${widget.serverId}/settings/bots',
            description: 'Manage server bots and automation',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'webhooks',
            icon: Icons.code_outlined,
            label: 'Webhooks',
            route: '/server/${widget.serverId}/settings/webhooks',
            description: 'Manage incoming webhooks',
            requiredPermission: 'MANAGE_WEBHOOKS',
          ),
          SettingsItem(
            id: 'events',
            icon: Icons.event_outlined,
            label: 'Events',
            route: '/server/${widget.serverId}/settings/events',
            description: 'Create and manage scheduled events',
            requiredPermission: 'MANAGE_EVENTS',
          ),
        ],
      ),
      SettingsSection(
        title: 'Community',
        items: [
          SettingsItem(
            id: 'onboarding',
            icon: Icons.rocket_launch_outlined,
            label: 'Onboarding',
            route: '/server/${widget.serverId}/settings/onboarding',
            description: 'Welcome screen and onboarding questions',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'templates',
            icon: Icons.description_outlined,
            label: 'Server Template',
            route: '/server/${widget.serverId}/settings/templates',
            description: 'Pre-made layouts and saves',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),
      SettingsSection(
        title: 'Danger Zone',
        items: [
          SettingsItem(
            id: 'delete',
            icon: Icons.delete_outline,
            label: 'Delete Server',
            route: '/server/${widget.serverId}/settings/delete',
            description: 'Permanently delete this server',
            requiredPermission: 'DELETE_SERVER',
            isDanger: true,
          ),
        ],
      ),
    ];

    // Filter sections and items based on permissions
    return sections.map((section) {
      final visibleItems = section.items.where((item) {
        if (item.requiredPermission == null) return true;
        return _hasPermission(item.requiredPermission!);
      }).toList();
      return SettingsSection(title: section.title, items: visibleItems);
    }).where((s) => s.items.isNotEmpty).toList();
  }

  Widget _buildSection(BuildContext context, SettingsSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

class SettingsSection {
  final String title;
  final List<SettingsItem> items;

  SettingsSection({
    required this.title,
    required this.items,
  });
}

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
