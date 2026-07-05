import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';
import 'package:mobile/features/shared/presentation/widgets/flicko_error_state.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      initial: () => const Scaffold(
        backgroundColor: Color(FlickoColors.bgPrimary),
        body: SafeArea(child: ProfileSkeleton()),
      ),
      loading: () => const Scaffold(
        backgroundColor: Color(FlickoColors.bgPrimary),
        body: SafeArea(child: ProfileSkeleton()),
      ),
      authenticated: (user, profile) => _buildProfile(context, ref, user, profile),
      unauthenticated: () => Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        body: FlickoErrorState(
          type: FlickoErrorType.unauthorized,
          onRetry: () => context.go('/login'),
        ),
      ),
      error: (msg) => Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        body: FlickoErrorState(
          type: FlickoErrorType.generic,
          customMessage: msg,
          onRetry: () => ref.read(authNotifierProvider.notifier).checkAuth(),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, dynamic user, UserModel? profile) {
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? 'user';
    final bio = profile?.bio ?? 'Tell the world about yourself';
    final accentColor = Color(int.tryParse(profile?.accentColor?.replaceAll('#', '0xFF') ?? '') ?? FlickoColors.blurple);
    final bannerUrl = profile?.bannerUrl;
    final bannerColors = profile?.bannerColors ?? const [];
    final avatarUrl = profile?.avatarUrl;
    final avatarDecoration = profile?.avatarDecoration;
    final location = profile?.location;
    final websiteUrl = profile?.websiteUrl;
    final socialLink = profile?.socialLink;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, displayName, accentColor, bannerUrl, bannerColors),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIdentitySection(displayName, username, accentColor, avatarUrl, avatarDecoration, location),
                  const SizedBox(height: 24),
                  _buildCardSection('ABOUT ME', bio),
                  const SizedBox(height: 16),
                  _buildMemberSinceCard(profile?.createdAt ?? DateTime.now()),
                  if ((websiteUrl != null && websiteUrl.isNotEmpty) || (socialLink != null && socialLink.isNotEmpty)) ...[
                    const SizedBox(height: 24),
                    _buildLinksSection(websiteUrl, socialLink),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    String title,
    Color accentColor,
    String? bannerUrl,
    List<String> bannerColors,
  ) {
    final hasImage = bannerUrl != null && bannerUrl.isNotEmpty;
    final gradientColors = bannerColors.length >= 2
        ? bannerColors
            .take(2)
            .map((c) => Color(int.tryParse(c.replaceAll('#', '0xFF')) ?? FlickoColors.blurple))
            .toList()
        : [accentColor, accentColor.withValues(alpha: 0.6)];

    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(FlickoColors.bgPrimary),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
              ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(FlickoColors.bgPrimary)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => context.push('/profile/settings/share-profile')),
        IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
      ],
    );
  }

  Widget _buildIdentitySection(
      String name, String username, Color accentColor, String? avatarUrl, String? avatarDecoration, String? location) {
    return Transform.translate(
      offset: const Offset(0, -50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(FlickoColors.bgPrimary),
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  name: name,
                  status: 'online',
                  size: 80,
                  decoration: avatarDecoration,
                ),
              ),
              const Spacer(),
              _buildBadgeRow(),
            ],
          ),
          const SizedBox(height: 12),
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
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(FlickoColors.blurple), size: 18),
                const SizedBox(width: 6),
                Text(
                  location,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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

  Widget _buildMemberSinceCard(DateTime createdAt) {
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
            'MEMBER SINCE',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/Flicko-for-black-background.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('MMMM d, yyyy').format(createdAt),
                style: GoogleFonts.outfit(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection(String title, String content) {
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
          Text(
            content,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/profile/settings/edit-profile'),
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
            onPressed: () => context.push('/profile/settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildLinksSection(String? websiteUrl, String? socialLink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKS',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (websiteUrl != null && websiteUrl.isNotEmpty) ...[
          _buildBrutalistLinkCard('WEBSITE', websiteUrl),
          const SizedBox(height: 12),
        ],
        if (socialLink != null && socialLink.isNotEmpty) ...[
          _buildBrutalistLinkCard('SOCIAL PROFILE', socialLink),
        ],
      ],
    );
  }

  Widget _buildBrutalistLinkCard(String label, String url) {
    final icon = _getLinkIcon(url);
    return GestureDetector(
      onTap: () async {
        String formattedUrl = url.trim();
        if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
          formattedUrl = 'https://$formattedUrl';
        }
        final uri = Uri.tryParse(formattedUrl);
        if (uri != null) {
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('Could not launch URL: $e');
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(FlickoColors.blurple),
              offset: Offset(4, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _getLinkIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('github.com')) {
      return Icons.code;
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return Icons.alternate_email;
    } else if (lower.contains('instagram.com')) {
      return Icons.camera_alt;
    } else if (lower.contains('linkedin.com')) {
      return Icons.business;
    } else if (lower.contains('youtube.com')) {
      return Icons.play_arrow;
    }
    return Icons.language;
  }
}
