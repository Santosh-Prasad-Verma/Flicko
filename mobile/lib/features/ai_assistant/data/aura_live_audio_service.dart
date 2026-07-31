import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum AuraLivePhase { connecting, ready, listening, responding, complete }

class AuraLiveTurnResult {
  final Uint8List audioPcm;
  final int outputSampleRate;
  final String inputTranscript;
  final String outputTranscript;
  final String model;
  final int promptTokenCount;
  final int responseTokenCount;
  final int totalTokenCount;

  const AuraLiveTurnResult({
    required this.audioPcm,
    required this.outputSampleRate,
    required this.inputTranscript,
    required this.outputTranscript,
    required this.model,
    this.promptTokenCount = 0,
    this.responseTokenCount = 0,
    this.totalTokenCount = 0,
  });

  bool get hasNativeAudio => audioPcm.isNotEmpty;

  String get displayText {
    final text = outputTranscript.trim();
    if (text.isNotEmpty) return text;
    final input = inputTranscript.trim();
    if (input.isNotEmpty) return 'Aura answered your voice request.';
    return 'Aura live response received.';
  }
}

class AuraLiveAudioException implements Exception {
  final String message;
  final Object? cause;

  const AuraLiveAudioException(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

class AuraLiveAudioService {
  static const String defaultModel = 'aura-stella-en';
  static const String defaultAgentEndpoint = 'wss://agent.deepgram.com/v1/agent/converse';
  static const int inputSampleRate = 48000;
  static const int outputSampleRate = 24000;
  static const Duration _setupTimeout = Duration(seconds: 12);
  static const Duration _responseTimeout = Duration(seconds: 45);
  static const Duration _maxInputDuration = Duration(seconds: 12);
  static const Duration _minInputDuration = Duration(milliseconds: 1000);
  static const Duration _silenceStopDuration = Duration(milliseconds: 1200);

  static const String _defaultSystemPrompt = r'''# Role & Identity
You are Aura, the native AI Voice Companion and Central Command Intelligence inside the Flicko application. You serve dual roles:
1. Full Application Controller: Executing real-time voice commands to control all aspects of Flicko (messaging, calls, music, navigation, settings, social).
2. Conversational Companion: Engaging in natural, intelligent, warm, and casual dialogue on any topic, question, or task.

# General Voice Directives
- Voice Output Only: Do not use markdown syntax (no asterisks, bullet points, numbered lists, hashtags, emojis, or code blocks) because your words will be spoken directly via Text-to-Speech (TTS). Use natural punctuation for fluid spoken cadence.
- Operational Brevity: For application commands and control tasks, confirm the action in 1 short, crisp sentence (under 100 characters).
- Casual Conversations: For general questions, advice, tech discussions, stories, or casual banter, be engaging, warm, articulate, and conversational while keeping speech flowing and easy to listen to.
- Persona: Cybernetic, intelligent, friendly, confident, and ultra-responsive.

# Application Control & Navigation Reference
- Navigation & Screens:
  • "Open Settings" -> Navigates to Settings (/profile/settings)
  • "Open Account Settings" -> Navigates to Account Settings (/profile/settings/account)
  • "Open Privacy Settings" -> Navigates to Privacy (/profile/settings/privacy)
  • "Open Voice Settings" -> Navigates to Voice Settings (/profile/settings/voice)
  • "Open Appearance" / "Dark Mode" -> Navigates to Appearance (/profile/settings/appearance)
  • "Open Aura Settings" -> Navigates to Aura AI Config (/profile/settings/aura)
  • "Open Profile" -> Navigates to User Profile (/profile)
  • "Open Direct Messages" / "Open DMs" -> Navigates to DM list (/dms)
  • "Open Music" / "Open Sonic Drip" -> Navigates to Music Player (/sonic-drip)
  • "Open Servers" / "Go Home" -> Navigates to Server Hub (/home)
  • "Open Friends" -> Navigates to Friends List (/friends)
  • "Open Store" -> Navigates to Flicko Store (/store)
  • "Open Gaming" / "Open Ludo" -> Navigates to Gaming Hub or Ludo (/gaming or /ludo)
  • "Open News" -> Navigates to News Feed (/newz)
  • "Open Notifications" -> Navigates to Notifications (/notifications)
  • "Open Search" -> Navigates to Search (/search)

- Direct Messaging & Communication:
  • "Message [Name]: [Message]" -> Sends direct message to friend/contact
  • "Send DM to [Name] saying [Message]" -> Sends direct message
  • "Read my unread messages" -> Checks notifications and DMs

- Calls & Voice Channel Control:
  • "Disconnect call" / "Leave call" -> End current voice session or call
  • "Mute microphone" / "Unmute" -> Toggles audio input state
  • "Start voice call with [Name]" -> Connects to voice call

- Music & Media Controls (Sonic Drip):
  • "Play [Song/Genre]" -> Searches and plays track on Sonic Drip
  • "Pause music" / "Stop music" -> Pauses current audio playback
  • "Resume music" -> Resumes audio playback
  • "Next song" / "Skip track" -> Advances music queue

# Behavioral Rules
- When the user gives a command (e.g., "Open my settings" or "Message Alex hey what's up"), immediately acknowledge the action concisely and execute.
- When the user asks a casual question (e.g., "How does quantum computing work?" or "Tell me a joke"), answer conversationally, accurately, and naturally.
- Always remain helpful, positive, and attentive to user intent.''';

  final AudioRecorder _recorder = AudioRecorder();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _silenceTimer;
  bool _closed = false;

  Future<AuraLiveTurnResult> runPushToTalkTurn({
    required String apiKey,
    required String model,
    required String voiceName,
    required String systemInstruction,
    void Function(AuraLivePhase phase)? onPhase,
    void Function(double level)? onInputLevel,
    void Function(String transcript)? onInputTranscript,
    void Function(String transcript)? onOutputTranscript,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const AuraLiveAudioException('Deepgram API key is not configured.');
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const AuraLiveAudioException('Microphone permission is required.');
    }

    return _runTurn(
      apiKey: cleanKey,
      model: model,
      voiceName: voiceName,
      systemInstruction: systemInstruction,
      onPhase: onPhase,
      onInputTranscript: onInputTranscript,
      onOutputTranscript: onOutputTranscript,
      sendInput: () async {
        onPhase?.call(AuraLivePhase.listening);
        await _streamMicrophone(onInputLevel);
      },
    );
  }

  Future<AuraLiveTurnResult> runTextTurn({
    required String apiKey,
    required String prompt,
    required String model,
    required String voiceName,
    required String systemInstruction,
    void Function(AuraLivePhase phase)? onPhase,
    void Function(String transcript)? onOutputTranscript,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const AuraLiveAudioException('Deepgram API key is not configured.');
    }

    return _runTurn(
      apiKey: cleanKey,
      model: model,
      voiceName: voiceName,
      systemInstruction: systemInstruction,
      onPhase: onPhase,
      onOutputTranscript: onOutputTranscript,
      sendInput: () async {
        onPhase?.call(AuraLivePhase.responding);
        _sendJson({
          'type': 'InjectAgentMessage',
          'message': prompt.trim(),
        });
      },
    );
  }

  Future<AuraLiveTurnResult> _runTurn({
    required String apiKey,
    required String model,
    required String voiceName,
    required String systemInstruction,
    required Future<void> Function() sendInput,
    void Function(AuraLivePhase phase)? onPhase,
    void Function(String transcript)? onInputTranscript,
    void Function(String transcript)? onOutputTranscript,
  }) async {
    await dispose();
    _closed = false;
    onPhase?.call(AuraLivePhase.connecting);

    final setupComplete = Completer<void>();
    final turnComplete = Completer<AuraLiveTurnResult>();
    final outputBytes = BytesBuilder(copy: false);
    final inputTranscript = StringBuffer();
    final outputTranscript = StringBuffer();
    final effectiveModel = model.isNotEmpty ? model : defaultModel;
    final effectiveVoice = voiceName.isNotEmpty ? voiceName : defaultModel;
    final promptToUse = systemInstruction.isNotEmpty
        ? systemInstruction
        : _defaultSystemPrompt;

    final String deepgramVoice;
    switch (voiceName.toLowerCase()) {
      case 'aoede':
      case 'stella':
        deepgramVoice = 'aura-stella-en';
        break;
      case 'puck':
      case 'arcas':
        deepgramVoice = 'aura-arcas-en';
        break;
      case 'charon':
      case 'zeus':
        deepgramVoice = 'aura-zeus-en';
        break;
      case 'kore':
      case 'luna':
        deepgramVoice = 'aura-luna-en';
        break;
      case 'fenrir':
      case 'asteria':
        deepgramVoice = 'aura-asteria-en';
        break;
      case 'orpheus':
        deepgramVoice = 'aura-orpheus-en';
        break;
      case 'angus':
        deepgramVoice = 'aura-angus-en';
        break;
      default:
        deepgramVoice = voiceName.startsWith('aura-')
            ? voiceName.replaceAll('aura-2-', 'aura-')
            : 'aura-stella-en';
    }

    try {
      final uri = Uri.parse(defaultAgentEndpoint);
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Authorization': 'Token $apiKey',
        },
      );
      _channel = channel;

      _socketSub = channel.stream.listen(
        (event) {
          try {
            // Binary data = PCM output audio from Deepgram Aura TTS (24kHz linear16)
            if (event is List<int> || event is Uint8List) {
              final bytes = event is Uint8List
                  ? event
                  : Uint8List.fromList(event as List<int>);
              outputBytes.add(bytes);
              onPhase?.call(AuraLivePhase.responding);
              return;
            }

            final decoded = _decodeServerMessage(event);
            if (decoded == null) return;

            final type = decoded['type'] as String?;

            if (type == 'Welcome' || type == 'SettingsApplied') {
              if (!setupComplete.isCompleted) {
                setupComplete.complete();
                onPhase?.call(AuraLivePhase.ready);
              }
              return;
            }

            if (type == 'Error') {
              final errorMsg = decoded['message'] ?? decoded['description'] ?? 'Deepgram Agent Error';
              if (!turnComplete.isCompleted) {
                turnComplete.completeError(
                  AuraLiveAudioException('Deepgram Agent error', errorMsg),
                );
              }
              return;
            }

            if (type == 'UserStartedSpeaking') {
              onPhase?.call(AuraLivePhase.listening);
            } else if (type == 'AgentThinking') {
              onPhase?.call(AuraLivePhase.responding);
            } else if (type == 'AgentStartedSpeaking') {
              onPhase?.call(AuraLivePhase.responding);
            } else if (type == 'AgentAudioDone' || type == 'UtteranceEnd') {
              if (outputBytes.length > 0 && !turnComplete.isCompleted) {
                onPhase?.call(AuraLivePhase.complete);
                turnComplete.complete(
                  AuraLiveTurnResult(
                    audioPcm: outputBytes.takeBytes(),
                    outputSampleRate: outputSampleRate,
                    inputTranscript: inputTranscript.toString(),
                    outputTranscript: outputTranscript.toString(),
                    model: deepgramVoice,
                  ),
                );
              }
            } else if (type == 'ConversationText') {
              final role = decoded['role'] as String?;
              final content = decoded['content'] as String?;
              if (content != null && content.trim().isNotEmpty) {
                if (role == 'user') {
                  inputTranscript.write(content);
                  onInputTranscript?.call(inputTranscript.toString());
                } else {
                  outputTranscript.write(content);
                  onOutputTranscript?.call(outputTranscript.toString());
                }
              }
            }
          } catch (error) {
            if (!turnComplete.isCompleted) {
              turnComplete.completeError(
                AuraLiveAudioException(
                  'Failed to parse Deepgram Agent response',
                  error,
                ),
              );
            }
          }
        },
        onError: (error) {
          if (!turnComplete.isCompleted) {
            turnComplete.completeError(
              AuraLiveAudioException('Deepgram Agent socket failed', error),
            );
          }
        },
        onDone: () {
          if (!_closed && !turnComplete.isCompleted) {
            if (outputBytes.length > 0) {
              turnComplete.complete(
                AuraLiveTurnResult(
                  audioPcm: outputBytes.takeBytes(),
                  outputSampleRate: outputSampleRate,
                  inputTranscript: inputTranscript.toString(),
                  outputTranscript: outputTranscript.toString(),
                  model: deepgramVoice,
                ),
              );
            } else {
              turnComplete.completeError(
                const AuraLiveAudioException(
                  'Deepgram Agent socket closed early.',
                ),
              );
            }
          }
        },
      );

      await channel.ready.timeout(_setupTimeout);

      // Send valid Deepgram Voice Agent Settings payload
      _sendJson({
        'type': 'Settings',
        'audio': {
          'input': {
            'encoding': 'linear16',
            'sample_rate': inputSampleRate,
          },
          'output': {
            'encoding': 'linear16',
            'sample_rate': outputSampleRate,
            'container': 'none',
          },
        },
        'agent': {
          'listen': {
            'provider': {
              'type': 'deepgram',
              'model': 'nova-2-general',
            },
          },
          'think': {
            'provider': {
              'type': 'open_ai',
              'model': 'gpt-4o-mini',
            },
            'prompt': promptToUse,
          },
          'speak': {
            'provider': {
              'type': 'deepgram',
              'model': deepgramVoice,
            },
          },
        },
      });

      await setupComplete.future.timeout(_setupTimeout);
      await sendInput();

      // Fallback timeout check to ensure completion if AgentAudioDone isn't sent
      Timer(const Duration(seconds: 4), () {
        if (!turnComplete.isCompleted && outputBytes.length > 0) {
          onPhase?.call(AuraLivePhase.complete);
          turnComplete.complete(
            AuraLiveTurnResult(
              audioPcm: outputBytes.takeBytes(),
              outputSampleRate: outputSampleRate,
              inputTranscript: inputTranscript.toString(),
              outputTranscript: outputTranscript.toString(),
              model: effectiveModel,
            ),
          );
        }
      });

      return await turnComplete.future.timeout(_responseTimeout);
    } on TimeoutException catch (error) {
      if (outputBytes.length > 0) {
        return AuraLiveTurnResult(
          audioPcm: outputBytes.takeBytes(),
          outputSampleRate: outputSampleRate,
          inputTranscript: inputTranscript.toString(),
          outputTranscript: outputTranscript.toString(),
          model: effectiveModel,
        );
      }
      throw AuraLiveAudioException('Deepgram Agent timed out.', error);
    } catch (error) {
      if (error is AuraLiveAudioException) rethrow;
      throw AuraLiveAudioException('Deepgram Agent failed.', error);
    } finally {
      await dispose();
    }
  }

  Future<void> _streamMicrophone(
    void Function(double level)? onInputLevel,
  ) async {
    DateTime startedAt = DateTime.now();
    DateTime lastVoiceAt = startedAt;
    int bytesSent = 0;
    final stopInput = Completer<void>();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: inputSampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: 4096,
      ),
    );

    _micSub = stream.listen(
      (chunk) {
        if (_closed || chunk.isEmpty) return;
        bytesSent += chunk.length;
        final level = _estimatePcmLevel(chunk);
        onInputLevel?.call(level);
        if (level > 0.018) {
          lastVoiceAt = DateTime.now();
        }
        // Send raw binary PCM bytes directly to Deepgram Agent WebSocket
        _channel?.sink.add(chunk);
      },
      onError: (error) {
        if (!stopInput.isCompleted) {
          stopInput.completeError(
            AuraLiveAudioException('Microphone stream failed.', error),
          );
        }
      },
    );

    _silenceTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      final now = DateTime.now();
      final hasMinimumAudio = now.difference(startedAt) >= _minInputDuration;
      final hasSpeech = bytesSent >= (inputSampleRate * 2);
      final silenceLongEnough =
          now.difference(lastVoiceAt) >= _silenceStopDuration;
      if (hasMinimumAudio && hasSpeech && silenceLongEnough) {
        if (!stopInput.isCompleted) stopInput.complete();
      }
    });

    await stopInput.future.timeout(_maxInputDuration, onTimeout: () {});
    await _stopMic();
  }

  Map<String, dynamic>? _decodeServerMessage(dynamic event) {
    if (event is String) {
      final decoded = jsonDecode(event);
      return decoded is Map<String, dynamic> ? decoded : null;
    }
    if (event is List<int>) {
      final decoded = jsonDecode(utf8.decode(event));
      return decoded is Map<String, dynamic> ? decoded : null;
    }
    return null;
  }

  void _sendJson(Map<String, dynamic> payload) {
    if (_closed) return;
    _channel?.sink.add(jsonEncode(payload));
  }

  double _estimatePcmLevel(Uint8List bytes) {
    if (bytes.length < 2) return 0;
    final data = ByteData.sublistView(bytes);
    int count = 0;
    double sumSquares = 0;
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final sample = data.getInt16(i, Endian.little) / 32768.0;
      sumSquares += sample * sample;
      count++;
    }
    if (count == 0) return 0;
    return math.sqrt(sumSquares / count).clamp(0.0, 1.0);
  }

  Future<void> _stopMic() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (error) {
      debugPrint('[AuraLive] recorder stop ignored: $error');
    }
  }

  Future<void> dispose() async {
    _closed = true;
    await _stopMic();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (error) {
      debugPrint('[AuraLive] socket close ignored: $error');
    }
    _channel = null;
  }
}
