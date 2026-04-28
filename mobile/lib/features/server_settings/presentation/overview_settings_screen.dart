import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

class OverviewSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const OverviewSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<OverviewSettingsScreen> createState() => _OverviewSettingsScreenState();
}

class _OverviewSettingsScreenState extends ConsumerState<OverviewSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _serverData;
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
      final response = await Supabase.instance.client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'Server not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _serverData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading server data: ${e.toString()}';
        _isLoading = false;
      });
    }
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
        title: Text(
          'Overview',
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
            Text('Error loading server', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadServerData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServerInfo(),
          const SizedBox(height: 24),
          _buildSection('SERVER INFORMATION', [
            _buildInfoRow('Server ID', _serverData?['id'] ?? 'Unknown'),
            _buildInfoRow('Created', _formatDate(_serverData?['created_at'])),
            _buildInfoRow('Owner', _serverData?['owner_id'] ?? 'Unknown'),
          ]),
          const SizedBox(height: 24),
          _buildSection('PREFERENCES', [
            _buildToggleRow('Explicit Content Filter', 'Filter explicit content', true),
            _buildToggleRow('Verification Level', 'Require verification', false),
          ]),
        ],
      ),
    );
  }

  Widget _buildServerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: _serverData?['icon'] != null ? NetworkImage(_serverData!['icon'] as String) : null,
            child: _serverData?['icon'] == null
                ? Text(
                    _serverData?['name']?[0] ?? '?',
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 24),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serverData?['name'] ?? 'Unknown',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_serverData?['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _serverData!['description'] as String,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, String description, bool value) {
    return SwitchListTile(
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: (v) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label - Coming Soon')),
        );
      },
      activeThumbColor: const Color(FlickoColors.blurple),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}
