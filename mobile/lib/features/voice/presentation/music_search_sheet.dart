import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/application/music_notifier.dart';
import 'package:mobile/data/models/music_model.dart';
import 'package:google_fonts/google_fonts.dart';

class MusicSearchSheet extends ConsumerStatefulWidget {
  const MusicSearchSheet({super.key});

  @override
  ConsumerState<MusicSearchSheet> createState() => _MusicSearchSheetState();
}

class _MusicSearchSheetState extends ConsumerState<MusicSearchSheet> {
  final _searchController = TextEditingController();
  MusicType _selectedType = MusicType.track;

  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(musicNotifierProvider.notifier).search(value, type: _selectedType);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicNotifierProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: black,
        border: Border(top: BorderSide(color: lime, width: 6)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: grey, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SONIC_SEARCH',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: white,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: grey,
                      border: Border.all(color: white, width: 2),
                    ),
                    child: const Icon(Icons.close, color: white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: grey,
                border: Border.all(color: white, width: 3),
                boxShadow: const [
                  BoxShadow(color: lime, offset: Offset(4, 4)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: GoogleFonts.robotoMono(color: white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'SEARCH_VIBRATIONS...',
                  hintStyle: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.3)),
                  prefixIcon: const Icon(Icons.search, color: lime),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),

          // Filter Toggles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: MusicType.values.map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = type);
                      _onSearch(_searchController.text);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? lime : black,
                        border: Border.all(color: isSelected ? black : white, width: 2.5),
                        boxShadow: isSelected ? null : [
                          const BoxShadow(color: white, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Text(
                        type.name.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          color: isSelected ? black : white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Results
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: lime, strokeWidth: 4))
                : state.searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: state.searchResults.length,
                        padding: const EdgeInsets.all(20),
                        itemBuilder: (context, index) {
                          final item = state.searchResults[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: grey,
                              border: Border.all(color: white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: grey, offset: Offset(4, 4)),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  border: Border.all(color: white, width: 2),
                                  color: black,
                                  image: item.imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(item.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: item.imageUrl == null
                                    ? const Icon(Icons.music_note, color: lime)
                                    : null,
                              ),
                              title: Text(
                                item.name.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  color: white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                item.artistName.toUpperCase(),
                                style: GoogleFonts.robotoMono(
                                  color: white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: GestureDetector(
                                onTap: () {
                                  ref.read(musicNotifierProvider.notifier).addToQueue(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: lime,
                                      content: Text(
                                        'ADDED ${item.name.toUpperCase()} TO MANIFEST',
                                        style: GoogleFonts.robotoMono(
                                          color: black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lime,
                                    border: Border.all(color: black, width: 2),
                                  ),
                                  child: const Icon(Icons.add, color: black, size: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: grey, width: 4),
            ),
            child: Icon(Icons.sensors, size: 64, color: grey),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty ? 'WAITING_FOR_INPUT...' : 'NO_SIGNAL_FOUND',
            style: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.3),
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
