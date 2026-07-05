import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:mobile/features/newz/data/news_article.dart';
import 'package:mobile/features/newz/data/news_service.dart';
import 'package:mobile/features/newz/presentation/in_app_browser_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final String articleId;

  const NewsDetailScreen({
    super.key,
    required this.articleId,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  NewsArticle? _article;
  bool _isLoading = true;

  Color get _accent => GetIt.I<MyTheme>().currentColor();
  static const Color _bgDark = Color(0xFF07040A);
  static const Color _cardBg = Color(0xFF0F0F12);

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    final articles = await NewsService().fetchNews();
    NewsArticle? found;
    try {
      found = articles.firstWhere((a) => a.id == widget.articleId);
    } catch (_) {
      if (articles.isNotEmpty) {
        found = articles.first;
      }
    }

    if (mounted) {
      setState(() {
        _article = found;
        _isLoading = false;
      });
    }
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    final article = _article;

    if (article == null) {
      return Scaffold(
        backgroundColor: _bgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Article not found',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildLiquidGlassBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _cardBg,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (article.imageUrl.isNotEmpty)
                    Image.network(
                      article.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: _cardBg),
                    )
                  else
                    Container(color: _cardBg),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _bgDark.withValues(alpha: 0.8),
                          _bgDark,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          article.category.displayName,
                          style: GoogleFonts.inter(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        article.readTime,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        article.publishDate,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    article.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: _accent.withValues(alpha: 0.2),
                        child: Text(
                          article.author.isNotEmpty ? article.author[0].toUpperCase() : 'N',
                          style: GoogleFonts.inter(color: _accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.author,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      article.summary,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    article.content,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InAppBrowserScreen(
                                url: article.sourceUrl!,
                                title: article.title,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                        label: Text(
                          'Read Original Story',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
