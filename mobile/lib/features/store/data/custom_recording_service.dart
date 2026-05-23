import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CustomSoundRecord {
  final String id;
  final String name;
  final String emoji;
  final List<double> waveformPoints;
  final double duration;
  final DateTime createdAt;
  final String? url;

  CustomSoundRecord({
    required this.id,
    required this.name,
    required this.emoji,
    required this.waveformPoints,
    required this.duration,
    required this.createdAt,
    this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'waveformPoints': waveformPoints,
    'duration': duration,
    'createdAt': createdAt.toIso8601String(),
    'url': url,
  };

  factory CustomSoundRecord.fromJson(Map<String, dynamic> json) {
    return CustomSoundRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🎙️',
      waveformPoints: (json['waveformPoints'] as List).map((v) => (v as num).toDouble()).toList(),
      duration: (json['duration'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      url: json['url'] as String?,
    );
  }
}

final customRecordingServiceProvider = Provider<CustomRecordingService>((ref) => CustomRecordingService());

class CustomRecordingService {
  Future<List<CustomSoundRecord>> getCustomRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('custom_sound_recordings');
      if (data == null) return [];
      final list = jsonDecode(data) as List;
      return list.map((item) => CustomSoundRecord.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecording(CustomSoundRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getCustomRecordings();
      current.add(record);
      final list = current.map((r) => r.toJson()).toList();
      await prefs.setString('custom_sound_recordings', jsonEncode(list));
    } catch (_) {}
  }
}
