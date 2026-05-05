import 'dart:async';
import 'dart:io';
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

/// Enhanced MessageInput with Emoji/GIF pickers and Voice Recorder
///
/// Mirrors React Native MessageInput with all features integrated.
class EnhancedMessageInput extends StatefulWidget {
  final Function(String, {List<XFile>? attachments, String? gifUrl, String? stickerUrl}) onSend;
  final String? replyToName;
  final VoidCallback? onCancelReply;
  final Function()? onTypingStart;
  final Function()? onTypingStop;
  final VoidCallback? onPollRequested;

  const EnhancedMessageInput({
    super.key,
    required this.onSend,
    this.replyToName,
    this.onCancelReply,
    this.onTypingStart,
    this.onTypingStop,
    this.onPollRequested,
  });

  @override
  State<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends State<EnhancedMessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  List<XFile> _selectedFiles = [];
  bool _isEmpty = true;
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
  
  // Mock users for mention autocomplete (in production, fetch from server members)
  final List<MentionUser> _availableUsers = [
    MentionUser(id: '1', username: 'alice', displayName: 'Alice', avatarUrl: null, status: 'online'),
    MentionUser(id: '2', username: 'bob', displayName: 'Bob', avatarUrl: null, status: 'idle'),
    MentionUser(id: '3', username: 'charlie', displayName: 'Charlie', avatarUrl: null, status: 'offline'),
    MentionUser(id: '4', username: 'dave', avatarUrl: null, status: 'online'),
    MentionUser(id: '5', username: 'eve', displayName: 'Eve', avatarUrl: null, status: 'dnd'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
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

  Future<void> _pickFiles() async {
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

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showPermissionDenied('Microphone');
        return;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _recordingPath = path;
      });

      // Start recording timer
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
        // Send voice message
        widget.onSend('🎤 Voice message', attachments: [XFile(_recordingPath!)]);
      } else {
        await _audioRecorder.stop();
        // Delete temp file if cancelled
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
      HapticFeedback.lightImpact();
      _controller.clear();
      setState(() {
        _selectedFiles = [];
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
      },
    );
  }

  void _showStickerPicker() {
    context.showStickerPicker(
      onStickerSelected: (stickerUrl) {
        widget.onSend('', stickerUrl: stickerUrl);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgPrimary),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mention autocomplete (shown when typing @)
            if (_showMentions)
              MentionAutocomplete(
                users: _availableUsers,
                query: _mentionQuery,
                onSelect: _insertMention,
                onDismiss: _dismissMentions,
              ),
            if (widget.replyToName != null) _buildReplyBar(),
            if (_selectedFiles.isNotEmpty) _buildAttachmentPreview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAttachButton(),
                Expanded(child: _buildTextField()),
                if (_isEmpty) ...[
                  _buildStickerButton(),
                  _buildGifButton(),
                  _buildPollButton(),
                  _buildEmojiButton(),
                  _buildVoiceButton(),
                ] else
                  _buildSendButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgPrimary),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel button
            IconButton(
              onPressed: () => _stopRecording(cancel: true),
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
            
            // Recording indicator
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Recording duration
            Text(
              _formatDuration(_recordingSeconds),
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Waveform placeholder
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(20, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 3,
                        height: 10 + (index % 5) * 4.0,
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.blurple),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Lock recording
            if (!_isLockedRecording)
              IconButton(
                onPressed: () => setState(() => _isLockedRecording = true),
                icon: const Icon(Icons.lock, color: Color(FlickoColors.textSecondary)),
              ),
            
            // Send button
            IconButton(
              onPressed: () => _stopRecording(),
              icon: const Icon(Icons.send, color: Color(FlickoColors.blurple)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_selectedFiles[index].path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeFile(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Color(FlickoColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${widget.replyToName}',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onCancelReply,
            child: const Icon(Icons.close, size: 16, color: Color(FlickoColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 4),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Color(FlickoColors.textMuted)),
        onPressed: _pickFiles,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 1,
        style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        decoration: InputDecoration(
          hintText: 'Message',
          hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        onSubmitted: (_) => _handleSend(),
      ),
    );
  }

  Widget _buildGifButton() {
    return GestureDetector(
      onTap: _showGifPicker,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'GIF',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStickerButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 4),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.sticky_note_2_outlined, color: Color(FlickoColors.textMuted)),
        onPressed: _showStickerPicker,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildPollButton() {
    if (widget.onPollRequested == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 4),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.poll_outlined, color: Color(FlickoColors.textMuted)),
        onPressed: widget.onPollRequested,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmojiButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 4),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.emoji_emotions_outlined, color: Color(FlickoColors.textMuted)),
        onPressed: _showEmojiPicker,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.heavyImpact();
        _startRecording();
      },
      onLongPressEnd: (_) {
        if (!_isLockedRecording) {
          _stopRecording();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: const BoxDecoration(
          color: Color(FlickoColors.bgTertiary),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.mic, color: Color(FlickoColors.textMuted)),
          onPressed: () {
            // Show hint for long press
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hold to record', style: GoogleFonts.inter()),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.blurple),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.send, color: Colors.white),
        onPressed: _handleSend,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
