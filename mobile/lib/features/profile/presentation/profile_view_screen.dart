import 'dart:async';
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
/// a sleek, brutalist black/neon design.
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

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
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

  // Theme tokens
  static const Color _neon = Color(0xFFC0F500);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
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
          .or('and(user_id.eq.$currentUserId,friend_id.eq.$profileId),and(user_id.eq.$profileId,friend_id.eq.$currentUserId)')
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
        'user_id_1': currentUserId,
        'user_id_2': profileId,
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
        await _client.from('friend_requests').insert({
          'sender_id': currentUser.id,
          'receiver_id': widget.userId,
          'status': 'pending',
        });
        setState(() => _friendStatus = 'pending_sent');
      } else if (_friendStatus == 'pending_received') {
        await _client
            .from('friend_requests')
            .update({'status': 'accepted'})
            .eq('sender_id', widget.userId)
            .eq('receiver_id', currentUser.id);

        await _client.from('friends').insert([
          {'user_id': currentUser.id, 'friend_id': widget.userId},
          {'user_id': widget.userId, 'friend_id': currentUser.id},
        ]);

        setState(() => _friendStatus = 'friends');
      } else if (_friendStatus == 'friends') {
        final confirmed = await _showConfirmDialog(
          'REMOVE FRIEND',
          'Are you sure you want to remove this user from your friends?',
        );

        if (confirmed) {
          await _client.from('friends').delete().or(
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
            backgroundColor: _surface,
            shape: const RoundedRectangleBorder(),
            title: Text(title,
                style: GoogleFonts.epilogue(
                    color: _white, fontWeight: FontWeight.w900, fontSize: 18)),
            content: Text(message,
                style: GoogleFonts.inter(
                    color: _white.withValues(alpha: 0.7), fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('CANCEL',
                    style: GoogleFonts.spaceGrotesk(
                        color: _muted, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('CONFIRM',
                    style: GoogleFonts.spaceGrotesk(
                        color: const Color(FlickoColors.red),
                        fontWeight: FontWeight.w800)),
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
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _neon)),
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
                    _buildSectionTitle('ABOUT ME'),
                    _buildAboutCard(profile.bio),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('MEMBER SINCE'),
                              _buildInfoBadge(
                                DateFormat('MMMM d, yyyy')
                                    .format(profile.createdAt),
                                Icons.calendar_today_rounded,
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
                                _buildSectionTitle('ROLES'),
                                _buildRolesList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (profile.badges.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('BADGES'),
                      _buildBadgesRow(profile.badges),
                    ],

                    if ((profile.websiteUrl != null && profile.websiteUrl!.isNotEmpty) ||
                        (profile.socialLink != null && profile.socialLink!.isNotEmpty)) ...[
                      const SizedBox(height: 24),
                      _buildLinksSection(profile.websiteUrl, profile.socialLink),
                    ],

                    if (!isOwnProfile && _mutualServers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('MUTUAL SERVERS'),
                      _buildMutualServers(),
                    ],

                    if (!isOwnProfile) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('PRIVATE NOTE'),
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
            const Icon(Icons.person_off_rounded, size: 64, color: _muted),
            const SizedBox(height: 16),
            Text('USER NOT FOUND',
                style: GoogleFonts.epilogue(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'This profile is unavailable or private.',
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: _muted.withValues(alpha: 0.3))),
                child: Text('GO BACK',
                    style: GoogleFonts.spaceGrotesk(
                        color: _white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  Widget _buildBanner(UserModel profile, bool isOwnProfile) {
    final bannerUrl = profile.bannerUrl;
    final accentHex = profile.accentColor ?? '#C0F500';
    Color accentColor;
    try {
      accentColor = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      accentColor = const Color(0xFFC0F500);
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
        : [accentColor, accentColor.withValues(alpha: 0.4)];

    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner Image/Gradient
          Container(
            height: 180,
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
                ? Image.network(
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
                  )
                : null,
          ),

          // Top Actions
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleBtn(Icons.arrow_back, () {
                  if (context.canPop()) context.pop();
                }),
                Row(
                  children: [
                    _buildCircleBtn(Icons.share_outlined, () {
                      context.push('/profile/settings/share-profile');
                    }),
                    const SizedBox(width: 8),
                    _buildCircleBtn(Icons.more_vert, _showMoreOptions),
                  ],
                ),
              ],
            ),
          ),

          // Avatar
          Positioned(
            top: 130,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _bg,
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5)
                ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: _white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: _white, size: 20),
      ),
    );
  }

  Widget _buildIdentity(UserModel profile) {
    final statusColor = profile.onlineStatus == 'online'
        ? _neon
        : profile.onlineStatus == 'idle'
            ? const Color(0xFFFEE75C)
            : _muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (profile.displayName ?? profile.username).toUpperCase(),
          style: GoogleFonts.epilogue(
            color: _white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            fontStyle: FontStyle.italic,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('@${profile.username}',
                style: GoogleFonts.spaceMono(
                    color: _neon, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(profile.onlineStatus.toUpperCase(),
                style: GoogleFonts.spaceMono(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ],
        ),
        if (profile.location != null && profile.location!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: _neon, size: 16),
              const SizedBox(width: 6),
              Text(
                profile.location!,
                style: GoogleFonts.spaceMono(
                  color: _white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        if (profile.customStatus != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _white.withValues(alpha: 0.05)),
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
                    style: GoogleFonts.inter(
                        color: _white.withValues(alpha: 0.7), fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
              label: 'STORE',
              onTap: () => context.push('/store'),
            ),
            _QuickEntry(
              icon: Icons.brush_rounded,
              label: 'CREATOR',
              onTap: () => context.push('/creator'),
            ),
            _QuickEntry(
              icon: Icons.music_note_rounded,
              label: 'SONIC',
              onTap: () => context.push('/profile/settings/sonic-drip'),
            ),
            _QuickEntry(
              icon: Icons.workspace_premium_rounded,
              label: 'PLUS',
              onTap: () => context.push('/premium/plus'),
            ),
          ]
        : <_QuickEntry>[];

    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = entries[i];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: e.onTap,
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(e.icon, color: _neon, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    e.label,
                    style: GoogleFonts.jetBrainsMono(
                      color: _white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
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
          accent: _neon,
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
              'EDIT PROFILE',
              Icons.edit_rounded,
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

    String friendLabel = 'ADD FRIEND';
    Color friendColor = _neon;
    Color friendTextColor = Colors.black;
    IconData friendIcon = Icons.person_add_rounded;

    if (_friendStatus == 'friends') {
      friendLabel = 'FRIENDS';
      friendColor = _surface;
      friendTextColor = _white;
      friendIcon = Icons.check_circle_rounded;
    } else if (_friendStatus == 'pending_sent') {
      friendLabel = 'PENDING';
      friendColor = _surface;
      friendTextColor = _muted;
      friendIcon = Icons.access_time_filled_rounded;
    } else if (_friendStatus == 'pending_received') {
      friendLabel = 'ACCEPT';
      friendColor = _neon;
      friendTextColor = Colors.black;
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
            backgroundColor: friendColor,
            textColor: friendTextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBtn(
            'MESSAGE',
            Icons.chat_bubble_rounded,
            () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming Soon'))),
            primary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(String label, IconData icon, VoidCallback onTap,
      {bool primary = true, Color? backgroundColor, Color? textColor}) {
    final bgColor = backgroundColor ?? (primary ? _neon : _surface);
    final txtColor = textColor ?? (primary ? Colors.black : _white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: _white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: txtColor, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color: txtColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: _white, size: 20),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.epilogue(
                color: _white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Container(height: 1, width: 40, color: _neon),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAboutCard(String? bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _white.withValues(alpha: 0.05)),
      ),
      child: Text(
        bio ?? 'This user has no bio.',
        style: GoogleFonts.inter(
          color: _white.withValues(alpha: 0.7),
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _white.withValues(alpha: 0.05))),
      child: Row(
        children: [
          Icon(icon, color: _neon, size: 18),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.spaceGrotesk(
                  color: _white, fontWeight: FontWeight.w600)),
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
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(role['name']?.toString().toUpperCase() ?? 'ROLE',
                  style: GoogleFonts.spaceMono(
                      color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBadgesRow(List<Badge> badges) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: badges.map<Widget>((badge) {
        final color = Color(int.parse(badge.color.replaceFirst('#', '0xFF')));
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surface,
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
                border: Border.all(color: _white.withValues(alpha: 0.1)),
              ),
              child: server['icon'] != null
                  ? Image.network(server['icon'], fit: BoxFit.cover)
                  : Center(
                      child: Text(server['name'][0].toString().toUpperCase(),
                          style: GoogleFonts.epilogue(
                              color: _neon, fontWeight: FontWeight.w900))),
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
          border: Border.all(color: _white.withValues(alpha: 0.05))),
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
                        borderSide:
                            BorderSide(color: _white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditingNote = false),
                      child: Text('CANCEL',
                          style: GoogleFonts.spaceGrotesk(color: _muted)),
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
                          backgroundColor: _neon,
                          foregroundColor: Colors.black),
                      child: Text('SAVE',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w900)),
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
                  const Icon(Icons.sticky_note_2_rounded,
                      color: _muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _note.isEmpty ? 'Click to add a private note...' : _note,
                      style: GoogleFonts.inter(
                          color: _note.isEmpty ? _muted : _white,
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
              height: 1, width: 200, color: _white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text('FLICKO // USER IDENTITY VERIFIED',
              style: GoogleFonts.spaceMono(
                  color: _white.withValues(alpha: 0.15),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0)),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    final isOwnProfile = _friendStatus == 'self';

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                color: _white.withValues(alpha: 0.1)),
            if (!isOwnProfile) ...[
              _sheetItem(Icons.block_rounded, 'BLOCK USER', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Coming Soon')));
              }, color: const Color(FlickoColors.red)),
              _sheetItem(Icons.report_problem_rounded, 'REPORT PROFILE', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Coming Soon')));
              }, color: const Color(FlickoColors.red)),
            ],
            _sheetItem(Icons.copy_rounded, 'COPY USER ID', () {
              Clipboard.setData(ClipboardData(text: widget.userId));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('ID copied!')));
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? _white, size: 22),
      title: Text(label,
          style: GoogleFonts.spaceGrotesk(
              color: color ?? _white, fontWeight: FontWeight.w700)),
      onTap: onTap,
    );
  }

  Widget _buildLinksSection(String? websiteUrl, String? socialLink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('LINKS'),
        const SizedBox(height: 8),
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
        final uri = Uri.tryParse(url);
        if (uri != null) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _neon.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: _neon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceMono(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: GoogleFonts.spaceGrotesk(
                      color: _white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: _muted, size: 16),
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
