import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.maybeWhen(
      authenticated: (user, profile) => _buildProfile(context, ref, user, profile),
      orElse: () => const Scaffold(body: Center(child: Text('Logged out'))),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, dynamic user, dynamic profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';
    final bio = profile?.bio ?? 'Tell the world about yourself';
    final accentColor = Color(int.tryParse(profile?.accentColor?.replaceAll('#', '0xFF') ?? '') ?? FlickoColors.blurple);

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header with Banner and Avatar
          _buildHeader(context, profile, accentColor),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentitySection(displayName, username, profile?.customStatus, profile?.customStatusEmoji),
                const SizedBox(height: 16),
                _buildNitroBanner(context),
                const SizedBox(height: 24),
                _buildCardSection('ABOUT ME', bio),
                const SizedBox(height: 16),
                _buildCardSection(
                  'FLICKO MEMBER SINCE', 
                  profile?.createdAt != null 
                      ? DateFormat('MMM d, yyyy').format(profile!.createdAt!)
                      : 'Recently',
                  prefixWidget: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.asset(
                      'assets/images/Flicko-con-without-background.png',
                      height: 20,
                      width: 20,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(FlickoColors.blurple), size: 16),
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionButtons(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile, Color accentColor) {
    final bannerUrl = profile?.bannerUrl;
    final avatarUrl = profile?.avatarUrl;
    final title = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';
    return SizedBox(
      height: 160 + 60, // 160 for banner + 60 for overlapping avatar overflow
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: (bannerUrl == null || bannerUrl.isEmpty)
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getBannerColors(profile),
                  )
                : null,
              image: (bannerUrl != null && bannerUrl.isNotEmpty) 
                ? DecorationImage(
                    image: NetworkImage(bannerUrl),
                    fit: BoxFit.cover,
                  ) 
                : null,
            ),
          ),
          
          // Glossy Overlay for depth
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          // Bottom fade edge to merge banner with profile card background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(FlickoColors.bgPrimary).withValues(alpha: 0.8),
                    const Color(FlickoColors.bgPrimary),
                  ],
                ),
              ),
            ),
          ),
          
          // Avatar
          Positioned(
            top: 160 - 46, // Half of avatar height
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(FlickoColors.bgPrimary),
                shape: BoxShape.circle,
              ),
              child: UserAvatar(
                imageUrl: avatarUrl,
                name: title,
                status: profile?.onlineStatus ?? 'offline',
                size: 80,
                showStatus: true,
              ),
            ),
          ),

          // Badges perfectly aligned next to avatar
          Positioned(
            top: 160 + 12,
            right: 16,
            child: _buildBadgeRow(),
          ),

          // Actions
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://flicko.app/u/$username'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile link copied!', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(FlickoColors.blurple),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  onPressed: () => _showProfileOptions(context, username),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNitroBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/premium/nitro'),
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
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Unlock premium perks and more!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection(String name, String username, String? customStatus, String? emoji) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '@$username',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 16,
          ),
        ),
        if (customStatus != null || emoji != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              if (customStatus != null)
                Expanded(
                  child: Text(
                    customStatus,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadgeRow() {
    return Row(
      children: [
        _buildBadge(Icons.shield, const Color(0xFF9B84EE)),
        _buildBadge(Icons.flash_on, const Color(0xFFF47FFF)),
        _buildBadge(Icons.verified, Colors.blue),
      ],
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildCardSection(String title, String content, {Widget? trailing, Widget? prefixWidget}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // ignore: use_null_aware_elements
              if (prefixWidget != null) prefixWidget,
              Expanded(
                child: Text(
                  content,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                  ),
                ),
              ),
              // ignore: use_null_aware_elements
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/u/settings/edit-profile'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.bgSecondary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => context.push('/u/settings'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/premium/nitro'),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('Get Nitro', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5865F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileOptions(BuildContext context, String username) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white70),
              title: Text('Edit Profile', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/u/settings/edit-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: Text('Settings', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/u/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: Text('Share Profile', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: 'https://flicko.app/u/$username'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile link copied!', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(FlickoColors.blurple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Color> _getBannerColors(dynamic profile) {
    if (profile?.bannerColors != null && profile!.bannerColors!.length >= 2) {
      try {
        return profile.bannerColors!.map<Color>((c) {
          final hex = c.toString().replaceFirst('#', '');
          if (hex.length == 6) return Color(int.parse('0xFF$hex'));
          if (hex.length == 8) return Color(int.parse('0x$hex'));
          return Color(int.parse(hex));
        }).toList();
      } catch (_) {}
    }
    return [
      const Color(0xFF5865F2),
      const Color(0xFFEB459E),
      const Color(0xFFFEE75C).withValues(alpha: 0.8),
    ];
  }
}

