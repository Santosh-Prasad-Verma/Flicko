import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'emoji_picker.dart';
import 'gif_picker.dart';
import 'mention_autocomplete.dart';
import 'sticker_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/badge_alchemy_service.dart';
import 'package:mobile/data/repositories/server_repository.dart';
import 'package:mobile/data/models/user_model.dart';

/// Enhanced MessageInput with Emoji/GIF pickers and Voice Recorder
class EnhancedMessageInput extends ConsumerStatefulWidget {
  final String? serverId;
  final Function(String, {List<XFile>? attachments, String? gifUrl, String? stickerUrl}) onSend;
  final String? replyToName;
  final VoidCallback? onCancelReply;
  final Function()? onTypingStart;
  final Function()? onTypingStop;
  final VoidCallback? onPollRequested;

  const EnhancedMessageInput({
    super.key,
    this.serverId,
    required this.onSend,
    this.replyToName,
    this.onCancelReply,
    this.onTypingStart,
    this.onTypingStop,
    this.onPollRequested,
  });

  @override
  ConsumerState<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends ConsumerState<EnhancedMessageInput> {
  static const Color _neonGreen = Color(0xFF52B788);
  // Removed _bgBlack
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  List<XFile> _selectedFiles = [];
  bool _isEmpty = true;
  bool _showExtras = false;
  
  bool _isRecording = false;
  bool _isLockedRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _recordingPath;
  Timer? _typingTimer;
  bool _isTyping = false;
  
  // Mention autocomplete state
  bool _showMentions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;
  
  // Users for mention autocomplete
  final List<MentionUser> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _loadServerMembers();
  }

  Future<void> _loadServerMembers() async {
    final serverId = widget.serverId;
    if (serverId == null) return;

    try {
      final repository = ref.read(serverRepositoryProvider);
      final members = await repository.getServerMembers(serverId);
      if (mounted) {
        setState(() {
          _availableUsers.clear();
          _availableUsers.addAll(members.map((m) => MentionUser(
            id: m.id,
            username: m.username,
            displayName: m.displayName,
            avatarUrl: m.avatarUrl,
            status: m.onlineStatus,
          )));
        });
      }
    } catch (_) {
      // Fail silently
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {
      _isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
    });

    // Handle typing indicators
    if (_controller.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTypingStart?.call();
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _isTyping = false;
        widget.onTypingStop?.call();
      }
    });

    // Check for mention context
    _checkForMentions();
  }

  void _checkForMentions() {
    final text = _controller.text;
    final cursorPosition = _controller.selection.start;
    
    if (cursorPosition <= 0) {
      _dismissMentions();
      return;
    }
    
    // Find the start of current word
    int wordStart = cursorPosition - 1;
    while (wordStart >= 0 && text[wordStart] != ' ' && text[wordStart] != '\n') {
      wordStart--;
    }
    wordStart++;
    
    // Check if word starts with @
    if (wordStart >= 0 && wordStart < text.length && text[wordStart] == '@') {
      setState(() {
        _showMentions = true;
        _mentionStartIndex = wordStart;
        _mentionQuery = text.substring(wordStart + 1, cursorPosition);
      });
    } else {
      _dismissMentions();
    }
  }

  void _dismissMentions() {
    setState(() {
      _showMentions = false;
      _mentionQuery = '';
      _mentionStartIndex = -1;
    });
  }

  void _insertMention(MentionUser user) {
    if (_mentionStartIndex < 0) return;
    
    final mentionText = '@${user.username} ';
    final text = _controller.text;
    final cursorPosition = _controller.selection.start;
    
    final newText = text.substring(0, _mentionStartIndex) + 
                    mentionText + 
                    text.substring(cursorPosition);
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: _mentionStartIndex + mentionText.length,
    );
    
    _dismissMentions();
  }

  Future<void> _handlePickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images);
          _isEmpty = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _handlePickCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedFiles.add(image);
          _isEmpty = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking from camera: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showPermissionDenied('Microphone');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _recordingPath = path;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      _recordingTimer?.cancel();
      
      if (!cancel && _recordingPath != null) {
        await _audioRecorder.stop();
        widget.onSend('🎤 Voice message', attachments: [XFile(_recordingPath!)]);
        ref.read(badgeAlchemyProvider.notifier).incrementMessagesSent();
      } else {
        await _audioRecorder.stop();
        if (_recordingPath != null) {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      setState(() {
        _isRecording = false;
        _isLockedRecording = false;
        _recordingSeconds = 0;
        _recordingPath = null;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty && _controller.text.trim().isEmpty) {
        _isEmpty = true;
      }
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty || _selectedFiles.isNotEmpty) {
      widget.onSend(text, attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null);
      ref.read(badgeAlchemyProvider.notifier).incrementMessagesSent();
      HapticFeedback.lightImpact();
      _controller.clear();
      setState(() {
        _selectedFiles = [];
        _showExtras = false;
        _isEmpty = true;
      });
      _isTyping = false;
      widget.onTypingStop?.call();
    }
  }

  void _showEmojiPicker() {
    context.showEmojiPicker(
      onEmojiSelected: (emoji) {
        final text = _controller.text;
        final selection = _controller.selection;
        final newText = text.substring(0, selection.start) + 
                        emoji + 
                        text.substring(selection.end);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: selection.start + emoji.length,
        );
      },
    );
  }

  void _showGifPicker() {
    context.showGifPicker(
      onGifSelected: (gifUrl) {
        widget.onSend('', gifUrl: gifUrl);
        ref.read(badgeAlchemyProvider.notifier).incrementMessagesSent();
      },
    );
  }

  void _showStickerPicker() {
    context.showStickerPicker(
      onStickerSelected: (stickerUrl) {
        widget.onSend('', stickerUrl: stickerUrl);
        ref.read(badgeAlchemyProvider.notifier).incrementMessagesSent();
      },
    );
  }

  void _showPermissionDenied(String permission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permission permission is required'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording || _isLockedRecording) {
      return _buildRecordingUI();
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0E).withOpacity(0.7),
            border: Border(
              top: BorderSide(
                color: const Color(FlickoColors.brandLime).withOpacity(0.15),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mention autocomplete
            if (_showMentions)
              MentionAutocomplete(
                users: _availableUsers,
                query: _mentionQuery,
                onSelect: _insertMention,
                onDismiss: _dismissMentions,
              ),
            
            // Reply bar
            if (widget.replyToName != null) _buildReplyBar(),
            
            // Selected files
            if (_selectedFiles.isNotEmpty) _buildAttachmentPreview(),

            // Extras Drawer
            if (_showExtras)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0F0E).withOpacity(0.7),
                      border: Border(bottom: BorderSide(color: _textWhite.withOpacity(0.05))),
                    ),
                    child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ExtraButton(
                        icon: Icons.emoji_emotions_rounded,
                        label: 'EMOJI',
                        onTap: _showEmojiPicker,
                      ),
                      const SizedBox(width: 16),
                      _ExtraButton(
                        icon: Icons.gif_box_rounded,
                        label: 'GIF',
                        onTap: _showGifPicker,
                      ),
                      const SizedBox(width: 16),
                      _ExtraButton(
                        icon: Icons.sticky_note_2_rounded,
                        label: 'STICKER',
                        onTap: _showStickerPicker,
                      ),
                      const SizedBox(width: 16),
                      _ExtraButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'CAMERA',
                        onTap: _handlePickCamera,
                      ),
                      const SizedBox(width: 16),
                      _ExtraButton(
                        icon: Icons.photo_library_rounded,
                        label: 'GALLERY',
                        onTap: _handlePickImage,
                      ),
                      const SizedBox(width: 16),
                      if (widget.onPollRequested != null) ...[
                        _ExtraButton(
                          icon: Icons.poll_rounded,
                          label: 'POLL',
                          onTap: () {
                            setState(() => _showExtras = false);
                            widget.onPollRequested!();
                          },
                        ),
                        const SizedBox(width: 16),
                      ],
                      _ExtraButton(
                        icon: Icons.mic_rounded,
                        label: 'VOICE',
                        onTap: _startRecording,
                      ),
                    ],
                  ),
                ),
              ))),

            // Main input row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showExtras = !_showExtras),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _showExtras ? _neonGreen.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showExtras ? _neonGreen : _textWhite.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _showExtras ? 0.125 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: _showExtras ? _neonGreen : _textWhite,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(FlickoColors.brandLime).withOpacity(0.2),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        minLines: 1,
                        style: GoogleFonts.inter(
                          color: _textWhite,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.spaceMono(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isEmpty ? Colors.white.withOpacity(0.05) : _neonGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isEmpty ? _textWhite.withOpacity(0.1) : _neonGreen,
                          width: 1,
                        ),
                        boxShadow: _isEmpty ? null : [
                          BoxShadow(
                            color: _neonGreen.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20, 
                        color: _isEmpty ? _textMuted : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )));
  }

  Widget _buildRecordingUI() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0E).withOpacity(0.7),
            border: Border(
              top: BorderSide(
                color: const Color(FlickoColors.brandLime).withOpacity(0.15),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel button
            IconButton(
              onPressed: () => _stopRecording(cancel: true),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            ),
            
            // Recording indicator
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Recording duration
            Text(
              _formatDuration(_recordingSeconds),
              style: GoogleFonts.spaceMono(
                color: _textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Waveform placeholder
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _textMuted.withOpacity(0.2)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(20, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 3,
                        height: 10 + (index % 5) * 4.0,
                        decoration: BoxDecoration(
                          color: _neonGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send button
            GestureDetector(
              onTap: () => _stopRecording(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _neonGreen.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 20, 
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    )));
  }

  Widget _buildAttachmentPreview() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _neonGreen.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      File(_selectedFiles[index].path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: GestureDetector(
                    onTap: () => _removeFile(index),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surfaceContainer, width: 2),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: _textWhite.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18, color: _neonGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${widget.replyToName}',
              style: GoogleFonts.spaceMono(
                color: _textWhite,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onCancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: _textWhite.withOpacity(0.1)),
              ),
              child: Icon(Icons.close_rounded, size: 14, color: _textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textMuted = Color(0xFF71717A);
  static const Color _textWhite = Color(0xFFFBF9FA);

  const _ExtraButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _textWhite.withOpacity(0.05)),
            ),
            child: Icon(icon, color: _neonGreen, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: _textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
