import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../domain/music_models.dart';
import '../../data/drip_bash_repository.dart';
import '../../application/sonic_drip_notifier.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DRIP BASH SHEET — BlackHole-style categorized music search
// ═══════════════════════════════════════════════════════════════════════════════

class DripBashSheet extends ConsumerStatefulWidget {
  const DripBashSheet({super.key});

  @override
  ConsumerState<DripBashSheet> createState() => _DripBashSheetState();
}

class _DripBashSheetState extends ConsumerState<DripBashSheet> {
  final _searchController = TextEditingController();
  CategorizedSearchResults _categorized = const CategorizedSearchResults.empty();
  List<Track> _flatResults = [];
  bool _isLoading = false;
  String _selectedSource = 'saavn';
  Timer? _debounce;

  // Album drill-down state
  String? _albumName;
  List<Track>? _albumSongs;
  bool _loadingAlbum = false;

  static const _lime = Color(0xFF52B788);
  static const _black = Color(0xFF000000);
  static const _surface = Color(0xFF0A0A0A);

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _categorized = const CategorizedSearchResults.empty();
        _flatResults = [];
        _albumSongs = null;
        _albumName = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() { _isLoading = true; _albumSongs = null; _albumName = null; });
    try {
      final repo = ref.read(dripBashRepositoryProvider);
      if (_selectedSource == 'saavn') {
        final results = await repo.searchSaavnCategorized(query);
        if (mounted) setState(() { _categorized = results; _flatResults = []; });
      } else {
        final results = await repo.searchYouTube(query);
        if (mounted) setState(() { _flatResults = results; _categorized = const CategorizedSearchResults.empty(); });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAlbum(Track album) async {
    setState(() { _loadingAlbum = true; _albumName = album.name; });
    try {
      final repo = ref.read(dripBashRepositoryProvider);
      final songs = await repo.fetchAlbumSongs(album.id);
      if (mounted) setState(() { _albumSongs = songs; _loadingAlbum = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAlbum = false);
    }
  }

  void _addToQueue(Track track) {
    ref.read(sonicDripProvider.notifier).addDripBashTrack(track);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added: ${track.name}', style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.w700)),
      backgroundColor: _lime,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _playNow(Track track) {
    ref.read(sonicDripProvider.notifier).playDripBash(track);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        border: Border(top: BorderSide(color: _lime, width: 3)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchInput(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 2))),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DRIP_BASH', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(
                _selectedSource == 'saavn' ? 'SAAVN_FULL_STREAM // 320KBPS' : 'YOUTUBE_STREAM // INVIDIOUS',
                style: GoogleFonts.robotoMono(color: _lime, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ]),
          ),
          _buildSourceToggle(),
        ],
      ),
    );
  }

  Widget _buildSourceToggle() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _sourceBtn('SAAVN', 'saavn'),
        _sourceBtn('YOUTUBE', 'youtube'),
      ]),
    );
  }

  Widget _sourceBtn(String label, String source) {
    final selected = _selectedSource == source;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSource = source;
          // Album drill-downs are Saavn-specific — reset on source change
          // so we never show "Add All" against an album from a different
          // source.
          _albumName = null;
          _albumSongs = null;
          _categorized = const CategorizedSearchResults.empty();
          _flatResults = [];
        });
        if (_searchController.text.isNotEmpty) _performSearch(_searchController.text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? _lime : Colors.transparent,
        child: Text(label, style: GoogleFonts.spaceMono(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }

  // ─── Search Input ───────────────────────────────────────────────────────────

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: _lime, offset: Offset(3, 3))],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'SEARCH_SONGS...',
            hintStyle: GoogleFonts.spaceGrotesk(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: const Icon(Icons.search, color: _lime, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchController.clear(); _onSearchChanged(''); },
                    child: const Icon(Icons.close, color: Colors.white54, size: 20),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  // ─── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: _lime, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('SCANNING...', style: GoogleFonts.robotoMono(color: _lime, fontSize: 11, fontWeight: FontWeight.w900)),
      ]));
    }

    // Album drill-down view
    if (_albumSongs != null) return _buildAlbumView();

    // Categorized results (Saavn)
    if (_categorized.categories.isNotEmpty) return _buildCategorizedResults();

    // Flat results (YouTube)
    if (_flatResults.isNotEmpty) return _buildFlatResults();

    // Empty state
    if (_searchController.text.isNotEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, color: Colors.white.withValues(alpha: 0.1), size: 48),
        const SizedBox(height: 12),
        Text('NO_RESULTS_FOUND', style: GoogleFonts.spaceGrotesk(color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w700)),
      ]));
    }

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_note, color: _lime.withValues(alpha: 0.15), size: 64),
      const SizedBox(height: 16),
      Text('TYPE_TO_SEARCH', style: GoogleFonts.robotoMono(color: Colors.white.withValues(alpha: 0.2), fontSize: 12, fontWeight: FontWeight.w900)),
    ]));
  }

  // ─── Categorized Results ────────────────────────────────────────────────────

  Widget _buildCategorizedResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _categorized.categories.length,
      itemBuilder: (context, index) {
        final category = _categorized.categories[index];
        return _CategorySection(
          category: category,
          onTrackTap: _addToQueue,
          onTrackPlay: _playNow,
          onAlbumTap: category.title == 'Albums' ? _openAlbum : null,
        );
      },
    );
  }

  Widget _buildFlatResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _flatResults.length,
      itemBuilder: (context, index) => _SongTile(
        track: _flatResults[index],
        onTap: () => _addToQueue(_flatResults[index]),
        onPlay: () => _playNow(_flatResults[index]),
      ),
    );
  }

  // ─── Album View ─────────────────────────────────────────────────────────────

  Widget _buildAlbumView() {
    return Column(children: [
      // Back header
      GestureDetector(
        onTap: () => setState(() { _albumSongs = null; _albumName = null; }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _lime.withValues(alpha: 0.3)))),
          child: Row(children: [
            const Icon(Icons.arrow_back_ios, color: _lime, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              (_albumName ?? 'ALBUM').toUpperCase(),
              style: GoogleFonts.spaceGrotesk(color: _lime, fontWeight: FontWeight.w900, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            GestureDetector(
              onTap: () {
                if (_albumSongs != null && _albumSongs!.isNotEmpty) {
                  ref.read(sonicDripProvider.notifier).addAlbumToQueue(_albumSongs!);
                  Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: _lime,
                child: Text('ADD_ALL', style: GoogleFonts.spaceMono(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
            ),
          ]),
        ),
      ),
      if (_loadingAlbum)
        const Expanded(child: Center(child: CircularProgressIndicator(color: _lime)))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _albumSongs?.length ?? 0,
            itemBuilder: (context, index) => _SongTile(
              track: _albumSongs![index],
              onTap: () => _addToQueue(_albumSongs![index]),
              onPlay: () => _playNow(_albumSongs![index]),
              showIndex: true,
              index: index + 1,
            ),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY SECTION — BlackHole-style section with header and items
// ═══════════════════════════════════════════════════════════════════════════════

class _CategorySection extends StatelessWidget {
  final SearchCategory category;
  final ValueChanged<Track> onTrackTap;
  final ValueChanged<Track> onTrackPlay;
  final ValueChanged<Track>? onAlbumTap;

  const _CategorySection({
    required this.category,
    required this.onTrackTap,
    required this.onTrackPlay,
    this.onAlbumTap,
  });

  static const _lime = Color(0xFF52B788);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: _lime,
              child: Text(
                category.title.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 2)),
            const SizedBox(width: 8),
            Text(
              '${category.items.length}',
              style: GoogleFonts.robotoMono(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        // Items
        if (category.title == 'Albums' || category.title == 'Artists')
          _buildGridItems()
        else
          ...category.items.map((track) => _SongTile(
            track: track,
            onTap: () => onTrackTap(track),
            onPlay: () => onTrackPlay(track),
          )),
      ],
    );
  }

  Widget _buildGridItems() {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: category.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = category.items[index];
          return _MediaCard(
            track: item,
            onTap: () => onAlbumTap != null ? onAlbumTap!(item) : onTrackTap(item),
            isArtist: category.title == 'Artists',
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEDIA CARD — Album/Artist card (BlackHole imageCard-style)
// ═══════════════════════════════════════════════════════════════════════════════

class _MediaCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final bool isArtist;

  const _MediaCard({required this.track, required this.onTap, this.isArtist = false});

  static const _lime = Color(0xFF52B788);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Artwork
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              borderRadius: isArtist ? BorderRadius.circular(60) : BorderRadius.zero,
              boxShadow: [BoxShadow(color: _lime.withValues(alpha: 0.15), offset: const Offset(2, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: track.imageUrl != null
                ? Image.network(track.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(height: 8),
          Text(
            track.name.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          if (!isArtist)
            Text(
              track.artistName,
              style: GoogleFonts.robotoMono(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
        ]),
      ),
    );
  }

  Widget _placeholder() {
    return Center(child: Icon(
      isArtist ? Icons.person : Icons.album,
      color: _lime.withValues(alpha: 0.3), size: 32,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SONG TILE — BlackHole MediaTile-style with brutalist theme
// ═══════════════════════════════════════════════════════════════════════════════

class _SongTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final bool showIndex;
  final int? index;

  const _SongTile({
    required this.track,
    required this.onTap,
    required this.onPlay,
    this.showIndex = false,
    this.index,
  });

  static const _lime = Color(0xFF52B788);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          // Index or thumbnail
          if (showIndex && index != null)
            SizedBox(
              width: 28, height: 48,
              child: Center(child: Text(
                '$index',
                style: GoogleFonts.robotoMono(color: _lime, fontWeight: FontWeight.w900, fontSize: 12),
              )),
            )
          else
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: _lime.withValues(alpha: 0.4), width: 1),
              ),
              child: track.imageUrl != null
                  ? Image.network(track.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: _lime, size: 20))
                  : const Icon(Icons.music_note, color: _lime, size: 20),
            ),
          const SizedBox(width: 12),
          // Track info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              track.name.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              if (track.albumName != null) ...[
                Flexible(child: Text(
                  track.albumName!,
                  style: GoogleFonts.robotoMono(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                Text(' • ', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9)),
              ],
              Flexible(child: Text(
                track.artistName,
                style: GoogleFonts.robotoMono(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ]),
          ])),
          // Duration + add button
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(
              track.durationFormatted,
              style: GoogleFonts.robotoMono(color: _lime, fontSize: 10, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Source badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                color: track.source == 'youtube' ? Colors.red : _lime.withValues(alpha: 0.2),
                child: Text(
                  track.source == 'youtube' ? 'YT' : 'SV',
                  style: GoogleFonts.spaceMono(
                    color: track.source == 'youtube' ? Colors.white : _lime,
                    fontSize: 7, fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Add to queue button
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(border: Border.all(color: _lime, width: 1)),
                  child: const Icon(Icons.add, color: _lime, size: 14),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}
