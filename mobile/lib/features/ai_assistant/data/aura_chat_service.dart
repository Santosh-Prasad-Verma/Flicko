import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/models/music_model.dart';
import 'package:mobile/data/services/music_service.dart';
import 'package:mobile/features/voice/application/sonic_drip_notifier.dart';
import 'package:mobile/features/voice/domain/music_models.dart' as sonic;
import 'package:mobile/data/services/user_search_service.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/ai_assistant/data/aura_settings_provider.dart';
import 'package:mobile/features/ai_assistant/data/web_search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuraMessage {
  final String id;
  final String sender; // 'user' or 'aura'
  final String text;
  final DateTime timestamp;
  final bool isLiked;
  final bool isDisliked;
  final String? imageUrl; // For image generator output

  AuraMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isLiked = false,
    this.isDisliked = false,
    this.imageUrl,
  });

  AuraMessage copyWith({
    String? text,
    bool? isLiked,
    bool? isDisliked,
    String? imageUrl,
  }) {
    return AuraMessage(
      id: id,
      sender: sender,
      text: text ?? this.text,
      timestamp: timestamp,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isLiked': isLiked,
      'isDisliked': isDisliked,
      'imageUrl': imageUrl,
    };
  }

  factory AuraMessage.fromMap(Map<String, dynamic> map) {
    return AuraMessage(
      id: map['id'] ?? '',
      sender: map['sender'] ?? 'aura',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      isLiked: map['isLiked'] ?? false,
      isDisliked: map['isDisliked'] ?? false,
      imageUrl: map['imageUrl'],
    );
  }
}

class AuraSession {
  final String id;
  final String category; // 'Text Writer', 'Image Generator', 'Code Tutor'
  final String title;
  final List<AuraMessage> messages;
  final DateTime lastActive;

  AuraSession({
    required this.id,
    required this.category,
    required this.title,
    required this.messages,
    required this.lastActive,
  });

  AuraSession copyWith({
    String? title,
    List<AuraMessage>? messages,
    DateTime? lastActive,
  }) {
    return AuraSession(
      id: id,
      category: category,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'messages': messages.map((m) => m.toMap()).toList(),
      'lastActive': lastActive.toIso8601String(),
    };
  }

  factory AuraSession.fromMap(Map<String, dynamic> map) {
    return AuraSession(
      id: map['id'] ?? '',
      category: map['category'] ?? 'Text Writer',
      title: map['title'] ?? '',
      messages:
          (map['messages'] as List?)
              ?.map((m) => AuraMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      lastActive: map['lastActive'] != null
          ? DateTime.parse(map['lastActive'])
          : DateTime.now(),
    );
  }
}

class AuraRateLimiter {
  static final List<DateTime> _timestamps = [];
  static const int maxRequestsPerMinute = 20;
  static const Duration windowDuration = Duration(minutes: 1);

  static bool checkAndRecord() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > windowDuration);
    if (_timestamps.length >= maxRequestsPerMinute) {
      return false; // Exceeded rate limit
    }
    _timestamps.add(now);
    return true;
  }

  static int get remainingRequests {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > windowDuration);
    return (maxRequestsPerMinute - _timestamps.length).clamp(0, maxRequestsPerMinute);
  }
}

class AuraNotifier extends Notifier<List<AuraSession>> {
  @override
  List<AuraSession> build() {
    _loadSessions();
    return [];
  }

  static const String _apiKeyStorageKey = 'aura_gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_apiKeyStorageKey);
    if (storedKey != null && storedKey.trim().isNotEmpty) {
      return storedKey.trim();
    }
    final envKey = AppConfig.geminiApiKey.trim();
    return envKey.isEmpty ? null : envKey;
  }

  Future<void> saveApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_apiKeyStorageKey);
    } else {
      await prefs.setString(_apiKeyStorageKey, key);
    }
  }

  static const String _storageKey = 'flicko_aura_sessions';

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List decoded = jsonDecode(data);
        state = decoded.map((item) => AuraSession.fromMap(item)).toList()
          ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
      } else {
        // Pre-populate with mockup history
        state = [
          AuraSession(
            id: 'mock-1',
            category: 'Code Tutor',
            title: 'How to use Visual Studio',
            lastActive: DateTime.now().subtract(const Duration(hours: 2)),
            messages: [
              AuraMessage(
                id: 'm1-1',
                sender: 'user',
                text: 'How do I start a simple debug session in VS?',
                timestamp: DateTime.now().subtract(const Duration(hours: 2)),
              ),
              AuraMessage(
                id: 'm1-2',
                sender: 'aura',
                text:
                    'To start debugging in Visual Studio:\n1. Open your project.\n2. Set a breakpoint by clicking in the left margin next to the code line.\n3. Press **F5** or click the green Start Debugging play button in the toolbar.\n4. Use **F10** to step over, and **F11** to step into functions.',
                timestamp: DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ],
          ),
          AuraSession(
            id: 'mock-2',
            category: 'Text Writer',
            title: 'Healthy eating tips',
            lastActive: DateTime.now().subtract(const Duration(hours: 5)),
            messages: [
              AuraMessage(
                id: 'm2-1',
                sender: 'user',
                text:
                    'Describe to me the basic principles of healthy eating. Briefly, but with all the important aspects, please, also you can tell me a little more about the topic of sports and training',
                timestamp: DateTime.now().subtract(const Duration(hours: 5)),
              ),
              AuraMessage(
                id: 'm2-2',
                sender: 'aura',
                text:
                    'Basic principles of a healthy diet:\nBalance: Make sure your diet contains all the essential macro and micronutrients in the correct proportions: carbohydrates, proteins, fats, vitamins and minerals. It is important to maintain a balance of calories to meet your body\'s needs, but not to overeat.',
                timestamp: DateTime.now().subtract(const Duration(hours: 5)),
              ),
            ],
          ),
          AuraSession(
            id: 'mock-3',
            category: 'Image Generator',
            title: 'Dog in red plaid in house in winter',
            lastActive: DateTime.now().subtract(const Duration(days: 1)),
            messages: [
              AuraMessage(
                id: 'm3-1',
                sender: 'user',
                text: 'Dog in red plaid in house in winter',
                timestamp: DateTime.now().subtract(const Duration(days: 1)),
              ),
              AuraMessage(
                id: 'm3-2',
                sender: 'aura',
                text:
                    'Here is your generated image of a cozy dog in red plaid inside a warm cabin during a snowy winter day.',
                timestamp: DateTime.now().subtract(const Duration(days: 1)),
                imageUrl:
                    'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=800',
              ),
            ],
          ),
          AuraSession(
            id: 'mock-4',
            category: 'Text Writer',
            title: 'Best clothing combinations',
            lastActive: DateTime.now().subtract(const Duration(days: 2)),
            messages: [
              AuraMessage(
                id: 'm4-1',
                sender: 'user',
                text:
                    'What clothing items combine best for a smart casual summer look?',
                timestamp: DateTime.now().subtract(const Duration(days: 2)),
              ),
              AuraMessage(
                id: 'm4-2',
                sender: 'aura',
                text:
                    'For a perfect smart casual summer look:\n1. **Tops**: Light linen shirts (white, light blue, soft olive) or high-quality knit polos.\n2. **Bottoms**: Well-fitted chinos in beige, sand, or navy, or linen-blend trousers.\n3. **Footwear**: Leather loafers, clean white minimalist sneakers, or suede espadrilles.\n4. **Accessories**: A brown leather belt matching your loafers, and classic tortoiseshell sunglasses.',
                timestamp: DateTime.now().subtract(const Duration(days: 2)),
              ),
            ],
          ),
        ];
        _saveSessions();
      }
    } catch (_) {
      // SharedPreferences error fallback
    }
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(state.map((s) => s.toMap()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  Future<AuraSession> createNewSession(
    String category, {
    String? initialPrompt,
  }) async {
    final newId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final String initialTitle = initialPrompt != null
        ? (initialPrompt.length > 30
              ? '${initialPrompt.substring(0, 27)}...'
              : initialPrompt)
        : 'New $category Session';

    final newSession = AuraSession(
      id: newId,
      category: category,
      title: initialTitle,
      messages: [],
      lastActive: DateTime.now(),
    );

    state = [newSession, ...state];
    await _saveSessions();
    return newSession;
  }

  Future<void> clearHistory() async {
    state = [];
    await _saveSessions();
  }

  Future<void> deleteSession(String sessionId) async {
    state = state.where((s) => s.id != sessionId).toList();
    await _saveSessions();
  }

  Future<void> updateMessageFeedback(
    String sessionId,
    String messageId, {
    bool? like,
    bool? dislike,
  }) async {
    state = state.map((session) {
      if (session.id == sessionId) {
        final updatedMessages = session.messages.map((msg) {
          if (msg.id == messageId) {
            return msg.copyWith(
              isLiked: like ?? msg.isLiked,
              isDisliked: dislike ?? msg.isDisliked,
            );
          }
          return msg;
        }).toList();
        return session.copyWith(messages: updatedMessages);
      }
      return session;
    }).toList();
    await _saveSessions();
  }

  Future<void> sendMessage(String sessionId, String text) async {
    final userMsg = AuraMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    // Rate Limit Guard
    if (!AuraRateLimiter.checkAndRecord()) {
      final rateMsg = AuraMessage(
        id: 'msg_rate_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'aura',
        text: '⚠️ **Rate Limit Reached**: You are sending messages too quickly. Please wait a moment before sending another message. (Limit: ${AuraRateLimiter.maxRequestsPerMinute} reqs/min).',
        timestamp: DateTime.now(),
      );
      state = state.map((session) {
        if (session.id == sessionId) {
          return session.copyWith(
            messages: [...session.messages, userMsg, rateMsg],
            lastActive: DateTime.now(),
          );
        }
        return session;
      }).toList();
      await _saveSessions();
      return;
    }

    // Add user message immediately
    state = state.map((session) {
      if (session.id == sessionId) {
        final updatedTitle = session.messages.isEmpty
            ? (text.length > 30 ? '${text.substring(0, 27)}...' : text)
            : session.title;
        return session.copyWith(
          title: updatedTitle,
          messages: [...session.messages, userMsg],
          lastActive: DateTime.now(),
        );
      }
      return session;
    }).toList();
    await _saveSessions();

    // Trigger thinking delay
    await Future.delayed(const Duration(milliseconds: 800));

    final activeSession = state.firstWhere((s) => s.id == sessionId);
    final String category = activeSession.category;

    String responseText = '';
    String? imageUrl;

    bool liveSuccess = false;

    // 1. Try local command parsing first for quick execution
    String? localCommandResponse;
    final lowerText = text.trim().toLowerCase();

    if (lowerText.startsWith('play ') || lowerText.startsWith('queue ')) {
      final query = text.substring(text.indexOf(' ') + 1).trim();
      localCommandResponse = await _executeTool('play_song', {'query': query});
    } else if (lowerText.startsWith('message ') ||
        lowerText.startsWith('msg ') ||
        lowerText.startsWith('text ')) {
      final firstSpace = text.indexOf(' ');
      final colon = text.indexOf(':');
      if (firstSpace != -1) {
        if (colon > firstSpace) {
          final username = text.substring(firstSpace + 1, colon).trim();
          final msg = text.substring(colon + 1).trim();
          localCommandResponse = await _executeTool('send_dm', {
            'recipientUsername': username,
            'message': msg,
          });
        } else {
          final rest = text.substring(firstSpace + 1).trim();
          final firstInnerSpace = rest.indexOf(' ');
          if (firstInnerSpace != -1) {
            final username = rest.substring(0, firstInnerSpace).trim();
            final msg = rest.substring(firstInnerSpace + 1).trim();
            localCommandResponse = await _executeTool('send_dm', {
              'recipientUsername': username,
              'message': msg,
            });
          }
        }
      }
    } else if (lowerText == 'list servers' ||
        lowerText == 'show servers' ||
        lowerText == 'my servers' ||
        lowerText.contains('list my servers')) {
      localCommandResponse = await _executeTool('list_servers', {});
    } else if (lowerText.startsWith('search ') ||
        lowerText.startsWith('google ') ||
        lowerText.startsWith('lookup ') ||
        lowerText.startsWith('web search ')) {
      final query = text.replaceAll(RegExp(r'^(search|google|lookup|web search)\s+', caseSensitive: false), '').trim();
      localCommandResponse = await _executeTool('web_search', {'query': query});
    }

    if (localCommandResponse != null) {
      responseText = localCommandResponse;
      liveSuccess = true;
    }

    // 2. Call Aura Edge Function (xAI Grok API, key stays server-side)
    if (!liveSuccess) {
      try {
        final supabaseUrl = AppConfig.supabaseUrl;
        final dio = Dio();

        // Get the current Supabase auth token
        final accessToken = supabase.Supabase.instance.client.auth.currentSession?.accessToken;

        // Build conversation history for context
        final conversationMessages = <Map<String, String>>[];
        for (final msg in activeSession.messages) {
          conversationMessages.add({
            'role': msg.sender == 'user' ? 'user' : 'assistant',
            'content': msg.text,
          });
        }

        final settings = ref.read(auraSettingsProvider);
        final language = settings.language;
        final temperature = settings.temperature;

        final response = await dio.post(
          '$supabaseUrl/functions/v1/aura-chat',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              if (accessToken != null)
                'Authorization': 'Bearer $accessToken',
              'apikey': AppConfig.supabaseAnonKey,
            },
          ),
          data: {
            'messages': conversationMessages,
            'category': category,
            'language': language,
            'temperature': temperature,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;

          // Check for function call from Grok
          if (data['functionCall'] != null) {
            final fc = data['functionCall'];
            final name = fc['name'] as String;
            final args = Map<String, dynamic>.from(fc['args'] ?? {});
            responseText = await _executeTool(name, args);
            liveSuccess = true;
          } else if (data['text'] != null &&
              (data['text'] as String).isNotEmpty) {
            responseText = data['text'];
            liveSuccess = true;
          }
        }
      } catch (e) {
        // Edge function call failed, fall through to Gemini fallback
      }
    }

    // 3. Gemini fallback — if primary model failed, try Google Gemini
    if (!liveSuccess) {
      try {
        final geminiKey = await getApiKey();
        if (geminiKey != null && geminiKey.isNotEmpty) {
          final dio = Dio();
          final geminiModel = AppConfig.geminiTextModel.isNotEmpty
              ? AppConfig.geminiTextModel
              : 'gemini-2.0-flash';

          // Build Gemini-compatible messages
          final geminiContents = <Map<String, dynamic>>[];
          for (final msg in activeSession.messages) {
            geminiContents.add({
              'role': msg.sender == 'user' ? 'user' : 'model',
              'parts': [{'text': msg.text}],
            });
          }

          final settings = ref.read(auraSettingsProvider);
          final language = settings.language;
          final temperature = settings.temperature;

          final geminiResponse = await dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$geminiKey',
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: {
              'contents': geminiContents,
              'systemInstruction': {
                'parts': [
                  {
                    'text': 'You are Aura AI. Please respond in the user\'s selected language: $language.'
                  }
                ]
              },
              'generationConfig': {
                'temperature': temperature,
                'maxOutputTokens': 2048,
              },
            },
          );

          if (geminiResponse.statusCode == 200 && geminiResponse.data != null) {
            final candidates = geminiResponse.data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final geminiText = parts[0]['text'] as String?;
                if (geminiText != null && geminiText.isNotEmpty) {
                  responseText = geminiText;
                  liveSuccess = true;
                }
              }
            }
          }
        }
      } catch (e) {
        // Gemini fallback also failed, fall through to mock
      }
    }

    // 4. Fallback to simulated response if all live APIs failed
    if (!liveSuccess) {
      if (category == 'Image Generator') {
        responseText = 'Generated an image representing "$text".';
        imageUrl = _generateImageMockUrl(text);
      } else if (category == 'Code Tutor') {
        responseText = _generateCodeResponse(text);
      } else {
        responseText = generateTextResponse(text);
      }
    }

    final auraMsg = AuraMessage(
      id: 'msg_aura_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'aura',
      text: responseText,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );

    state = state.map((session) {
      if (session.id == sessionId) {
        return session.copyWith(
          messages: [...session.messages, auraMsg],
          lastActive: DateTime.now(),
        );
      }
      return session;
    }).toList();
    await _saveSessions();
  }

  String generateTextResponse(String prompt) {
    final lower = prompt.toLowerCase().trim();

    // Greetings / Hellos
    if (lower == 'hello' ||
        lower == 'hi' ||
        lower == 'hey' ||
        lower.startsWith('hello ') ||
        lower.startsWith('hi ')) {
      final greetings = [
        "Hello! I'm Aura, your AI voice companion. It's wonderful to talk to you today. How can I help you?",
        "Hi there! Aura here, ready to assist. What's on your mind today?",
        "Hey! Great to connect with you. I'm here to chat, answer questions, or just keep you company. How can I help you?",
      ];
      // Deterministic choice based on time
      return greetings[DateTime.now().millisecond % greetings.length];
    }

    // Jokes / Humor
    if (lower.contains('joke') || lower.contains('clever')) {
      final jokes = [
        "Why do programmers wear glasses? Because they can't C#!",
        "How many programmers does it take to change a light bulb? None, that's a hardware problem!",
        "There are 10 types of people in the world: those who understand binary, and those who don't.",
        "Why did the database administrator leave his wife? She had one-to-many relationships!",
      ];
      return jokes[DateTime.now().millisecond % jokes.length];
    }

    // Data Engineering
    if (lower.contains('data engineering') || lower.contains('data engineer')) {
      return "Data engineering is the practice of designing and building systems for collecting, storing, and analyzing data at scale. It focuses on clean pipelines, schemas, and robust storage rather than visual design.";
    }

    // Glassmorphism / UI Design
    if (lower.contains('glassmorphism') ||
        lower.contains('design') ||
        lower.contains('ui')) {
      return "Glassmorphism is a popular design trend characterized by translucent, frosted-glass-like elements. It uses subtle borders, background blurs, and vibrant multi-colored radial background glows to create an immersive, futuristic cybernetic look.";
    }

    // Healthy eating & habits
    if (lower.contains('healthy') ||
        lower.contains('eat') ||
        lower.contains('food') ||
        lower.contains('habit')) {
      return "Basic principles of a healthy diet:\n\n"
          "• **Balance**: Make sure your diet contains all the essential macro and micronutrients in the correct proportions: carbohydrates, proteins, fats, vitamins and minerals.\n"
          "• **Hydration**: Drink at least 2-3 liters of water daily to maintain cognitive and metabolic performance.\n"
          "• **Caloric Intake**: Match your active metabolic output to avoid fat storage or muscle degradation.\n"
          "• **Sports Connection**: Consume complex carbs 2 hours before training for explosive energy, and premium protein sources within 45 mins post-workout to maximize muscle fiber repair.";
    }

    // Flutter / coding
    if (lower.contains('flutter') ||
        lower.contains('widget') ||
        lower.contains('dart')) {
      return "Flutter is Google's portable UI toolkit for crafting beautiful, natively compiled applications for mobile, web, and desktop from a single codebase. It uses the Dart programming language and provides high-performance rendering.";
    }

    // Music
    if (lower.contains('music') ||
        lower.contains('song') ||
        lower.contains('play')) {
      return "Music is the art of arranging sounds in time to produce a composition through the elements of melody, harmony, rhythm, and timbre. I can play songs for you if you tell me what to play!";
    }

    // General fallback that repeats some user context
    final genericResponses = [
      "I hear you! That's a really interesting point. Could you tell me more about what you mean by '$prompt'?",
      "That's a fascinating question about '$prompt'. While I'm in simulated fallback mode right now, I'd say the key is to look at it from a structural perspective.",
      "Aura here! I'm interested in hearing more of your thoughts on '$prompt'. Let's explore that topic further!",
      "I completely understand. If we look deeper into '$prompt', we can find some really interesting patterns. What specific aspect would you like to focus on?",
    ];
    return genericResponses[lower.length % genericResponses.length];
  }

  String _generateCodeResponse(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('flutter') ||
        lower.contains('widget') ||
        lower.contains('custom')) {
      return 'Here is a custom premium Glassmorphic card widget in Flutter:\n\n'
          '```dart\n'
          'import \'dart:ui\';\n'
          'import \'package\':flutter/material.dart;\n\n'
          'class GlassCard extends StatelessWidget {\n'
          '  final Widget child;\n'
          '  const GlassCard({super.key, required this.child});\n\n'
          '  @override\n'
          '  Widget build(BuildContext context) {\n'
          '    return ClipRRect(\n'
          '      borderRadius: BorderRadius.circular(16),\n'
          '      child: BackdropFilter(\n'
          '        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),\n'
          '        child: Container(\n'
          '          padding: const EdgeInsets.all(16),\n'
          '          decoration: BoxDecoration(\n'
          '            color: Colors.white.withOpacity(0.05),\n'
          '            border: Border.all(\n'
          '              color: Colors.white.withOpacity(0.1),\n'
          '              width: 1.5,\n'
          '            ),\n'
          '            borderRadius: BorderRadius.circular(16),\n'
          '          ),\n'
          '          child: child,\n'
          '        ),\n'
          '      ),\n'
          '    );\n'
          '  }\n'
          '}\n'
          '```\n\n'
          'This uses `BackdropFilter` combined with transparent borders for a beautiful cybernetic look.';
    } else if (lower.contains('animation') ||
        lower.contains('3d') ||
        lower.contains('sphere')) {
      return 'To draw a custom 3D projected spherical wireframe, you can write a `CustomPainter` like this:\n\n'
          '```dart\n'
          'class Sphere3DPainter extends CustomPainter {\n'
          '  final double rotationX;\n'
          '  final double rotationY;\n'
          '  \n'
          '  Sphere3DPainter(this.rotationX, this.rotationY);\n'
          '  \n'
          '  @override\n'
          '  void paint(Canvas canvas, Size size) {\n'
          '    final paint = Paint()\n'
          '      ..color = const Color(0xFFFF007F)\n'
          '      ..style = PaintingStyle.stroke\n'
          '      ..strokeWidth = 1.0;\n'
          '    // Loop over latitude and longitude coordinates...\n'
          '  }\n'
          '  \n'
          '  @override\n'
          '  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;\n'
          '}\n'
          '```\n\n'
          'I can help you build the full mathematical projection system if you need it!';
    }
    return 'Here is a general solution to structure your logic cleanly:\n\n'
        '```dart\n'
        '// Safe execution wrapper for AI computations\n'
        'Future<T> runAuraTask<T>(Future<T> Function() task) async {\n'
        '  try {\n'
        '    return await task();\n'
        '  } catch (e, stack) {\n'
        '    print("Aura Compute Exception: \$e");\n'
        '    print(stack);\n'
        '    rethrow;\n'
        '  }\n'
        '}\n'
        '```\n\n'
        'Would you like me to write tests or adapt this to a specific design pattern?';
  }

  Future<String> _executeTool(String name, Map<String, dynamic> args) async {
    if (name == 'play_song') {
      final query = args['query'] as String? ?? '';
      if (query.isEmpty) return 'No song name provided.';

      try {
        final musicService = ref.read(musicServiceProvider);
        final results = await musicService.searchMusic(
          query: query,
          type: MusicType.track,
        );
        if (results.isEmpty) {
          return 'No matching songs found on Sonic Drip for "$query".';
        }
        final bestMatch = results.first;
        // Route through the live Sonic Drip notifier so audio actually plays.
        final sonicTrack = sonic.Track(
          id: bestMatch.id,
          name: bestMatch.name,
          artistName: bestMatch.artistName,
          albumName: bestMatch.albumName,
          durationMs: bestMatch.durationMs,
          imageUrl: bestMatch.imageUrl,
          previewUrl: bestMatch.previewUrl,
          externalUrl: bestMatch.externalUrl,
          source: bestMatch.source,
        );
        await ref.read(sonicDripProvider.notifier).playDripBash(sonicTrack);
        return '🎵 Started playing **${bestMatch.name}** by **${bestMatch.artistName}** on Sonic Drip!';
      } catch (e) {
        return 'Error playing song: $e';
      }
    } else if (name == 'send_dm') {
      final recipientUsername =
          args['recipientUsername'] as String? ??
          args['recipientName'] as String? ??
          '';
      final message = args['message'] as String? ?? '';

      if (recipientUsername.isEmpty || message.isEmpty) {
        return 'Recipient username or message is empty.';
      }

      try {
        final searchService = ref.read(userSearchServiceProvider);
        final matches = await searchService.searchUsers(recipientUsername);
        if (matches.isEmpty) {
          return 'Could not find a user matching "$recipientUsername" in contacts.';
        }
        final match = matches.first;

        final authState = ref.read(authNotifierProvider);
        final myId = authState.maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => '',
        );

        if (myId.isEmpty) {
          return 'You must be logged in to send DMs.';
        }

        await ref
            .read(dmRepositoryProvider)
            .sendMessage(
              senderId: myId,
              recipientId: match.id,
              content: message,
            );
        return '💬 Direct message sent to **@${match.username}**: "$message"';
      } catch (e) {
        return 'Failed to send message: $e';
      }
    } else if (name == 'list_servers') {
      try {
        final serversState = ref.read(serversNotifierProvider);
        final servers = serversState.servers;
        if (servers.isEmpty) {
          return 'You are not currently joined to any servers.';
        }
        final list = servers.map((s) => '• **${s.name}**').join('\n');
        return '🌐 Here are the servers you are currently active in:\n\n$list';
      } catch (e) {
        return 'Error listing servers: $e';
      }
    } else if (name == 'web_search' || name == 'search_web') {
      final query = args['query'] as String? ?? args['q'] as String? ?? '';
      if (query.isEmpty) return 'No search query specified.';
      try {
        final searchService = ref.read(auraWebSearchServiceProvider);
        final result = await searchService.search(query);
        if (result == null || !result.hasResults) {
          return 'No live web search results found for "$query".';
        }
        return '🌐 **Web Search Results via ${result.provider}**:\n\n${result.summary.isNotEmpty ? result.summary : result.voiceSummary}';
      } catch (e) {
        return 'Web search failed: $e';
      }
    }
    return 'Unknown tool: $name';
  }

  String _generateImageMockUrl(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('dog') || lower.contains('puppy')) {
      return 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=800';
    } else if (lower.contains('car') || lower.contains('cyber')) {
      return 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&q=80&w=800';
    } else if (lower.contains('mountain') ||
        lower.contains('nature') ||
        lower.contains('winter')) {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&q=80&w=800';
    } else if (lower.contains('music') ||
        lower.contains('concert') ||
        lower.contains('neon')) {
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&q=80&w=800';
    }
    // Default placeholder abstract aesthetic
    return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=800';
  }
}

final auraSessionsProvider = NotifierProvider<AuraNotifier, List<AuraSession>>(
  AuraNotifier.new,
);
