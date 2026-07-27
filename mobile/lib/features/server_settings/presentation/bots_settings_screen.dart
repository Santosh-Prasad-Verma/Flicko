import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class BotInfo {
  final String name;
  final String displayName;
  final String description;
  final String avatar;
  final bool enabled;

  BotInfo({
    required this.name,
    required this.displayName,
    required this.description,
    required this.avatar,
    required this.enabled,
  });
}

class BotsSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotsSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BotsSettingsScreen> createState() => _BotsSettingsScreenState();
}

class _BotsSettingsScreenState extends ConsumerState<BotsSettingsScreen> {
  bool _isLoading = true;
  List<BotInfo> _bots = [];
  String? _errorMessage;

  // Available bots configuration
  final List<Map<String, dynamic>> _availableBots = [
    {
      'name': 'moderation',
      'displayName': 'Moderation Bot',
      'description': 'Automatically moderate messages and warn users',
      'avatar': '🛡️',
      'table': 'mod_settings',
    },
    {
      'name': 'automod',
      'displayName': 'AutoMod',
      'description': 'Advanced automated moderation with custom rules',
      'avatar': '🤖',
      'table': 'automod_settings',
    },
    {
      'name': 'welcome',
      'displayName': 'Welcome Bot',
      'description': 'Greet new members with custom messages',
      'avatar': '👋',
      'table': 'welcome_settings',
    },
    {
      'name': 'leveling',
      'displayName': 'Leveling Bot',
      'description': 'Award XP and levels for user activity',
      'avatar': '⭐',
      'table': 'level_settings',
    },
    {
      'name': 'ticket',
      'displayName': 'Ticket Bot',
      'description': 'Create support tickets for users',
      'avatar': '🎫',
      'table': 'ticket_settings',
    },
    {
      'name': 'starboard',
      'displayName': 'Starboard Bot',
      'description': 'Save starred messages to a channel',
      'avatar': '⭐',
      'table': 'starboard_settings',
    },
    {
      'name': 'music',
      'displayName': 'Music Bot',
      'description': 'Play music in voice channels',
      'avatar': '🎵',
      'table': 'music_settings',
    },
    // Note: 'poll' is intentionally omitted — there is no poll_settings table.
    // Polls are stateless per-message; nothing to toggle on a server level.
  ];

  @override
  void initState() {
    super.initState();
    _loadBotStatuses();
  }

  Future<void> _loadBotStatuses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<BotInfo> bots = [];

      for (var botConfig in _availableBots) {
        final tableName = botConfig['table'] as String;
        bool enabled = false;

        try {
          final response = await Supabase.instance.client
              .from(tableName)
              .select('enabled')
              .eq('server_id', widget.serverId)
              .maybeSingle();

          if (response != null) {
            enabled = response['enabled'] as bool? ?? false;
          }
        } catch (e) {
          // If table doesn't exist or no settings, bot is disabled by default
          enabled = false;
        }

        bots.add(BotInfo(
          name: botConfig['name'] as String,
          displayName: botConfig['displayName'] as String,
          description: botConfig['description'] as String,
          avatar: botConfig['avatar'] as String,
          enabled: enabled,
        ));
      }

      setState(() {
        _bots = bots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBot(BotInfo bot, bool enabled) async {
    // HIGH-11: Route through the backend API so the server-side permission
    // check (server owner OR MANAGE_GUILD) runs and audits the change.
    // Falls back to direct Supabase write only for development environments
    // where AppConfig.apiBaseUrl is not set.
    try {
      if (AppConfig.hasApiBaseUrl) {
        await _toggleBotViaApi(bot, enabled);
      } else {
        await _toggleBotViaSupabase(bot, enabled);
      }
      await _loadBotStatuses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle bot: ${e.toString()}'),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
    }
  }

  Future<void> _toggleBotViaApi(BotInfo bot, bool enabled) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated');
    }
    final base = AppConfig.apiBaseUrl;
    final uri = Uri.parse(
      '${base.endsWith('/') ? base : '$base/'}servers/${widget.serverId}/bots/${bot.name}/settings',
    );
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({'enabled': enabled}),
    );
    if (response.statusCode == 403) {
      throw Exception('You need MANAGE_GUILD permission to change bot settings');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> _toggleBotViaSupabase(BotInfo bot, bool enabled) async {
    final botConfig = _availableBots.firstWhere((b) => b['name'] == bot.name);
    final tableName = botConfig['table'] as String;

    final existing = await Supabase.instance.client
        .from(tableName)
        .select('*')
        .eq('server_id', widget.serverId)
        .maybeSingle();

    if (existing != null) {
      await Supabase.instance.client
          .from(tableName)
          .update({'enabled': enabled})
          .eq('server_id', widget.serverId);
    } else {
      await Supabase.instance.client.from(tableName).insert({
        'server_id': widget.serverId,
        'enabled': enabled,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  void _handleBotPress(BotInfo bot) {
    context.push('/server/${widget.serverId}/settings/bot-${bot.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Bots',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(FlickoColors.blurple),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text(
              'Error loading bots',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBotStatuses,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Marketplace Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5865F2), Color(0xFF4752C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5865F2).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'App Directory',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Discover new bots, AI agents, and tools to enhance your server.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/server/${widget.serverId}/settings/bots/marketplace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5865F2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Explore Marketplace',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Description box
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, color: Color(FlickoColors.blurple), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable bots to add moderation, leveling, tickets and more to your server. Tap a bot to configure its settings.',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bot list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _bots.length,
            itemBuilder: (context, index) => _buildBotCard(_bots[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildBotCard(BotInfo bot) {
    return GestureDetector(
      onTap: () => _handleBotPress(bot),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      bot.avatar,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bot.displayName,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bot.description,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: bot.enabled,
                  onChanged: (value) => _toggleBot(bot, value),
                  activeThumbColor: const Color(FlickoColors.blurple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bot.enabled
                        ? const Color(0x1F43B581)
                        : const Color(FlickoColors.bgTertiary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bot.enabled ? 'Active' : 'Inactive',
                    style: GoogleFonts.inter(
                      color: bot.enabled
                          ? const Color(0xFF43B581)
                          : const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(FlickoColors.textMuted),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
