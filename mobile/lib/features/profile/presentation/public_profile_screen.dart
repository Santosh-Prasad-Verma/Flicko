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
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';

/// Unified Profile Screen — Flicko's Ultimate Profile Experience
/// Handles both current user (Self) and other users (Public) with
/// a sleek, brutalist black/neon design.
///
/// Standardized across:
/// - ProfileScreen (Self)
/// - PublicProfileScreen (Others)
/// - ProfileViewScreen (Legacy)
class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
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

  final _client = Supabase.instance.client;

  // Status colors and labels
  static const Map<String, Color> _statusColors = {
    'online': Color(FlickoColors.statusOnline),
    'idle': Color(FlickoColors.statusIdle),
    'dnd': Color(FlickoColors.statusDnd),
    'offline': Color(FlickoColors.statusOffline),
  };

  static const Map<String, String> _statusLabels = {
    'online': 'Online',
    'idle': 'Idle',
    'dnd': 'Do Not Disturb',
    'offline': 'Offline',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadProfile();
  }

  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
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

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      // Fetch profile
      final response = await _client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .single();

      _profile = UserModel.fromJson(response);

      // Get current user to determine if own profile
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (user, _) => user,
            orElse: () => null,
          );

      final isOwnProfile = currentUser?.id == widget.userId;

      if (!isOwnProfile && currentUser != null) {
        // Check friend status
        await _checkFriendStatus(currentUser.id);
        // Fetch mutual servers
        await _loadMutualServers(currentUser.id);
        // Fetch private note
        await _loadNote(currentUser.id);
      }

      // Fetch user roles
      await _loadUserRoles();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profile = null;
        });
      }
    }
  }

  Future<void> _checkFriendStatus(String currentUserId) async {
    try {
      // Check if blocked
      final blocked = await _client
          .from('blocked_users')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', widget.userId)
          .maybeSingle();

      if (blocked != null) {
        setState(() => _friendStatus = 'blocked');
        return;
      }

      // Check if friends
      final friendship = await _client
          .from('friends')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('friend_id', widget.userId)
          .maybeSingle();

      if (friendship != null) {
        setState(() => _friendStatus = 'friends');
        return;
      }

      // Check reverse direction too
      final reverseFriendship = await _client
          .from('friends')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('friend_id', currentUserId)
          .maybeSingle();

      if (reverseFriendship != null) {
        setState(() => _friendStatus = 'friends');
        return;
      }

      // Check pending sent
      final sent = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', currentUserId)
          .eq('receiver_id', widget.userId)
          .eq('status', 'pending')
          .maybeSingle();

      if (sent != null) {
        setState(() => _friendStatus = 'pending_sent');
        return;
      }

      // Check pending received
      final recv = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', widget.userId)
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (recv != null) {
        setState(() => _friendStatus = 'pending_received');
        return;
      }

      setState(() => _friendStatus = 'none');
    } catch (e) {
      setState(() => _friendStatus = 'none');
    }
  }

  Future<void> _loadMutualServers(String currentUserId) async {
    try {
      // Get current user's servers
      final myMemberships = await _client
          .from('server_members')
          .select('server_id')
          .eq('user_id', currentUserId);

      // Get target user's servers
      final theirMemberships = await _client
          .from('server_members')
          .select('server_id')
          .eq('user_id', widget.userId);

      final myServerIds =
          (myMemberships as List).map((m) => m['server_id'] as String).toSet();
      final mutualIds = (theirMemberships as List)
          .map((m) => m['server_id'] as String)
          .where((id) => myServerIds.contains(id))
          .toList();

      if (mutualIds.isEmpty) return;

      // Fetch server details
      final servers = await _client
          .from('servers')
          .select('id, name, icon')
          .inFilter('id', mutualIds);

      setState(() {
        _mutualServers =
            (servers as List).map((s) => s as Map<String, dynamic>).toList();
      });
    } catch (e) {
      // Non-critical
    }
  }

  Future<void> _loadUserRoles() async {
    try {
      final roleRows = await _client
          .from('member_roles')
          .select('roles(id, name, color)')
          .eq('user_id', widget.userId);

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

      setState(() {
        _userRoles = rolesById.values.toList();
      });
    } catch (e) {
      // Non-critical
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    setState(() => _isActionLoading = true);

    try {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _acceptFriendRequest() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    setState(() => _isActionLoading = true);

    try {
      await _client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('sender_id', widget.userId)
          .eq('receiver_id', currentUser.id);

      await _client.from('friends').insert([
        {'user_id': currentUser.id, 'friend_id': widget.userId, 'status': 'accepted'},
      ]);

      await _client.from('friendships').insert([
        {'user_id': currentUser.id, 'friend_id': widget.userId},
      ]);

      setState(() => _friendStatus = 'friends');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _removeFriend() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    final displayName =
        _profile?.displayName ?? _profile?.username ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Remove Friend',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove $displayName as a friend?',
          style:
              GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style:
                  GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.red),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);

    try {
      await _client
          .from('friends')
          .delete()
          .or('user_id.eq.${currentUser.id},user_id.eq.${widget.userId}')
          .or('friend_id.eq.${currentUser.id},friend_id.eq.${widget.userId}');

      await _client
          .from('friendships')
          .delete()
          .or('user_id.eq.${currentUser.id},user_id.eq.${widget.userId}')
          .or('friend_id.eq.${currentUser.id},friend_id.eq.${widget.userId}');

      setState(() => _friendStatus = 'none');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _blockUser() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    final displayName =
        _profile?.displayName ?? _profile?.username ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Block User',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Block $displayName? They will no longer be able to send you messages or friend requests.',
          style:
              GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style:
                  GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.red),
            ),
            child: Text(
              'Block',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('blocked_users').upsert({
        'user_id': currentUser.id,
        'blocked_user_id': widget.userId,
      });

      await _client
          .from('friends')
          .delete()
          .or('user_id.eq.${currentUser.id},user_id.eq.${widget.userId}')
          .or('friend_id.eq.${currentUser.id},friend_id.eq.${widget.userId}');

      await _client
          .from('friendships')
          .delete()
          .or('user_id.eq.${currentUser.id},user_id.eq.${widget.userId}')
          .or('friend_id.eq.${currentUser.id},friend_id.eq.${widget.userId}');

      setState(() => _friendStatus = 'blocked');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    setState(() => _isActionLoading = true);

    try {
      await _client
          .from('blocked_users')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('blocked_user_id', widget.userId);

      setState(() => _friendStatus = 'none');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  void _showMoreOptions() {
    final isOwnProfile = _isOwnProfile;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.textMuted),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link,
                  color: Color(FlickoColors.textPrimary)),
              title: Text(
                'Copy Profile Link',
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary)),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text: 'https://flicko.app/u/${widget.userId}'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied')),
                );
              },
            ),
            if (!isOwnProfile) ...[
              if (_friendStatus == 'blocked')
                ListTile(
                  leading: const Icon(Icons.check_circle_outline,
                      color: Color(FlickoColors.statusOnline)),
                  title: Text(
                    'Unblock User',
                    style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _unblockUser();
                  },
                )
              else
                ListTile(
                  leading:
                      const Icon(Icons.block, color: Color(FlickoColors.red)),
                  title: Text(
                    'Block User',
                    style:
                        GoogleFonts.inter(color: const Color(FlickoColors.red)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _blockUser();
                  },
                ),
              ListTile(
                leading:
                    const Icon(Icons.report, color: Color(FlickoColors.red)),
                title: Text(
                  'Report',
                  style:
                      GoogleFonts.inter(color: const Color(FlickoColors.red)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
            ],
            if (isOwnProfile)
              ListTile(
                leading: const Icon(Icons.edit,
                    color: Color(FlickoColors.textPrimary)),
                title: Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/u/settings/edit-profile');
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Report User',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Reporting functionality coming soon.',
          style:
              GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style:
                  GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNote(String currentUserId) async {
    try {
      final res = await _client
          .from('user_notes')
          .select('note')
          .eq('user_id', currentUserId)
          .eq('target_user_id', widget.userId)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _note = res['note'] as String? ?? '';
          _noteController.text = _note;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveNote() async {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

    if (currentUser == null) return;

    final newNote = _noteController.text.trim();

    setState(() {
      _note = newNote;
      _isEditingNote = false;
    });

    try {
      if (newNote.isEmpty) {
        await _client
            .from('user_notes')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('target_user_id', widget.userId);
      } else {
        await _client.from('user_notes').upsert({
          'user_id': currentUser.id,
          'target_user_id': widget.userId,
          'note': newNote,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  bool get _isOwnProfile {
    final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );
    return currentUser?.id == widget.userId;
  }

  List<Map<String, dynamic>> _buildBadges(UserModel profile) {
    final badges = <Map<String, dynamic>>[];

    if (profile.isStaff) {
      badges.add({
        'icon': Icons.shield,
        'label': 'Flicko Staff',
        'color': const Color(FlickoColors.red)
      });
    }

    if (profile.isPartner) {
      badges.add({
        'icon': Icons.diamond,
        'label': 'Partnered Server Owner',
        'color': const Color(FlickoColors.blurple)
      });
    }

    if (profile.hasNitro) {
      badges.add({
        'icon': Icons.auto_awesome,
        'label': 'Nitro Subscriber',
        'color': const Color(FlickoColors.blurple)
      });
    }

    return badges;
  }

  String _formatJoinDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color get _accentColor {
    if (_profile?.accentColor != null) {
      final hex = _profile!.accentColor!.replaceAll('#', '0xFF');
      return Color(int.tryParse(hex) ?? FlickoColors.blurple);
    }
    return const Color(FlickoColors.blurple);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(FlickoColors.bgTertiary),
        body: SafeArea(
          child: ProfileSkeleton(),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgTertiary),
        appBar: AppBar(
          backgroundColor: const Color(FlickoColors.bgTertiary),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(FlickoColors.textPrimary)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'User not found',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    final displayName = profile.displayName ?? profile.username;
    final onlineStatus = profile.onlineStatus;
    final badges = _buildBadges(profile);
    final isOwnProfile = _isOwnProfile;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Banner
              SliverToBoxAdapter(
                child: _buildBanner(),
              ),

              // Profile Card
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(FlickoColors.bgSecondary),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Avatar + Actions Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildAvatarWithStatus(displayName, onlineStatus),
                              const Spacer(),
                              _buildActionButtons(isOwnProfile),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Identity
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: GoogleFonts.inter(
                                      color:
                                          const Color(FlickoColors.textPrimary),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isOwnProfile) ...[
                                    const SizedBox(width: 10),
                                    _buildStatusBadge(onlineStatus),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${profile.username}',
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textMuted),
                                  fontSize: 14,
                                ),
                              ),
                              if (profile.pronouns != null &&
                                  profile.pronouns!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  profile.pronouns!,
                                  style: GoogleFonts.inter(
                                    color:
                                        const Color(FlickoColors.textSecondary),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (profile.customStatus != null ||
                                  profile.customStatusEmoji != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (profile.customStatusEmoji != null) ...[
                                      Text(profile.customStatusEmoji!,
                                          style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                    ],
                                    if (profile.customStatus != null)
                                      Expanded(
                                        child: Text(
                                          profile.customStatus!,
                                          style: GoogleFonts.inter(
                                            color: const Color(
                                                FlickoColors.textSecondary),
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
                          ),
                        ),

                        // Badges
                        if (badges.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Wrap(
                              spacing: 8,
                              children: badges
                                  .map((b) => _buildBadgeItem(b))
                                  .toList(),
                            ),
                          ),

                        // Divider
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Divider(
                              color: Color(FlickoColors.bgTertiary), height: 1),
                        ),

                        // About Me
                        if (profile.bio != null && profile.bio!.isNotEmpty)
                          _buildSection(
                              'ABOUT ME',
                              Text(
                                profile.bio!,
                                style: GoogleFonts.inter(
                                  color:
                                      const Color(FlickoColors.textSecondary),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              )),

                        // Member Since
                        _buildSection(
                          'FLICKO MEMBER SINCE',
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.13),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.calendar_today,
                                    size: 14, color: _accentColor),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatJoinDate(profile.createdAt),
                                style: GoogleFonts.inter(
                                  color:
                                      const Color(FlickoColors.textSecondary),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Roles
                        if (_userRoles.isNotEmpty)
                          _buildSection(
                            'ROLES — ${_userRoles.length}',
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _userRoles
                                  .map((r) => _buildRolePill(r))
                                  .toList(),
                            ),
                          ),

                        // Mutual Servers
                        if (!isOwnProfile && _mutualServers.isNotEmpty)
                          _buildSection(
                            'MUTUAL SERVERS — ${_mutualServers.length}',
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _mutualServers
                                  .map((s) => _buildMutualServerChip(s))
                                  .toList(),
                            ),
                          ),

                        // Note
                        if (!isOwnProfile)
                          _buildSection('NOTE', _buildNoteSection()),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Floating Nav Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavButton(Icons.arrow_back, () => context.pop()),
                  _buildNavButton(Icons.more_horiz, _showMoreOptions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner background
          if (_profile?.bannerUrl != null)
            Image.network(
              _profile!.bannerUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: (_profile?.bannerColors != null &&
                          _profile!.bannerColors!.length >= 2)
                      ? [
                          Color(int.parse(_profile!.bannerColors![0]
                              .replaceFirst('#', '0xFF'))),
                          Color(int.parse(_profile!.bannerColors![1]
                              .replaceFirst('#', '0xFF'))),
                        ]
                      : [
                          _accentColor,
                          _accentColor.withValues(alpha: 0.67),
                          const Color(FlickoColors.bgTertiary),
                        ],
                ),
              ),
            ),

          // Bottom fade
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(FlickoColors.bgSecondary)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithStatus(String displayName, String status) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Color(FlickoColors.bgSecondary),
            shape: BoxShape.circle,
          ),
          child: UserAvatar(
            imageUrl: _profile?.avatarUrl,
            name: displayName,
            size: 84,
            status: _parseStatus(status),
            showStatus: false,
            userId: widget.userId,
            showBadge: true,
          ),
        ),

        // Status dot
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _statusColors[status] ??
                  const Color(FlickoColors.statusOnline),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(FlickoColors.bgSecondary),
                width: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  UserStatus _parseStatus(String? status) {
    switch (status) {
      case 'online':
        return UserStatus.online;
      case 'idle':
        return UserStatus.idle;
      case 'dnd':
        return UserStatus.dnd;
      default:
        return UserStatus.offline;
    }
  }

  Widget _buildActionButtons(bool isOwnProfile) {
    if (isOwnProfile) {
      return _ActionButton(
        icon: Icons.edit,
        label: 'Edit Profile',
        onPressed: () => context.push('/u/settings/edit-profile'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Friend button
        if (_friendStatus == 'none')
          _ActionButton(
            icon: Icons.person_add,
            label: 'Add Friend',
            color: _accentColor,
            onPressed: _isActionLoading ? null : _sendFriendRequest,
            loading: _isActionLoading,
          )
        else if (_friendStatus == 'pending_sent')
          const _ActionButton(
            icon: Icons.access_time,
            label: 'Pending',
            color: Color(0xFF4E5058),
            disabled: true,
          )
        else if (_friendStatus == 'pending_received')
          _ActionButton(
            icon: Icons.check_circle,
            label: 'Accept',
            color: const Color(FlickoColors.statusOnline),
            onPressed: _isActionLoading ? null : _acceptFriendRequest,
            loading: _isActionLoading,
          )
        else if (_friendStatus == 'friends')
          _ActionButton(
            icon: Icons.people,
            label: 'Friends',
            color: const Color(0xFF4E5058),
            onPressed: _isActionLoading ? null : _removeFriend,
          )
        else if (_friendStatus == 'blocked')
          _ActionButton(
            icon: Icons.block,
            label: 'Unblock',
            color: const Color(FlickoColors.red),
            onPressed: _isActionLoading ? null : _unblockUser,
            loading: _isActionLoading,
          ),
        const SizedBox(width: 8),

        // Message button
        _ActionButton(
          icon: Icons.chat_bubble,
          label: 'Message',
          color: const Color(0xFF4E5058),
          onPressed: () => context.go('/dms/${widget.userId}'),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color =
        _statusColors[status] ?? const Color(FlickoColors.statusOnline);
    final label = _statusLabels[status] ?? 'Online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(Map<String, dynamic> badge) {
    return Tooltip(
      message: badge['label'] as String,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: (badge['color'] as Color).withValues(alpha: 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(
          badge['icon'] as IconData,
          size: 16,
          color: badge['color'] as Color,
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildRolePill(Map<String, dynamic> role) {
    final colorStr = role['color'] as String? ?? '#80848E';
    final color = Color(int.parse(colorStr.replaceAll('#', '0xFF')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            role['name'] as String? ?? 'Role',
            style: GoogleFonts.inter(
                color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualServerChip(Map<String, dynamic> server) {
    final iconUrl = server['icon'] as String?;
    final name = server['name'] as String? ?? 'Server';

    return InkWell(
      onTap: () => context.push('/server/${server['id']}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(iconUrl,
                    width: 20, height: 20, fit: BoxFit.cover),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(FlickoColors.blurple),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    if (_isEditingNote) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 256,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Click to add a note about this user',
                hintStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted)),
                border: InputBorder.none,
                counterStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 11,
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isEditingNote = false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted)),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        _noteController.text = _note;
        setState(() => _isEditingNote = true);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit,
                size: 14, color: Color(FlickoColors.textMuted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _note.isNotEmpty
                    ? _note
                    : 'Click to add a note — only you can see this',
                style: GoogleFonts.inter(
                  color: _note.isNotEmpty
                      ? const Color(FlickoColors.textSecondary)
                      : const Color(FlickoColors.textMuted),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

/// Small action button used in the profile header
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onPressed,
    this.loading = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? const Color(FlickoColors.blurple);

    return ElevatedButton.icon(
      onPressed: disabled || loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 15, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
    );
  }
}
