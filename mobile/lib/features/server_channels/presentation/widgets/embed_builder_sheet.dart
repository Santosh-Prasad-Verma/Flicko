import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Embed Builder Sheet
/// Visual embed creation sheet to format rich title, description, side color bar, thumbnail, and footers.
class EmbedBuilderSheet extends StatefulWidget {
  final String channelId;

  const EmbedBuilderSheet({super.key, required this.channelId});

  static void show(BuildContext context, {required String channelId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EmbedBuilderSheet(channelId: channelId),
      ),
    );
  }

  @override
  State<EmbedBuilderSheet> createState() => _EmbedBuilderSheetState();
}

class _EmbedBuilderSheetState extends State<EmbedBuilderSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _authorController = TextEditingController();
  final _footerController = TextEditingController();

  Color _selectedColor = const Color(FlickoColors.brandLime);
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _authorController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _sendEmbedMessage() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty && desc.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final embedData = {
        'title': title,
        'description': desc,
        'author': _authorController.text.trim(),
        'footer': _footerController.text.trim(),
        'color': '#${_selectedColor.toARGB32().toRadixString(16).substring(2)}',
      };

      await Supabase.instance.client.from('messages').insert({
        'channel_id': widget.channelId,
        'user_id': userId,
        'content': '',
        'embeds': [embedData],
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.art_track_rounded, color: Color(FlickoColors.brandLime)),
              const SizedBox(width: 10),
              Text('Rich Embed Builder', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Embed Title',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Embed Description...',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _authorController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Author Name (Optional)',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _footerController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Footer Text (Optional)',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Embed Side Color Selector
                Text('Accent Border Color', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Color(FlickoColors.brandLime),
                    Colors.purpleAccent,
                    Colors.blueAccent,
                    Colors.redAccent,
                    Colors.amberAccent,
                  ].map((color) {
                    final isSel = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendEmbedMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.brandLime),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text('Send Rich Embed', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
