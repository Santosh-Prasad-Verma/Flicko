import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Help & Support Screen
///
/// Provides links to documentation, FAQ, community, and contact options.
/// Route: /profile/settings/help
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  final List<_HelpRow> _helpRows = const [
    _HelpRow(icon: Icons.book_outlined, label: 'FAQ', description: 'Frequently asked questions'),
    _HelpRow(icon: Icons.chat_bubbles_outlined, label: 'Community', description: 'Join our community server'),
    _HelpRow(icon: Icons.description_outlined, label: 'Terms of Service', description: 'Read our terms of service'),
    _HelpRow(icon: Icons.shield_check_outlined, label: 'Privacy Policy', description: 'Read our privacy policy'),
    _HelpRow(icon: Icons.bug_report_outlined, label: 'Report a Bug', description: 'Help us fix issues'),
    _HelpRow(icon: Icons.info_outline, label: 'App Version', description: 'Flicko v1.0.0'),
  ];

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
          'Help & Support',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _helpRows.length,
        itemBuilder: (context, index) {
          final row = _helpRows[index];
          return _buildHelpRow(context, row, index == _helpRows.length - 1);
        },
      ),
    );
  }

  Widget _buildHelpRow(BuildContext context, _HelpRow row, bool isLast) {
    return InkWell(
      onTap: () => _handleTap(context, row.label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: isLast ? BorderRadius.circular(8) : const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.zero),
          border: isLast ? null : const Border(
            bottom: BorderSide(color: Color(0xFF232428)),
          ),
        ),
        child: Row(
          children: [
            Icon(row.icon, size: 22, color: const Color(FlickoColors.blurple)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    row.description,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(FlickoColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String label) {
    switch (label) {
      case 'FAQ':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FAQ section coming soon.')),
        );
        break;
      case 'Community':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community invite coming soon.')),
        );
        break;
      case 'Terms of Service':
        _launchUrl('https://flicko.dev/terms');
        break;
      case 'Privacy Policy':
        _launchUrl('https://flicko.dev/privacy');
        break;
      case 'Report a Bug':
        _launchUrl('mailto:support@flicko.dev?subject=Bug%20Report');
        break;
      case 'App Version':
        break;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _HelpRow {
  final IconData icon;
  final String label;
  final String description;

  const _HelpRow({
    required this.icon,
    required this.label,
    required this.description,
  });
}
