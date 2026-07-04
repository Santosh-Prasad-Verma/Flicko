import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/data/voice_filter_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class VoiceSynthBoardSheet extends ConsumerStatefulWidget {
  const VoiceSynthBoardSheet({super.key});

  @override
  ConsumerState<VoiceSynthBoardSheet> createState() => _VoiceSynthBoardSheetState();
}

class _VoiceSynthBoardSheetState extends ConsumerState<VoiceSynthBoardSheet> with SingleTickerProviderStateMixin {
  late AnimationController _waveAnimationController;

  static const Color _bg = Color(0xFF000000);
  static const Color _neon = Color(0xFF52B788);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _gold = Color(0xFFFFD700);

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

    return Container(
      color: _bg,
      padding: const EdgeInsets.only(bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent brutalist border
            Container(
              height: 4,
              width: double.infinity,
              color: _neon,
            ),
            
            // Handle & Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOCAL_FX_SYNTHESIZER',
                        style: GoogleFonts.spaceGrotesk(
                          color: _white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'REAL-TIME VOICE STREAM MODULATION',
                        style: GoogleFonts.spaceMono(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Visualizer Spectrum Box
            Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: _neon, width: 1.5),
                color: Colors.black,
              ),
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
            const SizedBox(height: 24),

            // Preset choices
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'VOCAL_PRESETS',
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
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
                'SYNTHESIZER_PARAMETERS',
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
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
          color: isSelected ? _lime : Colors.black,
          border: Border.all(color: _lime, width: 2),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.black : _lime,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.spaceMono(
                color: isSelected ? Colors.black : Colors.white,
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
                style: GoogleFonts.spaceMono(color: _muted, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                displayVal.toUpperCase(),
                style: GoogleFonts.spaceMono(color: _neon, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: _lime,
            inactiveColor: _muted.withOpacity(0.2),
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
