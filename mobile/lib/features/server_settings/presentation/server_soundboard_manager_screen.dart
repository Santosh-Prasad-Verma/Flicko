import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Server Soundboard Manager Screen
/// Admin portal to upload audio files, assign sound names, and set emoji icons for custom server soundboards.
class ServerSoundboardManagerScreen extends StatefulWidget {
  final String serverId;

  const ServerSoundboardManagerScreen({super.key, required this.serverId});

  @override
  State<ServerSoundboardManagerScreen> createState() => _ServerSoundboardManagerScreenState();
}

class _ServerSoundboardManagerScreenState extends State<ServerSoundboardManagerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sounds = [];

  final _soundNameController = TextEditingController();
  final _audioUrlController = TextEditingController();
  String _selectedEmoji = '🔊';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void dispose() {
    _soundNameController.dispose();
    _audioUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('server_soundboard_sounds')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _sounds = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSound() async {
    final name = _soundNameController.text.trim();
    final url = _audioUrlController.text.trim();
    if (name.isEmpty || _isUploading) return;

    final finalUrl = url.isNotEmpty ? url : 'https://www.myinstants.com/media/sounds/quack.mp3';

    setState(() => _isUploading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('server_soundboard_sounds').insert({
        'server_id': widget.serverId,
        'uploader_id': userId,
        'sound_name': name,
        'audio_url': finalUrl,
        'emoji': _selectedEmoji,
      });

      _soundNameController.clear();
      _audioUrlController.clear();
      if (mounted) Navigator.pop(context);
      await _loadSounds();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAddSoundModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Soundboard Clip', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _soundNameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Sound Name (e.g. Quack, Airhorn)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _audioUrlController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Audio URL (.mp3)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['🔊', '🎉', '🎺', '💥', '🦆'].map((emoji) {
                  final isSel = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(FlickoColors.brandLime).withValues(alpha: 0.2) : Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: isSel ? Border.all(color: const Color(FlickoColors.brandLime)) : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _addSound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Upload Soundboard Clip', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Server Soundboard Studio', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: Color(FlickoColors.brandLime)), onPressed: _showAddSoundModal),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _sounds.isEmpty
              ? Center(child: Text('No soundboard clips added yet.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2),
                  itemCount: _sounds.length,
                  itemBuilder: (context, index) {
                    final s = _sounds[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(s['emoji'] as String? ?? '🔊', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s['sound_name'] as String, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Tap to Preview', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
