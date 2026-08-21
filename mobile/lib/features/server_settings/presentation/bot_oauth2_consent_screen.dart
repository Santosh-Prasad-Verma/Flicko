import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Bot OAuth2 Consent Screen
/// Authorization screen listing requested scopes (Read Messages, Manage Webhooks, Trigger Commands) before installing to server.
class BotOAuth2ConsentScreen extends StatefulWidget {
  final String serverId;
  final String botId;

  const BotOAuth2ConsentScreen({
    super.key,
    required this.serverId,
    required this.botId,
  });

  @override
  State<BotOAuth2ConsentScreen> createState() => _BotOAuth2ConsentScreenState();
}

class _BotOAuth2ConsentScreenState extends State<BotOAuth2ConsentScreen> {
  bool _isAuthorizing = false;

  final List<String> _requestedScopes = [
    'Access channel text messages',
    'Execute slash commands',
    'Manage incoming webhooks',
    'Read member presence status',
  ];

  Future<void> _grantAuthorization() async {
    if (_isAuthorizing) return;
    setState(() => _isAuthorizing = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('bot_oauth_grants').upsert({
        'bot_id': widget.botId,
        'server_id': widget.serverId,
        'granted_by': userId,
        'granted_scopes': ['bot', 'applications.commands', 'messages.read'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ Bot Authorized & Installed to Server!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isAuthorizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Authorize Bot Integration', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(FlickoColors.brandLime), size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Authorize Bot Access',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'This bot is requesting the following permissions for your server:',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _requestedScopes.map((scope) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Color(FlickoColors.brandLime), size: 20),
                          const SizedBox(width: 12),
                          Text(scope, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    )).toList(),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAuthorizing ? null : _grantAuthorization,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.brandLime),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isAuthorizing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text('Authorize & Install', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
