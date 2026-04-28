import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Invites Screen
///
/// Lists active invites with create/delete.
class InvitesScreen extends ConsumerStatefulWidget {
  final String serverId;
  const InvitesScreen({super.key, required this.serverId});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _Invite {
  final String id;
  final String code;
  final int uses;
  final int? maxUses;
  final String creatorName;
  final DateTime? expiresAt;

  _Invite({
    required this.id,
    required this.code,
    required this.uses,
    this.maxUses,
    required this.creatorName,
    this.expiresAt,
  });
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  bool _isLoading = true;
  List<_Invite> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('invites')
          .select('*, auth.users!inviter_id(username)')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _invites = (response as List).map((r) {
          final data = r as Map<String, dynamic>;
          final users = data['auth']?['users'] as Map<String, dynamic>?;
          return _Invite(
            id: data['id']?.toString() ?? data['code']?.toString() ?? '',
            code: data['code'] as String,
            uses: data['uses'] as int? ?? 0,
            maxUses: data['max_uses'] as int?,
            creatorName: users?['username'] as String? ?? 'Unknown',
            expiresAt: data['expires_at'] != null ? DateTime.parse(data['expires_at'] as String) : null,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invites: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _createInvite() async {
    try {
      final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 8).toUpperCase();
      final currentUserId = ref.read(currentUserIdProvider);
      
      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to create an invite'),
              backgroundColor: Color(FlickoColors.danger),
            ),
          );
        }
        return;
      }
      
      await Supabase.instance.client
          .from('invites')
          .insert({
            'server_id': widget.serverId,
            'code': code,
            'inviter_id': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'uses': 0,
          });

      await _loadInvites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite created: $code'),
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

  void _shareInvite(_Invite invite) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('flicko.app/invite/${invite.code}')),
    );
  }

  void _deleteInvite(_Invite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Invite?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'Invite ${invite.code} will be permanently deleted.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.danger)),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('invites')
          .delete()
          .eq('id', invite.id);
      
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
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _invites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_off, size: 48, color: Color(FlickoColors.textMuted)),
                      const SizedBox(height: 16),
                      Text(
                        'No invites yet',
                        style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an invite to share this server',
                        style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createInvite,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Invite'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invites.length,
                  itemBuilder: (context, index) => _buildInviteCard(_invites[index]),
                ),
    );
  }

  Widget _buildInviteCard(_Invite invite) {
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
                  invite.code,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.blurple),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share, color: Color(FlickoColors.textMuted)),
                onPressed: () => _shareInvite(invite),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(FlickoColors.danger)),
                onPressed: () => _deleteInvite(invite),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 8),
              Text(
                'Created by ${invite.creatorName}',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.people, size: 16, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 8),
              Text(
                '${invite.uses} uses${invite.maxUses != null ? ' / ${invite.maxUses}' : ''}',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (invite.expiresAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Color(FlickoColors.textMuted)),
                const SizedBox(width: 8),
                Text(
                  'Expires: ${_formatDate(invite.expiresAt!)}',
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
