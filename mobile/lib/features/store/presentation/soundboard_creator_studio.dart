import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/custom_recording_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class SoundboardCreatorStudio extends ConsumerStatefulWidget {
  const SoundboardCreatorStudio({super.key});

  @override
  ConsumerState<SoundboardCreatorStudio> createState() => _SoundboardCreatorStudioState();
}

class _SoundboardCreatorStudioState extends ConsumerState<SoundboardCreatorStudio> with TickerProviderStateMixin {
  late AnimationController _recordingFlashController;
  late AnimationController _waveformTickController;

  bool _isRecording = false;
  bool _hasRecorded = false;
  double _recordingDuration = 0.0;
  final List<double> _liveWaveform = [];
  double _startTrim = 0.1;
  double _endTrim = 0.9;
  
  final TextEditingController _nameController = TextEditingController();
  String _selectedEmoji = '🎙️';

  final List<String> _emojis = ['🎙️', '🔥', '💥', '👻', '👑', '🤡', '🌈', '🚨', '🎮', '🔊'];

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF000000);
  static const Color _neon = Color(0xFF52B788);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);

  @override
  void initState() {
    super.initState();
    _recordingFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _waveformTickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
        if (_isRecording) {
          setState(() {
            _recordingDuration += 0.1;
            // Generate a cool visual wave peak
            _liveWaveform.add(0.2 + math.Random().nextDouble() * 0.8);
            if (_recordingDuration >= 10.0) {
              _stopRecording();
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _recordingFlashController.dispose();
    _waveformTickController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startRecording() {
    FlickoHaptics.light();
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _recordingDuration = 0.0;
      _liveWaveform.clear();
    });
    _recordingFlashController.repeat(reverse: true);
    _waveformTickController.repeat();
  }

  void _stopRecording() {
    FlickoHaptics.medium();
    _recordingFlashController.stop();
    _waveformTickController.stop();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });
  }

  void _saveSoundboard() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sound name'), backgroundColor: Colors.red),
      );
      return;
    }

    final trimmedWave = _liveWaveform.sublist(
      (_liveWaveform.length * _startTrim).floor(),
      (_liveWaveform.length * _endTrim).floor(),
    );

    final record = CustomSoundRecord(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      emoji: _selectedEmoji,
      waveformPoints: trimmedWave,
      duration: _recordingDuration * (_endTrim - _startTrim),
      createdAt: DateTime.now(),
    );

    await ref.read(customRecordingServiceProvider).saveRecording(record);
    FlickoHaptics.heavy();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sound "${record.name}" created!'), backgroundColor: _lime),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOUND_STUDIO',
          style: GoogleFonts.inter(
            color: _white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Studio Deck Header
            Text(
              'CUSTOM SOUNDBOARD RECORDER',
              style: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Live waveform visualizer box
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: _neon, width: 2),
                color: Colors.black,
              ),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: WaveformPainter(
                      wavePoints: _liveWaveform,
                      startTrim: _startTrim,
                      endTrim: _endTrim,
                      isTrimming: _hasRecorded,
                      neonColor: _neon,
                    ),
                  ),
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _recordingFlashController,
                            builder: (context, _) => Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(_recordingFlashController.value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'REC  ${_recordingDuration.toStringAsFixed(1)}s / 10.0s',
                            style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Record Trigger Button
            if (!_hasRecorded)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.black : Colors.red,
                          border: Border.all(color: _isRecording ? Colors.red : Colors.black, width: 4),
                          boxShadow: _isRecording
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _isRecording ? Colors.red : Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording ? 'TAP TO STOP RECORDING' : 'TAP TO RECORD AUDIO',
                      style: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Trim controls, form fields and save buttons
            if (_hasRecorded) ...[
              Text(
                'TRIM AUDIO GROOVE',
                style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Start: ${(_startTrim * 100).toInt()}%', style: GoogleFonts.inter(color: _muted, fontSize: 10)),
                  Expanded(
                    child: RangeSlider(
                      values: RangeValues(_startTrim, _endTrim),
                      onChanged: (values) {
                        setState(() {
                          _startTrim = values.start;
                          _endTrim = values.end;
                        });
                      },
                      activeColor: _lime,
                      inactiveColor: _muted.withOpacity(0.3),
                    ),
                  ),
                  Text('End: ${(_endTrim * 100).toInt()}%', style: GoogleFonts.inter(color: _muted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 24),

              // Form fields
              Text(
                'SOUND DETAILS',
                style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                maxLength: 20,
                style: GoogleFonts.inter(color: _white),
                decoration: InputDecoration(
                  labelText: 'SOUND NAME',
                  labelStyle: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: _muted, width: 1.5)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neon, width: 2.0)),
                  counterStyle: GoogleFonts.inter(color: _muted),
                ),
              ),
              const SizedBox(height: 16),

              // Emoji grid
              Text(
                'SELECT SOUNDBOARD EMOJI',
                style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _emojis.map((emoji) {
                  final isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _lime : Colors.black,
                        border: Border.all(color: _lime, width: 2),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _saveSoundboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _lime,
                          boxShadow: [
                            BoxShadow(color: Colors.white.withValues(alpha: 0.25),
                              blurRadius: 14, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'CREATE SOUNDBOARD',
                            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasRecorded = false;
                          _liveWaveform.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: _white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'RESET',
                            style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> wavePoints;
  final double startTrim;
  final double endTrim;
  final bool isTrimming;
  final Color neonColor;

  WaveformPainter({
    required this.wavePoints,
    required this.startTrim,
    required this.endTrim,
    required this.isTrimming,
    required this.neonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (wavePoints.isEmpty) return;

    final double widthBetweenPoints = size.width / wavePoints.length;
    final double midY = size.height / 2;

    for (int i = 0; i < wavePoints.length; i++) {
      final double x = i * widthBetweenPoints;
      final double progress = i / wavePoints.length;
      final bool inTrim = progress >= startTrim && progress <= endTrim;

      final paint = Paint()
        ..color = (isTrimming && !inTrim) ? Colors.grey.withOpacity(0.3) : neonColor
        ..strokeWidth = math.max(1.5, widthBetweenPoints - 1)
        ..strokeCap = StrokeCap.round;

      final double height = wavePoints[i] * size.height * 0.4;
      canvas.drawLine(
        Offset(x, midY - height),
        Offset(x, midY + height),
        paint,
      );
    }

    if (isTrimming) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Draw trim handle lines
      canvas.drawLine(Offset(size.width * startTrim, 0), Offset(size.width * startTrim, size.height), borderPaint);
      canvas.drawLine(Offset(size.width * endTrim, 0), Offset(size.width * endTrim, size.height), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
