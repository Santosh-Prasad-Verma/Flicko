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

    widget.onSend(
        content, _selectedFiles.isEmpty ? null : List.from(_selectedFiles));

    _controller.clear();
    setState(() {
      _selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        FlickoSpacing.md,
        FlickoSpacing.sm,
        FlickoSpacing.md,
        FlickoSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgPrimary),
        border: Border(
          top: BorderSide(color: Color(FlickoColors.border), width: 1),
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
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(FlickoColors.brandLime),
                                  width: 1.5,
                                ),
                              ),
                              child: Image.file(
                                File(_selectedFiles[index].path),
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
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
                                color: Color(FlickoColors.brandLime),
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Color(FlickoColors.black)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _handlePickImage,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(FlickoColors.bgSecondary),
                      foregroundColor: const Color(FlickoColors.textPrimary),
                      side: const BorderSide(
                          color: Color(FlickoColors.border), width: 1.5),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Icon(Icons.add, size: 24),
                  ),
                ),
                const SizedBox(width: FlickoSpacing.sm),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgSecondary),
                      border: Border.all(
                          color: const Color(FlickoColors.border), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: FlickoSpacing.md),
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(
                          color: Color(FlickoColors.textPrimary)),
                      decoration: const InputDecoration(
                        hintText: 'ENTER MESSAGE...',
                        hintStyle:
                            TextStyle(color: Color(FlickoColors.textMuted)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: FlickoSpacing.sm),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSend,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(FlickoColors.brandLime),
                      foregroundColor: const Color(FlickoColors.black),
                      shape: const RoundedRectangleBorder(),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.send_rounded, size: 22),
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
