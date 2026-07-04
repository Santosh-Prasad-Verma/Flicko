import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/newz/data/news_article.dart';
import 'package:mobile/features/newz/data/news_service.dart';
import 'package:mobile/features/newz/presentation/in_app_browser_screen.dart';
import 'package:mobile/features/shared/presentation/widgets/pill_search_bar.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final NewsService _newsService = NewsService();
  NewsCategory _selectedCategory = NewsCategory.all;
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _accent = Color(0xFF52B788);
  static const Color _bgDark = Color(0xFF050505);
  static const Color _cardBg = Color(0xFF0F0F12);

  @override
  void initState() {
    super.initState();
    _fetchArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchArticles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final articles = await _newsService.fetchNews(
        category: _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onCategoryChanged(NewsCategory category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    _fetchArticles();
  }

  Future<void> _onRefresh() async {
    _newsService.clearCache();
    await _fetchArticles();
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

  @override
  Widget build(BuildContext context) {
    final articles = _filteredArticles;

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(),
            // Category tabs
            _buildCategoryBar(),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent))
                  : _error != null && articles.isEmpty
                      ? _buildErrorState()
                      : articles.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _onRefresh,
                              color: _accent,
                              backgroundColor: _cardBg,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: articles.length,
                                itemBuilder: (context, index) {
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: PillSearchBar(
        controller: _searchController,
        hintText: 'Search news, topics or authors...',
        onBackPressed: () => context.pop(),
        onChanged: (val) => setState(() => _searchQuery = val),
        onClear: () => setState(() => _searchQuery = ''),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accent : _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _accent
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                cat.displayName,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Large card layout matching the reference design:
  /// Full-width image on top, source logo + category tags below, title, bookmark icon
  Widget _buildNewsCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
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
                  // Gradient overlay for readability
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
                  // Source badge + Bookmark
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.newspaper_rounded,
                              color: Colors.white.withValues(alpha: 0.8), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            article.author.length > 20
                                ? '${article.author.substring(0, 20)}...'
                                : article.author,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
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
            // Content area below image
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
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
                  // Summary
                  Text(
                    article.summary,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Category tags + metadata row
                  Row(
                    children: [
                      // Category tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _accent.withValues(alpha: 0.25)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            article.publishDate,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.access_time_rounded,
                          color: Colors.white.withValues(alpha: 0.3), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        article.readTime,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.3),
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
          child: Icon(Icons.article_outlined,
              color: Colors.white.withValues(alpha: 0.1), size: 48),
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
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white.withValues(alpha: 0.1), size: 48),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_rounded,
              color: Colors.white.withValues(alpha: 0.15), size: 56),
          const SizedBox(height: 16),
          Text(
            'No articles found',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another category or search term',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 12,
            ),
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
            Icon(Icons.wifi_off_rounded,
                color: Colors.white.withValues(alpha: 0.15), size: 56),
            const SizedBox(height: 16),
            Text(
              'Failed to load news',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchArticles,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openArticle(NewsArticle article) {
    if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) {
      // Open in in-app browser
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppBrowserScreen(
            url: article.sourceUrl!,
            title: article.title,
          ),
        ),
      );
    } else {
      // Fallback: in-app detail screen for mock articles
      context.push('/newz/article/${article.id}');
    }
  }
}
