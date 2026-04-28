import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

class BotLevelingSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotLevelingSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BotLevelingSettingsScreen> createState() => _BotLevelingSettingsScreenState();
}

class _BotLevelingSettingsScreenState extends ConsumerState<BotLevelingSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _settings;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('level_settings')
          .select('*')
          .eq('server_id', widget.serverId)
          .maybeSingle();

      setState(() {
        _settings = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    try {
      if (_settings != null) {
        await Supabase.instance.client
            .from('level_settings')
            .update({'enabled': enabled})
            .eq('server_id', widget.serverId);
      } else {
        await Supabase.instance.client
            .from('level_settings')
            .insert({
              'server_id': widget.serverId,
              'enabled': enabled,
              'created_at': DateTime.now().toIso8601String(),
            });
      }
      await _loadSettings();
    } catch (e) {
      _showError('Failed to update settings: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(FlickoColors.danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              'Leveling Bot',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text('Error loading settings', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Award XP and levels to users based on their activity in the server.',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Status', [
            SwitchListTile(
              title: Text('Enable Leveling', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Text('Award XP for user activity', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12)),
              value: _settings?['enabled'] ?? false,
              onChanged: _toggleEnabled,
              activeThumbColor: const Color(FlickoColors.blurple),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Settings', [
            _buildInfoField('XP per Message', '${_settings?['xp_per_message'] ?? 15} XP'),
            _buildInfoField('XP per Voice Minute', '${_settings?['xp_per_voice'] ?? 5} XP'),
            _buildInfoField('Max Level', '${_settings?['max_level'] ?? 100}'),
            _buildInfoField('Cooldown', '${_settings?['cooldown'] ?? 60} seconds'),
          ]),
          const SizedBox(height: 24),
          _buildSection('Features', [
            _buildToggleField('Voice XP', 'Award XP for voice chat', _settings?['voice_xp'] ?? true),
            _buildToggleField('Message XP', 'Award XP for messages', _settings?['message_xp'] ?? true),
            _buildToggleField('Role Rewards', 'Assign roles at levels', _settings?['role_rewards'] ?? true),
            _buildToggleField('Announcements', 'Announce level ups', _settings?['announcements'] ?? true),
          ]),
          const SizedBox(height: 24),
          _buildSection('Commands', [
            _buildInfoField('/rank', 'Check your rank and XP'),
            _buildInfoField('/leaderboard', 'View the server leaderboard'),
            _buildInfoField('/level [user]', 'Check a user\'s level'),
            _buildInfoField('/setxp [user] [amount]', 'Set user XP (admin)'),
            _buildInfoField('/addrole [level] [role]', 'Add role reward'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Container(decoration: BoxDecoration(color: const Color(FlickoColors.bgSecondary), borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 14)),
          Text(value, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToggleField(String label, String hint, bool value) {
    return SwitchListTile(
      title: Text(label, style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 14)),
      subtitle: Text(hint, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12)),
      value: value,
      onChanged: (v) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label toggle - Coming Soon'))),
      activeThumbColor: const Color(FlickoColors.blurple),
    );
  }
}
