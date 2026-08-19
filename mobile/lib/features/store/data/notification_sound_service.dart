import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;

/// Notification sound definition
class NotificationSound {
  final String id;
  final String name;
  final String slug;
  final String? assetPath;
  final String? remoteUrl;
  final bool isPremium;
  final String? previewEmoji;

  const NotificationSound({
    required this.id,
    required this.name,
    required this.slug,
    this.assetPath,
    this.remoteUrl,
    this.isPremium = false,
    this.previewEmoji,
  });

  factory NotificationSound.fromJson(Map<String, dynamic> json) {
    return NotificationSound(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? json['id'],
      assetPath: json['asset_path'] as String?,
      remoteUrl: json['remote_url'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      previewEmoji: json['preview_emoji'] as String?,
    );
  }
}

/// Built-in notification sounds
class BuiltInSounds {
  static const defaultSound = NotificationSound(
    id: 'default',
    name: 'Default',
    slug: 'default',
    previewEmoji: '🔔',
  );

  static const chime = NotificationSound(
    id: 'chime',
    name: 'Chime',
    slug: 'chime',
    previewEmoji: '🎵',
  );

  static const ping = NotificationSound(
    id: 'ping',
    name: 'Ping',
    slug: 'ping',
    previewEmoji: '⚡',
  );

  static const pop = NotificationSound(
    id: 'pop',
    name: 'Pop',
    slug: 'pop',
    previewEmoji: '💫',
  );

  static const cosmic = NotificationSound(
    id: 'cosmic',
    name: 'Cosmic',
    slug: 'cosmic',
    isPremium: true,
    previewEmoji: '🌌',
  );

  static const neon = NotificationSound(
    id: 'neon',
    name: 'Neon Glow',
    slug: 'neon',
    isPremium: true,
    previewEmoji: '✨',
  );

  static const retro = NotificationSound(
    id: 'retro',
    name: 'Retro',
    slug: 'retro',
    isPremium: true,
    previewEmoji: '👾',
  );

  static const crystal = NotificationSound(
    id: 'crystal',
    name: 'Crystal',
    slug: 'crystal',
    isPremium: true,
    previewEmoji: '💎',
  );

  static const all = [defaultSound, chime, ping, pop, cosmic, neon, retro, crystal];

  static NotificationSound? getById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Service for managing notification sounds from the store
final notificationSoundServiceProvider = Provider<NotificationSoundService>((ref) {
  return NotificationSoundService();
});

/// Provider for user's owned notification sounds
final ownedSoundsProvider = FutureProvider<List<NotificationSound>>((ref) async {
  final service = ref.read(notificationSoundServiceProvider);
  return service.getOwnedSounds();
});

/// Provider for currently selected notification sound
final selectedSoundProvider = NotifierProvider<SelectedSoundNotifier, NotificationSound>(() {
  return SelectedSoundNotifier();
});

class SelectedSoundNotifier extends Notifier<NotificationSound> {
  @override
  NotificationSound build() {
    _loadSelectedSound();
    return BuiltInSounds.defaultSound;
  }

  Future<void> _loadSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString('selected_notification_sound');
    if (soundId != null) {
      final sound = BuiltInSounds.getById(soundId);
      if (sound != null) {
        state = sound;
      }
    }
  }

  Future<void> setSound(NotificationSound sound) async {
    state = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_notification_sound', sound.id);
  }
}

class NotificationSoundService {
  /// Get all available notification sounds (built-in + owned from store)
  Future<List<NotificationSound>> getOwnedSounds() async {
    final sounds = <NotificationSound>[...BuiltInSounds.all];

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return sounds;

      // Get owned sound packs from user_cosmetics
      final response = await client
          .from('user_cosmetics')
          .select('''
            product_id,
            cosmetic_catalog!inner(cosmetic_type, metadata)
          ''')
          .eq('user_id', userId)
          .eq('cosmetic_catalog.cosmetic_type', 'sound_pack');

      // Add owned premium sounds
      for (final item in response) {
        try {
          final metadata = item['cosmetic_catalog']?['metadata'] as Map<String, dynamic>?;
          if (metadata != null && metadata['sounds'] != null) {
            final soundList = metadata['sounds'] as List;
            for (final s in soundList) {
              final sound = NotificationSound.fromJson(s as Map<String, dynamic>);
              // Remove from list if already exists (replace with owned version)
              sounds.removeWhere((existing) => existing.id == sound.id);
              sounds.add(sound);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      dev.log('[NOTIF_SOUND] Error fetching owned sounds: $e');
    }

    return sounds;
  }

  /// Check if a sound is owned by the user
  Future<bool> isSoundOwned(String soundId) async {
    if (!BuiltInSounds.getById(soundId)!.isPremium) return true;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await client
          .from('user_cosmetics')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', soundId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }
}

/// Sound picker widget for selecting notification sounds
class SoundPickerWidget extends ConsumerStatefulWidget {
  final NotificationSound? selectedSound;
  final Function(NotificationSound) onSoundSelected;

  const SoundPickerWidget({
    super.key,
    this.selectedSound,
    required this.onSoundSelected,
  });

  @override
  ConsumerState<SoundPickerWidget> createState() => _SoundPickerWidgetState();
}

class _SoundPickerWidgetState extends ConsumerState<SoundPickerWidget> {
  static const Color _neon = Color(0xFF9B84EE);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

  @override
  Widget build(BuildContext context) {
    final soundsAsync = ref.watch(ownedSoundsProvider);

    return Container(
      height: 320,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notification Sound',
                  style: TextStyle(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: _muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: soundsAsync.when(
              data: (sounds) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sounds.length,
                itemBuilder: (context, index) => _buildSoundItem(sounds[index]),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: _neon),
              ),
              error: (_, __) => Center(
                child: Text('Error loading sounds', style: TextStyle(color: _muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundItem(NotificationSound sound) {
    final isSelected = widget.selectedSound?.id == sound.id;

    return GestureDetector(
      onTap: () {
        widget.onSoundSelected(sound);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _neon.withValues(alpha: 0.15) : _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _neon : _white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _neon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  sound.previewEmoji ?? '🔔',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sound.name,
                    style: TextStyle(
                      color: _white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sound.isPremium)
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: _neon,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: _neon)
            else
              Icon(Icons.play_arrow, color: _muted),
          ],
        ),
      ),
    );
  }
}

/// Show sound picker bottom sheet
void showSoundPicker(
  BuildContext context, {
  required NotificationSound selectedSound,
  required Function(NotificationSound) onSoundSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SoundPickerWidget(
      selectedSound: selectedSound,
      onSoundSelected: onSoundSelected,
    ),
  );
}
