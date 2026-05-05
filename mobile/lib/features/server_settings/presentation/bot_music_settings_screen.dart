import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

class BotMusicSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotMusicSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BotMusicSettingsScreen> createState() => _BotMusicSettingsScreenState();
}

class _BotMusicSettingsScreenState extends ConsumerState<BotMusicSettingsScreen> {
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
          .from('music_settings')
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
            .from('music_settings')
            .update({'enabled': enabled})
            .eq('server_id', widget.serverId);
      } else {
        await Supabase.instance.client
            .from('music_settings')
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
      
      appBar: AppBar(
        
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text('🎵', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              'Music Bot',
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
              'Play music in voice channels with queue management and controls.',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Status', [
            SwitchListTile(
              title: Text('Enable Music Bot', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Text('Allow music playback in voice channels', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12)),
              value: _settings?['enabled'] ?? false,
              onChanged: _toggleEnabled,
              activeThumbColor: const Color(FlickoColors.blurple),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Settings', [
            _buildInfoField('Default Volume', '${_settings?['default_volume'] ?? 75}%'),
            _buildInfoField('Queue Limit', '${_settings?['queue_limit'] ?? 50} songs'),
            _buildInfoField('DJ Role', _settings?['dj_role_id'] != null ? 'Configured' : 'None'),
          ]),
          const SizedBox(height: 24),
          _buildSection('Features', [
            _buildToggleField('Auto-play', 'Auto-play next song in queue', _settings?['auto_play'] ?? true),
            _buildToggleField('Loop Queue', 'Loop the entire queue', _settings?['loop_queue'] ?? false),
            _buildToggleField('Song Requests', 'Allow users to request songs', _settings?['allow_requests'] ?? true),
            _buildToggleField('Lyrics Display', 'Show lyrics for songs', _settings?['show_lyrics'] ?? false),
          ]),
          const SizedBox(height: 24),
          _buildSection('Commands', [
            _buildInfoField('/play [song]', 'Play a song'),
            _buildInfoField('/skip', 'Skip current song'),
            _buildInfoField('/queue', 'Show the queue'),
            _buildInfoField('/volume [0-100]', 'Set volume'),
            _buildInfoField('/pause', 'Pause playback'),
            _buildInfoField('/resume', 'Resume playback'),
            _buildInfoField('/clear', 'Clear the queue'),
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
