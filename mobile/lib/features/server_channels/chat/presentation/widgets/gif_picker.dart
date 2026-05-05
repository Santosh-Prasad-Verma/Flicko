import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import '../../../../../../data/services/giphy_service.dart';

/// GIF Picker Widget
///
/// Discord-style GIF picker with trending GIFs and search.
/// Mirrors the React Native GifPicker component.
/// Note: Requires GIPHY API integration for production use.
class GifPicker extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;
  final VoidCallback onClose;

  const GifPicker({
    super.key,
    required this.onGifSelected,
    required this.onClose,
  });

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final TextEditingController _searchController = TextEditingController();
  final GiphyService _giphyService = GiphyService();
  
  bool _isSearching = false;
  bool _isLoading = false;
  String _selectedCategory = 'trending';
  
  List<GiphyGif> _trendingGifs = [];
  List<GiphyGif> _searchResults = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTrendingGifs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingGifs() async {
    if (!_giphyService.isConfigured) {
      setState(() {
        _errorMessage = 'GIPHY API not configured';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gifs = await _giphyService.getTrendingGifs(limit: 30);
      setState(() {
        _trendingGifs = gifs;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load GIFs: $e';
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (_isSearching) {
      _searchGifs(query);
    }
  }

  Future<void> _searchGifs(String query) async {
    if (!_giphyService.isConfigured) {
      setState(() {
        _errorMessage = 'GIPHY API not configured';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gifs = await _giphyService.searchGifs(query, limit: 30);
      setState(() {
        _searchResults = gifs;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to search GIFs: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.textMuted),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with search
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search GIFs',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(FlickoColors.textMuted),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(FlickoColors.textMuted),
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(FlickoColors.bgTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close,
                    color: Color(FlickoColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          
          // Category tabs (only show when not searching)
          if (!_isSearching) ...[
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryTab('Trending', 'trending', Icons.trending_up),
                  _buildCategoryTab('Reactions', 'reactions', Icons.sentiment_very_satisfied),
                  _buildCategoryTab('Funny', 'funny', Icons.sentiment_very_satisfied),
                  _buildCategoryTab('Memes', 'memes', Icons.face),
                  _buildCategoryTab('Gaming', 'gaming', Icons.videogame_asset),
                  _buildCategoryTab('Sports', 'sports', Icons.sports),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          const Divider(color: Color(FlickoColors.bgTertiary), height: 1),
          
          // GIF grid
          Expanded(
            child: _isLoading
                ? _buildLoadingIndicator()
                : _errorMessage != null
                    ? _buildErrorMessage()
                    : _isSearching
                        ? _buildSearchResults()
                        : _buildGifGrid(_trendingGifs),
          ),
          
          // GIPHY attribution
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Powered by',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'GIPHY',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.blurple),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(FlickoColors.blurple)
              : const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : const Color(FlickoColors.textSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected
                    ? Colors.white
                    : const Color(FlickoColors.textSecondary),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGifGrid(List<GiphyGif> gifs) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final gif = gifs[index];
        return GestureDetector(
          onTap: () {
            widget.onGifSelected(gif.displayUrl);
            widget.onClose();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: const Color(FlickoColors.bgTertiary),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: gif.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(FlickoColors.bgTertiary),
                      child: const Icon(
                        Icons.gif,
                        color: Color(FlickoColors.textMuted),
                        size: 40,
                      ),
                    ),
                  ),
                  // GIF label overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        gif.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _errorMessage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              color: Color(FlickoColors.textMuted),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return _buildGifGrid(_searchResults);
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.blurple)),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(FlickoColors.textMuted),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Failed to load GIFs',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTrendingGifs,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension to show GifPicker
extension GifPickerExtension on BuildContext {
  void showGifPicker({
    required Function(String gifUrl) onGifSelected,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GifPicker(
        onGifSelected: onGifSelected,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}
