import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';

enum AuraVoiceState { idle, listening, thinking, speaking }

class AuraVoiceScreen extends ConsumerStatefulWidget {
  const AuraVoiceScreen({super.key});

  @override
  ConsumerState<AuraVoiceScreen> createState() => _AuraVoiceScreenState();
}

class _AuraVoiceScreenState extends ConsumerState<AuraVoiceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  AuraVoiceState _currentState = AuraVoiceState.idle;
  String _subtitleText = "Tap the microphone to talk with Aura";
  String _activeSpeechWord = "";
  
  // Custom prompts to let user toggle different responses
  final List<String> _quickPrompts = [
    "Tell me about this year's top 5 trends | for Instagram marketers",
    "What are the basic principles of healthy eating?",
    "Show me some code for a glassmorphic card",
  ];
  int _selectedPromptIndex = 0;

  // Audio recording, STT and TTS objects
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _speechInitialized = false;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.0;

  static const Color _bgBlack = Color(0xFF000000);
  static const Color _accentPink = Color(0xFFFF007F);
  static const Color _accentPurple = Color(0xFF8B00FF);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _initVoiceServices();
  }

  Future<void> _initVoiceServices() async {
    try {
      _speechInitialized = await _speechToText.initialize();
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    _animationController.dispose();
    super.dispose();
  }

  void _triggerVoiceFlow() async {
    if (_currentState != AuraVoiceState.idle) return;

    HapticFeedback.mediumImpact();

    // Request permissions
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        _subtitleText = "Microphone permission is required to talk to Aura.";
      });
      return;
    }

    // 1. Listening State
    setState(() {
      _currentState = AuraVoiceState.listening;
      _subtitleText = "Listening...";
      _currentAmplitude = 0.0;
    });

    // Start AudioRecorder for real-time amplitude capture
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/aura_voice_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: tempPath,
      );

      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (_currentState == AuraVoiceState.listening) {
          final amp = await _audioRecorder.getAmplitude();
          setState(() {
            // Map decibel range -60.0 to 0.0 to normalized 0.0 to 1.0
            _currentAmplitude = ((amp.current + 50.0) / 50.0).clamp(0.0, 1.0);
          });
        }
      });
    } catch (_) {}

    // Start real Speech-to-Text if available
    String spokenText = "";
    if (_speechInitialized) {
      try {
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              spokenText = result.recognizedWords;
              if (spokenText.isNotEmpty) {
                _subtitleText = spokenText;
              }
            });
          },
          listenOptions: SpeechListenOptions(
            listenFor: const Duration(seconds: 4),
            pauseFor: const Duration(seconds: 2),
          ),
        );
      } catch (_) {}
    }

    // Wait for the user to finish speaking (4 seconds max)
    await Future.delayed(const Duration(seconds: 4));

    // Stop listening/amplitude recording
    await _stopAmplitudeRecording();

    if (!mounted) return;

    // Fallback if user didn't say anything, use selected prompt
    if (spokenText.trim().isEmpty) {
      spokenText = _quickPrompts[_selectedPromptIndex].split('|').first.trim();
      setState(() {
        _subtitleText = spokenText;
      });
      await Future.delayed(const Duration(milliseconds: 800));
    }

    // 2. Thinking State
    setState(() {
      _currentState = AuraVoiceState.thinking;
      _subtitleText = "Aura is analyzing your request...";
      _currentAmplitude = 0.0;
    });

    // Get response (either Live Gemini or local simulated)
    String responseText = "";
    final notifier = ref.read(auraSessionsProvider.notifier);
    final apiKey = await notifier.getApiKey();
    bool liveSuccess = false;

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final dio = Dio();
        final response = await dio.post(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
          data: {
            'contents': [
              {
                'parts': [
                  {
                    'text': "You are Aura, a voice companion. Keep your response extremely brief, conversational, and direct (max 2 sentences).\n\nUser: $spokenText"
                  }
                ]
              }
            ]
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final candidates = response.data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            responseText = candidates[0]['content']['parts'][0]['text'] ?? '';
            liveSuccess = true;
          }
        }
      } catch (_) {}
    }

    if (!liveSuccess) {
      // Clean up response formatting (e.g. remove markdown bullet points for voice reader)
      responseText = notifier.generateTextResponse(spokenText);
      responseText = responseText.replaceAll('*', '').replaceAll('•', '').trim();
    }

    if (!mounted) return;

    // 3. Speaking State
    setState(() {
      _currentState = AuraVoiceState.speaking;
      _subtitleText = responseText;
    });

    // Run TTS voice
    try {
      await _flutterTts.speak(responseText);
      
      // Animate subtitles word by word matching TTS
      final words = responseText.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (!mounted || _currentState != AuraVoiceState.speaking) break;
        setState(() {
          _activeSpeechWord = words[i];
          _subtitleText = words.sublist(0, i + 1).join(' ');
          // Modulate speaking amplitude for painter wiggles
          _currentAmplitude = 0.2 + 0.4 * math.sin(i * 0.8).abs();
        });
        await Future.delayed(const Duration(milliseconds: 280));
      }
    } catch (_) {
      // Fallback if speaking fails
    }

    if (!mounted) return;

    // 4. Return to Idle
    setState(() {
      _currentState = AuraVoiceState.idle;
      _subtitleText = "Aura has finished speaking. Tap mic to talk again.";
      _activeSpeechWord = "";
      _currentAmplitude = 0.0;
    });
  }

  Future<void> _stopAmplitudeRecording() async {
    _amplitudeTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
  }

  void _resetFlow() {
    HapticFeedback.lightImpact();
    _stopAmplitudeRecording();
    _flutterTts.stop();
    setState(() {
      _currentState = AuraVoiceState.idle;
      _subtitleText = "Tap the microphone to talk with Aura";
      _activeSpeechWord = "";
      _currentAmplitude = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // Radial aura backgrounds matching states
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              double auraOpacity = 0.12;
              if (_currentState == AuraVoiceState.listening) {
                auraOpacity = 0.18 + 0.05 * math.sin(_animationController.value * math.pi * 10);
              } else if (_currentState == AuraVoiceState.thinking) {
                auraOpacity = 0.25;
              } else if (_currentState == AuraVoiceState.speaking) {
                auraOpacity = 0.20 + 0.08 * math.cos(_animationController.value * math.pi * 15);
              }

              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        (_currentState == AuraVoiceState.thinking 
                            ? _accentPurple 
                            : _accentPink).withValues(alpha: auraOpacity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(context),
                _buildPromptSelector(),
                Expanded(
                  child: Center(
                    child: _build3DSphereContainer(),
                  ),
                ),
                _buildSubtitleOverlay(),
                const SizedBox(height: 40),
                _buildVoiceControlBar(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _textWhite),
            onPressed: () => context.pop(),
          ),
          Column(
            children: [
              Text(
                'AURA VOICE COMPANION',
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _currentState.name.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: _currentState == AuraVoiceState.listening
                      ? _accentPink
                      : _currentState == AuraVoiceState.thinking
                          ? _accentPurple
                          : _currentState == AuraVoiceState.speaking
                              ? const Color(0xFF00FFCC)
                              : _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // Spacer balance
        ],
      ),
    );
  }

  Widget _buildPromptSelector() {
    if (_currentState != AuraVoiceState.idle) return const SizedBox(height: 48);

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _quickPrompts.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedPromptIndex == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPromptIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accentPink.withValues(alpha: 0.12) : const Color(0xFF111115),
                border: Border.all(
                  color: isSelected ? _accentPink : const Color(0xFF222228),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  index == 0 
                      ? "Instagram Trends" 
                      : index == 1 
                          ? "Healthy Diet" 
                          : "Glassmorphic Widget",
                  style: GoogleFonts.spaceGrotesk(
                    color: isSelected ? Colors.white : _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _build3DSphereContainer() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FittedBox(
          fit: BoxFit.contain,
          child: CustomPaint(
            size: const Size(260, 260),
            painter: AuraMeshPainter(
              animationValue: _animationController.value,
              state: _currentState,
              amplitude: _currentAmplitude,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitleOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _subtitleText,
                  key: ValueKey(_subtitleText),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: _textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          if (_activeSpeechWord.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Aura is saying: "$_activeSpeechWord"',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF00FFCC),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(duration: 100.ms),
          ]
        ],
      ),
    );
  }

  Widget _buildVoiceControlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reset action
          _buildCircleButton(
            Icons.refresh_rounded,
            _resetFlow,
            size: 48,
            backgroundColor: const Color(0xFF111115),
            iconColor: _textWhite,
          ),
          // Main mic trigger
          GestureDetector(
            onTap: _triggerVoiceFlow,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_accentPink, _accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentPink.withValues(alpha: 0.4),
                    blurRadius: _currentState == AuraVoiceState.listening ? 24 : 12,
                    spreadRadius: _currentState == AuraVoiceState.listening ? 4 : 1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _currentState == AuraVoiceState.listening
                      ? Icons.graphic_eq_rounded
                      : _currentState == AuraVoiceState.speaking
                          ? Icons.volume_up_rounded
                          : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            )
                .animate(target: _currentState == AuraVoiceState.listening ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 400.ms, curve: Curves.bounceOut),
          ),
          // Close screen
          _buildCircleButton(
            Icons.close_rounded,
            () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            size: 48,
            backgroundColor: const Color(0xFF111115),
            iconColor: _textWhite,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
    IconData icon,
    VoidCallback onTap, {
    required double size,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF222228)),
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: size * 0.45),
        ),
      ),
    );
  }
}

class AuraMeshPainter extends CustomPainter {
  final double animationValue;
  final AuraVoiceState state;
  final double amplitude;

  AuraMeshPainter({
    required this.animationValue,
    required this.state,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final double radius = size.width / 2.6;

    // Projection constants
    const double cameraDistance = 300.0;

    // Determine physics speed and wiggles based on state
    double speedMultiplier = 1.0;
    double deformationAmplitude = 0.05;
    double latLongGridScale = 1.0;

    switch (state) {
      case AuraVoiceState.idle:
        speedMultiplier = 0.5;
        deformationAmplitude = 0.02;
        break;
      case AuraVoiceState.listening:
        speedMultiplier = 1.2;
        deformationAmplitude = 0.10 + 0.05 * math.sin(animationValue * math.pi * 20);
        break;
      case AuraVoiceState.thinking:
        speedMultiplier = 2.5;
        deformationAmplitude = 0.15;
        latLongGridScale = 0.5; // Compresses mesh coordinates dynamically
        break;
      case AuraVoiceState.speaking:
        speedMultiplier = 1.5;
        deformationAmplitude = 0.08 + 0.06 * math.cos(animationValue * math.pi * 12);
        break;
    }

    // Rotational angles modulated by time and state speed
    final double angleX = animationValue * math.pi * 2 * speedMultiplier;
    final double angleY = animationValue * math.pi * 1 * speedMultiplier;

    // Define color mappings for state lines
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Color startColor = state == AuraVoiceState.thinking 
        ? const Color(0xFF8B00FF) 
        : const Color(0xFFFF007F);
    final Color endColor = state == AuraVoiceState.thinking 
        ? const Color(0xFF00FFCC) 
        : const Color(0xFF8B00FF);

    // Number of coordinate rings (latitude & longitude wireframes)
    final int latitudes = (12 * latLongGridScale).round().clamp(6, 16);
    final int longitudes = (24 * latLongGridScale).round().clamp(12, 32);

    List<List<Offset>> projectedGrid = List.generate(latitudes, (_) => []);

    for (int lat = 0; lat < latitudes; lat++) {
      // theta goes from -PI/2 to PI/2
      final double latAngle = (lat / (latitudes - 1)) * math.pi - (math.pi / 2);
      
      for (int lon = 0; lon < longitudes; lon++) {
        // phi goes from -PI to PI
        final double lonAngle = (lon / longitudes) * 2 * math.pi - math.pi;

        // Form base sphere coordinates
        double baseRadius = radius;

        // Apply organic trigonometric noise waves to deform sphere
        final double timeOffset = animationValue * math.pi * 2;
        
        // Modulate noise based on state and real-time amplitude
        double currentAmp = state == AuraVoiceState.listening || state == AuraVoiceState.speaking 
            ? amplitude 
            : deformationAmplitude;

        final double noise = math.sin(4 * lonAngle + timeOffset * speedMultiplier) * 
                            math.cos(3 * latAngle + timeOffset * speedMultiplier);
        
        baseRadius += baseRadius * noise * currentAmp;

        final double x = baseRadius * math.cos(latAngle) * math.cos(lonAngle);
        final double y = baseRadius * math.cos(latAngle) * math.sin(lonAngle);
        final double z = baseRadius * math.sin(latAngle);

        // Apply 3D coordinate rotation on X-axis
        final double cosX = math.cos(angleX);
        final double sinX = math.sin(angleX);
        final double rotatedY1 = y * cosX - z * sinX;
        final double rotatedZ1 = y * sinX + z * cosX;

        // Apply 3D coordinate rotation on Y-axis
        final double cosY = math.cos(angleY);
        final double sinY = math.sin(angleY);
        final double rotatedX2 = x * cosY - rotatedZ1 * sinY;
        final double rotatedZ2 = x * sinY + rotatedZ1 * cosY;

        // Perspective projection calculation
        final double perspective = cameraDistance / (cameraDistance + rotatedZ2);
        final double projX = rotatedX2 * perspective + centerX;
        final double projY = rotatedY1 * perspective + centerY;

        projectedGrid[lat].add(Offset(projX, projY));
      }
    }

    // Draw longitude lines (connecting latitude points sequentially)
    for (int lat = 0; lat < latitudes; lat++) {
      for (int lon = 0; lon < longitudes; lon++) {
        final currentPoint = projectedGrid[lat][lon];
        final nextLonPoint = projectedGrid[lat][(lon + 1) % longitudes];

        // Draw horizontal mesh connections
        final double fraction = lat / latitudes;
        paint.color = Color.lerp(startColor, endColor, fraction)!.withValues(alpha: 0.5);
        canvas.drawLine(currentPoint, nextLonPoint, paint);

        // Draw vertical mesh connections
        if (lat < latitudes - 1) {
          final nextLatPoint = projectedGrid[lat + 1][lon];
          canvas.drawLine(currentPoint, nextLatPoint, paint);
        }
      }
    }

    // Draw soft outer boundary ring
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [startColor, endColor, startColor],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

    canvas.drawCircle(Offset(centerX, centerY), radius * 1.1, borderPaint);
  }

  @override
  bool shouldRepaint(covariant AuraMeshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.state != state || oldDelegate.amplitude != amplitude;
  }
}
