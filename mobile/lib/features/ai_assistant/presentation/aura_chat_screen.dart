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
  String? _speakingMessageId;

  Color get _bgBlack => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardGrey => Theme.of(context).cardColor;
  Color get _borderGrey => Theme.of(context).dividerColor;
  Color get _textWhite => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get _textMuted => Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF8E8E9F);
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  Color get _accentPink {
    final settings = ref.watch(auraSettingsProvider);
    if (settings.themeName == 'Sync with App') {
      return Theme.of(context).primaryColor;
    }
    return const Color(0xFF6C5CE7);
  }

  Color get _accentPurple {
    final accent = ref.watch(auraSettingsProvider).accentColor;
    return accent == Colors.transparent ? const Color(0xFF00F2FE) : accent;
  }

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

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    if (overrideText == null) _messageController.clear();
    setState(() {
      _isTyping = true;
    });

    if (_currentSessionId == null) {
      final session = await ref.read(auraSessionsProvider.notifier).createNewSession(
            widget.category,
            initialPrompt: text,
          );
      _currentSessionId = session.id;
    }

    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _scrollToBottom();
    });

    await ref.read(auraSessionsProvider.notifier).sendMessage(_currentSessionId!, text);

    if (mounted) {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _toggleSpeak(String messageId, String text) {
    if (_speakingMessageId == messageId) {
      setState(() {
        _speakingMessageId = null;
      });
    } else {
      setState(() {
        _speakingMessageId = messageId;
      });

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
        ? sessions.firstWhere(
            (s) => s.id == _currentSessionId,
            orElse: () => AuraSession(
              id: '',
              category: widget.category,
              title: '',
              messages: [],
              lastActive: DateTime.now(),
            ),
          )
        : null;

    final messages = activeSession?.messages ?? [];
    final categoryColors = {
      'Text Writer': const Color(0xFF00F2FE),
      'Image Generator': const Color(0xFFFF00F5),
      'Code Tutor': const Color(0xFF00FFCC),
    };
    final accent = categoryColors[widget.category] ?? _accentPurple;

    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: _buildAppBar(context, activeSession?.title ?? 'New Session', accent),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DeepSpaceBackgroundPainter(
                animationValue: 0.0,
                accentColor: accent,
                isLight: _isLight,
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
      backgroundColor: _bgBlack.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _textWhite.withOpacity(0.04),
              border: Border.all(
                color: _textWhite.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textWhite,
              size: 14,
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.category.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Icon(
              Icons.mic_rounded,
              color: accent,
              size: 20,
            ),
            onPressed: () => context.push('/profile/settings/aura/voice'),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: _textWhite.withOpacity(0.06),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    final promptCards = [
      {
        'icon': Icons.bolt_rounded,
        'title': 'Brainstorm Ideas',
        'subtitle': 'Creative concepts for a tech startup',
      },
      {
        'icon': Icons.edit_note_rounded,
        'title': 'Draft & Write',
        'subtitle': 'Write a compelling product email',
      },
      {
        'icon': Icons.code_rounded,
        'title': 'Code Assistant',
        'subtitle': 'Build a responsive Flutter widget',
      },
      {
        'icon': Icons.travel_explore_rounded,
        'title': 'Web Research',
        'subtitle': 'Summarize latest AI news',
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  accent.withOpacity(0.25),
                  accent.withOpacity(0.04),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.category == 'Text Writer'
                  ? Icons.auto_awesome_rounded
                  : widget.category == 'Image Generator'
                      ? Icons.palette_rounded
                      : Icons.terminal_rounded,
              color: accent,
              size: 44,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text(
            'What can I build for you?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: _textWhite,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask Aura anything — powered by Gemini & Grok API with live web intelligence.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: promptCards.length,
            itemBuilder: (context, index) {
              final card = promptCards[index];
              final IconData iconData = card['icon'] as IconData;
              final String title = card['title'] as String;
              final String subtitle = card['subtitle'] as String;

              return GestureDetector(
                onTap: () => _sendMessage(subtitle),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _textWhite.withOpacity(0.025),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _textWhite.withOpacity(0.06),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconData,
                          color: accent,
                          size: 16,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: _textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              color: _textMuted,
                              fontSize: 10.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(AuraMessage msg, Color accent) {
    final isUser = msg.sender == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAuraAvatar(accent),
            const SizedBox(width: 10),
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
            const SizedBox(width: 10),
            _buildUserAvatar(),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
  }

  Widget _buildAuraAvatar(Color accent) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _textWhite.withOpacity(0.04),
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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _textWhite.withOpacity(0.05),
        border: Border.all(
          color: _textWhite.withOpacity(0.1),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(Icons.person_rounded, color: _textWhite, size: 18),
      ),
    );
  }

  Widget _buildMessageBubble(AuraMessage msg, bool isUser, Color accent) {
    if (isUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          gradient: LinearGradient(
            colors: [
              accent,
              accent.withBlue((accent.blue + 40).clamp(0, 255)),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _textWhite.withOpacity(0.035),
          border: Border.all(
            color: _textWhite.withOpacity(0.07),
            width: 1.2,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
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
                  borderRadius: BorderRadius.circular(14),
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
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
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
                  style: GoogleFonts.inter(fontSize: 12),
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
          activeColor: accent,
          isActive: msg.isLiked,
        ),
        const SizedBox(width: 8),
        _buildActionIcon(
          isSpeaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'RUN CODE',
                    style: GoogleFonts.outfit(
                      color: accent,
                      fontSize: 10,
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
      color: isActive ? (activeColor ?? _textWhite) : _textMuted.withOpacity(0.6),
      size: 15,
    );

    if (isWiggling) {
      child = child
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shake(hz: 8, curve: Curves.easeInOut, rotation: 0.05);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _textWhite.withOpacity(0.04),
          border: Border.all(color: _textWhite.withOpacity(0.07)),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildTypingIndicator(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuraAvatar(accent),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _textWhite.withOpacity(0.035),
              border: Border.all(color: _textWhite.withOpacity(0.07)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
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
                    color: accent.withOpacity(0.8),
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
      decoration: BoxDecoration(
        color: _bgBlack.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: _textWhite.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _textWhite.withOpacity(0.04),
              border: Border.all(color: _textWhite.withOpacity(0.08)),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_rounded, color: _textWhite, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _textWhite.withOpacity(0.04),
                border: Border.all(color: _textWhite.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.inter(color: _textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Message Aura...',
                  hintStyle: GoogleFonts.inter(
                    color: _textMuted.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent,
                    accent.withBlue((accent.blue + 30).clamp(0, 255)),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
  final bool isLight;

  DeepSpaceBackgroundPainter({
    required this.animationValue,
    required this.accentColor,
    this.isLight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double nebula1Opacity = isLight ? 0.05 : 0.18;
    final double nebula2Opacity = isLight ? 0.03 : 0.10;

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
          (isLight ? accentColor : const Color(0xFF00F2FE)).withOpacity(nebula2Opacity),
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
