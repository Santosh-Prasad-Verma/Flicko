import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_chat_controller.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class DMChatScreen extends ConsumerStatefulWidget {
  final String userId;
  const DMChatScreen({super.key, required this.userId});

  @override
  ConsumerState<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends ConsumerState<DMChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _recipientProfile;
  bool _showExtraControls = false;

  // Design tokens
  static const _bgPrimary = Color(0xFF000000);
  static const _bgCard = Color(0xFF0A0A0A);
  static const _bgSurface = Color(0xFF111111);
  static const _greenPunch = Color(0xFF10B981);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9CA3AF);
  static const _border = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _fetchRecipient();
  }

  Future<void> _fetchRecipient() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _recipientProfile = res;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateToProfile() {
    context.push('/u/${widget.userId}');
  }

  void _startVoiceCall() {
    context.push('/call/outgoing', extra: {
      'calleeName': _recipientProfile?['username'] ?? 'User',
      'calleeAvatarUrl': _recipientProfile?['avatar'],
      'callType': 'voice',
    });
  }

  void _startVideoCall() {
    context.push('/call/outgoing', extra: {
      'calleeName': _recipientProfile?['username'] ?? 'User',
      'calleeAvatarUrl': _recipientProfile?['avatar'],
      'callType': 'video',
    });
  }

  void _sendMessage() {
    final txt = _textController.text;
    if (txt.trim().isNotEmpty) {
      _textController.clear();
      ref.read(dmChatControllerProvider(widget.userId).notifier).sendMessage(txt);
    }
  }

  Future<void> _pickMedia(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          ref.read(dmChatControllerProvider(widget.userId).notifier).sendMessage('', localAttachments: images);
          setState(() => _showExtraControls = false);
        }
      } else {
        final XFile? image = await picker.pickImage(source: source);
        if (image != null) {
          ref.read(dmChatControllerProvider(widget.userId).notifier).sendMessage('', localAttachments: [image]);
          setState(() => _showExtraControls = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error picking media: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: _bgSurface,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(dmChatControllerProvider(widget.userId));
    final authState = ref.watch(authNotifierProvider);
    final myId = authState.maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => '',
    );

    final recipientName = _recipientProfile != null
        ? (_recipientProfile!['username'] ?? _recipientProfile!['full_name'] ?? 'User')
        : 'Chat';
    final recipientAvatar = _recipientProfile != null ? _recipientProfile!['avatar'] as String? : null;

    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: _bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            children: [
              // Tappable avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, width: 1),
                  image: recipientAvatar != null && recipientAvatar.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(recipientAvatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: recipientAvatar == null || recipientAvatar.isEmpty
                    ? Center(
                        child: Text(
                          recipientName.isNotEmpty ? recipientName[0].toUpperCase() : 'U',
                          style: GoogleFonts.outfit(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipientName,
                      style: GoogleFonts.outfit(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Online',
                      style: GoogleFonts.outfit(color: _greenPunch, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Voice call icon
          IconButton(
            icon: const Icon(Icons.call_outlined, color: _textSecondary, size: 24),
            onPressed: _startVoiceCall,
            tooltip: 'Voice Call',
          ),
          // Video call icon
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: _textSecondary, size: 24),
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _border, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator(color: _greenPunch))
                : chatState.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _navigateToProfile,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _bgSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _border, width: 1.5),
                                  image: recipientAvatar != null && recipientAvatar.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(recipientAvatar),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: recipientAvatar == null || recipientAvatar.isEmpty
                                    ? Icon(Icons.person, color: _textSecondary, size: 36)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              recipientName,
                              style: GoogleFonts.outfit(
                                color: _textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This is the beginning of your conversation.',
                              style: GoogleFonts.outfit(color: _textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[chatState.messages.length - 1 - index];
                          final isMe = msg.senderId == myId;
                          final msgTime = DateFormat('jm').format(msg.createdAt);

                          final hasText = msg.content.trim().isNotEmpty;
                          final hasAttachments = msg.attachments != null && msg.attachments!.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _bgSurface,
                                      border: Border.all(color: _border, width: 1),
                                      image: recipientAvatar != null && recipientAvatar.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(recipientAvatar),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: recipientAvatar == null || recipientAvatar.isEmpty
                                        ? Center(
                                            child: Text(
                                              recipientName.isNotEmpty ? recipientName[0].toUpperCase() : 'U',
                                              style: GoogleFonts.outfit(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe ? _greenPunch : _bgSurface,
                                      border: Border.all(
                                        color: isMe ? _greenPunch : _border,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (hasAttachments)
                                          ...msg.attachments!.map((attachment) => Container(
                                            margin: EdgeInsets.only(bottom: hasText ? 8 : 4),
                                            constraints: const BoxConstraints(maxHeight: 200),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _border, width: 1),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Image.network(
                                              attachment.url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: _bgPrimary,
                                                padding: const EdgeInsets.all(16),
                                                child: const Icon(Icons.broken_image, color: _textSecondary),
                                              ),
                                            ),
                                          )),
                                        if (hasText)
                                          Text(
                                            msg.content,
                                            style: GoogleFonts.outfit(
                                              color: isMe ? Colors.black : _textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        SizedBox(height: hasText ? 4 : 0),
                                        Text(
                                          msgTime,
                                          style: GoogleFonts.outfit(
                                            color: isMe ? Colors.black54 : _textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Extra controls row (media)
          if (_showExtraControls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: _bgSurface,
                border: Border(top: BorderSide(color: _border, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInputAction(Icons.photo_library_outlined, 'Gallery', () => _pickMedia(ImageSource.gallery)),
                  _buildInputAction(Icons.camera_alt_outlined, 'Camera', () => _pickMedia(ImageSource.camera)),
                ],
              ),
            ),

          // Bottom Input bar
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: _bgPrimary,
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: Row(
              children: [
                // Toggle extra controls
                GestureDetector(
                  onTap: () => setState(() => _showExtraControls = !_showExtraControls),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showExtraControls ? _greenPunch : _bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Icon(
                      _showExtraControls ? Icons.close : Icons.add,
                      color: _showExtraControls ? Colors.black : _textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: GoogleFonts.outfit(color: _textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Message $recipientName',
                              hintStyle: GoogleFonts.outfit(color: _textSecondary, fontSize: 15),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _greenPunch,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1),
              ),
              child: Icon(icon, color: _textSecondary, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
