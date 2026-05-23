import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class VoiceFilter {
  final String activePresetName;
  final double pitchSemitones;
  final double reverbRoom;
  final double bitcrushFrequency;
  final bool isEnabled;

  const VoiceFilter({
    this.activePresetName = 'NONE',
    this.pitchSemitones = 0.0,
    this.reverbRoom = 0.0,
    this.bitcrushFrequency = 16.0,
    this.isEnabled = false,
  });

  VoiceFilter copyWith({
    String? activePresetName,
    double? pitchSemitones,
    double? reverbRoom,
    double? bitcrushFrequency,
    bool? isEnabled,
  }) {
    return VoiceFilter(
      activePresetName: activePresetName ?? this.activePresetName,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      reverbRoom: reverbRoom ?? this.reverbRoom,
      bitcrushFrequency: bitcrushFrequency ?? this.bitcrushFrequency,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

final voiceFilterProvider = NotifierProvider<VoiceFilterNotifier, VoiceFilter>(VoiceFilterNotifier.new);

class VoiceFilterNotifier extends Notifier<VoiceFilter> {
  @override
  VoiceFilter build() {
    final equippedSkinAsync = ref.watch(equippedVoiceSkinProvider);
    return equippedSkinAsync.maybeWhen(
      data: (skin) {
        if (skin != null) {
          return skin.filter;
        }
        return const VoiceFilter();
      },
      orElse: () => const VoiceFilter(),
    );
  }

  void selectPreset(String name) {
    switch (name.toUpperCase()) {
      case 'NONE':
        state = const VoiceFilter(activePresetName: 'NONE', isEnabled: false);
        break;
      case 'ROBOT':
        state = const VoiceFilter(
          activePresetName: 'ROBOT',
          pitchSemitones: -2.0,
          reverbRoom: 35.0,
          bitcrushFrequency: 8.0,
          isEnabled: true,
        );
        break;
      case 'AUTOTUNE':
        state = const VoiceFilter(
          activePresetName: 'AUTOTUNE',
          pitchSemitones: 0.0,
          reverbRoom: 15.0,
          bitcrushFrequency: 16.0,
          isEnabled: true,
        );
        break;
      case 'CHIPMUNK':
        state = const VoiceFilter(
          activePresetName: 'CHIPMUNK',
          pitchSemitones: 6.0,
          reverbRoom: 10.0,
          bitcrushFrequency: 16.0,
          isEnabled: true,
        );
        break;
      case 'ECHO':
        state = const VoiceFilter(
          activePresetName: 'ECHO',
          pitchSemitones: 0.0,
          reverbRoom: 85.0,
          bitcrushFrequency: 16.0,
          isEnabled: true,
        );
        break;
      case 'SYNTH VOX':
        state = const VoiceFilter(
          activePresetName: 'SYNTH VOX',
          pitchSemitones: -4.0,
          reverbRoom: 55.0,
          bitcrushFrequency: 6.0,
          isEnabled: true,
        );
        break;
      default:
        break;
    }
  }

  void updatePitch(double val) {
    state = state.copyWith(
      activePresetName: 'CUSTOM',
      pitchSemitones: val,
      isEnabled: true,
    );
  }

  void updateReverb(double val) {
    state = state.copyWith(
      activePresetName: 'CUSTOM',
      reverbRoom: val,
      isEnabled: true,
    );
  }

  void updateBitcrush(double val) {
    state = state.copyWith(
      activePresetName: 'CUSTOM',
      bitcrushFrequency: val,
      isEnabled: true,
    );
  }

  void toggle(bool enabled) {
    state = state.copyWith(
      isEnabled: enabled,
      activePresetName: enabled ? (state.activePresetName == 'NONE' ? 'CUSTOM' : state.activePresetName) : 'NONE',
    );
  }
}

class VoiceSkinDefinition {
  final String id;
  final String name;
  final String slug;
  final String visualizerStyle; // 'arcade_grid', 'oscilloscope', 'ember_wave', 'matrix_binary', 'standard'
  final VoiceFilter filter;

  const VoiceSkinDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.visualizerStyle,
    required this.filter,
  });
}

class BuiltInVoiceSkins {
  static const arcade8Bit = VoiceSkinDefinition(
    id: '8bit-arcade-skin',
    name: '8-Bit Arcade Skin',
    slug: '8bit-arcade-skin',
    visualizerStyle: 'arcade_grid',
    filter: VoiceFilter(
      activePresetName: '8BIT ARCADE',
      pitchSemitones: 3.0,
      reverbRoom: 15.0,
      bitcrushFrequency: 3.0,
      isEnabled: true,
    ),
  );

  static const retroRadio = VoiceSkinDefinition(
    id: 'retro-radio-skin',
    name: 'Retro Radio Skin',
    slug: 'retro-radio-skin',
    visualizerStyle: 'oscilloscope',
    filter: VoiceFilter(
      activePresetName: 'RETRO RADIO',
      pitchSemitones: -0.5,
      reverbRoom: 5.0,
      bitcrushFrequency: 12.0,
      isEnabled: true,
    ),
  );

  static const lofiTape = VoiceSkinDefinition(
    id: 'lofi-tape-skin',
    name: 'Lofi Tape Skin',
    slug: 'lofi-tape-skin',
    visualizerStyle: 'ember_wave',
    filter: VoiceFilter(
      activePresetName: 'LOFI TAPE',
      pitchSemitones: 0.0,
      reverbRoom: 45.0,
      bitcrushFrequency: 16.0,
      isEnabled: true,
    ),
  );

  static const cyberVocoder = VoiceSkinDefinition(
    id: 'cyber-vocoder-skin',
    name: 'Cyber Vocoder Skin',
    slug: 'cyber-vocoder-skin',
    visualizerStyle: 'matrix_binary',
    filter: VoiceFilter(
      activePresetName: 'CYBER VOCODER',
      pitchSemitones: -5.0,
      reverbRoom: 65.0,
      bitcrushFrequency: 2.0,
      isEnabled: true,
    ),
  );

  static const all = [arcade8Bit, retroRadio, lofiTape, cyberVocoder];

  static VoiceSkinDefinition? getById(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final equippedVoiceSkinProvider = FutureProvider<VoiceSkinDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      final item = equipped['VOICE_SKIN'] ?? equipped['voice_skin'] ?? equipped['VoiceSkin'];
      if (item != null) {
        return BuiltInVoiceSkins.getById(item.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
