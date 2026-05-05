import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DMChatInput extends StatefulWidget {
  final Function(String content, List<XFile>? attachments) onSend;

  const DMChatInput({
    super.key,
    required this.onSend,
  });

  @override
  State<DMChatInput> createState() => _DMChatInputState();
}

class _DMChatInputState extends State<DMChatInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedFiles = [];

  static const Color _neon = Color(0xFFC0F500);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

  void _handlePickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFiles.add(image);
      });
    }
  }

  void _handlePickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedFiles.add(video);
      });
    }
  }

  void _handleSend() {
    final content = _controller.text.trim();
    if (content.isEmpty && _selectedFiles.isEmpty) return;

    widget.onSend(content, _selectedFiles.isEmpty ? null : List.from(_selectedFiles));
    
    _controller.clear();
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _showEmojiSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('EMOJI PICKER — COMING SOON', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, color: Colors.black)),
        backgroundColor: _neon,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _white.withValues(alpha: 0.1), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedFiles.isNotEmpty)
              Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: _neon, width: 2),
                              color: _surface,
                            ),
                            child: Image.file(
                              File(_selectedFiles[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  border: Border(
                                    bottom: BorderSide(color: _neon, width: 2),
                                    left: BorderSide(color: _neon, width: 2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: _neon,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                GestureDetector(
                  onTap: _handlePickImage,
                  onLongPress: _handlePickVideo, // Long press for video
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.add, color: _white, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 5,
                            minLines: 1,
                            style: GoogleFonts.inter(
                              color: _white,
                              fontSize: 14,
                            ),
                            cursorColor: _neon,
                            decoration: InputDecoration(
                              hintText: 'TYPE MESSAGE...',
                              hintStyle: GoogleFonts.spaceMono(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showEmojiSoon,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.emoji_emotions_outlined, color: _muted, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _neon,
                    ),
                    child: const Icon(Icons.send, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
