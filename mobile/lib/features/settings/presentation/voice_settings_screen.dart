import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Voice & Video Settings Screen
///
/// Voice chat settings, audio quality, and device preferences.
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

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
          'Voice & Video',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('INPUT DEVICE'),
          _buildSettingsCard([
            ListTile(
              title: Text(
                'Input Device',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Default Microphone',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(FlickoColors.textMuted),
              ),
            ),
            _buildToggleSetting('Noise Suppression', 'Remove background noise', true),
            _buildToggleSetting('Echo Cancellation', 'Reduce echo and feedback', true),
            _buildToggleSetting('Automatic Gain Control', 'Normalize input volume', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('OUTPUT DEVICE'),
          _buildSettingsCard([
            ListTile(
              title: Text(
                'Output Device',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Default Speaker',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(FlickoColors.textMuted),
              ),
            ),
            _buildToggleSetting(' attenuation', 'Lower volume of other apps during calls', true),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('CALL BEHAVIOR'),
          _buildSettingsCard([
            _buildToggleSetting('Answer on Join', 'Automatically connect audio when joining voice', false),
            _buildToggleSetting('Video on Join', 'Automatically enable video when joining', false),
            _buildToggleSetting('Show Call Notifications', 'Show incoming call notifications', true),
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
}
