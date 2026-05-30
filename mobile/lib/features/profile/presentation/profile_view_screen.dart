import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/profile/presentation/widgets/gava_now_playing_bar.dart';
import 'package:mobile/features/voice/application/sonic_drip_notifier.dart';
import 'package:mobile/features/voice/domain/music_models.dart' show PlaybackStatus;
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unified Profile Screen — Flicko's Ultimate Profile Experience
/// Handles both current user (Self) and other users (Public) with
/// a refined, modern dark design using soft mint green accents.
///
/// Standardized across:
/// - ProfileScreen (Self)
/// - PublicProfileScreen (Others)
/// - ProfileViewScreen (Legacy)
class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileViewScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  UserModel? _profile;
  String _friendStatus =
      'none'; // self, none, pending_sent, pending_received, friends
  List<Map<String, dynamic>> _mutualServers = [];
  List<Map<String, dynamic>> _userRoles = [];
  String _note = '';
  bool _isEditingNote = false;
  final _noteController = TextEditingController();
  bool _isActionLoading = false;
  String? _errorMessage;
  final _client = Supabase.instance.client;

  // ─── Refined Theme Tokens (Soft/Light Green) ───
  static const Color _accent = Color(0xFF7DCEA0); // Soft mint green
  static const Color _accentLight = Color(0xFFA8E6CF); // Lighter mint
  static const Color _bg = Color(0xFF0A0A0F); // Deep dark blue-black
  static const Color _surface = Color(0xFF12131A); // Slightly lighter surface
  static const Color _cardBg = Color(0xFF16171F); // Card background
  static const Color _white = Color(0xFFF0EFF4); // Softer white
  static const Color _muted = Color(0xFF6B6B7B); // Warmer muted

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadAll();
  }

  @override
  void didUpdateWidget(ProfileViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch Profile
      final isUuid = RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false)
          .hasMatch(widget.userId);

      final response = isUuid
          ? await _client
              .from('profiles')
              .select('*')
              .eq('id', widget.userId)
              .single()
          : await _client
              .from('profiles')
              .select('*')
              .eq('username', widget.userId)
              .single();

      _profile = UserModel.fromJson(response);
      debugPrint(
          'Profile loaded: avatar=${_profile!.avatarUrl}, banner=${_profile!.bannerUrl}');
      final profileId = _profile!.id;

      // 2. Determine ownership
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (user, _) => user,
            orElse: () => null,
          );

      final isOwnProfile = currentUser?.id == profileId;

      if (isOwnProfile) {
        _friendStatus = 'self';
      } else if (currentUser != null) {
        // 3. Load Relationship State
        await _checkFriendStatus(currentUser.id, profileId);
        // 4. Load Mutual Context
        await _loadMutualServers(currentUser.id, profileId);
      }

      // 5. Load Public Metadata
      await _loadUserRoles(profileId);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _checkFriendStatus(
      String currentUserId, String profileId) async {
    try {
      // Check friendship table
      final friendship = await _client
          .from('friends')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('friend_id', profileId)
          .maybeSingle();

      if (friendship != null) {
        setState(() => _friendStatus = 'friends');
        return;
      }

      // Check friend_requests table
      final sent = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', currentUserId)
          .eq('receiver_id', profileId)
          .eq('status', 'pending')
          .maybeSingle();

      if (sent != null) {
        setState(() => _friendStatus = 'pending_sent');
        return;
      }

      final recv = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', profileId)
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (recv != null) {
        setState(() => _friendStatus = 'pending_received');
        return;
      }

      setState(() => _friendStatus = 'none');
    } catch (e) {
      debugPrint('Friend status check failed: $e');
      setState(() => _friendStatus = 'none');
    }
  }

  Future<void> _loadMutualServers(
      String currentUserId, String profileId) async {
    try {
      final response = await _client.rpc('get_mutual_servers', params: {
        'user_a': currentUserId,
        'user_b': profileId,
      });

      if (response != null && mounted) {
        setState(() {
          _mutualServers = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Mutual servers fetch failed: $e');
      // Fallback manual check if RPC doesn't exist
      try {
        final myMemberships = await _client
            .from('server_members')
            .select('server_id')
            .eq('user_id', currentUserId);

        final theirMemberships = await _client
            .from('server_members')
            .select('server_id')
            .eq('user_id', profileId);

        final myServerIds = (myMemberships as List)
            .map((m) => m['server_id'] as String)
            .toSet();
        final mutualIds = (theirMemberships as List)
            .map((m) => m['server_id'] as String)
            .where((id) => myServerIds.contains(id))
            .toList();

        if (mutualIds.isNotEmpty) {
          final servers = await _client
              .from('servers')
              .select('id, name, icon')
              .inFilter('id', mutualIds);
          setState(() {
            _mutualServers = List<Map<String, dynamic>>.from(servers);
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadUserRoles(String profileId) async {
    try {
      final roleRows = await _client
          .from('member_roles')
          .select('roles(id, name, color)')
          .eq('user_id', profileId);

      final rolesById = <String, Map<String, dynamic>>{};
      for (final row in roleRows as List) {
        if (row is! Map) continue;
        final roleData = row['roles'];
        if (roleData is! Map) continue;

        final role = Map<String, dynamic>.from(roleData);
        final id = role['id']?.toString();
        if (id != null && id.isNotEmpty) {
          rolesById[id] = role;
        }
      }

      if (mounted) {
        setState(() {
          _userRoles = rolesById.values.toList();
        });
      }
    } catch (e) {
      debugPrint('Roles fetch failed: $e');
    }
  }

  Future<void> _handleFriendAction() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);

    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (user, _) => user,
            orElse: () => null,
          );

      if (currentUser == null) return;

      if (_friendStatus == 'none') {
        try {
          await _client.from('friend_requests').insert({
            'sender_id': currentUser.id,
            'receiver_id': widget.userId,
            'status': 'pending',
          });
        } on PostgrestException catch (e) {
          if (e.message.contains('duplicate key value') || e.code == '23505') {
            await _client
                .from('friend_requests')
                .update({'status': 'pending'})
                .eq('sender_id', currentUser.id)
                .eq('receiver_id', widget.userId);
          } else {
            rethrow;
          }
        }
        setState(() => _friendStatus = 'pending_sent');
      } else if (_friendStatus == 'pending_received') {
        await _client
            .from('friend_requests')
            .update({'status': 'accepted'})
            .eq('sender_id', widget.userId)
            .eq('receiver_id', currentUser.id);

        await _client.from('friends').insert([
          {'user_id': currentUser.id, 'friend_id': widget.userId, 'status': 'accepted'},
          {'user_id': widget.userId, 'friend_id': currentUser.id, 'status': 'accepted'},
        ]);

        await _client.from('friendships').insert([
          {'user_id': currentUser.id, 'friend_id': widget.userId},
          {'user_id': widget.userId, 'friend_id': currentUser.id},
        ]);

        setState(() => _friendStatus = 'friends');
      } else if (_friendStatus == 'friends') {
        final confirmed = await _showConfirmDialog(
          'Remove Friend',
          'Are you sure you want to remove this user from your friends?',
        );

        if (confirmed) {
          await _client.from('friends').delete().or(
              'and(user_id.eq.${currentUser.id},friend_id.eq.${widget.userId}),and(user_id.eq.${widget.userId},friend_id.eq.${currentUser.id})');
          await _client.from('friendships').delete().or(
              'and(user_id.eq.${currentUser.id},friend_id.eq.${widget.userId}),and(user_id.eq.${widget.userId},friend_id.eq.${currentUser.id})');
          setState(() => _friendStatus = 'none');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Action failed: $e'),
              backgroundColor: const Color(FlickoColors.red)),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _white.withValues(alpha: 0.08)),
            ),
            title: Text(title,
                style: GoogleFonts.inter(
                    color: _white, fontWeight: FontWeight.w700, fontSize: 18)),
            content: Text(message,
                style: GoogleFonts.inter(
                    color: _white.withValues(alpha: 0.6), fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        color: _muted, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(FlickoColors.red).withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Confirm',
                    style: GoogleFonts.inter(
                        color: const Color(FlickoColors.red),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch when auth profile updates (e.g. after saving edit profile)
    ref.listen(authNotifierProvider, (previous, next) {
      next.maybeWhen(
        authenticated: (_, profile) {
          if (profile != null && profile.id == widget.userId && !_isLoading) {
            setState(() => _profile = profile);
          }
        },
        orElse: () {},
      );
    });

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(height: 20),
              Text('Loading profile...',
                  style: GoogleFonts.inter(
                      color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _profile == null) {
      return _buildErrorState();
    }

    final profile = _profile!;
    final isOwnProfile = _friendStatus == 'self';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Banner + Header Actions
            SliverToBoxAdapter(child: _buildBanner(profile, isOwnProfile)),

            // 2. Identity + Main Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),
                    _buildIdentity(profile),
                    const SizedBox(height: 16),
                    _buildQuickIconRow(isOwnProfile),
                    if (isOwnProfile) _buildGavaBar(),
                    const SizedBox(height: 16),
                    _buildActionRow(isOwnProfile),
                    const SizedBox(height: 32),

                    // 3. Info Content
                    _buildSectionTitle('About Me'),
                    _buildAboutCard(profile.bio),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Member Since'),
                              _buildInfoBadge(
                                DateFormat('MMMM d, yyyy')
                                    .format(profile.createdAt),
                                imageAsset: 'assets/images/Flicko-for-black-background.png',
                              ),
                            ],
                          ),
                        ),
                        if (_userRoles.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Roles'),
                                _buildRolesList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (profile.badges.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Badges'),
                      _buildBadgesRow(profile.badges),
                    ],

                    if ((profile.websiteUrl != null && profile.websiteUrl!.isNotEmpty) ||
                        (profile.socialLink != null && profile.socialLink!.isNotEmpty)) ...[
                      const SizedBox(height: 24),
                      _buildLinksSection(profile.websiteUrl, profile.socialLink),
                    ],

                    if (!isOwnProfile && _mutualServers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Mutual Servers'),
                      _buildMutualServers(),
                    ],

                    if (!isOwnProfile) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Private Note'),
                      _buildNoteSection(),
                    ],

                    const SizedBox(height: 48),
                    _buildFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _muted.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.person_off_rounded, size: 48, color: _muted),
            ),
            const SizedBox(height: 24),
            Text('User Not Found',
                style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                  _errorMessage ?? 'This profile is unavailable or private.',
                  style: GoogleFonts.inter(color: _muted, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Text('Go Back',
                    style: GoogleFonts.inter(
                        color: _accent, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).scale(
            begin: const Offset(0.95, 0.95),
            curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildBanner(UserModel profile, bool isOwnProfile) {
    final bannerUrl = profile.bannerUrl;
    final accentHex = profile.accentColor ?? '#7DCEA0';
    Color accentColor;
    try {
      accentColor = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      accentColor = _accent;
    }

    final bannerColors = profile.bannerColors;
    final List<Color> gradientColors = bannerColors != null && bannerColors.length >= 2
        ? bannerColors.take(2).map((c) {
            try {
              return Color(int.parse(c.replaceAll('#', '0xFF')));
            } catch (_) {
              return accentColor;
            }
          }).toList()
        : [accentColor, accentColor.withValues(alpha: 0.2)];

    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return SizedBox(
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner Image/Gradient with bottom fade
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: !hasBanner
                  ? LinearGradient(
                      colors: [...gradientColors, _bg],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: hasBanner
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [...gradientColors, _bg],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Smooth bottom fade
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _bg.withValues(alpha: 0.0),
                                _bg.withValues(alpha: 0.6),
                                _bg,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),

          // Top Actions
          Positioned(
            top: 46,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleBtn(Icons.arrow_back_rounded, () {
                  if (context.canPop()) context.pop();
                }),
                Row(
                  children: [
                    _buildCircleBtn(Icons.share_outlined, () {
                      context.push('/profile/settings/share-profile');
                    }),
                    const SizedBox(width: 10),
                    _buildCircleBtn(Icons.more_horiz_rounded, _showMoreOptions),
                  ],
                ),
              ],
            ),
          ),

          // Avatar with clean cutout & conditional decoration glow
          Positioned(
            top: 148,
            left: 20,
            child: Builder(
              builder: (context) {
                final hasDec = profile.avatarDecoration != null &&
                    profile.avatarDecoration != 'none' &&
                    profile.avatarDecoration!.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _bg,
                    shape: BoxShape.circle,
                    boxShadow: hasDec
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.25),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: UserAvatar(
                    imageUrl: profile.avatarUrl,
                    name: profile.displayName ?? profile.username,
                    size: 90,
                    status: profile.onlineStatus,
                    showStatus: true,
                    decoration: profile.avatarDecoration,
                    userId: widget.userId,
                    showBadge: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: _white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: _white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentity(UserModel profile) {
    final statusColor = profile.onlineStatus == 'online'
        ? _accent
        : profile.onlineStatus == 'idle'
            ? const Color(0xFFFEE75C)
            : _muted;

    final statusLabel = profile.onlineStatus == 'online'
        ? 'Online'
        : profile.onlineStatus == 'idle'
            ? 'Idle'
            : profile.onlineStatus == 'dnd'
                ? 'Do Not Disturb'
                : 'Offline';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display name with elegant styling
        Text(
          profile.displayName ?? profile.username,
          style: GoogleFonts.spaceGrotesk(
            color: _white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('@${profile.username}',
                style: GoogleFonts.jetBrainsMono(
                    color: _accent, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(statusLabel,
                      style: GoogleFonts.spaceGrotesk(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        if (profile.location != null && profile.location!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: _accent.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 6),
              Text(
                profile.location!,
                style: GoogleFonts.outfit(
                  color: _white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        if (profile.customStatus != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile.customStatusEmoji != null) ...[
                  Text(profile.customStatusEmoji!,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    profile.customStatus!,
                    style: GoogleFonts.outfit(
                        color: _white.withValues(alpha: 0.6), fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],      ],
    );
  }

  /// Compact icon row sitting just under the banner / identity.
  /// Shows quick-access entry points to Store, Creator, Sonic Drip, and Premium
  /// for the current user. For other profiles, shows a slim share/dm row.
  Widget _buildQuickIconRow(bool isOwnProfile) {
    final entries = isOwnProfile
        ? <_QuickEntry>[
            _QuickEntry(
              icon: Icons.storefront_rounded,
              label: 'Store',
              onTap: () => context.push('/store'),
            ),
            _QuickEntry(
              icon: Icons.brush_rounded,
              label: 'Creator',
              onTap: () => context.push('/creator'),
            ),
            _QuickEntry(
              icon: Icons.music_note_rounded,
              label: 'Sonic',
              onTap: () => context.push('/profile/settings/sonic-drip'),
            ),
            _QuickEntry(
              icon: Icons.workspace_premium_rounded,
              label: 'Plus',
              onTap: () => context.push('/premium/plus'),
            ),
          ]
        : <_QuickEntry>[];

    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = entries[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: e.onTap,
            child: Container(
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _white.withValues(alpha: 0.06)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.icon, color: _accent, size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.label,
                    style: GoogleFonts.inter(
                      color: _white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 80 * i)).slideX(
              begin: 0.1, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  /// Reads sonic-drip state and renders the Gava bar when a track is loaded.
  /// Uses Consumer so the parent ConsumerStatefulWidget doesn't rebuild on
  /// every progress tick.
  Widget _buildGavaBar() {
    return Consumer(
      builder: (context, ref, _) {
        final track = ref.watch(
          sonicDripProvider.select((s) => s.playback.currentTrack),
        );
        final status = ref.watch(
          sonicDripProvider.select((s) => s.playback.status),
        );
        if (track == null) return const SizedBox.shrink();

        return GavaNowPlayingBar(
          trackTitle: track.name,
          artist: track.artistName,
          artworkUrl: track.imageUrl,
          isPlaying: status == PlaybackStatus.playing,
          accent: _accent,
          onTap: () => context.push('/profile/settings/sonic-drip'),
        );
      },
    );
  }

  Widget _buildActionRow(bool isOwnProfile) {
    if (isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: _buildBtn(
              'Edit Profile',
              Icons.edit_outlined,
              () => context.push('/profile/settings/edit-profile'),
              primary: false,
            ),
          ),
          const SizedBox(width: 12),
          _buildSquareBtn(
              Icons.settings_rounded, () => context.push('/profile/settings')),
        ],
      );
    }

    String friendLabel = 'Add Friend';
    Color friendBgColor = _accent;
    Color friendTextColor = const Color(0xFF0A0A0F);
    IconData friendIcon = Icons.person_add_rounded;

    if (_friendStatus == 'friends') {
      friendLabel = 'Friends';
      friendBgColor = _accent.withValues(alpha: 0.12);
      friendTextColor = _accent;
      friendIcon = Icons.check_circle_rounded;
    } else if (_friendStatus == 'pending_sent') {
      friendLabel = 'Pending';
      friendBgColor = _surface;
      friendTextColor = _muted;
      friendIcon = Icons.access_time_filled_rounded;
    } else if (_friendStatus == 'pending_received') {
      friendLabel = 'Accept';
      friendBgColor = _accent;
      friendTextColor = const Color(0xFF0A0A0F);
      friendIcon = Icons.how_to_reg_rounded;
    }

    return Row(
      children: [
        Expanded(
          child: _buildBtn(
            friendLabel,
            friendIcon,
            _handleFriendAction,
            primary:
                _friendStatus == 'none' || _friendStatus == 'pending_received',
            backgroundColor: friendBgColor,
            textColor: friendTextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBtn(
            'Message',
            Icons.chat_bubble_outline_rounded,
            () => context.go('/dms/${widget.userId}'),
            primary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(String label, IconData icon, VoidCallback onTap,
      {bool primary = true, Color? backgroundColor, Color? textColor}) {
    final bgColor = backgroundColor ?? (primary ? _accent : _surface);
    final txtColor = textColor ?? (primary ? const Color(0xFF0A0A0F) : _white);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : _white.withValues(alpha: 0.08),
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: txtColor, size: 17),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: txtColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: _white.withValues(alpha: 0.8), size: 20),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.spaceGrotesk(
                color: _white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        // Gradient accent bar
        Container(
          height: 2,
          width: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: const LinearGradient(
              colors: [_accent, _accentLight],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildAboutCard(String? bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white.withValues(alpha: 0.05)),
      ),
      child: Text(
        bio ?? 'This user has no bio.',
        style: GoogleFonts.outfit(
          color: bio != null ? _white.withValues(alpha: 0.65) : _muted,
          fontSize: 14,
          height: 1.65,
          fontStyle: bio == null ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text, {IconData? icon, String? imageAsset}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageAsset != null
                ? Image.asset(imageAsset, width: 16, height: 16, fit: BoxFit.contain)
                : Icon(icon, color: _accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: _white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRolesList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _userRoles.map((role) {
        final color = role['color'] != null
            ? Color(
                int.parse(role['color'].toString().replaceFirst('#', '0xFF')))
            : _muted;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(role['name']?.toString() ?? 'Role',
                  style: GoogleFonts.inter(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBadgesRow(List<Badge> badges) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: badges.map<Widget>((badge) {
        final color = Color(int.parse(badge.color.replaceFirst('#', '0xFF')));
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Tooltip(
            message: badge.name,
            child: Icon(
              IconData(int.parse(badge.icon), fontFamily: 'MaterialIcons'),
              color: color,
              size: 20,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMutualServers() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _mutualServers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final server = _mutualServers[index];
          return Tooltip(
            message: server['name'],
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _white.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: server['icon'] != null
                  ? Image.network(server['icon'], fit: BoxFit.cover)
                  : Center(
                      child: Text(server['name'][0].toString().toUpperCase(),
                          style: GoogleFonts.inter(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 18))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white.withValues(alpha: 0.05)),
      ),
      child: _isEditingNote
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: _white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter a private note...',
                    hintStyle: GoogleFonts.inter(color: _muted),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accent.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditingNote = false),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: _muted, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _note = _noteController.text;
                          _isEditingNote = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: const Color(0xFF0A0A0F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('Save',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            )
          : GestureDetector(
              onTap: () => setState(() {
                _isEditingNote = true;
                _noteController.text = _note;
              }),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.sticky_note_2_outlined,
                        color: _accent.withValues(alpha: 0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _note.isEmpty ? 'Click to add a private note...' : _note,
                      style: GoogleFonts.inter(
                          color: _note.isEmpty
                              ? _muted
                              : _white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontStyle: _note.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 1,
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                colors: [
                  _white.withValues(alpha: 0.0),
                  _white.withValues(alpha: 0.08),
                  _white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Flicko · Identity Verified',
              style: GoogleFonts.inter(
                  color: _white.withValues(alpha: 0.12),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    final isOwnProfile = _friendStatus == 'self';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: _white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (!isOwnProfile) ...[
                    _sheetItem(Icons.block_rounded, 'Block User', () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming Soon')));
                    }, color: const Color(FlickoColors.red)),
                    _sheetItem(Icons.report_outlined, 'Report Profile', () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming Soon')));
                    }, color: const Color(FlickoColors.red)),
                  ],
                  _sheetItem(Icons.copy_rounded, 'Copy User ID', () {
                    Clipboard.setData(ClipboardData(text: widget.userId));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('ID copied!')));
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? _white).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? _white.withValues(alpha: 0.8), size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.inter(
              color: color ?? _white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 14)),
      onTap: onTap,
    );
  }

  Widget _buildLinksSection(String? websiteUrl, String? socialLink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Links'),
        const SizedBox(height: 4),
        if (websiteUrl != null && websiteUrl.isNotEmpty) ...[
          _buildLinkCard('Website', websiteUrl),
          const SizedBox(height: 10),
        ],
        if (socialLink != null && socialLink.isNotEmpty) ...[
          _buildLinkCard('Social Profile', socialLink),
        ],
      ],
    );
  }
  Widget _buildLinkCard(String label, String url) {
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: GoogleFonts.outfit(
                      color: _white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                color: _muted.withValues(alpha: 0.6), size: 16),
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

class _QuickEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
