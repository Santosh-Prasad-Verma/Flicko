import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Account Settings Screen (Sleek Brutalist Black/Neon Theme)
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isEditingPhone = false;
  final _phoneController = TextEditingController();

  static const Color _neonGreen = Color(0xFFC0F500);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    return authState.maybeWhen(
      authenticated: (user, profile) => _buildScreen(context, profile),
      orElse: () => const Scaffold(
        backgroundColor: _bgBlack,
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, UserModel? profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';
    final email = profile?.id != null ? '$username@flicko.app' : null;

    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeroSection(),
                      const SizedBox(height: 32),
                      _buildProfileCard(displayName, username, profile?.avatarUrl, profile?.bannerUrl),
                      const SizedBox(height: 40),
                      _buildAccountInfoSection(email, username, profile),
                      const SizedBox(height: 40),
                      _buildAccountManagementSection(),
                      const SizedBox(height: 48),
                      _buildFooterData(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _neonGreen.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _textWhite, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('APP SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text('ACCOUNT MANAGEMENT',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8, letterSpacing: 1.0,
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

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('MY\nACCOUNT',
          style: GoogleFonts.epilogue(
            color: _textWhite, fontSize: 48, fontWeight: FontWeight.w900,
            letterSpacing: -2, height: 0.9, fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: _neonGreen,
              child: Text('IDENTITY',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MANAGE CREDENTIALS',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1,
                    ),
                  ),
                  Text('Profile, email, password & security',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted.withValues(alpha: 0.8), fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(String displayName, String username, String? avatarUrl, String? bannerUrl) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: bannerUrl == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_neonGreen.withValues(alpha: 0.3), _neonGreen.withValues(alpha: 0.05)],
                    )
                  : null,
              image: bannerUrl != null
                  ? DecorationImage(image: NetworkImage(bannerUrl), fit: BoxFit.cover)
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _surfaceContainer, width: 3),
                    ),
                    child: UserAvatar(imageUrl: avatarUrl, name: displayName, size: 56, status: 'online'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                        style: GoogleFonts.epilogue(
                          color: _textWhite, fontSize: 18,
                          fontWeight: FontWeight.w800, fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text('@$username',
                        style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/profile/settings/edit-profile'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: _neonGreen,
                    child: Text('EDIT',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection(String? email, String username, UserModel? profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CREDENTIALS',
          style: GoogleFonts.epilogue(
            color: _textWhite, fontSize: 22, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, letterSpacing: -0.5,
          ),
        ),
        Container(height: 2, color: _neonGreen, margin: const EdgeInsets.only(top: 6, bottom: 16)),
        _buildInfoCard(
          title: 'EMAIL', value: email ?? 'Not set', badge: 'VERIFIED',
          onTap: () => context.push('/profile/settings/change-email'),
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'USERNAME', value: '@$username', badge: 'UNIQUE',
          usePrimaryBadge: true,
          onTap: () => context.push('/profile/settings/change-username'),
        ),
        const SizedBox(height: 14),
        if (_isEditingPhone)
          _buildPhoneEditCard(profile?.phone)
        else
          _buildInfoCard(
            title: 'PHONE',
            value: profile?.phone ?? 'Not added',
            badge: profile?.phone != null ? 'ACTIVE' : 'NONE',
            onTap: () => setState(() {
              _isEditingPhone = true;
              _phoneController.text = profile?.phone?.replaceFirst('+', '') ?? '';
            }),
          ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'PASSWORD', value: '••••••••', badge: 'SECURE',
          onTap: () => context.push('/profile/settings/change-password'),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String badge,
    bool usePrimaryBadge = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          border: Border.all(
            color: usePrimaryBadge ? _neonGreen.withValues(alpha: 0.4) : _textWhite.withValues(alpha: 0.05),
            width: usePrimaryBadge ? 1.5 : 1,
          ),
          boxShadow: usePrimaryBadge
              ? [BoxShadow(color: _neonGreen.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8, runSpacing: 4,
                    children: [
                      Text(title,
                        style: GoogleFonts.epilogue(
                          color: _textWhite, fontSize: 18, fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic, letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: usePrimaryBadge ? _neonGreen : Colors.transparent,
                          border: usePrimaryBadge ? null : Border.all(color: _textWhite.withValues(alpha: 0.2)),
                        ),
                        child: Text(badge,
                          style: GoogleFonts.spaceMono(
                            color: usePrimaryBadge ? Colors.black : _textWhite.withValues(alpha: 0.4),
                            fontSize: 9, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(value, style: GoogleFonts.inter(color: _textMuted, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.chevron_right, color: _textWhite.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneEditCard(String? currentPhone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _neonGreen.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PHONE',
                style: GoogleFonts.epilogue(
                  color: _textWhite, fontSize: 18, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: _neonGreen,
                child: Text('EDITING',
                  style: GoogleFonts.spaceMono(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: GoogleFonts.spaceMono(color: _textMuted, fontSize: 12),
                    filled: true,
                    fillColor: _bgBlack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: _textWhite.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: _textWhite.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: _neonGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixText: '+ ',
                    prefixStyle: GoogleFonts.spaceMono(color: _neonGreen, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  if (_phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a phone number')),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    String phone = _phoneController.text.trim();
                    if (!phone.startsWith('+')) phone = '+$phone';
                    await ref.read(authNotifierProvider.notifier).updatePhone(phone);
                    if (mounted) setState(() => _isEditingPhone = false);
                    messenger.showSnackBar(const SnackBar(content: Text('Phone updated successfully')));
                  } catch (e) {
                    if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: _neonGreen,
                  child: const Icon(Icons.check, color: Colors.black, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _isEditingPhone = false),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.withValues(alpha: 0.2),
                  child: const Icon(Icons.close, color: Colors.red, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DANGER ZONE',
          style: GoogleFonts.epilogue(
            color: _textWhite, fontSize: 22, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2, color: Colors.red.withValues(alpha: 0.6),
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildDangerCard(
          title: 'DISABLE ACCOUNT',
          subtitle: 'Temporarily deactivate your account. Re-enable by logging in.',
          badge: 'REVERSIBLE', color: Colors.orange,
          onTap: () => _showDisableDialog(context),
        ),
        const SizedBox(height: 14),
        _buildDangerCard(
          title: 'DELETE ACCOUNT',
          subtitle: 'Permanently delete your account and all associated data.',
          badge: 'PERMANENT', color: Colors.red,
          onTap: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  Widget _buildDangerCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8, runSpacing: 4,
                    children: [
                      Text(title,
                        style: GoogleFonts.epilogue(
                          color: color, fontSize: 18, fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic, letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4))),
                        child: Text(badge,
                          style: GoogleFonts.spaceMono(
                            color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: GoogleFonts.inter(color: _textMuted, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _neonGreen.withValues(alpha: 0.2), margin: const EdgeInsets.only(bottom: 24)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _neonGreen.withValues(alpha: 0.05),
            border: Border.symmetric(horizontal: BorderSide(color: _textWhite.withValues(alpha: 0.05))),
          ),
          child: Center(
            child: Text('FLICKO // ACCOUNT SECURE',
              style: GoogleFonts.spaceMono(
                color: _textWhite.withValues(alpha: 0.3),
                fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDisableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text('DISABLE ACCOUNT',
          style: GoogleFonts.epilogue(color: Colors.orange, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
        content: Text(
          'Are you sure you want to disable your account? You can re-enable it by logging in again.',
          style: GoogleFonts.inter(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: _textWhite)),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(authNotifierProvider.notifier).disableAccount();
                if (mounted) context.go('/login');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text('Disable', style: GoogleFonts.spaceGrotesk(color: Colors.orange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text('DELETE ACCOUNT',
          style: GoogleFonts.epilogue(color: Colors.red, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
        content: Text(
          'This action is PERMANENT and cannot be undone. All your data will be deleted.',
          style: GoogleFonts.inter(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: _textWhite)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showFinalDeleteConfirmation(context);
            },
            child: Text('Delete Forever', style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text('FINAL CONFIRMATION',
          style: GoogleFonts.epilogue(color: Colors.red, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
        content: Text(
          'Your account will be permanently deleted. This cannot be undone.',
          style: GoogleFonts.inter(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: _textWhite)),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(authNotifierProvider.notifier).deleteAccount();
                if (mounted) context.go('/login');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text('I understand, delete',
              style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
