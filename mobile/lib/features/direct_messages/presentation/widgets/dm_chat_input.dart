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

import 'package:mobile/features/server_channels/chat/presentation/widgets/emoji_picker.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/gif_picker.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/sticker_picker.dart';

class DMChatInput extends StatefulWidget {
  final Function(String content, {List<XFile>? attachments, String? gifUrl, String? stickerUrl}) onSend;

  const DMChatInput({
    super.key,
    required this.onSend,
  });

  @override
  State<DMChatInput> createState() => _DMChatInputState();
}

class _DMChatInputState extends State<DMChatInput> {
  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<XFile> _selectedFiles = [];
  bool _showExtras = false;
  bool _isEmpty = true;

  // Voice recording state
  bool _isRecording = false;
  bool _isLockedRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _recordingPath;

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
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
    if (isEmpty != _isEmpty) {
      setState(() => _isEmpty = isEmpty);
    }
  }

  void _handlePickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFiles.add(image);
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
        _isLockedRecording = false;
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
    if (_isRecording || _isLockedRecording) {
      return _buildRecordingUI();
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceContainer.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: _textWhite.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedFiles.isNotEmpty)
                  SizedBox(
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
                              border: Border.all(color: _neonGreen.withValues(alpha: 0.5)),
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
                              onTap: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                  _isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _surfaceContainer, width: 2),
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            if (_showExtras)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _bgBlack,
                  border: Border(
                    bottom: BorderSide(
                      color: _textWhite.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ExtraButton(
                      icon: Icons.emoji_emotions_rounded,
                      label: 'Emoji',
                      onTap: _showEmojiPicker,
                    ),
                    _ExtraButton(
                      icon: Icons.gif_box_rounded,
                      label: 'GIF',
                      onTap: _showGifPicker,
                    ),
                    _ExtraButton(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'Sticker',
                      onTap: _showStickerPicker,
                    ),
                    _ExtraButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: _handlePickCamera,
                    ),
                    _ExtraButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: _handlePickImage,
                    ),
                    _ExtraButton(
                      icon: Icons.mic_rounded,
                      label: 'Voice',
                      onTap: _startRecording,
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bgBlack,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _textWhite.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Plus / extras toggle
                          IconButton(
                            onPressed: () =>
                                setState(() => _showExtras = !_showExtras),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: AnimatedRotation(
                              turns: _showExtras ? 0.125 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.add_rounded,
                                size: 24,
                                color: _showExtras ? _neonGreen : _textMuted,
                              ),
                            ),
                          ),
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
                                hintText: 'Message',
                                hintStyle: GoogleFonts.inter(
                                  color: _textMuted,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) => _handleSend(),
                            ),
                          ),
                          // Inline emoji shortcut
                          IconButton(
                            onPressed: _showEmojiPicker,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              size: 22,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send / mic toggle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: _isEmpty
                        ? GestureDetector(
                            key: const ValueKey('mic'),
                            onTap: _startRecording,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _bgBlack,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _textWhite.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.mic_rounded,
                                size: 22,
                                color: _textMuted,
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
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonGreen.withValues(alpha: 0.35),
                                    blurRadius: 14,
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
        color: _surfaceContainer,
        border: Border(
          top: BorderSide(
            color: _textWhite.withValues(alpha: 0.05),
            width: 1,
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
              style: GoogleFonts.inter(
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
                  color: _bgBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _textWhite.withValues(alpha: 0.1)),
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
                      color: _neonGreen.withValues(alpha: 0.3),
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
              border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: _neonGreen, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
