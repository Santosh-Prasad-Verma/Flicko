import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/data/voice_filter_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class VoiceSynthBoardSheet extends ConsumerStatefulWidget {
  const VoiceSynthBoardSheet({super.key});

  @override
  ConsumerState<VoiceSynthBoardSheet> createState() => _VoiceSynthBoardSheetState();
}

class _VoiceSynthBoardSheetState extends ConsumerState<VoiceSynthBoardSheet> with SingleTickerProviderStateMixin {
  late AnimationController _waveAnimationController;

  static const Color _neon = Color(FlickoColors.brandLime);
  static const Color _white = Color(FlickoColors.textPrimary);
  static const Color _lime = Color(FlickoColors.brandLime);
  static const Color _gold = Color(FlickoColors.gold);

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(voiceFilterProvider);
    final notifier = ref.read(voiceFilterProvider.notifier);
    final equippedSkinAsync = ref.watch(equippedVoiceSkinProvider);
    final equippedSkin = equippedSkinAsync.value;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F12).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle indicator
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Handle & Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VOCAL FX SYNTHESIZER',
                            style: GoogleFonts.spaceGrotesk(
                              color: _white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'REAL-TIME VOICE STREAM MODULATION',
                            style: GoogleFonts.spaceMono(
                              color: _white.withValues(alpha: 0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Visualizer Spectrum Box
                Container(
                  height: 110,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _neon.withValues(alpha: 0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withValues(alpha: 0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedBuilder(
                      animation: _waveAnimationController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: SynthesizerWavePainter(
                            animationValue: _waveAnimationController.value,
                            preset: filter.activePresetName,
                            pitch: filter.pitchSemitones,
                            reverb: filter.reverbRoom,
                            bitcrush: filter.bitcrushFrequency,
                            isEnabled: filter.isEnabled,
                            neonColor: _neon,
                            goldColor: _gold,
                            skinId: equippedSkin?.id,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Preset choices
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'VOCAL PRESETS',
                    style: GoogleFonts.spaceGrotesk(
                      color: _white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildPresetCard('NONE', '🎙️', filter.activePresetName == 'NONE', notifier),
                      _buildPresetCard('AUTOTUNE', '✨', filter.activePresetName == 'AUTOTUNE', notifier),
                      _buildPresetCard('ROBOT', '🤖', filter.activePresetName == 'ROBOT', notifier),
                      _buildPresetCard('CHIPMUNK', '🐿️', filter.activePresetName == 'CHIPMUNK', notifier),
                      _buildPresetCard('ECHO', '🌌', filter.activePresetName == 'ECHO', notifier),
                      _buildPresetCard('SYNTH VOX', '🎛️', filter.activePresetName == 'SYNTH VOX', notifier),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic Synthesizer Sliders
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'SYNTHESIZER PARAMETERS',
                    style: GoogleFonts.spaceGrotesk(
                      color: _white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pitch transposer semitones
                _buildSliderRow(
                  title: 'PITCH semitones',
                  value: filter.pitchSemitones,
                  min: -12.0,
                  max: 12.0,
                  displayVal: '${filter.pitchSemitones > 0 ? '+' : ''}${filter.pitchSemitones.toStringAsFixed(1)} semitones',
                  onChanged: (val) {
                    FlickoHaptics.light();
                    notifier.updatePitch(val);
                  },
                ),

                // Reverb room
                _buildSliderRow(
                  title: 'CATHEDRAL REVERB room',
                  value: filter.reverbRoom,
                  min: 0.0,
                  max: 100.0,
                  displayVal: '${filter.reverbRoom.toInt()}% room depth',
                  onChanged: (val) {
                    FlickoHaptics.light();
                    notifier.updateReverb(val);
                  },
                ),

                // Bitcrush pixels
                _buildSliderRow(
                  title: 'CYBER BITCRUSH distortion',
                  value: filter.bitcrushFrequency,
                  min: 4.0,
                  max: 16.0,
                  displayVal: '${filter.bitcrushFrequency.toInt()}-bit pixelate',
                  onChanged: (val) {
                    FlickoHaptics.light();
                    notifier.updateBitcrush(val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(String name, String emoji, bool isSelected, VoiceFilterNotifier notifier) {
    return GestureDetector(
      onTap: () {
        FlickoHaptics.medium();
        notifier.selectPreset(name);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? _lime.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _lime : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _lime.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.spaceMono(
                color: isSelected ? _lime : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayVal,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.spaceMono(color: _white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                displayVal.toUpperCase(),
                style: GoogleFonts.spaceMono(color: _neon, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: _lime,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: _white,
              overlayColor: _lime.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class SynthesizerWavePainter extends CustomPainter {
  final double animationValue;
  final String preset;
  final double pitch;
  final double reverb;
  final double bitcrush;
  final bool isEnabled;
  final Color neonColor;
  final Color goldColor;
  final String? skinId;

  SynthesizerWavePainter({
    required this.animationValue,
    required this.preset,
    required this.pitch,
    required this.reverb,
    required this.bitcrush,
    required this.isEnabled,
    required this.neonColor,
    required this.goldColor,
    this.skinId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isEnabled && skinId == null) {
      // Draw flat idle dry mic line
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      return;
    }

    final midY = size.height / 2;
    final frequency = 1.0 + (pitch / 6.0); // semitone adjusts speed
    final amplitude = 15.0 + reverb * 0.2; // reverb depth increases scale

    // Check if custom voice skin is active
    if (skinId != null) {
      switch (skinId) {
        case '8bit-arcade-skin':
          _drawArcadeGrid(canvas, size, midY, frequency, amplitude);
          break;
        case 'retro-radio-skin':
          _drawOscilloscope(canvas, size, midY, frequency, amplitude);
          break;
        case 'lofi-tape-skin':
          _drawEmberWave(canvas, size, midY, frequency, amplitude);
          break;
        case 'cyber-vocoder-skin':
          _drawMatrixBinary(canvas, size, midY, frequency, amplitude);
          break;
        default:
          _drawDefaultWave(canvas, size, midY, frequency, amplitude);
      }
      return;
    }

    _drawDefaultWave(canvas, size, midY, frequency, amplitude);
  }

  // 1. Arcade Grid Visualizer
  void _drawArcadeGrid(Canvas canvas, Size size, double midY, double frequency, double amplitude) {
    // Draw background green grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF00FF66).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final double step = 10.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical bar chunks
    final barPaint = Paint()
      ..color = const Color(0xFF00FF66)
      ..style = PaintingStyle.fill;
    final double barWidth = 6.0;
    final double barGap = 3.0;

    for (double x = 2; x < size.width; x += (barWidth + barGap)) {
      final double phase = (x / size.width) * 4 * math.pi * frequency + (animationValue * 2 * math.pi);
      final double ampHeight = (math.sin(phase).abs() * amplitude * 1.5).clamp(2.0, size.height / 2);
      
      // Draw rectangular bars rising up/down from center
      canvas.drawRect(
        Rect.fromLTRB(x, midY - ampHeight, x + barWidth, midY + ampHeight),
        barPaint,
      );
    }
  }

  // 2. AM Scope Oscilloscope
  void _drawOscilloscope(Canvas canvas, Size size, double midY, double frequency, double amplitude) {
    final wavePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw circular scopes or sweeping waveform
    final path = Path();
    path.moveTo(0, midY);
    for (double x = 0; x < size.width; x++) {
      // Periodic wobbly high frequency sweeps
      final double wobPhase = (x / size.width) * 40 * math.pi + (animationValue * 15 * math.pi);
      final double wobble = math.sin(wobPhase) * 2.0;

      final double phase = (x / size.width) * 6 * math.pi * frequency + (animationValue * 2 * math.pi);
      final double y = midY + math.sin(phase) * (amplitude + wobble);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);

    // Draw secondary background sweep glow
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawPath(path, glowPaint);
  }

  // 3. Lofi Tape Ember Wave
  void _drawEmberWave(Canvas canvas, Size size, double midY, double frequency, double amplitude) {
    final wavePaint = Paint()
      ..color = const Color(0xFFFAA61A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, midY);
    for (double x = 0; x < size.width; x++) {
      final double phase = (x / size.width) * 4 * math.pi * frequency + (animationValue * 2 * math.pi);
      final double y = midY + math.sin(phase) * amplitude;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);

    // Draw tiny orange embers floating above wave peaks
    final emberPaint = Paint()..color = const Color(0xFFED4245);
    final double step = 20.0;
    for (double x = 10; x < size.width; x += step) {
      final double phase = (x / size.width) * 4 * math.pi * frequency + (animationValue * 2 * math.pi);
      final double yPeak = midY + math.sin(phase) * amplitude;
      
      // Floating ember particles
      final double particleY = yPeak - 12 - ((animationValue * 10) % 25);
      final double particleSize = 1.5 + (x % 2.5);
      canvas.drawCircle(Offset(x + ((animationValue * 5) % 10), particleY), particleSize, emberPaint);
    }
  }

  // 4. Cyber Vocoder Matrix Binary Column Bounces
  void _drawMatrixBinary(Canvas canvas, Size size, double midY, double frequency, double amplitude) {
    final textStyle = GoogleFonts.spaceMono(
      color: const Color(0xFF00FF66),
      fontWeight: FontWeight.bold,
      fontSize: 9,
    );
    final double colWidth = size.width / 14;
    for (int i = 0; i < 14; i++) {
      final double x = (i * colWidth) + (colWidth / 2);
      final double phase = (x / size.width) * 4 * math.pi * frequency + (animationValue * 2 * math.pi);
      final double amp = midY + math.sin(phase) * amplitude * 1.6;
      
      // Calculate string character count
      final int charCount = ((amp - midY).abs() / 10.0).round().clamp(1, 6);
      for (int j = 0; j < charCount; j++) {
        final String char = (j % 2 == 0) ? '1' : '0';
        final double y = midY + (amp > midY ? (j * 11.5) : (-j * 11.5));
        
        final tp = TextPainter(
          text: TextSpan(text: char, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  // Fallback default waves
  void _drawDefaultWave(Canvas canvas, Size size, double midY, double frequency, double amplitude) {
    final path = Path();
    final paint = Paint()
      ..color = preset == 'ROBOT' ? goldColor : neonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = preset == 'ROBOT' ? 3.5 : 2.0;

    if (preset == 'ROBOT') {
      final double stepSize = bitcrush;
      path.moveTo(0, midY);
      for (double x = 0; x < size.width; x += stepSize) {
        final double phase = (x / size.width) * 4 * math.pi * frequency + (animationValue * 2 * math.pi);
        final double rawY = midY + math.sin(phase) * amplitude;
        final double quantizedY = (rawY / stepSize).round() * stepSize;
        path.lineTo(x, quantizedY);
        path.lineTo(x + stepSize, quantizedY);
      }
    } else if (preset == 'ECHO') {
      path.moveTo(0, midY);
      for (double x = 0; x < size.width; x++) {
        final double phase = (x / size.width) * 6 * math.pi * frequency + (animationValue * 2 * math.pi);
        final double y = midY + math.sin(phase) * amplitude;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);

      final echoPath = Path();
      final echoPaint = Paint()
        ..color = neonColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      echoPath.moveTo(0, midY);
      for (double x = 0; x < size.width; x++) {
        final double phase = (x / size.width) * 6 * math.pi * frequency + (animationValue * 2 * math.pi) - 0.8;
        final double y = midY + math.sin(phase) * amplitude * 0.6;
        echoPath.lineTo(x, y);
      }
      canvas.drawPath(echoPath, echoPaint);
      return;
    } else {
      path.moveTo(0, midY);
      for (double x = 0; x < size.width; x++) {
        final double phase = (x / size.width) * 5 * math.pi * frequency + (animationValue * 2 * math.pi);
        final double y = midY + math.sin(phase) * amplitude;
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SynthesizerWavePainter oldDelegate) => true;
}
