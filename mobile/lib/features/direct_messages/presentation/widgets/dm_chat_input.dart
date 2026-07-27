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
import 'package:mobile/features/server_channels/chat/presentation/widgets/emoji_picker.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/gif_picker.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/sticker_picker.dart';

class DMChatInput extends StatefulWidget {
  final Function(String content, {List<XFile>? attachments, String? gifUrl, String? stickerUrl}) onSend;
  final VoidCallback? onTypingStart;
  final VoidCallback? onTypingStop;

  const DMChatInput({
    super.key,
    required this.onSend,
    this.onTypingStart,
    this.onTypingStop,
  });

  @override
  State<DMChatInput> createState() => _DMChatInputState();
}

class _DMChatInputState extends State<DMChatInput> {
  static const Color _neonGreen = Color(FlickoColors.brandLime);
  static const Color _bgSecondary = Color(FlickoColors.bgSecondary);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF8E8E93);

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<XFile> _selectedFiles = [];
  bool _showExtras = false;
  bool _isEmpty = true;

  // Voice recording state
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _recordingPath;

  Timer? _typingThrottle;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _recordingTimer?.cancel();
    _typingThrottle?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
    if (isEmpty != _isEmpty) {
      setState(() => _isEmpty = isEmpty);
    }

    if (!isEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        widget.onTypingStart?.call();
      }
      _typingThrottle?.cancel();
      _typingThrottle = Timer(const Duration(seconds: 4), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          widget.onTypingStop?.call();
        }
      });
    } else {
      if (_isTyping) {
        _isTyping = false;
        _typingThrottle?.cancel();
        widget.onTypingStop?.call();
      }
    }
  }

  void _handlePickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images);
        _isEmpty = false;
      });
    }
  }

  void _handlePickCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedFiles.add(image);
        _isEmpty = false;
      });
    }
  }

  void _handleSend() {
    final content = _controller.text.trim();
    if (content.isEmpty && _selectedFiles.isEmpty) return;

    widget.onSend(
        content, attachments: _selectedFiles.isEmpty ? null : List.from(_selectedFiles));

    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() {
      _selectedFiles.clear();
      _showExtras = false;
      _isEmpty = true;
    });
  }

  // ── Voice Recording ──

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
        _showExtras = false;
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
        _recordingSeconds = 0;
        _recordingPath = null;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _showPermissionDenied(String permission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permission permission is required', style: GoogleFonts.inter()),
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

  // ── Pickers ──

  void _showEmojiPicker() {
    context.showEmojiPicker(
      onEmojiSelected: (emoji) {
        final text = _controller.text;
        final selection = _controller.selection;
        final newText = text.substring(0, selection.start) + emoji + text.substring(selection.end);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: selection.start + emoji.length);
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

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _buildRecordingUI();
    }

    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected attachments preview
                if (_selectedFiles.isNotEmpty)
                  SizedBox(
                    height: 84,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: _neonGreen.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    File(_selectedFiles[index].path),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                      _isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Extras drawer sheet
                if (_showExtras)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgTertiary),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ExtraTile(
                            icon: Icons.camera_alt_rounded,
                            label: 'Camera',
                            onTap: _handlePickCamera,
                          ),
                          const SizedBox(width: 16),
                          _ExtraTile(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            onTap: _handlePickImage,
                          ),
                          const SizedBox(width: 16),
                          _ExtraTile(
                            icon: Icons.emoji_emotions_rounded,
                            label: 'Emoji',
                            onTap: _showEmojiPicker,
                          ),
                          const SizedBox(width: 16),
                          _ExtraTile(
                            icon: Icons.gif_box_rounded,
                            label: 'GIF',
                            onTap: _showGifPicker,
                          ),
                          const SizedBox(width: 16),
                          _ExtraTile(
                            icon: Icons.sticky_note_2_rounded,
                            label: 'Sticker',
                            onTap: _showStickerPicker,
                          ),
                          const SizedBox(width: 16),
                          _ExtraTile(
                            icon: Icons.mic_rounded,
                            label: 'Voice',
                            onTap: _startRecording,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Main Chat Input Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Extras (+) Button
                      GestureDetector(
                        onTap: () => setState(() => _showExtras = !_showExtras),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _showExtras
                                ? _neonGreen.withValues(alpha: 0.18)
                                : const Color(FlickoColors.bgTertiary),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _showExtras
                                  ? _neonGreen.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: AnimatedRotation(
                            turns: _showExtras ? 0.125 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.add_rounded,
                              size: 22,
                              color: _showExtras ? _neonGreen : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Text Field Pill
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(FlickoColors.bgTertiary),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  maxLines: 5,
                                  minLines: 1,
                                  style: GoogleFonts.inter(
                                    color: _textWhite,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Message...',
                                    hintStyle: GoogleFonts.inter(
                                      color: _textMuted,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  textInputAction: TextInputAction.newline,
                                  onSubmitted: (_) => _handleSend(),
                                ),
                              ),
                              IconButton(
                                onPressed: _showEmojiPicker,
                                icon: const Icon(
                                  Icons.emoji_emotions_outlined,
                                  size: 22,
                                  color: _textMuted,
                                ),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send or Voice Mic button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: _isEmpty
                            ? GestureDetector(
                                key: const ValueKey('mic'),
                                onTap: _startRecording,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(FlickoColors.bgTertiary),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: const Icon(
                                    Icons.mic_rounded,
                                    size: 22,
                                    color: Colors.white70,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                key: const ValueKey('send'),
                                onTap: _handleSend,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _neonGreen,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _neonGreen.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    size: 20,
                                    color: Color(FlickoColors.bgPrimary),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => _stopRecording(cancel: true),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              _formatDuration(_recordingSeconds),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(18, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 3,
                        height: 8 + (index % 5) * 4.0,
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
            GestureDetector(
              onTap: () => _stopRecording(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, size: 18, color: Color(FlickoColors.bgPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExtraTile({
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(FlickoColors.brandLime), size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
