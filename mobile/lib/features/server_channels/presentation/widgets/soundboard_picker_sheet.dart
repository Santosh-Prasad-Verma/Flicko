import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Soundboard Picker Sheet
/// Grid picker sheet allowing members to trigger soundboard audio clips in text/voice channels.
class SoundboardPickerSheet extends StatefulWidget {
  final String serverId;
  final Function(String soundName, String audioUrl)? onSoundTriggered;

  const SoundboardPickerSheet({
    super.key,
    required this.serverId,
    this.onSoundTriggered,
  });

  static void show(BuildContext context, {required String serverId, Function(String soundName, String audioUrl)? onSoundTriggered}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SoundboardPickerSheet(serverId: serverId, onSoundTriggered: onSoundTriggered),
    );
  }

  @override
  State<SoundboardPickerSheet> createState() => _SoundboardPickerSheetState();
}

class _SoundboardPickerSheetState extends State<SoundboardPickerSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sounds = [];

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      final response = await Supabase.instance.client
          .from('server_soundboard_sounds')
          .select('*')
          .eq('server_id', widget.serverId);

      if (mounted) {
        setState(() {
          _sounds = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sounds = [
            {'sound_name': 'Quack', 'emoji': '🦆', 'audio_url': ''},
            {'sound_name': 'Airhorn', 'emoji': '🎺', 'audio_url': ''},
            {'sound_name': 'GG WP', 'emoji': '🎉', 'audio_url': ''},
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Color(FlickoColors.brandLime)),
              const SizedBox(width: 10),
              Text('Server Soundboard', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8),
                  itemCount: _sounds.length,
                  itemBuilder: (context, index) {
                    final s = _sounds[index];
                    return InkWell(
                      onTap: () {
                        widget.onSoundTriggered?.call(s['sound_name'] as String, s['audio_url'] as String? ?? '');
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgTertiary),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Text(s['emoji'] as String? ?? '🔊', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s['sound_name'] as String,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
