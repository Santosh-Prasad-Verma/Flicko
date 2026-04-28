import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

class BotTicketSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotTicketSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BotTicketSettingsScreen> createState() => _BotTicketSettingsScreenState();
}

class _BotTicketSettingsScreenState extends ConsumerState<BotTicketSettingsScreen> {
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
          .from('ticket_settings')
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
            .from('ticket_settings')
            .update({'enabled': enabled})
            .eq('server_id', widget.serverId);
      } else {
        await Supabase.instance.client
            .from('ticket_settings')
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
            const Text('🎫', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              'Ticket Bot',
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
              'Create support tickets for users to get help from moderators.',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Status', [
            SwitchListTile(
              title: Text('Enable Ticket Bot', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Text('Allow users to create support tickets', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12)),
              value: _settings?['enabled'] ?? false,
              onChanged: _toggleEnabled,
              activeThumbColor: const Color(FlickoColors.blurple),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Settings', [
            _buildInfoField('Ticket Channel', _settings?['channel_id'] != null ? 'Configured' : 'Not set'),
            _buildInfoField('Support Role', _settings?['support_role_id'] != null ? 'Configured' : 'Not set'),
            _buildInfoField('Ticket Category', _settings?['category'] ?? 'General'),
          ]),
          const SizedBox(height: 24),
          _buildSection('Features', [
            _buildToggleField('Auto-close', 'Close tickets after inactivity', _settings?['auto_close'] ?? false),
            _buildToggleField('Transcripts', 'Save ticket transcripts', _settings?['save_transcripts'] ?? false),
          ]),
          const SizedBox(height: 24),
          _buildSection('Commands', [
            _buildInfoField('/ticket create', 'Create a new ticket'),
            _buildInfoField('/ticket close', 'Close current ticket'),
            _buildInfoField('/ticket add', 'Add user to ticket'),
            _buildInfoField('/ticket remove', 'Remove user from ticket'),
            _buildInfoField('/ticket rename', 'Rename ticket'),
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
