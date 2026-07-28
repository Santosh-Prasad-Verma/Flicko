import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';

class VoiceChannelChatSheet extends ConsumerStatefulWidget {
  final String channelName;
  const VoiceChannelChatSheet({
    super.key,
    this.channelName = 'General',
  });

  static void show(BuildContext context, {String channelName = 'General'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => VoiceChannelChatSheet(channelName: channelName),
    );
  }

  @override
  ConsumerState<VoiceChannelChatSheet> createState() => _VoiceChannelChatSheetState();
}

class _VoiceChannelChatSheetState extends ConsumerState<VoiceChannelChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isInputEmpty = true;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() {
      final textEmpty = _msgController.text.trim().isEmpty;
      if (textEmpty != _isInputEmpty) {
        setState(() {
          _isInputEmpty = textEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final currentAuthUser = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    final String username = currentAuthUser?.userMetadata?['username'] as String? ?? 
                           currentAuthUser?.userMetadata?['display_name'] as String? ?? 
                           currentAuthUser?.email?.split('@').first ?? 'User';
    final String? avatarUrl = currentAuthUser?.userMetadata?['avatar_url'] as String? ?? 
                             currentAuthUser?.userMetadata?['avatar'] as String?;
    final String userId = currentAuthUser?.id ?? '';

    setState(() {
      _messages.add({
        'user': username,
        'avatar': avatarUrl ?? '',
        'userId': userId,
        'text': text,
        'time': 'Just now',
      });
      _msgController.clear();
      _isInputEmpty = true;
    });

    ref.read(voiceControllerProvider.notifier).playFlickoNotificationSound();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const brandGreen = Color(FlickoColors.brandLime);

    final currentAuthUser = ref.watch(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );
    final String currentUserId = currentAuthUser?.id ?? '';
    final String currentAvatarUrl = currentAuthUser?.userMetadata?['avatar_url'] as String? ?? 
                                   currentAuthUser?.userMetadata?['avatar'] as String? ?? '';
    final String currentUsername = currentAuthUser?.userMetadata?['username'] as String? ?? 'User';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header with Title and Close Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chat',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 8),

              // Messages List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgTertiary,
                        ),
                        child: const Icon(Icons.tag_rounded, color: brandGreen, size: 32),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Welcome to ${widget.channelName}!',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'This is the start of the ${widget.channelName} channel.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),

                    ..._messages.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(
                            imageUrl: (m['avatar'] != null && m['avatar']!.isNotEmpty) ? m['avatar'] : null,
                            name: m['user'] ?? 'User',
                            size: 36,
                            userId: m['userId'],
                            showStatus: false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      m['user'] ?? 'User',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      m['time'] ?? '',
                                      style: GoogleFonts.inter(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m['text'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

              // Bottom Input Bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: bgSecondary,
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    _buildInputIcon(Icons.add_rounded, () {}),
                    const SizedBox(width: 6),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: bgTertiary,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgController,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Message ${widget.channelName}...',
                                  hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white54, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Dynamic Send / Mic Action Button
                    GestureDetector(
                      onTap: _isInputEmpty ? null : _sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _isInputEmpty ? bgTertiary : brandGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isInputEmpty ? Icons.mic_rounded : Icons.send_rounded,
                          color: _isInputEmpty ? Colors.white54 : Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputIcon(IconData icon, VoidCallback onTap) {
    const bgTertiary = Color(FlickoColors.bgTertiary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: bgTertiary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
