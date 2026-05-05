import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
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

  void _handlePickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFiles.add(image);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FlickoSpacing.sm),
      color: const Color(FlickoColors.bgSecondary),
      child: SafeArea(
        child: Column(
          children: [
            if (_selectedFiles.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(FlickoRadius.sm),
                            child: Image.file(
                              File(_selectedFiles[index].path),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(FlickoColors.red),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(FlickoColors.textSecondary)),
                  onPressed: _handlePickImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgTertiary),
                      borderRadius: BorderRadius.circular(FlickoRadius.round),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md),
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(color: Color(FlickoColors.textPrimary)),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: Color(FlickoColors.textMuted)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(FlickoColors.blurple)),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
