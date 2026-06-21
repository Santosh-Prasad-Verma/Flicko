import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/features/ai_assistant/data/aura_settings_provider.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_sandbox_screen.dart';
import 'package:mobile/features/ai_assistant/presentation/aura_image_viewer_screen.dart';

class AuraChatScreen extends ConsumerStatefulWidget {
  final String category;
  final String? sessionId;

  const AuraChatScreen({
    super.key,
    required this.category,
    this.sessionId,
  });

  @override
  ConsumerState<AuraChatScreen> createState() => _AuraChatScreenState();
}

class _AuraChatScreenState extends ConsumerState<AuraChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentSessionId;
  bool _isTyping = false;
  
  // Track which message is currently simulating TTS speaking
  String? _speakingMessageId;

  static const Color _bgBlack = Color(0xFF06060E);
  static const Color _cardGrey = Color(0xFF0D0D1A);
  static const Color _borderGrey = Color(0xFF1C1C24);
  static const Color _accentPink = Color(0xFFFF00F5);
  Color get _accentPurple => ref.watch(auraSettingsProvider).accentColor;
  static const Color _textWhite = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF8E8E9F);

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _isTyping = true;
    });

    // Create session if it doesn't exist
    if (_currentSessionId == null) {
      final session = await ref.read(auraSessionsProvider.notifier).createNewSession(
        widget.category,
        initialPrompt: text,
      );
      _currentSessionId = session.id;
    }

    // Scroll to show user message + typing indicator
    _scrollToBottom();
    // Also schedule a second scroll after a brief delay for layout settling
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _scrollToBottom();
    });

    // Send message to provider
    await ref.read(auraSessionsProvider.notifier).sendMessage(_currentSessionId!, text);

    if (mounted) {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
      // Ensure scroll after the response bubble is rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

  // Simulate text-to-speech read out
  void _toggleSpeak(String messageId, String text) {
    if (_speakingMessageId == messageId) {
      setState(() {
        _speakingMessageId = null;
      });
    } else {
      setState(() {
        _speakingMessageId = messageId;
      });

      // Stop speaking automatically after a duration based on text length
      final durationMs = (text.length * 60).clamp(2000, 8000);
      Future.delayed(Duration(milliseconds: durationMs), () {
        if (mounted && _speakingMessageId == messageId) {
          setState(() {
            _speakingMessageId = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(auraSessionsProvider);
    final AuraSession? activeSession = _currentSessionId != null
        ? sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => AuraSession(id: '', category: widget.category, title: '', messages: [], lastActive: DateTime.now()))
        : null;

    final messages = activeSession?.messages ?? [];
    final categoryColors = {
      'Text Writer': _accentPink,
      'Image Generator': _accentPurple,
      'Code Tutor': const Color(0xFF00FFCC),
    };
    final accent = categoryColors[widget.category] ?? _accentPink;

    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: _buildAppBar(context, activeSession?.title ?? 'New Conversation', accent),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DeepSpaceBackgroundPainter(
                animationValue: 0.0,
                accentColor: ref.watch(auraSettingsProvider).accentColor,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyState(accent)
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              return _buildTypingIndicator(accent);
                            }
                            final msg = messages[index];
                            return _buildMessageRow(msg, accent);
                          },
                        ),
                ),
                _buildInputBar(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title, Color accent) {
    return AppBar(
      backgroundColor: _bgBlack,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.category.toUpperCase(),
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _textWhite.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: const [],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _borderGrey, height: 1),
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.15), width: 2),
              ),
              child: Icon(
                widget.category == 'Text Writer'
                    ? Icons.edit_note_rounded
                    : widget.category == 'Image Generator'
                        ? Icons.image_search_rounded
                        : Icons.code_rounded,
                color: accent,
                size: 48,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'How can I help you today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textWhite,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start chatting with Aura to generate texts, create code blocks, or visualize concepts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(AuraMessage msg, Color accent) {
    final isUser = msg.sender == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAuraAvatar(accent),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageBubble(msg, isUser, accent),
                if (!isUser) ...[
                  const SizedBox(height: 8),
                  _buildMessageActionBar(msg, accent),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildAuraAvatar(Color accent) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.03),
        border: Border.all(
          color: accent.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.blur_on_rounded, color: accent, size: 18),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 1.2,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildMessageBubble(AuraMessage msg, bool isUser, Color accent) {
    if (isUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7B4FFF),
              Color(0xFF5931CC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imageUrl != null) ...[
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AuraImageViewerScreen(imageUrl: msg.imageUrl!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              msg.text,
              style: GoogleFonts.inter(
                color: _textWhite,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMessageActionBar(AuraMessage msg, Color accent) {
    final isSpeaking = _speakingMessageId == msg.id;
    final containsCode = msg.text.contains('```');

    return Row(
      children: [
        _buildActionIcon(
          Icons.copy_rounded,
          () {
            Clipboard.setData(ClipboardData(text: msg.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Message copied to clipboard',
                  style: GoogleFonts.spaceMono(fontSize: 12),
                ),
                backgroundColor: _cardGrey,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        _buildActionIcon(
          msg.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
          () {
            if (_currentSessionId != null) {
              ref.read(auraSessionsProvider.notifier).updateMessageFeedback(
                    _currentSessionId!,
                    msg.id,
                    like: !msg.isLiked,
                    dislike: false,
                  );
            }
          },
          activeColor: Colors.blueAccent,
          isActive: msg.isLiked,
        ),
        const SizedBox(width: 8),
        _buildActionIcon(
          isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
          () => _toggleSpeak(msg.id, msg.text),
          activeColor: accent,
          isActive: isSpeaking,
          isWiggling: isSpeaking,
        ),
        const SizedBox(width: 8),
        _buildActionIcon(
          Icons.refresh_rounded,
          () {
            if (_currentSessionId != null) {
              ref.read(auraSessionsProvider.notifier).sendMessage(_currentSessionId!, msg.text);
            }
          },
        ),
        if (containsCode) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AuraSandboxScreen(code: msg.text),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'RUN PREVIEW',
                    style: GoogleFonts.spaceMono(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    VoidCallback onTap, {
    Color? activeColor,
    bool isActive = false,
    bool isWiggling = false,
  }) {
    Widget child = Icon(
      icon,
      color: isActive ? (activeColor ?? _textWhite) : _textMuted.withValues(alpha: 0.6),
      size: 16,
    );

    if (isWiggling) {
      child = child
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shake(hz: 8, curve: Curves.easeInOut, rotation: 0.05);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _cardGrey,
          border: Border.all(color: _borderGrey),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildTypingIndicator(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuraAvatar(accent),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _cardGrey,
              border: Border.all(color: _borderGrey),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.8),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .moveY(
                      begin: -3,
                      end: 3,
                      duration: 350.ms,
                      delay: (i * 150).ms,
                      curve: Curves.easeInOut,
                    );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Plus icon action (e.g. image picker placeholder)
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: _textWhite, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.inter(color: _textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Send message...',
                  hintStyle: GoogleFonts.inter(
                    color: _textMuted.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7B4FFF),
                    Color(0xFF5931CC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class DeepSpaceBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;

  DeepSpaceBackgroundPainter({
    required this.animationValue,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Overlapping radial gradients (Nebulas)
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.3), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), size.width * 0.8, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00F0FF).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.7), radius: size.width * 0.7));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), size.width * 0.7, paint2);
  }

  @override
  bool shouldRepaint(covariant DeepSpaceBackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.accentColor != accentColor;
}
