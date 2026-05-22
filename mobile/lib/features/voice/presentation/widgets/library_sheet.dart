import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../application/music_library_notifier.dart';
import '../../domain/music_models.dart';
import '../../data/music_library_repository.dart';

/// Library bottom sheet with playlists, liked songs, and history
class LibrarySheet extends ConsumerStatefulWidget {
  final Function(Track)? onTrackSelected;
  
  const LibrarySheet({super.key, this.onTrackSelected});

  @override
  ConsumerState<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends ConsumerState<LibrarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(musicLibraryProvider);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Library',
                  style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: _neon),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: _neon,
            labelColor: _white,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: [
              Tab(text: 'LIKED (${library.likedSongs.length})'),
              Tab(text: 'PLAYLISTS (${library.playlists.length})'),
              Tab(text: 'HISTORY'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLikedSongs(library),
                _buildPlaylists(library),
                _buildHistory(library),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedSongs(MusicLibrary library) {
    if (library.likedSongs.isEmpty) {
      return _buildEmptyState('No liked songs yet', 'Songs you like will appear here', Icons.favorite_border);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: library.likedSongs.length,
      itemBuilder: (context, index) {
        final track = library.likedSongs[index];
        return _TrackTile(
          track: track,
          onTap: () => widget.onTrackSelected?.call(track),
          onLike: () => ref.read(musicLibraryProvider.notifier).unlikeSong(track.id),
          isLiked: true,
        );
      },
    );
  }

  Widget _buildPlaylists(MusicLibrary library) {
    return Column(
      children: [
        // Create playlist button
        Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: () => _showCreatePlaylistDialog(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _neon.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: _neon, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Playlist',
                    style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Playlists list
        Expanded(
          child: library.playlists.isEmpty
              ? _buildEmptyState('No playlists', 'Create your first playlist', Icons.playlist_add)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: library.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = library.playlists[index];
                    return _PlaylistTile(
                      playlist: playlist,
                      onTap: () => _showPlaylistDetail(context, playlist),
                      onDelete: () => ref.read(musicLibraryProvider.notifier).deletePlaylist(playlist.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistory(MusicLibrary library) {
    if (library.history.isEmpty) {
      return _buildEmptyState('No history', 'Recently played songs will appear here', Icons.history);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: library.history.length,
      itemBuilder: (context, index) {
        final track = library.history[index];
        return _TrackTile(
          track: track,
          onTap: () => widget.onTrackSelected?.call(track),
          onLike: () => ref.read(musicLibraryProvider.notifier).toggleLike(track),
          isLiked: library.isLiked(track.id),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 48),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(color: _white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Create Playlist', style: GoogleFonts.inter(color: _white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: GoogleFonts.inter(color: _white),
              decoration: InputDecoration(
                hintText: 'Playlist name',
                hintStyle: GoogleFonts.inter(color: _muted),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: GoogleFonts.inter(color: _white),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: GoogleFonts.inter(color: _muted),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(musicLibraryProvider.notifier).createPlaylist(
                  controller.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neon),
            child: Text('Create', style: GoogleFonts.inter(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistDetail(BuildContext context, UserPlaylist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlaylistDetailSheet(
        playlist: playlist,
        onTrackSelected: widget.onTrackSelected,
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool isLiked;

  const _TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLike,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: const Color(0xFF52B788).withValues(alpha: 0.2),
                child: track.imageUrl != null
                    ? Image.network(track.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Color(0xFF52B788)))
                    : const Icon(Icons.music_note, color: Color(0xFF52B788)),
              ),
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artistName,
                    style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Like button
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? const Color(0xFF52B788) : const Color(0xFF71717A),
              ),
              onPressed: onLike,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final UserPlaylist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _PlaylistTile({
    required this.playlist,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Playlist cover
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF52B788).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: playlist.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(playlist.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultIcon()),
                    )
                  : _defaultIcon(),
            ),
            const SizedBox(width: 12),
            // Playlist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${playlist.trackCount} songs',
                    style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12),
                  ),
                ],
              ),
            ),
            // Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF71717A)),
              color: const Color(0xFF0C0C0E),
              onSelected: (value) {
                if (value == 'delete' && onDelete != null) {
                  onDelete!();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: GoogleFonts.inter(color: const Color(0xFFFBF9FA))),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultIcon() => const Icon(Icons.playlist_play, color: Color(0xFF52B788), size: 28);
}

class _PlaylistDetailSheet extends ConsumerWidget {
  final UserPlaylist playlist;
  final Function(Track)? onTrackSelected;

  const _PlaylistDetailSheet({
    required this.playlist,
    this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(musicLibraryProvider);
    
    // Get tracks from playlist
    final tracks = library.likedSongs
        .where((t) => playlist.trackIds.contains(t.id))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFBF9FA),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (playlist.description != null)
                        Text(
                          playlist.description!,
                          style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF71717A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tracks
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note, color: Color(0xFF71717A), size: 48),
                        const SizedBox(height: 12),
                        Text('No tracks yet', style: GoogleFonts.inter(color: const Color(0xFF71717A))),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tracks.length,
                    onReorder: (oldIndex, newIndex) {
                      ref.read(musicLibraryProvider.notifier)
                          .reorderPlaylist(playlist.id, oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return _TrackTile(
                        key: ValueKey(track.id),
                        track: track,
                        onTap: () {
                          Navigator.pop(context);
                          onTrackSelected?.call(track);
                        },
                        onLike: () => ref.read(musicLibraryProvider.notifier)
                            .removeFromPlaylist(playlist.id, track.id),
                        isLiked: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
