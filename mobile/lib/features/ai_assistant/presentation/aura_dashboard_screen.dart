import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class AuraDashboardScreen extends ConsumerStatefulWidget {
  const AuraDashboardScreen({super.key});

  @override
  ConsumerState<AuraDashboardScreen> createState() => _AuraDashboardScreenState();
}

class _AuraDashboardScreenState extends ConsumerState<AuraDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _bgBlack = Color(0xFF000000);
  static const Color _cardGrey = Color(0xFF111115);
  static const Color _borderGrey = Color(0xFF222228);
  static const Color _accentPink = Color(0xFFFF007F);
  static const Color _accentPurple = Color(0xFF8B00FF);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF8E8E93);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final notifier = ref.read(auraSessionsProvider.notifier);
    final currentKey = await notifier.getApiKey();
    final defaultKey = 'AIzaSyDhEKT-KK1COPAeRzy_ggDgHXwujIbtH64';
    final isCustom = currentKey != null && currentKey != defaultKey;

    final controller = TextEditingController(text: isCustom ? currentKey : '');
    bool obscureText = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF13101C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.08),
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
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Provide your own Gemini API key to activate live responses. If left empty, a shared default key is used.',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        obscureText: obscureText,
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter API Key...',
                          hintStyle: GoogleFonts.spaceMono(
                            color: Colors.white.withOpacity(0.3),
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
                              color: Colors.white.withOpacity(0.6),
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
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC0EC54),
                            foregroundColor: const Color(0xFF07040A),
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
                            await notifier.saveApiKey(newKey.isEmpty ? null : newKey);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newKey.isEmpty
                                        ? 'Using default shared Gemini API key.'
                                        : 'Gemini API key updated successfully!',
                                  ),
                                  backgroundColor: const Color(0xFF13101C),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Save',
                            style: GoogleFonts.spaceGrotesk(
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

  Widget _buildTopRow(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final String displayName = authState.maybeWhen(
      authenticated: (authUser, userProfile) {
        if (userProfile != null && userProfile.displayName != null && userProfile.displayName!.isNotEmpty) {
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
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          ),
        ),
        Row(
          children: [
            Text(
              'Hi, $displayName',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Text('👋', style: TextStyle(fontSize: 14)),
          ],
        ),
        GestureDetector(
          onTap: () => _showApiKeyDialog(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
            child: const Icon(Icons.key_rounded, color: Color(0xFFC0EC54), size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeading() {
    return Text(
      'How may I help\nyou today?',
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1);
  }

  Widget _buildBentoGrid() {
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
                color: const Color(0xFFC0EC54),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC0EC54).withOpacity(0.15),
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
                          color: Colors.black.withOpacity(0.06),
                        ),
                        child: const Icon(Icons.mic_none_rounded, color: Color(0xFF07040A), size: 22),
                      ),
                      const Icon(Icons.arrow_outward_rounded, color: Color(0xFF07040A), size: 20),
                    ],
                  ),
                  Text(
                    'Talk\nwith Bot',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF07040A),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
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
                  final session = await ref.read(auraSessionsProvider.notifier).createNewSession('Chat');
                  if (mounted) {
                    context.push('/profile/settings/aura/chat?category=Chat&sessionId=${session.id}');
                  }
                },
                child: Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13101C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFCBB6FC), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Chat with Bot',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_outward_rounded, color: Colors.white.withOpacity(0.4), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bottom: Cyber Brain Graphic Card
              Container(
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF13101C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.2),
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
                              return const LinearGradient(
                                colors: [Color(0xFFCBB6FC), Color(0xFFFFD1B3), Color(0xFFBFF6EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            child: CustomPaint(
                              painter: BrainWavePainter(),
                            ),
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
                              color: Colors.white.withOpacity(0.4),
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

  Widget _buildHistoryItem(AuraSession session) {
    final Map<String, Color> bulletColors = {
      'Text Writer': const Color(0xFFCBB6FC),
      'Image Generator': const Color(0xFFFFD1B3),
      'Code Tutor': const Color(0xFFC0EC54),
      'Chat': const Color(0xFFCBB6FC),
    };
    final dotColor = bulletColors[session.category] ?? const Color(0xFFCBB6FC);

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      onDismissed: (direction) {
        ref.read(auraSessionsProvider.notifier).deleteSession(session.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session "${session.title}" deleted.'),
            backgroundColor: const Color(0xFF13101C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13101C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.2),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onTap: () {
            context.push('/profile/settings/aura/chat?category=${session.category}&sessionId=${session.id}');
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
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.9),
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
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<AuraSession> filteredSessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (filteredSessions.isNotEmpty)
              GestureDetector(
                onTap: () {
                  ref.read(auraSessionsProvider.notifier).clearHistory();
                },
                child: Text(
                  'Clear all',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withOpacity(0.4),
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
                const Icon(Icons.history_toggle_off_rounded, color: Colors.white30, size: 36),
                const SizedBox(height: 12),
                Text(
                  'No search results or history',
                  style: GoogleFonts.spaceMono(color: Colors.white30, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(filteredSessions.length, 5),
            itemBuilder: (context, index) {
              final session = filteredSessions[index];
              return _buildHistoryItem(session);
            },
          ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(auraSessionsProvider);
    
    final filteredSessions = sessions.where((session) {
      final query = _searchQuery.toLowerCase();
      return session.title.toLowerCase().contains(query) ||
          session.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF07040A),
      body: Stack(
        children: [
          // Cybernetic magenta-purple soft radial glow in the background
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF381559).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
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
                    _buildTopRow(context),
                    const SizedBox(height: 32),
                    _buildWelcomeHeading(),
                    const SizedBox(height: 24),
                    _buildBentoGrid(),
                    const SizedBox(height: 36),
                    _buildHistorySection(filteredSessions),
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.cubicTo(
      size.width * 0.25, size.height * 0.1,
      size.width * 0.5, size.height * 0.9,
      size.width * 0.75, size.height * 0.3,
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.1,
      size.width * 0.95, size.height * 0.6,
      size.width, size.height * 0.4,
    );

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.cubicTo(
      size.width * 0.3, size.height * 0.3,
      size.width * 0.55, size.height * 0.8,
      size.width * 0.8, size.height * 0.2,
    );
    path2.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 3, paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.3), 2, paint);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.4), 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
