import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/features/ai_assistant/data/aura_chat_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(auraSessionsProvider);
    
    // Filter sessions based on search query
    final filteredSessions = sessions.where((session) {
      final query = _searchQuery.toLowerCase();
      return session.title.toLowerCase().contains(query) ||
          session.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: _bgBlack,
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
                    _accentPink.withValues(alpha: 0.15),
                    _accentPurple.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildTitleSection(),
                          const SizedBox(height: 24),
                          _buildSearchField(),
                          const SizedBox(height: 28),
                          _buildQuickToolsSection(),
                          const SizedBox(height: 36),
                          _buildHistorySection(filteredSessions),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profile/settings/aura/voice'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [_accentPink, _accentPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentPink.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'TALK TO AURA',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  void _showApiKeyDialog(BuildContext context) async {
    final notifier = ref.read(auraSessionsProvider.notifier);
    final currentKey = await notifier.getApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _borderGrey),
          ),
          title: Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: _accentPink, size: 22),
              const SizedBox(width: 10),
              Text(
                'GEMINI API KEY',
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Gemini API key to enable live responses. Leave empty to use local simulated mode.',
                style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: _bgBlack,
                  border: Border.all(color: _borderGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controller,
                  obscureText: true,
                  style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle: GoogleFonts.spaceMono(color: _textMuted.withValues(alpha: 0.5), fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                final key = controller.text.trim();
                await notifier.saveApiKey(key);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(key.isEmpty ? 'Using simulated local engine' : 'Gemini API Key saved'),
                      backgroundColor: _accentPink,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(
                'SAVE',
                style: GoogleFonts.spaceMono(color: _accentPink, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderGrey, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: _textWhite, size: 22),
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accentPink, _accentPurple],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AURA AI COMPANION',
                style: GoogleFonts.spaceGrotesk(
                  color: _textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showApiKeyDialog(context),
            icon: const Icon(Icons.vpn_key_rounded, color: _textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create, explore,\nbe inspired',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _cardGrey,
        border: Border.all(color: _borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 14),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: _textMuted, size: 20),
          hintText: 'Search queries or topics...',
          hintStyle: GoogleFonts.spaceMono(color: _textMuted, fontSize: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: const Icon(Icons.clear, color: _textWhite, size: 16),
                )
              : null,
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildQuickToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildToolCard(
                'AI text\nwriter',
                'Text Writer',
                const Icon(Icons.edit_note_rounded, color: _accentPink, size: 28),
              ),
              const SizedBox(width: 14),
              _buildToolCard(
                'AI image\ngenerator',
                'Image Generator',
                const Icon(Icons.image_search_rounded, color: _accentPurple, size: 28),
              ),
              const SizedBox(width: 14),
              _buildToolCard(
                'AI code\ntutor',
                'Code Tutor',
                const Icon(Icons.code_rounded, color: Color(0xFF00FFCC), size: 28),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildToolCard(String label, String category, Widget icon) {
    return GestureDetector(
      onTap: () async {
        final session = await ref.read(auraSessionsProvider.notifier).createNewSession(category);
        if (mounted) {
          context.push('/profile/settings/aura/chat?category=$category&sessionId=${session.id}');
        }
      },
      child: Container(
        width: 140,
        height: 145,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardGrey,
          border: Border.all(color: _borderGrey),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                icon,
                const Icon(Icons.arrow_outward_rounded, color: _textMuted, size: 18),
              ],
            ),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: _textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
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
              style: GoogleFonts.epilogue(
                color: _textWhite,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (filteredSessions.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(auraSessionsProvider.notifier).clearHistory();
                },
                child: Text(
                  'Clear all',
                  style: GoogleFonts.spaceMono(
                    color: _accentPink,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
                const Icon(Icons.history_toggle_off_rounded, color: _textMuted, size: 36),
                const SizedBox(height: 12),
                Text(
                  'No search results or history',
                  style: GoogleFonts.spaceMono(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSessions.length,
            itemBuilder: (context, index) {
              final session = filteredSessions[index];
              final categoryColors = {
                'Text Writer': _accentPink,
                'Image Generator': _accentPurple,
                'Code Tutor': const Color(0xFF00FFCC),
              };
              final accent = categoryColors[session.category] ?? _accentPink;

              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red.withValues(alpha: 0.2),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                ),
                onDismissed: (direction) {
                  ref.read(auraSessionsProvider.notifier).deleteSession(session.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Session "${session.title}" deleted.'),
                      backgroundColor: _cardGrey,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _cardGrey,
                    border: Border.all(color: _borderGrey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      context.push('/profile/settings/aura/chat?category=${session.category}&sessionId=${session.id}');
                    },
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Icon(
                          session.category == 'Text Writer'
                              ? Icons.edit_note_rounded
                              : session.category == 'Image Generator'
                                  ? Icons.image_search_rounded
                                  : Icons.code_rounded,
                          color: accent,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: _textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${session.category} · ${_formatTime(session.lastActive)}',
                      style: GoogleFonts.spaceMono(
                        color: _textMuted,
                        fontSize: 10,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _textMuted,
                      size: 14,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
