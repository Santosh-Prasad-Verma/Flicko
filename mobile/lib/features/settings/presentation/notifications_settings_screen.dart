import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Notifications Settings Screen
///
/// Push notification preferences and sound settings.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

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
          'Notifications',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('PUSH NOTIFICATIONS'),
          _buildSettingsCard([
            _buildToggleSetting('Enable Notifications', 'Receive push notifications', true),
            _buildToggleSetting('Direct Messages', 'Notify when you receive a DM', true),
            _buildToggleSetting('Mentions', 'Notify when you are mentioned', true),
            _buildToggleSetting('Server Messages', 'Notify for server messages', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('SOUNDS'),
          _buildSettingsCard([
            _buildToggleSetting('Message Sound', 'Play sound for new messages', true),
            _buildToggleSetting('Call Sound', 'Play sound for incoming calls', true),
            _buildToggleSetting('Notification Sound', 'Play sound for notifications', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('QUIET HOURS'),
          _buildSettingsCard([
            _buildToggleSetting('Enable Quiet Hours', 'Disable notifications during set hours', false),
            ListTile(
              title: Text(
                'Quiet Hours Schedule',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(FlickoColors.textMuted),
              ),
            ),
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
      activeColor: const Color(FlickoColors.blurple),
    );
  }
}
