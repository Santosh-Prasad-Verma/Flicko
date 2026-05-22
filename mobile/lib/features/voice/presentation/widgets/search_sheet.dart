import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/sonic_drip_notifier.dart';
import '../../domain/music_models.dart';

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _controller = TextEditingController();
  MusicType _type = MusicType.track;

  static const _lime = Color(0xFF52B788);
  static const _surface = Color(0xFF0A0A0A);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(sonicDripProvider.notifier).searchDebounced(value, type: _type);
  }

  void _onTypeChanged(MusicType type) {
    setState(() => _type = type);
    if (_controller.text.isNotEmpty) {
      ref.read(sonicDripProvider.notifier).searchDebounced(_controller.text, type: type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sonicDripProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        border: Border(top: BorderSide(color: Color(0xFF52B788), width: 3)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(context),
          _buildSearchBar(),
          _buildTypeFilter(),
          const SizedBox(height: 8),
          Expanded(child: _buildResults(state)),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'SEARCH_CATALOG',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        autofocus: true,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
        cursorColor: _lime,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 15,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF52B788)),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _controller.clear();
                    ref.read(sonicDripProvider.notifier).searchDebounced('');
                  },
                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                )
              : null,
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF333333), width: 2),
            borderRadius: BorderRadius.zero,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF333333), width: 2),
            borderRadius: BorderRadius.zero,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF52B788), width: 2),
            borderRadius: BorderRadius.zero,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: MusicType.values.map((type) {
          final isSelected = _type == type;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _onTypeChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? _lime : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _lime : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  type.name.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResults(SonicDripState state) {
    if (state.isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF52B788)),
      );
    }

    if (state.searchError != null) {
      return Center(
        child: Text(
          state.searchError!,
          style: GoogleFonts.inter(color: Colors.red.withValues(alpha: 0.7)),
        ),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),
            Text(
              _controller.text.isEmpty
                  ? 'TYPE TO SEARCH'
                  : 'NO_RESULTS_FOUND',
              style: GoogleFonts.robotoMono(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        return _SearchResultItem(track: state.searchResults[index]);
      },
    );
  }
}

class _SearchResultItem extends ConsumerWidget {
  final Track track;
  const _SearchResultItem({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInQueue = ref.watch(
      sonicDripProvider.select((s) => s.queue.any((t) => t.id == track.id)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(
          color: isInQueue
              ? const Color(0xFF52B788).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () {
          ref.read(sonicDripProvider.notifier).play(track);
          Navigator.pop(context);
        },
        leading: _Thumbnail(imageUrl: track.imageUrl),
        title: Text(
          track.name,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artistName,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: GestureDetector(
          onTap: isInQueue
              ? null
              : () {
                  ref.read(sonicDripProvider.notifier).addToQueue(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added "${track.name}" to queue'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF1A1A1A),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isInQueue
                  ? const Color(0xFF52B788).withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isInQueue
                    ? const Color(0xFF52B788)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              isInQueue ? Icons.check : Icons.add,
              color: isInQueue ? const Color(0xFF52B788) : Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  const _Thumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? const Icon(Icons.music_note, color: Colors.white24, size: 22)
          : null,
    );
  }
}
