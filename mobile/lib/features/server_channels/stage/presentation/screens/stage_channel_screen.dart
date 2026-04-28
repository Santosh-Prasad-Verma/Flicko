import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class StageParticipant {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isSpeaker;
  final bool handRaised;
  final bool selfMute;

  StageParticipant({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.isSpeaker,
    required this.handRaised,
    required this.selfMute,
  });

  factory StageParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return StageParticipant(
      userId: json['user_id'] as String,
      username: user?['username'] as String? ?? 'Unknown',
      displayName: user?['display_name'] as String?,
      avatarUrl: user?['avatar'] as String?,
      isSpeaker: !(json['suppress'] as bool? ?? false),
      handRaised: false, // TODO: store hand_raised in voice_states
      selfMute: json['self_mute'] as bool? ?? false,
    );
  }
}

class StageChannelScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const StageChannelScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<StageChannelScreen> createState() => _StageChannelScreenState();
}

class _StageChannelScreenState extends ConsumerState<StageChannelScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _channel;
  List<StageParticipant> _participants = [];
  bool _isConnected = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadChannel(),
      _loadParticipants(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadChannel() async {
    try {
      final response = await Supabase.instance.client
          .from('channels')
          .select('*')
          .eq('id', widget.channelId)
          .single();
      setState(() => _channel = response);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final response = await Supabase.instance.client
          .from('voice_states')
          .select('*, user:profiles!user_id(id, username, display_name, avatar)')
          .eq('channel_id', widget.channelId);
      
      setState(() {
        _participants = (response as List)
            .map((p) => StageParticipant.fromJson(p as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      // Handle error
    }
  }

  List<StageParticipant> get _speakers =>
      _participants.where((p) => p.isSpeaker).toList();

  List<StageParticipant> get _audience =>
      _participants.where((p) => !p.isSpeaker).toList();

  StageParticipant? get _currentUserParticipant {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );
    return _participants.firstWhere(
      (p) => p.userId == user?.id,
      orElse: () => _participants.first,
    );
  }

  bool get _isSpeaker => _currentUserParticipant?.isSpeaker ?? false;

  void _handleJoin() {
    // TODO: Implement voice connection
    setState(() => _isConnected = true);
  }

  void _handleLeave() {
    // TODO: Implement voice disconnection
    setState(() => _isConnected = false);
  }

  void _handleToggleMute() {
    setState(() => _isMuted = !_isMuted);
    // TODO: Implement actual mute toggle
  }

  void _handleRaiseHand() {
    // TODO: Implement raise hand mutation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hand raised')),
    );
  }

  void _handleParticipantPress(StageParticipant participant) {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (participant.userId == user?.id) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(participant.displayName ?? participant.username),
              subtitle: const Text('Moderator actions'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            if (!participant.isSpeaker)
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Invite to Speak'),
                onTap: () {
                  Navigator.pop(context);
                  _inviteToSpeak(participant.userId);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.mic_off),
                title: const Text('Move to Audience'),
                onTap: () {
                  Navigator.pop(context);
                  _moveToAudience(participant.userId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteToSpeak(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('voice_states')
          .update({'suppress': false})
          .eq('channel_id', widget.channelId)
          .eq('user_id', userId);
      await _loadParticipants();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to invite to speak')),
        );
      }
    }
  }

  Future<void> _moveToAudience(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('voice_states')
          .update({'suppress': true})
          .eq('channel_id', widget.channelId)
          .eq('user_id', userId);
      await _loadParticipants();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to move to audience')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(FlickoColors.blurple),
                      ),
                    )
                  : _buildContent(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.radio, color: Color(FlickoColors.accentSecondary), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _channel?['name'] ?? 'Stage',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_channel?['topic'] != null)
                  Text(
                    _channel!['topic'],
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.danger),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('SPEAKERS — ${_speakers.length}'),
          _speakers.isEmpty
              ? _buildEmptySection('No speakers yet')
              : _buildParticipantGrid(_speakers),
          const SizedBox(height: 24),
          _buildSectionTitle('AUDIENCE — ${_audience.length}'),
          _audience.isEmpty
              ? _buildEmptySection('No audience members')
              : _buildParticipantGrid(_audience),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: const Color(FlickoColors.textSecondary),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildEmptySection(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildParticipantGrid(List<StageParticipant> participants) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: participants.map((p) => _buildParticipantCard(p)).toList(),
    );
  }

  Widget _buildParticipantCard(StageParticipant participant) {
    return GestureDetector(
      onTap: () => _handleParticipantPress(participant),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (participant.displayName ?? participant.username)[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (participant.selfMute)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(FlickoColors.danger),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              participant.displayName ?? participant.username,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          top: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: _isConnected ? _buildConnectedControls() : _buildJoinButton(),
    );
  }

  Widget _buildConnectedControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: '',
          backgroundColor: _isMuted
              ? const Color(FlickoColors.danger)
              : const Color(FlickoColors.bgTertiary),
          onTap: _handleToggleMute,
        ),
        const SizedBox(width: 16),
        if (!_isSpeaker) ...[
          _buildControlButton(
            icon: Icons.back_hand,
            label: 'Raise Hand',
            backgroundColor: const Color(FlickoColors.warning),
            textColor: Colors.black,
            onTap: _handleRaiseHand,
          ),
          const SizedBox(width: 16),
        ],
        _buildControlButton(
          icon: Icons.exit_to_app,
          label: 'Leave',
          backgroundColor: const Color(FlickoColors.danger),
          textColor: Colors.white,
          onTap: _handleLeave,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor ?? const Color(FlickoColors.textPrimary), size: 22),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: textColor ?? const Color(FlickoColors.textPrimary),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return GestureDetector(
      onTap: _handleJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.blurple),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radio, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Join Stage',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
