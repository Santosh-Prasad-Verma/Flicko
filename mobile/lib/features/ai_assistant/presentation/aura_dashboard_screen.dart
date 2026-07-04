import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';
import 'package:mobile/features/ai_assistant/data/aura_settings_provider.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class AuraDashboardScreen extends ConsumerStatefulWidget {
  const AuraDashboardScreen({super.key});

  @override
  ConsumerState<AuraDashboardScreen> createState() =>
      _AuraDashboardScreenState();
}

class _AuraDashboardScreenState extends ConsumerState<AuraDashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  late AnimationController _bgAnimationController;

  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get _textMuted => Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF8E8E9F);
  Color get _borderColor => Theme.of(context).dividerColor;
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showApiKeyDialog(BuildContext context, Color accent) async {
    final notifier = ref.read(auraSessionsProvider.notifier);
    final currentKey = await notifier.getApiKey();
    final envKey = AppConfig.geminiApiKey.trim();
    final isLocalOverride = currentKey != null && currentKey != envKey;

    final controller = TextEditingController(
      text: isLocalOverride ? currentKey : '',
    );
    bool obscureText = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: _textColor.withOpacity(0.07),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini API Key',
                      style: GoogleFonts.inter(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      envKey.isNotEmpty
                          ? 'A runtime Gemini key is configured. Add a key here only if you want to override it on this device.'
                          : 'Provide a Gemini API key to activate live text and native-audio voice responses.',
                      style: GoogleFonts.inter(
                        color: _textColor.withOpacity(0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: _textColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _textColor.withOpacity(0.07),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        obscureText: obscureText,
                        style: GoogleFonts.spaceMono(
                          color: _textColor,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter API Key...',
                          hintStyle: GoogleFonts.spaceMono(
                            color: _textColor.withOpacity(0.3),
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _textColor.withOpacity(0.6),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                obscureText = !obscureText;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: _textColor.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final newKey = controller.text.trim();
                            await notifier.saveApiKey(
                              newKey.isEmpty ? null : newKey,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newKey.isEmpty
                                        ? (envKey.isNotEmpty
                                              ? 'Using configured environment Gemini API key.'
                                              : 'Gemini API key cleared. Aura Live needs a key to answer online.')
                                        : 'Gemini API key updated successfully!',
                                  ),
                                  backgroundColor: _cardBg,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Save',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopRow(BuildContext context, Color accent) {
    final authState = ref.watch(authNotifierProvider);
    final String displayName = authState.maybeWhen(
      authenticated: (authUser, userProfile) {
        if (userProfile != null &&
            userProfile.displayName != null &&
            userProfile.displayName!.isNotEmpty) {
          return userProfile.displayName!;
        }
        if (userProfile != null) {
          return userProfile.username;
        }
        final meta = authUser.userMetadata;
        if (meta != null && meta.containsKey('display_name')) {
          return meta['display_name'] as String;
        }
        if (meta != null && meta.containsKey('username')) {
          return meta['username'] as String;
        }
        if (authUser.email != null) {
          return authUser.email!.split('@').first;
        }
        return 'Buddy';
      },
      orElse: () => 'Buddy',
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/profile/settings');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _textColor.withOpacity(0.03),
              border: Border.all(
                color: _textColor.withOpacity(0.07),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textColor,
              size: 16,
            ),
          ),
        ),
        Row(
          children: [
            Text(
              'Hi, $displayName',
              style: GoogleFonts.inter(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Text('👋', style: TextStyle(fontSize: 14)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showApiKeyDialog(context, accent),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _textColor.withOpacity(0.03),
                  border: Border.all(
                    color: _textColor.withOpacity(0.07),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.key_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/profile/settings/aura/settings');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _textColor.withOpacity(0.03),
                  border: Border.all(
                    color: _textColor.withOpacity(0.07),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  color: _textColor,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroHeader(Color accent) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How may I help\nyou today?',
                style: GoogleFonts.inter(
                  color: _textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AURA AI assistant is ready to chat or speak with you.',
                style: GoogleFonts.inter(
                  color: _textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _textColor.withOpacity(0.03),
            border: Border.all(
              color: accent.withOpacity(0.15),
              width: 1.2,
            ),
          ),
          child: Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/happy-robot-assistant.png',
                width: 70,
                height: 70,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1);
  }

  Widget _buildBentoGrid(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Talk with Bot
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: () => context.push('/profile/settings/aura/voice'),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent,
                    const Color(0xFF5931CC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        child: const Icon(
                          Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  Text(
                    'Talk\nwith Bot',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Right Column: Chat with Bot & Brain card
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Top: Chat with Bot Card
              GestureDetector(
                onTap: () async {
                  final session = await ref
                      .read(auraSessionsProvider.notifier)
                      .createNewSession('Chat');
                  if (mounted) {
                    context.push(
                      '/profile/settings/aura/chat?category=Chat&sessionId=${session.id}',
                    );
                  }
                },
                child: Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _textColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _textColor.withOpacity(0.07),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _textColor.withOpacity(0.04),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Chat with Bot',
                              style: GoogleFonts.inter(
                                color: _textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: _textColor.withOpacity(0.4),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bottom: Cyber Brain Graphic Card
              Container(
                height: 84,
                decoration: BoxDecoration(
                  color: _textColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _textColor.withOpacity(0.07),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.65,
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  accent,
                                  const Color(0xFF00F0FF),
                                  const Color(0xFFFF00F5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            child: CustomPaint(painter: BrainWavePainter(color: _textColor.withOpacity(0.3))),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            'AURA ENGINE v2.5',
                            style: GoogleFonts.spaceMono(
                              color: _textColor.withOpacity(0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildHistoryItem(AuraSession session, Color accent) {
    final Map<String, Color> bulletColors = {
      'Text Writer': const Color(0xFFFF00F5),
      'Image Generator': const Color(0xFFFF00F5),
      'Code Tutor': const Color(0xFF00F0FF),
      'Chat': accent,
    };
    final dotColor = bulletColors[session.category] ?? accent;

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
        ),
      ),
      onDismissed: (direction) {
        ref.read(auraSessionsProvider.notifier).deleteSession(session.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session "${session.title}" deleted.'),
            backgroundColor: _cardBg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _textColor.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor.withOpacity(0.15), width: 1.2),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onTap: () {
            context.push(
              '/profile/settings/aura/chat?category=${session.category}&sessionId=${session.id}',
            );
          },
          leading: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          title: Text(
            session.title,
            style: GoogleFonts.inter(
              color: _textColor.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: GestureDetector(
            onTap: () {
              ref.read(auraSessionsProvider.notifier).deleteSession(session.id);
            },
            child: Icon(
              Icons.more_vert_rounded,
              color: _textColor.withOpacity(0.3),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<AuraSession> filteredSessions, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: GoogleFonts.inter(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (filteredSessions.isNotEmpty)
              GestureDetector(
                onTap: () {
                  ref.read(auraSessionsProvider.notifier).clearHistory();
                },
                child: Text(
                  'Clear all',
                  style: GoogleFonts.inter(
                    color: _textColor.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredSessions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  color: _textColor.withOpacity(0.3),
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'No search results or history',
                  style: GoogleFonts.inter(
                    color: _textColor.withOpacity(0.3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: math.min(filteredSessions.length, 5),
            itemBuilder: (context, index) {
              final session = filteredSessions[index];
              return _buildHistoryItem(session, accent);
            },
          ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(auraSettingsProvider);
    final rawAccent = settings.accentColor;
    final accent = rawAccent == Colors.transparent ? Theme.of(context).primaryColor : rawAccent;
    final sessions = ref.watch(auraSessionsProvider);

    final filteredSessions = sessions.where((session) {
      final query = _searchQuery.toLowerCase();
      return session.title.toLowerCase().contains(query) ||
          session.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: DeepSpaceBackgroundPainter(
                    animationValue: _bgAnimationController.value,
                    accentColor: accent,
                    isLight: _isLight,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(context, accent),
                    const SizedBox(height: 32),
                    _buildHeroHeader(accent),
                    const SizedBox(height: 24),
                    _buildBentoGrid(accent),
                    const SizedBox(height: 36),
                    _buildHistorySection(filteredSessions, accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrainWavePainter extends CustomPainter {
  final Color color;
  BrainWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.1,
      size.width * 0.5,
      size.height * 0.9,
      size.width * 0.75,
      size.height * 0.3,
    );
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.1,
      size.width * 0.95,
      size.height * 0.6,
      size.width,
      size.height * 0.4,
    );

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.cubicTo(
      size.width * 0.3,
      size.height * 0.3,
      size.width * 0.55,
      size.height * 0.8,
      size.width * 0.8,
      size.height * 0.2,
    );
    path2.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      3,
      paint..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.3), 2, paint);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.4), 2, paint);
  }

  @override
  bool shouldRepaint(covariant BrainWavePainter oldDelegate) => oldDelegate.color != color;
}

class DeepSpaceBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;
  final bool isLight;

  DeepSpaceBackgroundPainter({
    required this.animationValue,
    required this.accentColor,
    this.isLight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double nebula1Opacity = isLight ? 0.07 : 0.25;
    final double nebula2Opacity = isLight ? 0.04 : 0.12;

    // Overlapping radial gradients (Nebulas)
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(nebula1Opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.3), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), size.width * 0.8, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(nebula2Opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.7), radius: size.width * 0.7));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), size.width * 0.7, paint2);
  }

  @override
  bool shouldRepaint(covariant DeepSpaceBackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isLight != isLight;
}
