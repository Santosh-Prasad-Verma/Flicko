import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Glassmorphic Voice Message Recorder Sheet Widget
class VoiceMessageRecorder extends StatefulWidget {
  final Function(String filePath, Duration duration) onSend;
  final VoidCallback onCancel;

  const VoiceMessageRecorder({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  final List<double> _amplitudes = [];
  String? _currentPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = path;

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
        });

        _timer = Timer.periodic(const Duration(milliseconds: 100), (t) async {
          final amp = await _audioRecorder.getAmplitude();
          setState(() {
            _duration += const Duration(milliseconds: 100);
            // Convert dB to normalized 0.0 - 1.0 range for visualization
            final normalized = ((amp.current + 60) / 60).clamp(0.1, 1.0);
            _amplitudes.add(normalized);
            if (_amplitudes.length > 40) {
              _amplitudes.removeAt(0);
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Failed to start recording: $e');
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    if (path != null && _duration.inSeconds >= 1) {
      widget.onSend(path, _duration);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    widget.onCancel();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header indicator
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Recording Duration Timer & Pulse Dot
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_duration),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Simulated Live Waveform Visualizer
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _amplitudes.isEmpty
                      ? List.generate(
                          20,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3,
                            height: 12,
                            color: Colors.white24,
                          ),
                        )
                      : _amplitudes.map((amp) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3.5,
                            height: max(6, amp * 44),
                            decoration: BoxDecoration(
                              color: const Color(FlickoColors.green),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: _cancelRecording,
                  ),

                  // Send Button
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.green),
                      padding: const EdgeInsets.all(18),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.black),
                    onPressed: _stopAndSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
