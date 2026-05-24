import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';

enum AuraVoiceState { idle, listening, thinking, speaking }

class AuraVoiceScreen extends ConsumerStatefulWidget {
  const AuraVoiceScreen({super.key});

  @override
  ConsumerState<AuraVoiceScreen> createState() => _AuraVoiceScreenState();
}

class _AuraVoiceScreenState extends ConsumerState<AuraVoiceScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  
  AuraVoiceState _currentState = AuraVoiceState.idle;
  String _subtitleText = "Tap the microphone to talk with Aura";
  String _activeSpeechWord = "";
  
  // Suggested prompt chips for immediate testing/interaction
  final List<String> _suggestions = [
    "What is Data Engineering?",
    "Tell me a clever developer joke",
    "Explain what is glassmorphism in design",
    "Give me 3 daily healthy habits",
  ];

  // Voice Settings configuration
  String _selectedVoice = "Aoede"; // Puck, Charon, Kore, Fenrir, Aoede
  String _selectedModel = "gemini-2.5-flash"; // gemini-2.5-flash, gemini-2.0-flash

  // Audio recording, STT, TTS and just_audio player objects
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _speechInitialized = false;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.0;
  bool _isContinuousActive = false;

  static const Color _bgBlack = Color(0xFF020104);
  static const Color _accentLime = Color(0xFFC0EC54);
  static const Color _textMuted = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initVoiceServices();
  }

  Future<void> _initVoiceServices() async {
    try {
      _speechInitialized = await _speechToText.initialize();
      debugPrint('[Aura] Speech initialized: $_speechInitialized');
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('[Aura] Voice init error: $e');
    }
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _animationController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Prepend a standard 44-byte WAV header so just_audio can play PCM raw bytes
  Uint8List _pcmToWav(Uint8List pcmData, int sampleRate) {
    final int channels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final int blockAlign = channels * bitsPerSample ~/ 8;
    final int dataSize = pcmData.length;
    final int chunkSize = 36 + dataSize;

    final header = Uint8List(44);
    final bd = ByteData.sublistView(header);

    // RIFF header
    header.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // "RIFF"
    bd.setUint32(4, chunkSize, Endian.little);
    header.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // fmt subchunk
    header.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]); // "fmt "
    bd.setUint32(16, 16, Endian.little); // Subchunk1Size
    bd.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // "data"
    bd.setUint32(40, dataSize, Endian.little);

    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header);
    wavData.setRange(44, wavData.length, pcmData);
    return wavData;
  }

  void _triggerVoiceFlow({String? preSetText}) async {
    if (_currentState != AuraVoiceState.idle) return;

    HapticFeedback.mediumImpact();
    await _audioPlayer.stop();
    await _flutterTts.stop();

    // 1. Listening state
    setState(() {
      _currentState = AuraVoiceState.listening;
      _subtitleText = "Listening...";
      _currentAmplitude = 0.0;
    });

    String spokenText = preSetText ?? "";

    if (preSetText == null) {
      // Request microphone permissions
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _currentState = AuraVoiceState.idle;
          _subtitleText = "Microphone permission is required.";
        });
        return;
      }

      // Initialize speech recognition if not ready
      if (!_speechInitialized) {
        try {
          _speechInitialized = await _speechToText.initialize();
          debugPrint('[Aura] Re-initialized speech: $_speechInitialized');
        } catch (e) {
          debugPrint('[Aura] Speech re-init error: $e');
        }
      }

      // Start Speech-to-Text translation
      if (_speechInitialized) {
        try {
          await _speechToText.listen(
            onResult: (result) {
              if (!mounted) return;
              setState(() {
                spokenText = result.recognizedWords;
                if (spokenText.isNotEmpty) {
                  _subtitleText = spokenText;
                }
              });
            },
            onSoundLevelChange: (level) {
              if (!mounted) return;
              setState(() {
                // Map decibels range -2.0 to 12.0 to normalized 0.0 to 1.0
                _currentAmplitude = (level / 12.0).clamp(0.0, 1.0);
              });
            },
            listenOptions: SpeechListenOptions(
              listenFor: const Duration(seconds: 8),
              pauseFor: const Duration(seconds: 3),
              partialResults: true,
              cancelOnError: true,
            ),
          );
        } catch (e) {
          debugPrint('[Aura] STT listen error: $e');
        }
      }

      // Wait for listening to actually start (up to 1.5 seconds)
      int initWaitMs = 0;
      while (!_speechToText.isListening && initWaitMs < 1500) {
        await Future.delayed(const Duration(milliseconds: 100));
        initWaitMs += 100;
      }

      // Wait dynamically while user is speaking (up to 8 seconds max)
      int elapsedMs = 0;
      const int pollIntervalMs = 200;
      const int maxWaitMs = 8000;
      while (_speechToText.isListening && elapsedMs < maxWaitMs) {
        await Future.delayed(const Duration(milliseconds: pollIntervalMs));
        elapsedMs += pollIntervalMs;
      }

      // Explicitly stop listening in case of max duration timeout
      try {
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }
      } catch (_) {}
    } else {
      // Visual feedback for pre-selected chip
      setState(() {
        _subtitleText = spokenText;
      });
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;

    // Handle empty speech gracefully without forcing hardcoded fallbacks
    if (spokenText.trim().isEmpty) {
      setState(() {
        _currentState = AuraVoiceState.idle;
        _subtitleText = "I didn't catch that. Tap the mic to try again.";
        _currentAmplitude = 0.0;
      });
      return;
    }

    // 2. Thinking State
    setState(() {
      _currentState = AuraVoiceState.thinking;
      _subtitleText = "Analyzing your request...";
      _currentAmplitude = 0.0;
    });

    String responseText = "";
    bool audioSuccess = false;
    bool textFallbackSuccess = false;

    final notifier = ref.read(auraSessionsProvider.notifier);
    final apiKey = await notifier.getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      // List of models to try in cascading fallback order
      final modelsToTry = [
        _selectedModel, // e.g. gemini-2.5-flash or gemini-2.0-flash
        if (_selectedModel != "gemini-2.0-flash") "gemini-2.0-flash",
        "gemini-1.5-flash",
      ];

      // --- STAGE 1: Attempt Gemini Native Voice response (Audio Modality) ---
      for (final model in modelsToTry) {
        if (audioSuccess) break;
        try {
          final dio = Dio();
          final response = await dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            data: {
              'contents': [
                {
                  'parts': [
                    {
                      'text': "You are Aura, a voice companion. Keep your response extremely brief, conversational, and direct (max 2 sentences).\n\nUser: $spokenText"
                    }
                  ]
                }
              ],
              'generationConfig': {
                'responseModalities': ['AUDIO'],
                'speechConfig': {
                  'voiceConfig': {
                    'prebuiltVoiceConfig': {
                      'voiceName': _selectedVoice
                    }
                  }
                }
              }
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final candidates = response.data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              if (content != null) {
                final parts = content['parts'] as List?;
                String? base64Audio;
                int sampleRate = 24000;

                if (parts != null) {
                  for (var part in parts) {
                    if (part is Map) {
                      if (part.containsKey('text')) {
                        responseText += part['text'] as String;
                      }
                      if (part.containsKey('inlineData')) {
                        final inlineData = part['inlineData'] as Map;
                        base64Audio = inlineData['data'] as String?;
                        final mimeType = inlineData['mimeType'] as String?;
                        if (mimeType != null && mimeType.contains('rate=')) {
                          final rateStr = mimeType.split('rate=').last;
                          sampleRate = int.tryParse(rateStr) ?? 24000;
                        }
                      }
                    }
                  }
                }

                if (base64Audio != null && base64Audio.isNotEmpty) {
                  final pcmBytes = base64Decode(base64Audio);
                  final wavBytes = _pcmToWav(pcmBytes, sampleRate);

                  final tempDir = await getTemporaryDirectory();
                  final wavFile = File('${tempDir.path}/aura_voice_response.wav');
                  await wavFile.writeAsBytes(wavBytes);

                  if (responseText.isEmpty) {
                    responseText = "Sure! Here is the response.";
                  }

                  setState(() {
                    _currentState = AuraVoiceState.speaking;
                    _subtitleText = responseText;
                  });

                  final duration = await _audioPlayer.setFilePath(wavFile.path);
                  final durationMs = duration?.inMilliseconds ?? 3000;

                  _audioPlayer.play();
                  audioSuccess = true;
                  debugPrint('[Aura] Native audio success using model: $model');

                  // Sync subtitle words to audio duration
                  final words = responseText.split(' ');
                  final msPerWord = words.isNotEmpty ? (durationMs / words.length).round() : 250;
                  final sw = Stopwatch()..start();

                  for (int i = 0; i < words.length; i++) {
                    if (!mounted || _currentState != AuraVoiceState.speaking) break;
                    setState(() {
                      _activeSpeechWord = words[i];
                      _subtitleText = words.sublist(0, i + 1).join(' ');
                      // Paint visualization wave pulses
                      _currentAmplitude = 0.2 + 0.5 * math.sin(i * 1.2).abs();
                    });
                    final targetMs = (i + 1) * msPerWord;
                    final delay = targetMs - sw.elapsedMilliseconds;
                    if (delay > 0) {
                      await Future.delayed(Duration(milliseconds: delay));
                    }
                  }

                  // Wait for audio completion if stopwatch finished earlier
                  final remainingPlayTime = durationMs - sw.elapsedMilliseconds;
                  if (remainingPlayTime > 0) {
                    await Future.delayed(Duration(milliseconds: remainingPlayTime));
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[Aura] Audio API error with model $model: $e');
        }
      }

      // --- STAGE 2: Fallback to Text-only Generation + local TTS if Audio fails ---
      if (!audioSuccess) {
        for (final model in modelsToTry) {
          if (textFallbackSuccess) break;
          try {
            final dio = Dio();
            final response = await dio.post(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
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
                textFallbackSuccess = true;
                debugPrint('[Aura] Text API fallback success using model: $model');
              }
            }
          } catch (e) {
            debugPrint('[Aura] Text API fallback error with model $model: $e');
          }
        }
      }
    }

    // --- STAGE 3: Local simulation fallback if all online attempts fail ---
    if (!audioSuccess && !textFallbackSuccess) {
      responseText = notifier.generateTextResponse(spokenText);
      responseText = responseText.replaceAll('*', '').replaceAll('•', '').trim();
      
      // Clearly alert the user if their API key calls are failing
      if (apiKey != null && apiKey.isNotEmpty) {
        responseText = "[API Key rate limit exceeded (429) or invalid. Using simulated Aura fallback]\n\n$responseText";
      }
    }

    // If we didn't play audio natively, use standard Device TTS
    if (!audioSuccess) {
      if (!mounted) return;
      setState(() {
        _currentState = AuraVoiceState.speaking;
        _subtitleText = responseText;
      });

      try {
        await _flutterTts.speak(responseText);

        final words = responseText.split(' ');
        for (int i = 0; i < words.length; i++) {
          if (!mounted || _currentState != AuraVoiceState.speaking) break;
          setState(() {
            _activeSpeechWord = words[i];
            _subtitleText = words.sublist(0, i + 1).join(' ');
            _currentAmplitude = 0.2 + 0.4 * math.sin(i * 0.8).abs();
          });
          await Future.delayed(const Duration(milliseconds: 280));
        }
      } catch (_) {}
    }

    if (!mounted) return;

    // 4. Return to Idle state or listen again
    setState(() {
      _currentState = AuraVoiceState.idle;
      _subtitleText = _isContinuousActive
          ? "Listening again..."
          : "Aura has finished speaking. Tap mic to talk again.";
      _activeSpeechWord = "";
      _currentAmplitude = 0.0;
    });

    if (_isContinuousActive) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _currentState == AuraVoiceState.idle && _isContinuousActive) {
          _triggerVoiceFlow();
        }
      });
    }
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
    _audioPlayer.stop();
    _flutterTts.stop();
    setState(() {
      _isContinuousActive = false;
      _currentState = AuraVoiceState.idle;
      _subtitleText = "Tap the microphone to talk with Aura";
      _activeSpeechWord = "";
      _currentAmplitude = 0.0;
    });
  }

  void _showVoiceSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0C16).withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                    Colors.black.withOpacity(0.2),
                    BlendMode.srcOver,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Aura Configuration',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customize model engines and native audio voices',
                          style: GoogleFonts.spaceGrotesk(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Select Model Engine',
                          style: GoogleFonts.spaceMono(
                            color: _accentLime,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSheetSelector(
                              title: "Gemini 2.5 Flash",
                              isSelected: _selectedModel == "gemini-2.5-flash",
                              onTap: () {
                                setSheetState(() => _selectedModel = "gemini-2.5-flash");
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildSheetSelector(
                              title: "Gemini 2.0 Flash",
                              isSelected: _selectedModel == "gemini-2.0-flash",
                              onTap: () {
                                setSheetState(() => _selectedModel = "gemini-2.0-flash");
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Select Prebuilt Voice Tone',
                          style: GoogleFonts.spaceMono(
                            color: _accentLime,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            "Aoede",
                            "Puck",
                            "Charon",
                            "Kore",
                            "Fenrir",
                          ].map((voice) {
                            return _buildSheetSelector(
                              title: voice,
                              isSelected: _selectedVoice == voice,
                              onTap: () {
                                setSheetState(() => _selectedVoice = voice);
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentLime,
                            foregroundColor: const Color(0xFF020104),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Apply Changes',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetSelector({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accentLime : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _accentLime : Colors.white.withOpacity(0.08),
            width: 1.2,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: isSelected ? const Color(0xFF020104) : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // Dynamic pulsing radial background glow
          AnimatedBuilder(
            animation: Listenable.merge([_animationController, _glowController]),
            builder: (context, child) {
              double opacityFactor = 0.12 + 0.05 * _glowController.value;
              if (_currentState == AuraVoiceState.listening) {
                opacityFactor = 0.22 + 0.08 * math.sin(_animationController.value * math.pi * 12).abs();
              } else if (_currentState == AuraVoiceState.thinking) {
                opacityFactor = 0.26;
              } else if (_currentState == AuraVoiceState.speaking) {
                opacityFactor = 0.18 + 0.07 * math.cos(_animationController.value * math.pi * 8).abs();
              }

              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        const Color(0xFF381559).withOpacity(opacityFactor * 1.5),
                        const Color(0xFF0F031D).withOpacity(opacityFactor * 0.4),
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
                // Top Custom Header Row
                _buildHeaderRow(),
                
                // Fluid Central Orb Graphic
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFluidOrbContainer(),
                        const SizedBox(height: 16),
                        _buildStateIndicator(),
                      ],
                    ),
                  ),
                ),
                
                // Floating suggestion chips for query triggers (only show when idle)
                if (_currentState == AuraVoiceState.idle) _buildSuggestionsRow(),
                const SizedBox(height: 24),
                
                // Subtitles Overlay Panel
                _buildSubtitleOverlay(),
                const SizedBox(height: 40),
                
                // Voice Controls Action Bar
                _buildVoiceControlBar(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          _buildTopBadge(),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showVoiceSettingsSheet(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
              ),
              child: const Icon(Icons.tune_rounded, color: _accentLime, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _accentLime.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentLime, width: 1.2),
      ),
      child: Text(
        'AI Buddy',
        style: GoogleFonts.spaceGrotesk(
          color: _accentLime,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSuggestionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Text(
            "QUICK SUGGESTIONS",
            style: GoogleFonts.spaceMono(
              color: Colors.white.withOpacity(0.35),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final text = _suggestions[index];
              return Container(
                margin: const EdgeInsets.only(right: 10),
                child: ActionChip(
                  label: Text(text),
                  labelStyle: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withOpacity(0.03),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.0),
                  ),
                  onPressed: () {
                    _triggerVoiceFlow(preSetText: text);
                  },
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0.0);
  }

  Widget _buildFluidOrbContainer() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FittedBox(
          fit: BoxFit.contain,
          child: CustomPaint(
            size: const Size(280, 280),
            painter: AuraFluidOrbPainter(
              animationValue: _animationController.value,
              state: _currentState,
              amplitude: _currentAmplitude,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateIndicator() {
    if (_currentState == AuraVoiceState.idle) return const SizedBox.shrink();

    String label;
    IconData icon;
    Color color;
    switch (_currentState) {
      case AuraVoiceState.listening:
        label = 'Listening';
        icon = Icons.hearing_rounded;
        color = const Color(0xFF00D4FF);
        break;
      case AuraVoiceState.thinking:
        label = 'Processing';
        icon = Icons.auto_awesome_rounded;
        color = const Color(0xFFCBB6FC);
        break;
      case AuraVoiceState.speaking:
        label = 'Speaking';
        icon = Icons.record_voice_over_rounded;
        color = _accentLime;
        break;
      default:
        return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulseAlpha = 0.6 + 0.4 * _pulseController.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.3 * pulseAlpha),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.withValues(alpha: pulseAlpha), size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: color.withValues(alpha: pulseAlpha),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0));
  }

  Widget _buildSubtitleOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36),
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
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.38,
                  ),
                ),
              ),
            ),
          ),
          if (_activeSpeechWord.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _accentLime.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentLime.withOpacity(0.3), width: 1.0),
              ),
              child: Text(
                _activeSpeechWord.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: _accentLime,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Keyboard/Chat toggle button
          _buildCircleButton(
            Icons.keyboard_outlined,
            () async {
              HapticFeedback.lightImpact();
              final session = await ref.read(auraSessionsProvider.notifier).createNewSession('Chat');
              if (mounted) {
                context.pushReplacement('/profile/settings/aura/chat?category=Chat&sessionId=${session.id}');
              }
            },
            size: 54,
            backgroundColor: const Color(0xFF13101C),
            iconColor: Colors.white.withOpacity(0.9),
          ),
          
          // Central Microphone Activation Pulsing Button
          GestureDetector(
            onTap: () {
              if (_currentState == AuraVoiceState.idle) {
                setState(() {
                  _isContinuousActive = true;
                });
                _triggerVoiceFlow();
              } else {
                setState(() {
                  _isContinuousActive = false;
                });
                _resetFlow();
              }
            },
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                double glowScale = 1.0;
                if (_currentState == AuraVoiceState.listening) {
                  glowScale = 1.05 + 0.08 * _glowController.value;
                } else if (_currentState == AuraVoiceState.thinking) {
                  glowScale = 1.02;
                }
                
                return Transform.scale(
                  scale: glowScale,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentLime,
                      boxShadow: [
                        BoxShadow(
                          color: _accentLime.withOpacity(0.35),
                          blurRadius: _currentState == AuraVoiceState.listening ? 24 : 12,
                          spreadRadius: _currentState == AuraVoiceState.listening ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _currentState == AuraVoiceState.listening
                            ? Icons.graphic_eq_rounded
                            : _currentState == AuraVoiceState.speaking
                                ? Icons.volume_up_rounded
                                : _currentState == AuraVoiceState.thinking
                                    ? Icons.hourglass_empty_rounded
                                    : Icons.mic_none_rounded,
                        color: const Color(0xFF020104),
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Reset/Close Button
          _buildCircleButton(
            _currentState != AuraVoiceState.idle ? Icons.refresh_rounded : Icons.close_rounded,
            () {
              setState(() {
                _isContinuousActive = false;
              });
              if (_currentState != AuraVoiceState.idle) {
                _resetFlow();
              } else {
                HapticFeedback.lightImpact();
                context.pop();
              }
            },
            size: 54,
            backgroundColor: const Color(0xFF13101C),
            iconColor: Colors.white.withOpacity(0.9),
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
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class AuraFluidOrbPainter extends CustomPainter {
  final double animationValue;
  final AuraVoiceState state;
  final double amplitude;

  AuraFluidOrbPainter({
    required this.animationValue,
    required this.state,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width * 0.30;
    final Offset center = Offset(cx, cy);

    // --- State-driven dynamics ---
    double wiggleSpeed, wiggleScale;
    switch (state) {
      case AuraVoiceState.listening:
        wiggleSpeed = 2.5;
        wiggleScale = 0.10 + 0.22 * amplitude;
        break;
      case AuraVoiceState.speaking:
        wiggleSpeed = 1.8;
        wiggleScale = 0.06 + 0.14 * amplitude;
        break;
      case AuraVoiceState.thinking:
        wiggleSpeed = 4.0;
        wiggleScale = 0.16;
        break;
      case AuraVoiceState.idle:
        wiggleSpeed = 0.4;
        wiggleScale = 0.025;
        break;
    }

    final double phase = animationValue * 2 * math.pi * wiggleSpeed;
    final double breathe = 0.5 + 0.5 * math.sin(animationValue * math.pi * 2);

    // ═══════════════════════════════════════════
    // LAYER 0 — Deep Space Nebula Background Glow
    // ═══════════════════════════════════════════
    for (int g = 0; g < 3; g++) {
      final double gr = radius * (2.2 - g * 0.3);
      final double ga = state == AuraVoiceState.idle
          ? 0.06 + 0.03 * breathe
          : state == AuraVoiceState.listening
              ? 0.14 + 0.08 * amplitude
              : state == AuraVoiceState.thinking
                  ? 0.18
                  : 0.10 + 0.06 * amplitude;
      final colors = g == 0
          ? [const Color(0xFF7B2FFF).withValues(alpha: ga), Colors.transparent]
          : g == 1
              ? [const Color(0xFFFF007F).withValues(alpha: ga * 0.6), Colors.transparent]
              : [const Color(0xFF00D4FF).withValues(alpha: ga * 0.4), Colors.transparent];
      final glowPaint = Paint()
        ..shader = RadialGradient(colors: colors).createShader(
          Rect.fromCircle(center: center, radius: gr),
        );
      canvas.drawCircle(center, gr, glowPaint);
    }

    // ═══════════════════════════════════════════
    // LAYER 1 — Outer Particle Constellation Ring
    // ═══════════════════════════════════════════
    final double outerOrbitR = radius * 1.65;
    final int particleCount = 48;
    for (int i = 0; i < particleCount; i++) {
      final double angle = (i / particleCount) * 2 * math.pi + phase * 0.08;
      final double drift = math.sin(angle * 3 + phase * 0.6) * 4.0;
      final double pr = outerOrbitR + drift;
      final double px = cx + pr * math.cos(angle);
      final double py = cy + pr * math.sin(angle);
      final double particleSize = 1.2 + 1.0 * math.sin(angle * 5 + phase).abs();
      final double pa = 0.15 + 0.25 * math.sin(angle * 7 + phase * 1.5).abs();
      final pPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0xFFCBB6FC),
          const Color(0xFFC0EC54),
          (i / particleCount),
        )!.withValues(alpha: pa);
      canvas.drawCircle(Offset(px, py), particleSize, pPaint);
    }

    // ═══════════════════════════════════════════
    // LAYER 2 — Dual Orbital Guide Rings + Orbiting Nodes
    // ═══════════════════════════════════════════
    for (int ring = 0; ring < 2; ring++) {
      final double rr = radius * (1.50 + ring * 0.22);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = (ring == 0
                ? const Color(0xFFC0EC54)
                : const Color(0xFFCBB6FC))
            .withValues(alpha: 0.06 + 0.04 * breathe)
        ..strokeWidth = 0.8;
      canvas.drawCircle(center, rr, ringPaint);

      // Orbiting luminous nodes (3 per ring, evenly spaced)
      for (int n = 0; n < 3; n++) {
        final double na = phase * (0.25 + ring * 0.1) + (n * 2 * math.pi / 3);
        final double nx = cx + rr * math.cos(na);
        final double ny = cy + rr * math.sin(na);
        final nodeColor = ring == 0 ? const Color(0xFFC0EC54) : const Color(0xFFCBB6FC);
        // Glow halo
        canvas.drawCircle(
          Offset(nx, ny),
          6.0,
          Paint()
            ..style = PaintingStyle.fill
            ..color = nodeColor.withValues(alpha: 0.15),
        );
        // Core dot
        canvas.drawCircle(
          Offset(nx, ny),
          2.8,
          Paint()
            ..style = PaintingStyle.fill
            ..color = nodeColor.withValues(alpha: 0.85),
        );
      }
    }

    // ═══════════════════════════════════════════
    // LAYER 3 — Primary Equalizer Ring (48 bars)
    // ═══════════════════════════════════════════
    final int barCount = 48;
    final double eqRadius = radius * 1.14;
    for (int i = 0; i < barCount; i++) {
      final double angle = (i / barCount) * 2 * math.pi + phase * 0.12;
      final double t = i / barCount;

      double barH;
      switch (state) {
        case AuraVoiceState.listening:
          barH = 3.0 +
              30.0 *
                  amplitude *
                  (0.5 * math.sin(angle * 6 + phase * 3.0).abs() +
                      0.5 * math.cos(angle * 4 - phase * 2.2).abs());
          break;
        case AuraVoiceState.speaking:
          barH = 3.0 +
              24.0 *
                  amplitude *
                  (0.6 * math.cos(angle * 5 - phase * 2.0).abs() +
                      0.4 * math.sin(angle * 3 + phase * 1.5).abs());
          break;
        case AuraVoiceState.thinking:
          barH = 3.0 + 14.0 * math.sin(angle * 9 + phase * 4.0).abs();
          break;
        case AuraVoiceState.idle:
          barH = 2.5 + 3.5 * math.sin(angle * 2 + phase * 0.8).abs();
          break;
      }

      final double sx = cx + eqRadius * math.cos(angle);
      final double sy = cy + eqRadius * math.sin(angle);
      final double ex = cx + (eqRadius + barH) * math.cos(angle);
      final double ey = cy + (eqRadius + barH) * math.sin(angle);

      final barColor = Color.lerp(
        const Color(0xFFCBB6FC),
        const Color(0xFFC0EC54),
        t,
      )!;
      final barAlpha = state == AuraVoiceState.idle ? 0.4 : 0.75 + 0.25 * (barH / 30.0).clamp(0.0, 1.0);

      final bPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = state == AuraVoiceState.idle ? 1.8 : 2.6
        ..strokeCap = StrokeCap.round
        ..color = barColor.withValues(alpha: barAlpha);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), bPaint);
    }

    // ═══════════════════════════════════════════
    // LAYER 4 — Secondary Inner Equalizer Ring (24 thin bars)
    // ═══════════════════════════════════════════
    if (state != AuraVoiceState.idle) {
      final int innerBarCount = 24;
      final double innerEqR = radius * 0.92;
      for (int i = 0; i < innerBarCount; i++) {
        final double angle = (i / innerBarCount) * 2 * math.pi - phase * 0.18;
        double h;
        switch (state) {
          case AuraVoiceState.listening:
            h = 2.0 + 12.0 * amplitude * math.sin(angle * 7 + phase * 3.5).abs();
            break;
          case AuraVoiceState.speaking:
            h = 2.0 + 10.0 * amplitude * math.cos(angle * 5 - phase * 2.5).abs();
            break;
          case AuraVoiceState.thinking:
            h = 2.0 + 6.0 * math.sin(angle * 10 + phase * 5.0).abs();
            break;
          default:
            h = 2.0;
        }

        // Bars grow inward
        final double outerX = cx + innerEqR * math.cos(angle);
        final double outerY = cy + innerEqR * math.sin(angle);
        final double innerX = cx + (innerEqR - h) * math.cos(angle);
        final double innerY = cy + (innerEqR - h) * math.sin(angle);

        final bPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF00D4FF).withValues(alpha: 0.35 + 0.35 * (h / 12.0).clamp(0.0, 1.0));
        canvas.drawLine(Offset(outerX, outerY), Offset(innerX, innerY), bPaint);
      }
    }

    // ═══════════════════════════════════════════
    // LAYER 5 — Aurora Wave Fluid Orb (4 morphing layers)
    // ═══════════════════════════════════════════
    final List<List<Color>> layerGradients = [
      [const Color(0xFFCBB6FC), const Color(0xFFBFF6EB)], // lavender → mint
      [const Color(0xFF00D4FF), const Color(0xFF8B00FF)], // cyan → violet
      [const Color(0xFFFFD1B3), const Color(0xFFFF007F)], // peach → magenta
      [const Color(0xFFBFF6EB), const Color(0xFFC0EC54)], // mint → lime
    ];
    final List<double> layerAlphas = [0.88, 0.55, 0.40, 0.30];

    for (int layer = 0; layer < 4; layer++) {
      final double layerPhase = phase + (layer * math.pi / 2.0);
      final double lr = radius * (1.0 - layer * 0.07);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: layerGradients[layer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: lr));

      const int pts = 12;
      final List<Offset> points = [];
      for (int i = 0; i < pts; i++) {
        final double a = (i / pts) * 2 * math.pi;
        final double warp = (math.sin(a * 4 + layerPhase) * 0.55 +
                math.cos(a * 3 - layerPhase * 1.3) * 0.35 +
                math.sin(a * 6 + layerPhase * 0.7) * 0.10) *
            lr *
            wiggleScale;
        final double r = lr + warp;
        points.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
      }

      final Path path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < pts; i++) {
        final cur = points[i];
        final nxt = points[(i + 1) % pts];
        path.quadraticBezierTo(cur.dx, cur.dy, (cur.dx + nxt.dx) / 2, (cur.dy + nxt.dy) / 2);
      }
      path.close();

      canvas.save();
      if (layer > 0) {
        canvas.saveLayer(
          Rect.fromCircle(center: center, radius: radius * 1.5),
          Paint()..blendMode = BlendMode.screen,
        );
      }
      canvas.drawPath(path, paint..color = Colors.white.withValues(alpha: layerAlphas[layer]));
      if (layer > 0) {
        canvas.restore();
      }
      canvas.restore();
    }

    // ═══════════════════════════════════════════
    // LAYER 6 — Central Glassmorphic Core Highlight
    // ═══════════════════════════════════════════
    final double coreR = radius * 0.35;
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.30 + 0.10 * breathe),
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawCircle(center, coreR, corePaint);

    // Tiny specular highlight dot at top-left of core
    canvas.drawCircle(
      Offset(cx - coreR * 0.3, cy - coreR * 0.3),
      coreR * 0.15,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.45 + 0.15 * breathe),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
