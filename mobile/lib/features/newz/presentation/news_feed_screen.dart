import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:mobile/features/newz/data/news_article.dart';
import 'package:mobile/features/newz/data/news_service.dart';
import 'package:mobile/features/newz/presentation/in_app_browser_screen.dart';
import 'package:mobile/features/shared/presentation/widgets/pill_search_bar.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();

  NewsCategory _selectedCategory = NewsCategory.all;
  NewsSortOrder _selectedSort = NewsSortOrder.newest;
  NewsTimeRange _selectedTimeRange = NewsTimeRange.allTime;
  String _selectedSource = 'All Sources';

  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color get _accent => GetIt.I<MyTheme>().currentColor();
  static const Color _cardBg = Color(0xFF0F0F12);

  final List<String> _availableSources = [
    'All Sources',
    'Google News',
    'BBC News',
    'TechCrunch',
    'Wired',
    'IGN',
    'Science Daily',
    'CoinDesk',
    'NASA News',
    'Reuters',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchArticles(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchArticles(reset: false);
    }
  }

  Future<void> _fetchArticles({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _articles.clear();
        _hasMore = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final newArticles = await _newsService.fetchNews(
        category: _selectedCategory,
        sortOrder: _selectedSort,
        timeRange: _selectedTimeRange,
        sourceFilter: _selectedSource,
        page: _currentPage,
        pageSize: 15,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _articles = newArticles;
          } else {
            _articles.addAll(newArticles);
          }

          if (newArticles.isEmpty) {
            _hasMore = false;
          } else {
            _currentPage++;
          }

          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onCategoryChanged(NewsCategory category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    _fetchArticles(reset: true);
  }

  Future<void> _onRefresh() async {
    _newsService.clearCache();
    await _fetchArticles(reset: true);
  }

  List<NewsArticle> get _filteredArticles {
    if (_searchQuery.isEmpty) return _articles;
    final q = _searchQuery.toLowerCase();
    return _articles
        .where((a) =>
            a.title.toLowerCase().contains(q) ||
            a.summary.toLowerCase().contains(q) ||
            a.author.toLowerCase().contains(q))
        .toList();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(FlickoColors.brandLime), size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'News Filters & Options',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedSort = NewsSortOrder.newest;
                              _selectedTimeRange = NewsTimeRange.allTime;
                              _selectedSource = 'All Sources';
                            });
                          },
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.brandLime),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),

                    // Sort Order
                    Text(
                      'SORT BY',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NewsSortOrder.values.map((sort) {
                        final isSelected = sort == _selectedSort;
                        return ChoiceChip(
                          label: Text(sort.displayName),
                          selected: isSelected,
                          selectedColor: const Color(FlickoColors.brandLime),
                          backgroundColor: const Color(FlickoColors.bgTertiary),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _selectedSort = sort);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Time Range
                    Text(
                      'TIME RANGE',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NewsTimeRange.values.map((timeRange) {
                        final isSelected = timeRange == _selectedTimeRange;
                        return ChoiceChip(
                          label: Text(timeRange.displayName),
                          selected: isSelected,
                          selectedColor: const Color(FlickoColors.brandLime),
                          backgroundColor: const Color(FlickoColors.bgTertiary),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _selectedTimeRange = timeRange);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Source Filter
                    Text(
                      'NEWS SOURCE',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedSource,
                      dropdownColor: const Color(FlickoColors.bgTertiary),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(FlickoColors.bgTertiary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _availableSources.map((src) {
                        return DropdownMenuItem(
                          value: src,
                          child: Text(src),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _selectedSource = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(FlickoColors.brandLime),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _fetchArticles(reset: true);
                        },
                        child: Text(
                          'Apply Filters',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiquidGlassBackground({required Widget child}) {
    final currentTheme = GetIt.I<MyTheme>();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07040A),
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.6),
          radius: 1.5,
          colors: [
            currentTheme.currentColor().withValues(alpha: 0.08),
            const Color(0xFF07040A),
          ],
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final articles = _filteredArticles;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildLiquidGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search bar with filter toggle
              _buildSearchBar(),
              // Active Filter Chips indicator
              _buildActiveFiltersBar(),
              // Category tabs
              _buildCategoryBar(),
              const SizedBox(height: 8),

              // News List
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _accent))
                    : _error != null && articles.isEmpty
                        ? _buildErrorState()
                        : articles.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                color: _accent,
                                backgroundColor: _cardBg,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics()),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  itemCount: articles.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == articles.length) {
                                      return _buildLoadMoreIndicator();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildNewsCard(articles[index]),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: PillSearchBar(
              controller: _searchController,
              hintText: 'Search unlimited news, topics, sources...',
              onBackPressed: () => context.pop(),
              onChanged: (val) => setState(() => _searchQuery = val),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(FlickoColors.brandLime),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final bool hasActiveFilters = _selectedSort != NewsSortOrder.newest ||
        _selectedTimeRange != NewsTimeRange.allTime ||
        _selectedSource != 'All Sources';

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_selectedSort != NewsSortOrder.newest)
              _buildFilterBadge(_selectedSort.displayName, () {
                setState(() => _selectedSort = NewsSortOrder.newest);
                _fetchArticles(reset: true);
              }),
            if (_selectedTimeRange != NewsTimeRange.allTime)
              _buildFilterBadge(_selectedTimeRange.displayName, () {
                setState(() => _selectedTimeRange = NewsTimeRange.allTime);
                _fetchArticles(reset: true);
              }),
            if (_selectedSource != 'All Sources')
              _buildFilterBadge(_selectedSource, () {
                setState(() => _selectedSource = 'All Sources');
                _fetchArticles(reset: true);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBadge(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.brandLime),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(FlickoColors.brandLime)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: NewsCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = NewsCategory.values[index];
          final isSelected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => _onCategoryChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accent : _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _accent : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat.icon,
                    size: 14,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.displayName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large image area
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildArticleImage(article.imageUrl),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _cardBg.withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // Source badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.newspaper_rounded, color: Color(FlickoColors.brandLime), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            article.author.length > 22 ? '${article.author.substring(0, 22)}...' : article.author,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bookmark icon
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bookmark_border_rounded,
                          color: Colors.white.withValues(alpha: 0.8), size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.summary,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _accent.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          article.category.displayName,
                          style: GoogleFonts.inter(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (article.publishDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            article.publishDate,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.3), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        article.readTime,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.03),
        child: Center(
          child: Icon(Icons.article_outlined, color: Colors.white.withValues(alpha: 0.1), size: 48),
        ),
      );
    }

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.03),
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white.withValues(alpha: 0.1), size: 48),
          ),
        ),
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white.withValues(alpha: 0.03),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '✓ You are up to date with all news archives',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_rounded, color: Colors.white.withValues(alpha: 0.15), size: 56),
          const SizedBox(height: 16),
          Text(
            'No articles found for selected filters',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Try resetting filters or category',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedCategory = NewsCategory.all;
                _selectedSort = NewsSortOrder.newest;
                _selectedTimeRange = NewsTimeRange.allTime;
                _selectedSource = 'All Sources';
                _searchQuery = '';
                _searchController.clear();
              });
              _fetchArticles(reset: true);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(FlickoColors.brandLime)),
              shape: const StadiumBorder(),
            ),
            child: Text('Reset Filters', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime))),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white.withValues(alpha: 0.15), size: 56),
            const SizedBox(height: 16),
            Text(
              'Failed to load news',
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _fetchArticles(reset: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)),
                child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openArticle(NewsArticle article) {
    if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppBrowserScreen(
            url: article.sourceUrl!,
            title: article.title,
          ),
        ),
      );
    } else {
      context.push('/newz/article/${article.id}');
    }
  }
}
