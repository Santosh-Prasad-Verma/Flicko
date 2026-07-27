import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';

class SoundboardSheet extends ConsumerStatefulWidget {
  final String serverId;
  const SoundboardSheet({super.key, required this.serverId});

  static void show(BuildContext context, {required String serverId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SoundboardSheet(serverId: serverId),
    );
  }

  @override
  ConsumerState<SoundboardSheet> createState() => _SoundboardSheetState();
}

class _SoundboardSheetState extends ConsumerState<SoundboardSheet> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _flickoSounds = [
    {'name': 'quack', 'emoji': '🦆'},
    {'name': 'airhorn', 'emoji': '🔊'},
    {'name': 'cricket', 'emoji': '🦗'},
    {'name': 'golf clap', 'emoji': '👏'},
    {'name': 'sad horn', 'emoji': '🎺'},
    {'name': 'ba dum tss', 'emoji': '🥁'},
  ];

  final List<Map<String, String>> _clashSounds = [
    {'name': 'Gem Boost', 'emoji': '💎'},
    {'name': 'Coin Steal', 'emoji': '🪙'},
    {'name': 'Coins Collect', 'emoji': '🪙'},
    {'name': 'Elixir Steal', 'emoji': '🔮'},
    {'name': 'Elixir Collect', 'emoji': '🔮'},
    {'name': 'Dark Elixir', 'emoji': '🧪'},
  ];

  @override
  Widget build(BuildContext context) {
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
          decoration: const BoxDecoration(
            color: bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
              const SizedBox(height: 16),

              Text(
                'Soundboard',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                      hintText: 'Find the perfect sound',
                      hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.blur_on_rounded, color: brandGreen, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Flicko Sounds',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.98,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _flickoSounds.length,
                      itemBuilder: (context, index) {
                        final sound = _flickoSounds[index];
                        return _buildSoundTile(sound['name']!, sound['emoji']!);
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white10)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandGreen,
                          ),
                          child: const Icon(Icons.lock_rounded, color: Colors.black, size: 14),
                        ),
                        const Expanded(child: Divider(color: Colors.white10)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 10,
                          backgroundColor: brandGreen,
                          child: Icon(Icons.shield_rounded, size: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Clash of Clans',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _clashSounds.length,
                      itemBuilder: (context, index) {
                        final sound = _clashSounds[index];
                        return _buildSoundTile(sound['name']!, sound['emoji']!);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: brandGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Make some noise with Flicko Plus',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: brandGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Colors.black, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Get Plus',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: bgSecondary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildServerIcon(Icons.blur_on_rounded, true),
                    _buildServerIcon(Icons.shield_rounded, false),
                    _buildServerIcon(Icons.code_rounded, false),
                    _buildServerIcon(Icons.sports_esports_rounded, false),
                    _buildServerIcon(Icons.gamepad_rounded, false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundTile(String name, String emoji) {
    const bgTertiary = Color(FlickoColors.bgTertiary);
    return GestureDetector(
      onTap: () {
        final sound = SoundboardSound(
          id: name.toLowerCase().replaceAll(' ', '_'),
          serverId: widget.serverId,
          name: name,
          emoji: emoji,
          url: 'https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3',
          creatorId: 'system',
          createdAt: DateTime.now(),
        );
        ref.read(voiceControllerProvider.notifier).sendSoundboardSound(sound);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔊 Broadcasted sound: $name $emoji to channel'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgTertiary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerIcon(IconData icon, bool isSelected) {
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const brandGreen = Color(FlickoColors.brandLime);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? brandGreen : bgTertiary,
      ),
      child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 18),
    );
  }
}
