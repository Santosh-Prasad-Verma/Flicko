import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/music_party_session.dart';
import 'package:mobile/features/activities/music_party/providers/mp_session_provider.dart';

class MusicPartyScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? sessionId;

  const MusicPartyScreen({
    super.key,
    required this.roomId,
    this.sessionId,
  });

  @override
  ConsumerState<MusicPartyScreen> createState() => _MusicPartyScreenState();
}

class _MusicPartyScreenState extends ConsumerState<MusicPartyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-join if sessionId is provided
    if (widget.sessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(musicPartySessionProvider.notifier).joinSession(widget.sessionId!);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mpState = ref.watch(musicPartySessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: mpState == null
          ? _buildCreateView(theme)
          : _buildSessionView(theme, mpState),
    );
  }

  Widget _buildCreateView(ThemeData theme) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated music icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Music Party',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a listening session and DJ together',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 48),
            // Start session button
            GestureDetector(
              onTap: _createSession,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Start Music Party',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionView(ThemeData theme, MusicPartyState mpState) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(theme, mpState),
          _buildNowPlaying(theme, mpState),
          _buildPlaybackControls(theme, mpState),
          const SizedBox(height: 8),
          // Queue
          Expanded(child: _buildQueue(theme, mpState)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, MusicPartyState mpState) {
    final session = mpState.session;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Music Party',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.state.toUpperCase()} • ${session.rotationMode}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // DJ badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headphones, color: Color(0xFF1DB954), size: 14),
                const SizedBox(width: 4),
                const Text(
                  'DJ',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(ThemeData theme, MusicPartyState mpState) {
    final currentItem = mpState.queue.cast<MusicPartyQueueItem?>().firstWhere(
      (i) => i?.state == 'playing',
      orElse: () => null,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1DB954).withOpacity(0.15),
            const Color(0xFF191414).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1DB954).withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          // Album art placeholder
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: currentItem?.albumArtUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      currentItem!.albumArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.album, color: Colors.white24, size: 80),
                    ),
                  )
                : const Icon(Icons.album, color: Colors.white24, size: 80),
          ),
          const SizedBox(height: 20),
          // Track info
          Text(
            currentItem?.title ?? 'No track playing',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            currentItem?.artist ?? 'Add tracks to the queue',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(ThemeData theme, MusicPartyState mpState) {
    final isPlaying = mpState.session.state == 'playing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip back (vibe fire)
          _vibeButton(Icons.local_fire_department_rounded, const Color(0xFFFF6B35)),
          // Play/pause
          GestureDetector(
            onTap: () {
              if (isPlaying) {
                // Pause via anchor
              } else {
                ref.read(musicPartySessionProvider.notifier).play();
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          // Skip
          IconButton(
            onPressed: () {
              ref.read(musicPartySessionProvider.notifier).skip();
            },
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
          ),
          // Vibe thumbs up
          _vibeButton(Icons.thumb_up_alt_rounded, const Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _vibeButton(IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Send vibe reaction
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildQueue(ThemeData theme, MusicPartyState mpState) {
    final queuedItems = mpState.queue.where((i) => i.state == 'queued').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${queuedItems.length} tracks',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              // Add track button
              GestureDetector(
                onTap: () {
                  // TODO: Open Spotify search sheet
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Color(0xFF1DB954), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add Track',
                        style: TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: queuedItems.isEmpty
              ? Center(
                  child: Text(
                    'Queue is empty — add some tracks!',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: queuedItems.length,
                  itemBuilder: (context, index) =>
                      _buildQueueItem(queuedItems[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildQueueItem(MusicPartyQueueItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Mini album art
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.08),
            ),
            child: item.albumArtUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.albumArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.music_note, color: Colors.white24, size: 24),
                    ),
                  )
                : const Icon(Icons.music_note, color: Colors.white24, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? 'Unknown Track',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.artist ?? 'Unknown Artist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Duration
          if (item.durationMs != null)
            Text(
              _formatDuration(item.durationMs!),
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 8),
          // Remove button
          GestureDetector(
            onTap: () => ref.read(musicPartySessionProvider.notifier).removeQueueItem(item.id),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final minutes = (ms ~/ 60000);
    final seconds = ((ms % 60000) ~/ 1000);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _createSession() async {
    final notifier = ref.read(musicPartySessionProvider.notifier);
    final success = await notifier.createSession(roomId: widget.roomId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create Music Party session')),
      );
    }
  }
}
