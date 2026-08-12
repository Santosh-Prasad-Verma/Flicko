import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/server/data/invite_repository.dart';

class InviteModal extends ConsumerStatefulWidget {
  final String serverId;

  const InviteModal({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends ConsumerState<InviteModal> {
  bool _isLoading = true;
  ServerInvite? _invite;
  String? _errorMessage;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inviteRepositoryProvider);
      final invite = await repo.getOrCreateInvite(widget.serverId);
      if (mounted) {
        setState(() {
          _invite = invite;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_invite == null) return;
    Clipboard.setData(ClipboardData(text: _invite!.inviteUrl));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareLink() {
    if (_invite == null) return;
    Share.share(
      'Join our server on Flicko: ${_invite!.inviteUrl}',
      subject: 'Flicko Server Invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Friends to Server',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
              ),
            )
          else if (_errorMessage != null)
            Column(
              children: [
                Text(
                  'Failed to generate invite: $_errorMessage',
                  style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadInvite,
                  child: const Text('Retry'),
                ),
              ],
            )
          else ...[
            Text(
              'SHARE THIS LINK WITH OTHERS',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgPrimary),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(FlickoColors.bgTertiary)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _invite?.inviteUrl ?? '',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _copyToClipboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copied
                          ? const Color(FlickoColors.green)
                          : const Color(FlickoColors.blurple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _copied ? 'Copied' : 'Copy',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareLink,
                icon: const Icon(Icons.share, color: Color(FlickoColors.textPrimary)),
                label: Text(
                  'Share Link via Apps',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(FlickoColors.bgTertiary)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
