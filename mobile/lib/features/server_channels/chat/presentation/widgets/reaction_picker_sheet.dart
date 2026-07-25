import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Animated & Custom Emoji Reaction Picker Sheet
class ReactionPickerSheet extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;

  const ReactionPickerSheet({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  State<ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<ReactionPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _quickEmojis = [
    '👍', '❤️', '😂', '😮', '😢', '🔥', '🎉', '🚀', '👀', '💯', '👏', '🙌'
  ];

  static const List<String> _gestureEmojis = [
    '👍', '👎', '👊', '✌️', '🤟', '🤘', '👌', '🤝', '🙏', '💪', '👈', '👉'
  ];

  static const List<String> _heartEmojis = [
    '❤️', '💖', '💗', '💓', '💞', '💕', '💔', '💛', '💚', '💙', '💜', '🤎'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 380,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'Add Reaction',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(FlickoColors.green),
                labelColor: const Color(FlickoColors.green),
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(text: 'Quick'),
                  Tab(text: 'Gestures'),
                  Tab(text: 'Hearts'),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEmojiGrid(_quickEmojis),
                    _buildEmojiGrid(_gestureEmojis),
                    _buildEmojiGrid(_heartEmojis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      itemCount: emojis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onEmojiSelected(emoji);
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 26),
            ),
          ),
        );
      },
    );
  }
}
