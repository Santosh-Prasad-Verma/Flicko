import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class InvitesSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const InvitesSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<InvitesSettingsScreen> createState() => _InvitesSettingsScreenState();
}

class _InvitesSettingsScreenState extends ConsumerState<InvitesSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invites = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('invites')
          .select('*, profiles(username, display_name, avatar_url:avatar)')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _invites = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createInvite() async {
    try {
      final response = await Supabase.instance.client
          .from('invites')
          .insert({
            'server_id': widget.serverId,
            'code': _generateInviteCode(),
            'created_by': Supabase.instance.client.auth.currentUser?.id,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          })
          .select()
          .single();

      await _loadInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite created: ${response['code']}'),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create invite: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  String _generateInviteCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 8; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }

  Future<void> _deleteInvite(String inviteId) async {
    try {
      await Supabase.instance.client
          .from('invites')
          .delete()
          .or('id.eq.$inviteId,code.eq.$inviteId');

      await _loadInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite deleted'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete invite: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
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
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Invites',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: _createInvite,
          ),
        ],
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
            Text('Error loading invites', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadInvites, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text('No invites yet', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Create an invite to share this server', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createInvite,
              icon: const Icon(Icons.add),
              label: const Text('Create Invite'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invites.length,
        itemBuilder: (context, index) => _buildInviteCard(_invites[index]),
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final profile = invite['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] ?? 'Unknown';
    final code = invite['code'] as String;
    final createdAt = invite['created_at'] as String?;
    final expiresAt = invite['expires_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.blurple),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Color(FlickoColors.brandLime)),
                onPressed: () {
                  final link = 'https://flicko.app/invite/$code';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invite link copied: $link'),
                      backgroundColor: const Color(FlickoColors.success),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(FlickoColors.danger)),
                onPressed: () => _deleteInvite(invite['id'] as String),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 8),
              Text(
                'Created by $username',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 8),
              Text(
                createdAt != null ? _formatDate(createdAt) : '',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Color(FlickoColors.textMuted)),
                const SizedBox(width: 8),
                Text(
                  'Expires: ${_formatDate(expiresAt)}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}
