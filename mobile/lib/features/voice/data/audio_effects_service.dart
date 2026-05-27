import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

/// Equalizer band
class EqBand {
  final int index;
  final double frequency;
  final double gain; // -12 to +12 dB

  const EqBand({
    required this.index,
    required this.frequency,
    this.gain = 0.0,
  });

  EqBand copyWith({double? gain}) {
    return EqBand(index: index, frequency: frequency, gain: gain ?? this.gain);
  }
}

/// Equalizer preset
class EqPreset {
  final String id;
  final String name;
  final List<double> gains;

  const EqPreset({
    required this.id,
    required this.name,
    required this.gains,
  });

  static const List<EqPreset> builtIn = [
    EqPreset(id: 'flat', name: 'Flat', gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    EqPreset(id: 'bass_boost', name: 'Bass Boost', gains: [8, 6, 4, 2, 0, 0, 0, 0, 0, 0]),
    EqPreset(id: 'treble_boost', name: 'Treble Boost', gains: [0, 0, 0, 0, 0, 2, 4, 6, 8, 8]),
    EqPreset(id: 'rock', name: 'Rock', gains: [5, 4, 3, 1, -1, -1, 1, 3, 4, 5]),
    EqPreset(id: 'pop', name: 'Pop', gains: [-1, 2, 4, 5, 4, 2, 0, -1, -1, -1]),
    EqPreset(id: 'jazz', name: 'Jazz', gains: [3, 2, 1, 2, -2, -2, 0, 2, 3, 4]),
    EqPreset(id: 'classical', name: 'Classical', gains: [4, 3, 2, 1, -1, -1, 0, 2, 3, 4]),
    EqPreset(id: 'electronic', name: 'Electronic', gains: [5, 4, 2, 0, -2, 2, 1, 2, 4, 5]),
    EqPreset(id: 'hip_hop', name: 'Hip Hop', gains: [5, 4, 1, 3, -1, -1, 1, -1, 2, 3]),
    EqPreset(id: 'vocal', name: 'Vocal', gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
  ];
}

/// Audio effects state
class AudioEffects {
  final bool eqEnabled;
  final String? activePresetId;
  final List<EqBand> bands;
  final double bassBoost; // 0-100
  final double surround; // 0-100
  final double virtualizer; // 0-100
  final double loudnessEnhancer; // 0-100

  const AudioEffects({
    this.eqEnabled = false,
    this.activePresetId,
    this.bands = const [
      EqBand(index: 0, frequency: 31),
      EqBand(index: 1, frequency: 62),
      EqBand(index: 2, frequency: 125),
      EqBand(index: 3, frequency: 250),
      EqBand(index: 4, frequency: 500),
      EqBand(index: 5, frequency: 1000),
      EqBand(index: 6, frequency: 2000),
      EqBand(index: 7, frequency: 4000),
      EqBand(index: 8, frequency: 8000),
      EqBand(index: 9, frequency: 16000),
    ],
    this.bassBoost = 0,
    this.surround = 0,
    this.virtualizer = 0,
    this.loudnessEnhancer = 0,
  });

  EqPreset? get activePreset {
    if (activePresetId == null) return null;
    return EqPreset.builtIn.firstWhere((p) => p.id == activePresetId, orElse: () => EqPreset.builtIn.first);
  }

  AudioEffects copyWith({
    bool? eqEnabled,
    String? activePresetId,
    List<EqBand>? bands,
    double? bassBoost,
    double? surround,
    double? virtualizer,
    double? loudnessEnhancer,
  }) {
    return AudioEffects(
      eqEnabled: eqEnabled ?? this.eqEnabled,
      activePresetId: activePresetId ?? this.activePresetId,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      surround: surround ?? this.surround,
      virtualizer: virtualizer ?? this.virtualizer,
      loudnessEnhancer: loudnessEnhancer ?? this.loudnessEnhancer,
    );
  }
}

// Helper frequency list
const _freqList = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];

/// Service for managing audio effects.
///
/// Note: cross-platform DSP via just_audio is limited. The Android Equalizer
/// effect is wired up by the BlackHole stack (`AudioPlayerHandlerImpl`).
/// On iOS / desktop the band gains are persisted but only volume-coupled
/// adjustments are applied to the live player. UI surfaces a hint when the
/// active backend can't honor a band.
final audioEffectsProvider =
    NotifierProvider<AudioEffectsNotifier, AudioEffects>(AudioEffectsNotifier.new);

class AudioEffectsNotifier extends Notifier<AudioEffects> {
  @override
  AudioEffects build() {
    _loadSettings();
    return const AudioEffects();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final eqEnabled = prefs.getBool('audio_eq_enabled') ?? false;
      final presetId = prefs.getString('audio_eq_preset');
      final bassBoost = prefs.getDouble('audio_bass_boost') ?? 0;
      final surround = prefs.getDouble('audio_surround') ?? 0;
      final virtualizer = prefs.getDouble('audio_virtualizer') ?? 0;
      final loudness = prefs.getDouble('audio_loudness') ?? 0;

      // Load band gains
      final bands = List<EqBand>.generate(10, (i) {
        final gain = prefs.getDouble('audio_band_$i') ?? 0.0;
        return EqBand(
          index: i,
          frequency: _freqList[i],
          gain: gain,
        );
      });

      state = AudioEffects(
        eqEnabled: eqEnabled,
        activePresetId: presetId,
        bands: bands,
        bassBoost: bassBoost,
        surround: surround,
        virtualizer: virtualizer,
        loudnessEnhancer: loudness,
      );
    } catch (e) {
      dev.log('Error loading audio effects: $e', name: 'audio-effects');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('audio_eq_enabled', state.eqEnabled);
      if (state.activePresetId != null) {
        await prefs.setString('audio_eq_preset', state.activePresetId!);
      }
      await prefs.setDouble('audio_bass_boost', state.bassBoost);
      await prefs.setDouble('audio_surround', state.surround);
      await prefs.setDouble('audio_virtualizer', state.virtualizer);
      await prefs.setDouble('audio_loudness', state.loudnessEnhancer);

      for (final band in state.bands) {
        await prefs.setDouble('audio_band_${band.index}', band.gain);
      }
    } catch (e) {
      dev.log('Error saving audio effects: $e', name: 'audio-effects');
    }
  }

  void setEqEnabled(bool enabled) {
    state = state.copyWith(eqEnabled: enabled);
    _saveSettings();
  }

  void setPreset(String presetId) {
    final preset = EqPreset.builtIn.firstWhere(
      (p) => p.id == presetId,
      orElse: () => EqPreset.builtIn.first,
    );

    final bands = List<EqBand>.generate(10, (i) {
      return EqBand(
        index: i,
        frequency: _freqList[i],
        gain: preset.gains[i],
      );
    });

    state = state.copyWith(activePresetId: presetId, bands: bands);
    _saveSettings();
  }

  void setBandGain(int bandIndex, double gain) {
    final newBands = List<EqBand>.from(state.bands);
    newBands[bandIndex] = newBands[bandIndex].copyWith(gain: gain.clamp(-12.0, 12.0));
    state = state.copyWith(bands: newBands, activePresetId: null);
    _saveSettings();
  }

  void setBassBoost(double value) {
    state = state.copyWith(bassBoost: value.clamp(0.0, 100.0));
    _saveSettings();
  }

  void setSurround(double value) {
    state = state.copyWith(surround: value.clamp(0.0, 100.0));
    _saveSettings();
  }

  void setVirtualizer(double value) {
    state = state.copyWith(virtualizer: value.clamp(0.0, 100.0));
    _saveSettings();
  }

  void setLoudnessEnhancer(double value) {
    state = state.copyWith(loudnessEnhancer: value.clamp(0.0, 100.0));
    _saveSettings();
  }

  void resetAll() {
    state = const AudioEffects();
    _saveSettings();
  }
}
