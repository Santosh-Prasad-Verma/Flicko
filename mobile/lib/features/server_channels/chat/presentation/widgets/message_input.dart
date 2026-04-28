import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class MessageInput extends StatefulWidget {
  final Function(String, {List<XFile>? attachments}) onSend;
  final String? replyToName;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    required this.onSend,
    this.replyToName,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedFiles = [];
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    setState(() {
      _isEmpty = _controller.text.trim().isEmpty && _selectedFiles.isEmpty;
    });
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
      _controller.clear();
      setState(() {
        _selectedFiles = [];
        _isEmpty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF36393F),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyToName != null) _buildReplyBar(),
            if (_selectedFiles.isNotEmpty) _buildAttachmentPreview(),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF40444B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // + attach button (inside the bar)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFB5BAC1), size: 24),
                    onPressed: _pickFiles,
                    padding: const EdgeInsets.only(left: 12, right: 4, top: 12, bottom: 12),
                    constraints: const BoxConstraints(),
                    iconSize: 24,
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFDBDEE1),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message #general',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF6D6F78),
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  // Right side buttons (inside the bar)
                  if (_isEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.card_giftcard, color: Color(0xFFB5BAC1), size: 24),
                      onPressed: () {},
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFB5BAC1), size: 24),
                      onPressed: () {},
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFFB5BAC1), size: 24),
                      onPressed: _handleSend,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      height: 80,
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
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(_selectedFiles[index].path),
                    width: 68,
                    height: 68,
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
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2F3136),
        border: Border(
          left: BorderSide(
            color: Color(FlickoColors.blurple),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Color(FlickoColors.blurple)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${widget.replyToName}',
              style: GoogleFonts.inter(
                color: const Color(0xFFB5BAC1),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onCancelReply,
            child: const Icon(Icons.close, size: 16, color: Color(0xFFB5BAC1)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

