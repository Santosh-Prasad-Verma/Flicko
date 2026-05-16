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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(FlickoColors.blurple),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            if (widget.replyToName != null) _buildReplyBar(),
            if (_selectedFiles.isNotEmpty) _buildAttachmentPreview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAttachButton(),
                Expanded(child: _buildTextField()),
                if (_isEmpty) ...[
                  _buildActionButton(Icons.card_giftcard, 'Gifts'),
                  _buildActionButton(Icons.emoji_emotions_outlined, 'Emojis'),
                ] else
                  _buildSendButton(),
              ],
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

  Widget _buildActionButton(IconData icon, String name) {
    return IconButton(
      icon: Icon(icon, color: const Color(FlickoColors.textMuted)),
      onPressed: () => _showComingSoon(name),
    );
  }

  Widget _buildSendButton() {
    return IconButton(
      icon: const Icon(Icons.send, color: Color(FlickoColors.blurple)),
      onPressed: _handleSend,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

