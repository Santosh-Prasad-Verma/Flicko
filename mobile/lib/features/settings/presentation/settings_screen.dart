import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/settings/application/user_settings_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class DevModeNotifier extends AsyncNotifier<bool> {
  static const _key = 'developer_mode';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final current = state.asData?.value ?? false;
    await _setValue(!current);
  }

  Future<void> setValue(bool value) async {
    await _setValue(value);
  }

  Future<void> _setValue(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    ref.read(userSettingsNotifierProvider.notifier).setBool('system_developer_mode', value);
  }
}

final devModeProvider = AsyncNotifierProvider<DevModeNotifier, bool>(DevModeNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: authState.maybeWhen(
                authenticated: (user, profile) =>
                    _buildSettings(context, ref, user, profile),
                orElse: () => const Center(
                  child: Text('Logged out', style: TextStyle(color: _textWhite)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'USER SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'MANAGE PROFILE AND PREFERENCES',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildSettings(
      BuildContext context, WidgetRef ref, dynamic user, dynamic profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'USER\nSETTINGS',
              style: GoogleFonts.epilogue(
                color: _textWhite,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                height: 0.9,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileSection(context, displayName, username, profile?.avatarUrl),
            const SizedBox(height: 40),
            _buildSectionHeader('USER PREFERENCES'),
            _buildSettingsRow(context, Icons.person_outline_rounded, 'My Account',
                () => context.push('/profile/settings/account')),
            _buildSettingsRow(context, Icons.edit_note_rounded, 'Edit Profile',
                () => context.push('/profile/settings/edit-profile')),
            _buildSettingsRow(context, Icons.circle_rounded, 'Status',
                () => context.push('/profile/settings/status'),
                subtitle: 'Online · Custom status'),
            _buildSettingsRow(context, Icons.dns_rounded, 'Server Profiles',
                () => context.push('/profile/settings/server-profiles')),
            _buildSettingsRow(context, Icons.verified_user_outlined, 'Privacy & Safety',
                () => context.push('/profile/settings/privacy')),
            _buildSettingsRow(context, Icons.lock_outline_rounded, 'Encryption',
                () => context.push('/profile/settings/encryption')),
            const SizedBox(height: 32),
            _buildSectionHeader('PREMIUM SERVICES'),
            _buildSettingsRow(
              context,
              Icons.credit_card_rounded,
              'Premium Billing',
              () => context.push('/profile/settings/billing'),
            ),
            _buildSettingsRow(
              context,
              Icons.storefront_rounded,
              'Store',
              () => context.push('/store'),
              trailing: _buildPremiumBadge('NEW'),
            ),
            _buildSettingsRow(
              context,
              Icons.water_drop_rounded,
              'Sonic Drip',
              () => context.push('/profile/settings/sonic-drip'),
              trailing: _buildPremiumBadge('PRO'),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('APP EXPERIENCE'),
            _buildSettingsRow(
              context,
              Icons.palette_outlined,
              'Appearance',
              () => context.push('/profile/settings/appearance'),
              trailing: _buildPremiumBadge('NEW'),
            ),
            _buildSettingsRow(context, Icons.accessibility_new_rounded, 'Accessibility',
                () => context.push('/profile/settings/accessibility')),
            _buildSettingsRow(context, Icons.chat_bubble_outline_rounded, 'Chat',
                () => context.push('/profile/settings/chat')),
            _buildSettingsRow(context, Icons.notifications_active_outlined, 'Notifications',
                () => context.push('/profile/settings/notifications')),
            _buildSettingsRow(context, Icons.mic_none_rounded, 'Voice & Video',
                () => context.push('/profile/settings/voice')),
            _buildSettingsRow(
              context,
              Icons.language_rounded,
              'Language',
              () => context.push('/profile/settings/language'),
              subtitle: 'English (US)',
            ),
            _buildSettingsRow(
              context,
              Icons.translate_rounded,
              AppLocalizations.of(context)?.translateSettingsTileTitle ?? 'Auto-translate',
              () => context.push('/profile/settings/translate'),
              subtitle: AppLocalizations.of(context)?.translateSettingsTileSubtitle ?? 'AI per-message translation',
            ),
            _buildSettingsRow(context, Icons.data_usage_rounded, 'Data & Storage',
                () => context.push('/profile/settings/storage')),
            const SizedBox(height: 24),
            _buildPremiumBanner(context),
            const SizedBox(height: 32),
            _buildSectionHeader('AI COMPANION'),
            _buildSettingsRow(
              context,
              Icons.blur_on_rounded,
              'Aura AI Assistant',
              () => context.push('/profile/settings/aura'),
              subtitle: 'Chat & voice companion',
              trailing: _buildPremiumBadge('AURA'),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('SYSTEM CONTROLS'),
            _buildSettingsRow(
              context,
              Icons.developer_mode_rounded,
              'Developer Mode',
              () {
                final current = ref.read(devModeProvider).asData?.value ?? false;
                ref.read(devModeProvider.notifier).toggle();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(!current ? 'Developer Mode enabled. Restart app to apply.' : 'Developer Mode disabled.'),
                    backgroundColor: !current ? _neonGreen : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              isSwitch: true,
              switchValue: ref.watch(devModeProvider).asData?.value ?? false,
              onSwitchChanged: (val) {
                ref.read(devModeProvider.notifier).setValue(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? 'Developer Mode enabled. Restart app to apply.' : 'Developer Mode disabled.'),
                    backgroundColor: val ? _neonGreen : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            ),
            _buildSettingsRow(
              context, 
              Icons.bug_report_outlined, 
              'Bug Report', 
              () => launchUrl(Uri.parse('https://github.com/Tarun10A/flicko/issues'))
            ),
            _buildSettingsRow(
              context, 
              Icons.error_outline_rounded, 
              'Verify Sentry Setup', 
              () async {
                try {
                  final id = await Sentry.captureException(
                    StateError('This is test exception for verifying setup'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sentry Event captured! ID: $id'),
                        backgroundColor: _neonGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sentry capture failed: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            ),
            _buildSettingsRow(
              context,
              Icons.hexagon_outlined,
              'About Developer',
              () => context.push('/profile/settings/about-developer'),
              subtitle: 'Interactive 3D space & architect dossier',
              trailing: _buildPremiumBadge('DEV'),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('ACCOUNT ACTIONS'),
            _buildSettingsRow(
              context,
              Icons.logout_rounded,
              'Log Out',
              () => ref.read(authNotifierProvider.notifier).signOut(),
              isDanger: true,
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/branding/Flicko-for-black-background.png',
                    height: 48,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FLICKO // SYSTEM_OK v1.2.4',
                    style: GoogleFonts.spaceMono(
                      color: _textWhite.withValues(alpha: 0.15),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(
      BuildContext context, String name, String username, String? avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _neonGreen, width: 1.5),
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  name: name,
                  status: 'online',
                  size: 72,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: GoogleFonts.epilogue(
                        color: _textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: GoogleFonts.spaceMono(
                        color: _neonGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildProfileActionButton(
                  'EDIT PROFILE',
                  Icons.edit_rounded,
                  () => context.push('/profile/settings/edit-profile'),
                ),
              ),
              const SizedBox(width: 12),
              _buildProfileActionButton(
                '',
                Icons.share_rounded,
                () => context.push('/profile/settings/share-profile'),
                isIconOnly: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isIconOnly = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 42,
        width: isIconOnly ? 42 : null,
        padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 0 : 16),
        decoration: BoxDecoration(
          color: _bgBlack,
          border: Border.all(color: _textWhite.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _textWhite, size: 16),
            if (!isIconOnly) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/premium/nitro'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          border: Border.all(color: _neonGreen.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _neonGreen.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _neonGreen.withValues(alpha: 0.1),
                border: Border.all(color: _neonGreen.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.bolt_rounded, color: _neonGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLICKO PLUS',
                    style: GoogleFonts.epilogue(
                      color: _textWhite,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock maximum hardware and visual perks',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _neonGreen, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDanger = false,
    bool isSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    Widget? trailing,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(
          color: isDanger
              ? Colors.red.withValues(alpha: 0.2)
              : _textWhite.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDanger
                      ? Colors.red.withValues(alpha: 0.1)
                      : _neonGreen.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isDanger
                        ? Colors.red.withValues(alpha: 0.2)
                        : _neonGreen.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  icon,
                  color: isDanger ? Colors.redAccent : _neonGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: isDanger ? Colors.redAccent : _textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.spaceMono(
                          color: _textMuted.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isSwitch)
                _buildHardwareToggle(switchValue, onSwitchChanged ?? (_) { onTap(); })
              else
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _textWhite.withValues(alpha: 0.15),
                      size: 14,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: _neonGreen,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: Colors.black,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHardwareToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? _neonGreen : const Color(0xFF141416),
          border: Border.all(
            color: value ? _neonGreen : _textWhite.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 26 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                color: value ? Colors.black : const Color(0xFF71717A),
                child: Center(
                  child: Container(
                    width: 2,
                    height: 8,
                    color: value
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
