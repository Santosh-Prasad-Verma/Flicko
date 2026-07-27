import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class VoiceChannelChatSheet extends StatefulWidget {
  final String channelName;
  const VoiceChannelChatSheet({
    super.key,
    this.channelName = 'General',
  });

  static void show(BuildContext context, {String channelName = 'General'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => VoiceChannelChatSheet(channelName: channelName),
    );
  }

  @override
  State<VoiceChannelChatSheet> createState() => _VoiceChannelChatSheetState();
}

class _VoiceChannelChatSheetState extends State<VoiceChannelChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const brandGreen = Color(FlickoColors.brandLime);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Chat',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: bgTertiary,
                          ),
                          child: const Icon(Icons.tag_rounded, color: brandGreen, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to ${widget.channelName}!',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This is the start of the ${widget.channelName} channel.',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.edit_rounded, color: brandGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Edit channel',
                              style: GoogleFonts.inter(
                                color: brandGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),

                        ..._messages.map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: brandGreen,
                                    child: Icon(Icons.face_rounded, color: Colors.black, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['user'] ?? 'Tarun_ OP',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          m['text'] ?? '',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: bgSecondary,
                    child: Row(
                      children: [
                        _buildInputIcon(Icons.add_rounded, () {}),
                        const SizedBox(width: 4),
                        _buildInputIcon(Icons.widgets_rounded, () {}),
                        const SizedBox(width: 4),
                        _buildInputIcon(Icons.card_giftcard_rounded, () {}),
                        const SizedBox(width: 6),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: bgTertiary,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _msgController,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Message ${widget.channelName}...',
                                      hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (val) {
                                      if (val.trim().isNotEmpty) {
                                        setState(() {
                                          _messages.add({'user': 'Tarun_ OP', 'text': val.trim()});
                                          _msgController.clear();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white54, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        _buildInputIcon(Icons.mic_rounded, () {}),
                      ],
                    ),
                  ),
                ],
              ),

              Positioned(
                bottom: 60,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: brandGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.black, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputIcon(IconData icon, VoidCallback onTap) {
    const bgTertiary = Color(FlickoColors.bgTertiary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: bgTertiary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
