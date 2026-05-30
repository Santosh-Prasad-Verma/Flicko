import 'package:audioplayers/audioplayers.dart';

/// Lightweight per-effect player pool. Mirrors RN SoundUtils:
/// - one looping background-music slot (`bgm`)
/// - short SFX fire-and-forget
///
/// All [AudioPlayer] instances are created lazily so unit tests that subclass
/// this service can avoid the platform binding entirely.
class LudoSoundService {
  LudoSoundService._();
  LudoSoundService.testInstance();

  static final LudoSoundService instance = LudoSoundService._();

  AudioPlayer? _bgmPlayer;
  final List<AudioPlayer> _sfxPool = [];
  bool _muted = false;

  AudioPlayer get _bgm =>
      _bgmPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  bool get muted => _muted;

  void setMuted(bool value) {
    _muted = value;
    if (value) _bgmPlayer?.stop();
  }

  static const _assetMap = <String, String>{
    'home': 'ludo/sfx/home.mp3',
    'game_start': 'ludo/sfx/game_start.mp3',
    'dice_roll': 'ludo/sfx/dice_roll.mp3',
    'pile_move': 'ludo/sfx/pile_move.mp3',
    'safe_spot': 'ludo/sfx/safe_spot.mp3',
    'collide': 'ludo/sfx/collide.mp3',
    'home_win': 'ludo/sfx/home_win.mp3',
    'cheer': 'ludo/sfx/cheer.mp3',
    'ui': 'ludo/sfx/ui.mp3',
  };

  Future<void> play(String name) async {
    if (_muted) return;
    final asset = _assetMap[name];
    if (asset == null) return;

    if (name == 'home') {
      await _bgm.stop();
      await _bgm.play(AssetSource(asset), volume: 0.4);
      return;
    }

    final player = _acquireSfx();
    try {
      await player.play(AssetSource(asset));
    } catch (_) {
      // Best-effort: never throw from sfx.
    }
  }

  Future<void> stopBgm() async {
    await _bgmPlayer?.stop();
  }

  AudioPlayer _acquireSfx() {
    for (final p in _sfxPool) {
      if (p.state != PlayerState.playing) return p;
    }
    if (_sfxPool.length < 6) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _sfxPool.add(p);
      return p;
    }
    return _sfxPool.first;
  }

  Future<void> dispose() async {
    await _bgmPlayer?.dispose();
    _bgmPlayer = null;
    for (final p in _sfxPool) {
      await p.dispose();
    }
    _sfxPool.clear();
  }
}
