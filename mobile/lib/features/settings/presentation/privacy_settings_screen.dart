import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Privacy & Safety Settings Screen
///
/// Privacy controls, direct message filtering, and safety settings.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Privacy & Safety',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('PRIVACY'),
          _buildSettingsCard([
            _buildToggleSetting('Direct Messages', 'Allow direct messages from server members', true),
            _buildToggleSetting('Friend Requests', 'Allow friend requests from everyone', true),
            _buildToggleSetting('Activity Status', 'Show your activity status', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('SAFETY'),
          _buildSettingsCard([
            _buildToggleSetting('Filter Explicit Content', 'Filter explicit content in direct messages', true),
            _buildToggleSetting('Scan DMs for Spam', 'Automatically scan direct messages for spam', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('DATA'),
          _buildSettingsCard([
            _buildNavigationSetting('Request Data Export', 'Download a copy of your data'),
            _buildNavigationSetting('Delete All Messages', 'Permanently delete all your messages'),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleSetting(String title, String subtitle, bool value) {
    return SwitchListTile(
      value: value,
      onChanged: (_) {},
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      activeThumbColor: const Color(FlickoColors.blurple),
    );
  }

  Widget _buildNavigationSetting(String title, String subtitle) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(FlickoColors.textMuted),
      ),
    );
  }
}
