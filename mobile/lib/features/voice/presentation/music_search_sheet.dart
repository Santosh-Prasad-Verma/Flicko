import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/flicko_colors.dart';
import 'package:mobile/core/theme/flicko_radius.dart';
import 'package:mobile/core/theme/flicko_spacing.dart';
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
      decoration: BoxDecoration(
        color: FlickoColors.bgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(FlickoRadius.lg)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: FlickoColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Music',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: FlickoColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: FlickoColors.textMuted),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(FlickoSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: FlickoColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search for songs, artists, or albums...',
                hintStyle: const TextStyle(color: FlickoColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: FlickoColors.textMuted),
                filled: true,
                fillColor: FlickoColors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Filter Toggles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md),
            child: Row(
              children: MusicType.values.map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                        _onSearch(_searchController.text);
                      }
                    },
                    selectedColor: FlickoColors.accentPrimary,
                    backgroundColor: FlickoColors.bgSecondary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FlickoColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Results
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: state.searchResults.length,
                        padding: const EdgeInsets.all(FlickoSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = state.searchResults[index];
                          return ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(FlickoRadius.sm),
                                color: FlickoColors.bgSecondary,
                                image: item.imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(item.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: item.imageUrl == null
                                  ? const Icon(Icons.music_note, color: FlickoColors.textMuted)
                                  : null,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                color: FlickoColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.artistName,
                              style: const TextStyle(color: FlickoColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: FlickoColors.accentPrimary),
                              onPressed: () {
                                ref.read(musicNotifierProvider.notifier).addToQueue(item);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added ${item.name} to queue'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
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
          Icon(Icons.library_music, size: 64, color: FlickoColors.textMuted.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Search for music to play in the channel' : 'No results found',
            style: const TextStyle(color: FlickoColors.textMuted),
          ),
        ],
      ),
    );
  }
}
