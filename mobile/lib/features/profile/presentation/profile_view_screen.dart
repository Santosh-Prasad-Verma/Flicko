import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/button.dart';
import 'package:mobile/features/shared/presentation/widgets/card.dart' as flicko_card;
import 'package:mobile/features/shared/presentation/widgets/input.dart';
import 'package:mobile/features/shared/presentation/widgets/modal.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileViewScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _errorMessage;
  bool _isOwnProfile = false;
  String _friendStatus = 'none';
  String _note = '';
  bool _isEditingNote = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      _isOwnProfile = currentUser?.id == widget.userId;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .single();

      setState(() {
        _profile = response;
        _isLoading = false;
      });

      if (!_isOwnProfile && currentUser != null) {
        await _loadFriendStatus();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFriendStatus() async {
    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (currentUser == null) return;

      final friendship = await Supabase.instance.client
          .from('friendships')
          .select('*')
          .or('user_id.eq.${currentUser.id},friend_id.eq.${currentUser.id}')
          .or('user_id.eq.${widget.userId},friend_id.eq.${widget.userId}')
          .maybeSingle();

      if (friendship != null) {
        setState(() => _friendStatus = 'friends');
        return;
      }

      final sentRequest = await Supabase.instance.client
          .from('friend_requests')
          .select('*')
          .eq('sender_id', currentUser.id)
          .eq('receiver_id', widget.userId)
          .eq('status', 'pending')
          .maybeSingle();

      if (sentRequest != null) {
        setState(() => _friendStatus = 'pending_sent');
        return;
      }

      final receivedRequest = await Supabase.instance.client
          .from('friend_requests')
          .select('*')
          .eq('sender_id', widget.userId)
          .eq('receiver_id', currentUser.id)
          .eq('status', 'pending')
          .maybeSingle();

      if (receivedRequest != null) {
        setState(() => _friendStatus = 'pending_received');
        return;
      }

      setState(() => _friendStatus = 'none');
    } catch (e) {
      // Friend status load error is not critical
    }
  }

  Future<void> _handleFriendAction() async {
    if (_friendStatus == 'none') {
      await _sendFriendRequest();
    } else if (_friendStatus == 'pending_received') {
      await _acceptFriendRequest();
    } else if (_friendStatus == 'friends') {
      await _removeFriend();
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() {});
    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (currentUser == null) return;

      await Supabase.instance.client.from('friend_requests').insert({
        'sender_id': currentUser.id,
        'receiver_id': widget.userId,
        'status': 'pending',
      });

      setState(() {
        _friendStatus = 'pending_sent';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (currentUser == null) return;

      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('sender_id', widget.userId)
          .eq('receiver_id', currentUser.id);

      await Supabase.instance.client.from('friendships').insert([
        {'user_id': currentUser.id, 'friend_id': widget.userId},
        {'user_id': widget.userId, 'friend_id': currentUser.id},
      ]);

      setState(() => _friendStatus = 'friends');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    bool confirmed = false;
    if (mounted) {
      confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => Modal(
          visible: true,
          onClose: () => Navigator.of(context).pop(false),
          title: 'Remove Friend',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remove ${_profile?['display_name'] ?? _profile?['username']} as a friend?',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      title: 'Cancel',
                      onPress: () => Navigator.of(context).pop(false),
                      variant: ButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Button(
                      title: 'Remove',
                      onPress: () => Navigator.of(context).pop(true),
                      variant: ButtonVariant.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ) ?? false;
    }

    if (confirmed) {
      try {
        final currentUser = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user,
          orElse: () => null,
        );

        if (currentUser == null) return;

        await Supabase.instance.client
            .from('friendships')
            .delete()
            .or('user_id.eq.${currentUser.id},user_id.eq.${widget.userId}')
            .or('friend_id.eq.${currentUser.id},friend_id.eq.${widget.userId}');

        setState(() => _friendStatus = 'none');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove: ${e.toString()}'),
              backgroundColor: const Color(FlickoColors.danger),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        appBar: AppBar(
          backgroundColor: const Color(FlickoColors.bgPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
        ),
      );
    }

    if (_errorMessage != null || _profile == null) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        appBar: AppBar(
          backgroundColor: const Color(FlickoColors.bgPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
              const SizedBox(height: 16),
              Text('Error loading profile', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'User not found', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final displayName = _profile!['display_name'] ?? _profile!['username'] ?? 'Unknown';
    final username = _profile!['username'] ?? 'unknown';
    final accentColor = _profile!['accent_color'] ?? '#5865F2';

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(FlickoColors.textPrimary)),
            onPressed: () => _showMoreOptions(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildBanner(accentColor)),
          SliverToBoxAdapter(child: _buildProfileCard(displayName, username, accentColor)),
          SliverToBoxAdapter(child: _buildSections()),
        ],
      ),
    );
  }

  Widget _buildBanner(String accentColor) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(int.parse(accentColor.replaceFirst('#', '0xFF'))),
            Color(int.parse(accentColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.6),
            const Color(FlickoColors.bgPrimary),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildProfileCard(String displayName, String username, String accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      transform: Matrix4.translationValues(0, -50, 0),
      child: flicko_card.Card(
        elevation: flicko_card.CardElevation.subtle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Avatar(
                    uri: _profile!['avatar'] as String?,
                    name: displayName,
                    size: AvatarSize.xl,
                    status: _profile!['status'] == 'online'
                        ? StatusIndicator.online
                        : _profile!['status'] == 'idle'
                            ? StatusIndicator.idle
                            : _profile!['status'] == 'dnd'
                                ? StatusIndicator.dnd
                                : StatusIndicator.offline,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isOwnProfile) _buildFriendButtons() else _buildEditButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendButtons() {
    return Row(
      children: [
        if (_friendStatus == 'none')
          Expanded(
            child: Button(
              title: 'Add Friend',
              onPress: _handleFriendAction,
              variant: ButtonVariant.primary,
            ),
          ),
        if (_friendStatus == 'pending_sent')
          Expanded(
            child: Button(
              title: 'Pending',
              onPress: () {},
              variant: ButtonVariant.secondary,
              disabled: true,
            ),
          ),
        if (_friendStatus == 'pending_received')
          Expanded(
            child: Button(
              title: 'Accept',
              onPress: _handleFriendAction,
              variant: ButtonVariant.primary,
            ),
          ),
        if (_friendStatus == 'friends')
          Expanded(
            child: Button(
              title: 'Friends',
              onPress: _handleFriendAction,
              variant: ButtonVariant.secondary,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Button(
            title: 'Message',
            onPress: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message - Coming Soon')),
              );
            },
            variant: ButtonVariant.ghost,
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return Button(
      title: 'Edit Profile',
      onPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit Profile - Coming Soon')),
        );
      },
      variant: ButtonVariant.secondary,
    );
  }

  Widget _buildSections() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_profile?['bio'] != null) _buildSection('ABOUT ME', _profile!['bio'] as String),
          _buildSection('FLICKO MEMBER SINCE', _formatDate(_profile?['created_at'])),
          if (!_isOwnProfile) _buildNoteSection(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NOTE',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (_note.isNotEmpty && !_isEditingNote)
              TextButton(
                onPressed: () => setState(() => _isEditingNote = true),
                child: const Text('Edit', style: TextStyle(color: Color(FlickoColors.blurple))),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isEditingNote
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Input(
                      controller: _noteController,
                      hint: 'Add a note about this user',
                      maxLines: 4,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_noteController.text.length}/256',
                          style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingNote = false;
                                  _noteController.text = _note;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _saveNote,
                              child: const Text('Save', style: TextStyle(color: Color(FlickoColors.blurple))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : InkWell(
                  onTap: () {
                    setState(() {
                      _isEditingNote = true;
                      _noteController.text = _note;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 14, color: Color(FlickoColors.textMuted)),
                      const SizedBox(width: 8),
                      Text(
                        _note.isEmpty ? 'Click to add a note' : _note,
                        style: GoogleFonts.inter(
                          color: _note.isEmpty ? const Color(FlickoColors.textMuted) : const Color(FlickoColors.textPrimary),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _saveNote() async {
    setState(() {
      _note = _noteController.text;
      _isEditingNote = false;
    });
    // Save to local storage
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy User ID'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User ID copied')),
                );
              },
            ),
            if (!_isOwnProfile) ...[
              ListTile(
                leading: const Icon(Icons.block, color: Color(FlickoColors.danger)),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Block - Coming Soon')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}
