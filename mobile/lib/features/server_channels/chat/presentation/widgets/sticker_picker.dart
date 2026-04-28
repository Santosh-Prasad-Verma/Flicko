import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class StickerPicker extends StatelessWidget {
  final Function(String stickerUrl) onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  @override
  Widget build(BuildContext context) {
    // Mock stickers, similar to Discord's Wumpus / customized server stickers
    final List<Map<String, String>> mockStickers = [
      {'name': 'Hello', 'url': 'https://media.giphy.com/media/3o7aD2saalEvpXyBfO/giphy.gif'},
      {'name': 'Sad', 'url': 'https://media.giphy.com/media/L0HIznJ2hn4WndRshY/giphy.gif'},
      {'name': 'Angry', 'url': 'https://media.giphy.com/media/11tTNkNy1SdXGg/giphy.gif'},
      {'name': 'Laughing', 'url': 'https://media.giphy.com/media/10JhviPe0lRtQC/giphy.gif'},
      {'name': 'Confused', 'url': 'https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif'},
      {'name': 'Love', 'url': 'https://media.giphy.com/media/l4pTdcifPZLpDjL1e/giphy.gif'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      height: 400,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stickers',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(FlickoColors.textSecondary)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: mockStickers.length,
              itemBuilder: (context, index) {
                final sticker = mockStickers[index];
                return GestureDetector(
                  onTap: () {
                    onStickerSelected(sticker['url']!);
                    Navigator.pop(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      sticker['url']!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error, color: Color(FlickoColors.danger)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension StickerPickerContext on BuildContext {
  void showStickerPicker({required Function(String stickerUrl) onStickerSelected}) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StickerPicker(onStickerSelected: onStickerSelected),
    );
  }
}
