import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Account Settings Screen
///
/// Mirrors the React Native "My Account" settings tab.
/// Shows profile card with banner, avatar, email, username fields.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isEditingPhone = false;
  final _phoneController = TextEditingController();

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
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, UserModel? profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';
    final email = profile?.id != null ? '$username@flicko.app' : null;

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
          'My Account',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          _buildProfileCard(context, displayName, username, profile?.avatarUrl, profile?.bannerUrl),
          const SizedBox(height: 24),

          // Account Information Section
          _buildSectionHeader('ACCOUNT INFORMATION'),
          _buildFieldCard([
            _buildFieldItem(
              context,
              'Email',
              email ?? 'Not set',
              onTap: () => context.push('change-email'),
            ),
            _buildDivider(),
            _buildFieldItem(
              context,
              'Username',
              '@$username',
              onTap: () => context.push('change-username'),
            ),
            _buildDivider(),
            if (_isEditingPhone)
              _buildPhoneEditField(context, profile?.phone)
            else
              _buildFieldItem(
                context,
                'Phone Number',
                profile?.phone ?? 'Not added',
                onTap: () {
                  setState(() {
                    _isEditingPhone = true;
                    _phoneController.text = profile?.phone?.replaceFirst('+', '') ?? '';
                  });
                },
              ),
            _buildDivider(),
            _buildFieldItem(
              context,
              'Password',
              '••••••••',
              onTap: () => context.push('change-password'),
            ),
          ]),

          const SizedBox(height: 24),

          // Account Management Section
          _buildSectionHeader('ACCOUNT MANAGEMENT'),
          _buildFieldCard([
            _buildDangerItem(
              context,
              Icons.pause_circle_outline,
              'Disable Account',
              'Temporarily deactivate your account',
              const Color(FlickoColors.warning),
              onTap: () => _showDisableDialog(context),
            ),
            _buildDivider(),
            _buildDangerItem(
              context,
              Icons.delete_outline,
              'Delete Account',
              'Permanently delete your account and data',
              const Color(FlickoColors.danger),
              onTap: () => _showDeleteDialog(context),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    String displayName,
    String username,
    String? avatarUrl,
    String? bannerUrl,
  ) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Banner
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: bannerUrl == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(FlickoColors.blurple),
                        Color(0xFF3A45C3),
                      ],
                    )
                  : null,
              image: bannerUrl != null
                  ? DecorationImage(
                      image: NetworkImage(bannerUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),

          // Avatar and Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(FlickoColors.bgSecondary),
                        width: 4,
                      ),
                    ),
                    child: UserAvatar(
                      imageUrl: avatarUrl,
                      size: 80,
                      status: 'online',
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.push('edit-profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(FlickoColors.blurple),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Edit Profile',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildFieldCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildFieldItem(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textSecondary),
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(FlickoColors.textMuted),
      ),
    );
  }

  Widget _buildPhoneEditField(BuildContext context, String? currentPhone) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
              ),
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                ),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.add,
                  color: Color(FlickoColors.textSecondary),
                  size: 16,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              if (_phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a phone number')),
                );
                return;
              }
              
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                // Ensure number has + prefix if not already present
                String phone = _phoneController.text.trim();
                if (!phone.startsWith('+')) {
                  phone = '+$phone';
                }
                
                await ref.read(authNotifierProvider.notifier).updatePhone(phone);
                if (mounted) {
                  setState(() => _isEditingPhone = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Phone number updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error updating phone number: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, color: Color(FlickoColors.success)),
          ),
          IconButton(
            onPressed: () => setState(() => _isEditingPhone = false),
            icon: const Icon(Icons.close, color: Color(FlickoColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w600,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      color: const Color(FlickoColors.textMuted).withValues(alpha: 0.1),
    );
  }

  void _showDisableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Disable Account',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'Are you sure you want to disable your account? You can re-enable it by logging in again.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              try {
                await ref.read(authNotifierProvider.notifier).disableAccount();
                if (mounted) {
                  navigator.pop();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error disabling account: $e')),
                  );
                }
              }
            },
            child: Text(
              'Disable',
              style: GoogleFonts.inter(color: const Color(FlickoColors.warning)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Account',
          style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
        ),
        content: Text(
          'This action is PERMANENT and cannot be undone. All your data will be deleted. Are you absolutely sure?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteConfirmation(context);
            },
            child: Text(
              'Delete Forever',
              style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Final Confirmation',
          style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
        ),
        content: Text(
          'Your account will be permanently deleted. This cannot be undone.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              try {
                await ref.read(authNotifierProvider.notifier).deleteAccount();
                if (mounted) {
                  navigator.pop();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            child: Text(
              'I understand, delete',
              style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
