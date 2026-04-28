import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.maybeWhen(
      authenticated: (user, profile) => _buildSettings(context, ref, user, profile),
      orElse: () => const Scaffold(body: Center(child: Text('Logged out'))),
    );
  }

  Widget _buildSettings(BuildContext context, WidgetRef ref, dynamic user, dynamic profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';

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
          'Settings',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Profile Card Entry
          _buildProfileCard(context, displayName, username, profile?.avatarUrl),
          const SizedBox(height: 12),

          // Nitro Banner
          _buildNitroBanner(context),
          const SizedBox(height: 24),

          _buildSectionHeader('USER SETTINGS'),
          _buildSettingsRow(context, Icons.person_outline, 'My Account', () => context.push('/u/settings/account')),
          _buildSettingsRow(context, Icons.create_outlined, 'Edit Profile', () => context.push('/u/settings/edit-profile')),
          _buildSettingsRow(context, Icons.shield, 'Privacy & Safety', () => context.push('/u/settings/privacy')),
          const SizedBox(height: 24),

          _buildSectionHeader('APP SETTINGS'),
          _buildSettingsRow(context, Icons.palette_outlined, 'Appearance', () => context.push('/u/settings/appearance')),
          _buildSettingsRow(context, Icons.accessibility_new_outlined, 'Accessibility', () => context.push('/u/settings/accessibility')),
          _buildSettingsRow(context, Icons.chat_bubble_outline, 'Chat', () => context.push('/u/settings/chat')),
          _buildSettingsRow(context, Icons.notifications_none_outlined, 'Notifications', () => context.push('/u/settings/notifications')),
          _buildSettingsRow(context, Icons.mic_none_outlined, 'Voice & Video', () => context.push('/u/settings/voice')),
          _buildSettingsRow(context, Icons.language_outlined, 'Language', () => context.push('/u/settings/language')),
          _buildSettingsRow(context, Icons.storage_outlined, 'Data & Storage', () => context.push('/u/settings/storage')),
          const SizedBox(height: 24),

          _buildSectionHeader('PROFILE'),
          _buildSettingsRow(context, Icons.emoji_emotions_outlined, 'Status', () => context.push('/u/settings/status')),
          _buildSettingsRow(context, Icons.dns_outlined, 'Server Profiles', () => context.push('/u/settings/server-profiles')),
          const SizedBox(height: 24),

          _buildSectionHeader('BILLING'),
          const SizedBox(height: 24),

          _buildSectionHeader('ADVANCED'),
          _buildSettingsRow(context, Icons.code, 'Developer Mode', () {}, isSwitch: true),
          const SizedBox(height: 24),

          // Logout
          _buildSettingsRow(
            context,
            Icons.logout,
            'Log Out',
            () => ref.read(authNotifierProvider.notifier).signOut(),
            isDanger: true,
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Flicko Flutter v1.0.0',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String name, String username, String? avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: avatarUrl,
            status: 'online',
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@$username',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(FlickoColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildNitroBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/premium/nitro'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5865F2), Color(0xFF8547C6), Color(0xFFEB459E)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get Nitro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Unlock premium perks, bots, and more!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
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

  Widget _buildSettingsRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDanger = false,
    bool isSwitch = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        onTap: onTap,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: isDanger ? Colors.red : const Color(FlickoColors.textPrimary), size: 22),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: isDanger ? Colors.red : const Color(FlickoColors.textPrimary),
            fontSize: 16,
          ),
        ),
        trailing: isSwitch 
          ? Switch(value: false, onChanged: (v) {}, activeThumbColor: const Color(FlickoColors.blurple))
          : const Icon(Icons.chevron_right, color: Color(FlickoColors.textMuted), size: 20),
      ),
    );
  }
}
