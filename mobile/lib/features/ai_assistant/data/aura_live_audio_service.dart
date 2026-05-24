import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
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
  static const String defaultModel =
      'gemini-2.5-flash-native-audio-preview-12-2025';
  static const int inputSampleRate = 16000;
  static const int outputSampleRate = 24000;
  static const Duration _setupTimeout = Duration(seconds: 12);
  static const Duration _responseTimeout = Duration(seconds: 45);
  static const Duration _maxInputDuration = Duration(seconds: 10);
  static const Duration _minInputDuration = Duration(milliseconds: 1200);
  static const Duration _silenceStopDuration = Duration(milliseconds: 1100);

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
      throw const AuraLiveAudioException('Gemini API key is not configured.');
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
      throw const AuraLiveAudioException('Gemini API key is not configured.');
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
          'clientContent': {
            'turns': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt.trim()},
                ],
              },
            ],
            'turnComplete': true,
          },
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
    int detectedOutputRate = outputSampleRate;
    int promptTokens = 0;
    int responseTokens = 0;
    int totalTokens = 0;

    try {
      final uri = Uri(
        scheme: 'wss',
        host: 'generativelanguage.googleapis.com',
        path:
            '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
        queryParameters: {'key': apiKey},
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _socketSub = channel.stream.listen(
        (event) {
          try {
            final decoded = _decodeServerMessage(event);
            if (decoded == null) return;

            if (decoded['setupComplete'] != null &&
                !setupComplete.isCompleted) {
              setupComplete.complete();
              onPhase?.call(AuraLivePhase.ready);
              return;
            }

            final error = decoded['error'];
            if (error != null && !turnComplete.isCompleted) {
              turnComplete.completeError(
                AuraLiveAudioException('Gemini Live API error', error),
              );
              return;
            }

            final usage = decoded['usageMetadata'];
            if (usage is Map) {
              promptTokens = _readInt(usage['promptTokenCount']);
              responseTokens = _readInt(usage['responseTokenCount']);
              totalTokens = _readInt(usage['totalTokenCount']);
            }

            final serverContent = decoded['serverContent'];
            if (serverContent is! Map) return;

            if (serverContent['interrupted'] == true) {
              outputBytes.clear();
            }

            final inText = _readTranscription(
              serverContent['inputTranscription'],
            );
            if (inText.isNotEmpty) {
              inputTranscript.write(inText);
              onInputTranscript?.call(inputTranscript.toString());
            }

            final outText = _readTranscription(
              serverContent['outputTranscription'],
            );
            if (outText.isNotEmpty) {
              outputTranscript.write(outText);
              onOutputTranscript?.call(outputTranscript.toString());
            }

            final modelTurn = serverContent['modelTurn'];
            if (modelTurn is Map) {
              final parts = modelTurn['parts'];
              if (parts is List) {
                for (final part in parts) {
                  if (part is! Map) continue;
                  final text = part['text'];
                  if (text is String && text.trim().isNotEmpty) {
                    outputTranscript.write(text);
                    onOutputTranscript?.call(outputTranscript.toString());
                  }
                  final inlineData = part['inlineData'];
                  if (inlineData is Map) {
                    final data = inlineData['data'];
                    final mimeType = inlineData['mimeType'];
                    if (data is String && data.isNotEmpty) {
                      outputBytes.add(base64Decode(data));
                      detectedOutputRate =
                          _sampleRateFromMimeType(mimeType) ?? outputSampleRate;
                      onPhase?.call(AuraLivePhase.responding);
                    }
                  }
                }
              }
            }

            if (serverContent['turnComplete'] == true &&
                !turnComplete.isCompleted) {
              onPhase?.call(AuraLivePhase.complete);
              turnComplete.complete(
                AuraLiveTurnResult(
                  audioPcm: outputBytes.takeBytes(),
                  outputSampleRate: detectedOutputRate,
                  inputTranscript: inputTranscript.toString(),
                  outputTranscript: outputTranscript.toString(),
                  model: model,
                  promptTokenCount: promptTokens,
                  responseTokenCount: responseTokens,
                  totalTokenCount: totalTokens,
                ),
              );
            }
          } catch (error) {
            if (!turnComplete.isCompleted) {
              turnComplete.completeError(
                AuraLiveAudioException(
                  'Failed to parse Gemini Live response',
                  error,
                ),
              );
            }
          }
        },
        onError: (error) {
          if (!turnComplete.isCompleted) {
            turnComplete.completeError(
              AuraLiveAudioException('Gemini Live socket failed', error),
            );
          }
        },
        onDone: () {
          if (!_closed && !turnComplete.isCompleted) {
            turnComplete.completeError(
              const AuraLiveAudioException('Gemini Live socket closed early.'),
            );
          }
        },
      );

      await channel.ready.timeout(_setupTimeout);
      _sendJson({
        'setup': {
          'model': _normalizeModelName(model),
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'temperature': 0.8,
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': voiceName},
              },
            },
          },
          'systemInstruction': {
            'role': 'system',
            'parts': [
              {'text': systemInstruction},
            ],
          },
          'inputAudioTranscription': {},
          'outputAudioTranscription': {},
          'realtimeInputConfig': {
            'automaticActivityDetection': {
              'disabled': false,
              'silenceDurationMs': 700,
            },
            'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
          },
        },
      });

      await setupComplete.future.timeout(_setupTimeout);
      await sendInput();
      return await turnComplete.future.timeout(_responseTimeout);
    } on TimeoutException catch (error) {
      throw AuraLiveAudioException('Gemini Live timed out.', error);
    } catch (error) {
      if (error is AuraLiveAudioException) rethrow;
      throw AuraLiveAudioException('Gemini Live failed.', error);
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
        _sendJson({
          'realtimeInput': {
            'audio': {
              'mimeType': 'audio/pcm;rate=$inputSampleRate',
              'data': base64Encode(chunk),
            },
          },
        });
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
      final hasSpeech = bytesSent >= inputSampleRate;
      final silenceLongEnough =
          now.difference(lastVoiceAt) >= _silenceStopDuration;
      if (hasMinimumAudio && hasSpeech && silenceLongEnough) {
        if (!stopInput.isCompleted) stopInput.complete();
      }
    });

    await stopInput.future.timeout(_maxInputDuration, onTimeout: () {});
    await _stopMic();
    _sendJson({
      'realtimeInput': {'audioStreamEnd': true},
    });
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

  String _normalizeModelName(String model) {
    final trimmed = model.trim().isEmpty ? defaultModel : model.trim();
    return trimmed.startsWith('models/') ? trimmed : 'models/$trimmed';
  }

  String _readTranscription(Object? value) {
    if (value is Map) {
      final text = value['text'];
      return text is String ? text : '';
    }
    return '';
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int? _sampleRateFromMimeType(Object? mimeType) {
    if (mimeType is! String) return null;
    final match = RegExp(r'rate=(\d+)').firstMatch(mimeType);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
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
