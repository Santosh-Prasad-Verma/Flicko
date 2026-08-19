import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Activity Settings Screen
/// Controls user Rich Presence status cards ("Playing Valorant", "Coding in Flutter", "Listening to Sonic").
class ActivitySettingsScreen extends StatefulWidget {
  const ActivitySettingsScreen({super.key});

  @override
  State<ActivitySettingsScreen> createState() => _ActivitySettingsScreenState();
}

class _ActivitySettingsScreenState extends State<ActivitySettingsScreen> {
  bool _displayActivity = true;
  final _activityController = TextEditingController(text: 'Playing Flicko 🚀');
  final _detailsController = TextEditingController(text: 'Competitive Match');

  @override
  void dispose() {
    _activityController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _saveActivityStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final activityText = _displayActivity ? _activityController.text.trim() : null;

      await Supabase.instance.client.from('profiles').update({
        'status': activityText,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rich Presence Status Saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Activity Privacy & Rich Presence', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Display Current Activity', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Share your active game or app status with friends', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _displayActivity,
                  activeColor: const Color(FlickoColors.brandLime),
                  onChanged: (v) => setState(() => _displayActivity = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_displayActivity) ...[
            Text('Activity Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _activityController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Playing Valorant',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                filled: true,
                fillColor: const Color(FlickoColors.bgSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text('Game Details / State', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. In Competitive Match (Ranked)',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                filled: true,
                fillColor: const Color(FlickoColors.bgSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveActivityStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.brandLime),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Save Activity Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
