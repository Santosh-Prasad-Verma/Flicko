import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

final soundboardServiceProvider = Provider<SoundboardService>((ref) {
  return SoundboardService(
    Supabase.instance.client,
    ref.watch(dioProvider),
  );
});

class SoundboardService {
  final SupabaseClient _supabase;
  final Dio _dio;

  SoundboardService(this._supabase, this._dio);

  SoundboardSound _parseSoundJson(Map<String, dynamic> json) {
    return SoundboardSound(
      id: json['id'] as String? ?? '',
      serverId: (json['server_id'] ?? json['serverId'] ?? '') as String,
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🔊',
      url: (json['sound_url'] ?? json['url'] ?? '') as String,
      duration: (json['duration'] as num?)?.toInt() ?? 3,
      isFavorite: (json['is_favorite'] ?? json['isFavorite'] ?? false) as bool,
      creatorId: (json['uploaded_by'] ?? json['uploadedBy'] ?? json['creatorId'] ?? '') as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt'] as String) 
              : DateTime.now()),
    );
  }

  Future<List<SoundboardSound>> getServerSounds(String serverId) async {
    if (serverId == 'global' || serverId == 'trending') {
      return getTrendingSounds();
    }
    
    try {
      if (AppConfig.hasApiBaseUrl) {
        final response = await _dio.get('/servers/$serverId/soundboard');
        if (response.statusCode == 200) {
          final list = response.data as List;
          return list.map((json) => _parseSoundJson(Map<String, dynamic>.from(json as Map))).toList();
        }
      }
      
      // Fallback to Supabase if API URL is not configured
      final response = await _supabase
          .from('soundboard_sounds')
          .select()
          .eq('server_id', serverId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => _parseSoundJson(Map<String, dynamic>.from(json as Map))).toList();
    } catch (e) {
      debugPrint('Error getting server sounds: $e');
      return [];
    }
  }

  Future<List<SoundboardSound>> getFavoriteSounds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      if (AppConfig.hasApiBaseUrl) {
        final response = await _dio.get('/soundboard/favorites');
        if (response.statusCode == 200) {
          final list = response.data as List;
          return list.map((json) => _parseSoundJson(Map<String, dynamic>.from(json as Map))).toList();
        }
      }

      final response = await _supabase
          .from('soundboard_favorites')
          .select('sound:sound_id(*)')
          .eq('user_id', userId);

      return (response as List)
          .map((json) => _parseSoundJson(Map<String, dynamic>.from(json['sound'] as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting favorite sounds: $e');
      return [];
    }
  }

  Future<void> toggleFavorite(String soundId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await _supabase
          .from('soundboard_favorites')
          .select()
          .eq('user_id', userId)
          .eq('sound_id', soundId)
          .maybeSingle();

      if (existing != null) {
        if (AppConfig.hasApiBaseUrl) {
          await _dio.delete('/soundboard/sounds/$soundId/favorite');
        } else {
          await _supabase
              .from('soundboard_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('sound_id', soundId);
        }
      } else {
        if (AppConfig.hasApiBaseUrl) {
          await _dio.post('/soundboard/sounds/$soundId/favorite');
        } else {
          await _supabase.from('soundboard_favorites').insert({
            'user_id': userId,
            'sound_id': soundId,
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling favorite sound: $e');
    }
  }

  Future<void> playSound(String soundId, {String? serverId, String? channelId}) async {
    try {
      if (AppConfig.hasApiBaseUrl && serverId != null && channelId != null) {
        await _dio.post('/servers/$serverId/soundboard/play', data: {
          'sound_id': soundId,
          'channel_id': channelId,
        });
      } else {
        // Fallback to local RPC
        if (!soundId.startsWith('myinstants_')) {
          await _supabase.rpc('increment_sound_plays', params: {'sound_id': soundId});
        }
      }
    } catch (e) {
      debugPrint('Error incrementing play count: $e');
    }
  }

  Future<SoundboardSound?> uploadSound(String serverId, String name, String emoji, File file) async {
    try {
      if (AppConfig.hasApiBaseUrl) {
        final filename = file.path.split('/').last;
        final formData = FormData.fromMap({
          'name': name,
          'emoji': emoji,
          'file': await MultipartFile.fromFile(file.path, filename: filename),
        });

        final response = await _dio.post(
          '/servers/$serverId/soundboard',
          data: formData,
          options: Options(
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          ),
        );

        if (response.statusCode == 200) {
          return _parseSoundJson(Map<String, dynamic>.from(response.data as Map));
        }
      }
    } catch (e) {
      debugPrint('Error uploading sound: $e');
    }
    return null;
  }

  Future<bool> deleteSound(String soundId) async {
    try {
      if (AppConfig.hasApiBaseUrl) {
        final response = await _dio.delete('/soundboard/sounds/$soundId');
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('Error deleting sound: $e');
    }
    return false;
  }

  Future<List<SoundboardSound>> getTrendingSounds() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.myinstants.com/en/index/us/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final sounds = _parseMyInstantsHtml(response.body);
        if (sounds.isNotEmpty) return sounds;
      }
    } catch (e) {
      debugPrint('Error fetching trending sounds from MyInstants: $e');
    }
    return _fallbackSounds;
  }

  Future<List<SoundboardSound>> searchSounds(String query) async {
    if (query.trim().isEmpty) return getTrendingSounds();
    try {
      final response = await http.get(
        Uri.parse('https://www.myinstants.com/en/search/?name=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final sounds = _parseMyInstantsHtml(response.body);
        if (sounds.isNotEmpty) return sounds;
      }
    } catch (e) {
      debugPrint('Error searching sounds from MyInstants: $e');
    }
    // Filter fallback sounds as fallback
    final lower = query.toLowerCase();
    return _fallbackSounds.where((s) => s.name.toLowerCase().contains(lower)).toList();
  }

  List<SoundboardSound> _parseMyInstantsHtml(String htmlString) {
    final List<SoundboardSound> sounds = [];
    final divs = htmlString.split(RegExp(r'class="instant"|class=\x27instant\x27'));
    
    for (int i = 1; i < divs.length; i++) {
      final segment = divs[i];
      
      final linkRegex = RegExp(r'class="instant-link"[^>]*>([^<]+)</a>|class=\x27instant-link\x27[^>]*>([^<]+)</a>');
      final linkMatch = linkRegex.firstMatch(segment);
      if (linkMatch == null) continue;
      final name = (linkMatch.group(1) ?? linkMatch.group(2) ?? '').trim();
      if (name.isEmpty) continue;
      
      final playRegex = RegExp(r'onclick="play\(\x27([^\x27]+)\x27\)"|onclick=\x27play\((?:"|\x27)([^"\x27]+)(?:"|\x27)\)\x27');
      final playMatch = playRegex.firstMatch(segment);
      if (playMatch == null) continue;
      var mp3Path = playMatch.group(1) ?? playMatch.group(2) ?? '';
      if (mp3Path.isEmpty) continue;
      
      if (!mp3Path.startsWith('http')) {
        if (mp3Path.startsWith('/')) {
          mp3Path = 'https://www.myinstants.com$mp3Path';
        } else {
          mp3Path = 'https://www.myinstants.com/$mp3Path';
        }
      }
      
      final id = mp3Path.split('/').last.replaceAll('.mp3', '');
      final emoji = _getEmojiForSound(name);
      
      sounds.add(SoundboardSound(
        id: 'myinstants_$id',
        serverId: 'global',
        name: name,
        emoji: emoji,
        url: mp3Path,
        duration: 3,
        isFavorite: false,
        creatorId: 'myinstants',
        createdAt: DateTime.now(),
      ));
    }
    return sounds;
  }

  String _getEmojiForSound(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fart')) return '💨';
    if (lower.contains('boom') || lower.contains('explosion')) return '💥';
    if (lower.contains('horn') || lower.contains('siren')) return '📢';
    if (lower.contains('clap') || lower.contains('applause')) return '👏';
    if (lower.contains('cricket')) return '🦗';
    if (lower.contains('drum') || lower.contains('rimshot')) return '🥁';
    if (lower.contains('trombone')) return '📯';
    if (lower.contains('laugh') || lower.contains('lol') || lower.contains('giggle')) return '😂';
    if (lower.contains('victory') || lower.contains('win') || lower.contains('champion')) return '🏆';
    if (lower.contains('yeet') || lower.contains('fly') || lower.contains('space')) return '🚀';
    if (lower.contains('bonk') || lower.contains('hammer')) return '🔨';
    if (lower.contains('nani') || lower.contains('what') || lower.contains('shock')) return '😱';
    if (lower.contains('bruh')) return '😐';
    if (lower.contains('wow')) return '😮';
    if (lower.contains('oof') || lower.contains('death') || lower.contains('died')) return '💀';
    if (lower.contains('ping') || lower.contains('notification')) return '🔔';
    if (lower.contains('tada') || lower.contains('celebrate') || lower.contains('sparkle')) return '✨';
    if (lower.contains('gasp') || lower.contains('surprised')) return '😮';
    if (lower.contains('scream') || lower.contains('yell') || lower.contains('shout')) return '😱';
    if (lower.contains('sigh') || lower.contains('sad') || lower.contains('cry')) return '😔';
    if (lower.contains('pipe') || lower.contains('clang')) return '🔔';
    if (lower.contains('clash') || lower.contains('fight') || lower.contains('sword')) return '⚔️';
    if (lower.contains('punch') || lower.contains('hit') || lower.contains('slap')) return '👊';
    if (lower.contains('metal') || lower.contains('iron') || lower.contains('steel')) return '🔩';
    if (lower.contains('bell') || lower.contains('chime') || lower.contains('ring')) return '🔔';
    if (lower.contains('anime') || lower.contains('cute') || lower.contains('kawaii')) return '🌸';
    if (lower.contains('game') || lower.contains('retro') || lower.contains('pixel') || lower.contains('mario') || lower.contains('zelda')) return '🎮';
    if (lower.contains('meme') || lower.contains('funny') || lower.contains('joke') || lower.contains('troll')) return '🤡';
    if (lower.contains('alarm') || lower.contains('alert') || lower.contains('warning')) return '🚨';
    if (lower.contains('cat') || lower.contains('meow')) return '🐱';
    if (lower.contains('dog') || lower.contains('bark') || lower.contains('woof')) return '🐶';
    if (lower.contains('music') || lower.contains('song') || lower.contains('melody')) return '🎶';
    if (lower.contains('gun') || lower.contains('shoot') || lower.contains('shot') || lower.contains('fire')) return '🔫';
    if (lower.contains('car') || lower.contains('engine') || lower.contains('horn')) return '🚗';
    if (lower.contains('money') || lower.contains('cash') || lower.contains('coin')) return '💰';
    if (lower.contains('magic') || lower.contains('wizard') || lower.contains('spell')) return '🔮';
    if (lower.contains('water') || lower.contains('splash') || lower.contains('wet')) return '💦';
    if (lower.contains('fire') || lower.contains('hot') || lower.contains('burn')) return '🔥';
    if (lower.contains('ghost') || lower.contains('spooky') || lower.contains('scary')) return '👻';
    return '🎵';
  }

  List<SoundboardSound> get _fallbackSounds => [
        SoundboardSound(
          id: 'myinstants_vine_boom',
          serverId: 'global',
          name: 'Vine Boom',
          emoji: '💥',
          url: 'https://www.myinstants.com/media/sounds/vine-boom-sound-effect.mp3',
          duration: 1,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_airhorn',
          serverId: 'global',
          name: 'Airhorn',
          emoji: '📢',
          url: 'https://www.myinstants.com/media/sounds/airhorn.mp3',
          duration: 2,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_sad_trombone',
          serverId: 'global',
          name: 'Sad Trombone',
          emoji: '📯',
          url: 'https://www.myinstants.com/media/sounds/sadtrombone.mp3',
          duration: 3,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_bruh',
          serverId: 'global',
          name: 'Bruh',
          emoji: '😐',
          url: 'https://www.myinstants.com/media/sounds/bruh.mp3',
          duration: 1,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_wow',
          serverId: 'global',
          name: 'Wow',
          emoji: '😮',
          url: 'https://www.myinstants.com/media/sounds/anime-wow.mp3',
          duration: 1,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_oof',
          serverId: 'global',
          name: 'Oof',
          emoji: '💀',
          url: 'https://www.myinstants.com/media/sounds/roblox-death-sound_effect.mp3',
          duration: 1,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_crickets',
          serverId: 'global',
          name: 'Crickets',
          emoji: '🦗',
          url: 'https://www.myinstants.com/media/sounds/crickets.mp3',
          duration: 3,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_tada',
          serverId: 'global',
          name: 'Tada!',
          emoji: '✨',
          url: 'https://www.myinstants.com/media/sounds/tada.mp3',
          duration: 2,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_fart',
          serverId: 'global',
          name: 'Dry Fart',
          emoji: '💨',
          url: 'https://www.myinstants.com/media/sounds/dry-fart.mp3',
          duration: 1,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
        SoundboardSound(
          id: 'myinstants_metal_pipe',
          serverId: 'global',
          name: 'Metal Pipe Clang',
          emoji: '🔔',
          url: 'https://www.myinstants.com/media/sounds/metal-pipe-clang.mp3',
          duration: 2,
          isFavorite: false,
          creatorId: 'myinstants',
          createdAt: DateTime.now(),
        ),
      ];
}
