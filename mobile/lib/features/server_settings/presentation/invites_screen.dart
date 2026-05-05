import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Invites Screen
///
/// Lists active invites with create/delete.
/// Route: /server/:serverId/settings/invites
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
  final String? creatorName;
  final DateTime? expiresAt;

  _Invite({
    required this.id,
    required this.code,
    required this.uses,
    this.maxUses,
    this.creatorName,
    this.expiresAt,
  });
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  bool _isLoading = true;
  List<_Invite> _invites = [];
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      // Mock data — replace with Supabase query when invites table exists
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _invites = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvite() async {
    // Mock — generate a random code
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 8).toUpperCase();
    setState(() {
      _invites.insert(0, _Invite(id: code, code: code, uses: 0));
    });
  }

  void _shareInvite(_Invite invite) {
    // In real app, use share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('flicko.app/invite/${invite.code}')),
    );
  }

  void _deleteInvite(_Invite invite) {
    showDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _invites.removeWhere((i) => i.id == invite.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.red)),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
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
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(FlickoColors.blurple)),
            onPressed: _createInvite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _invites.isEmpty
              ? Center(
                  child: Text(
                    'No invites',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _invites.length,
                  itemBuilder: (context, index) {
                    final invite = _invites[index];
                    final expired = invite.expiresAt != null && invite.expiresAt!.isBefore(DateTime.now());
                    return Opacity(
                      opacity: expired ? 0.5 : 1,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgSecondary),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.code,
                                    style: GoogleFonts.inter(
                                      color: const Color(FlickoColors.blurple),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${invite.uses}${invite.maxUses != null ? '/${invite.maxUses}' : ''} uses'
                                    '${invite.creatorName != null ? ' \u2022 by ${invite.creatorName}' : ''}'
                                    '${expired ? ' \u2022 Expired' : ''}',
                                    style: GoogleFonts.inter(
                                      color: const Color(FlickoColors.textMuted),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 18, color: Color(FlickoColors.textSecondary)),
                              onPressed: () => _shareInvite(invite),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(FlickoColors.red)),
                              onPressed: () => _deleteInvite(invite),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
