import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/newz/data/news_article.dart';

/// Service to fetch news from Currents API.
///
/// API docs: https://currentsapi.services/en/docs/
class NewsService {
  static const String _baseUrl = 'https://api.currentsapi.services/v1';

  /// Singleton instance
  static final NewsService _instance = NewsService._();
  factory NewsService() => _instance;
  NewsService._();

  /// Simple in-memory cache to avoid hammering the API.
  /// Key = category string, Value = (timestamp, articles).
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// Map our app categories to Currents API category strings.
  static const Map<NewsCategory, String?> _categoryMap = {
    NewsCategory.all: null, // no filter = latest news
    NewsCategory.tech: 'technology',
    NewsCategory.education: 'academia',
    NewsCategory.gaming: 'game',
    NewsCategory.entertainment: 'entertainment',
    NewsCategory.sports: 'sports',
    NewsCategory.science: 'science',
    NewsCategory.health: 'health',
    NewsCategory.business: 'business',
    NewsCategory.global: 'world',
  };

  /// Whether the API key is configured.
  bool get hasApiKey => AppConfig.currentsApiKey.isNotEmpty;

  /// Fetch latest news articles, optionally filtered by category.
  Future<List<NewsArticle>> fetchNews({
    NewsCategory category = NewsCategory.all,
  }) async {
    if (!hasApiKey) {
      return _getFallbackArticles(category);
    }

    final cacheKey = category.name;
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.articles;
    }

    try {
      final apiCategory = _categoryMap[category];
      final queryParams = <String, String>{
        'apiKey': AppConfig.currentsApiKey,
        'language': 'en',
        'page_size': '25',
      };
      if (apiCategory != null) {
        queryParams['category'] = apiCategory;
      }

      final uri = Uri.parse('$_baseUrl/latest-news').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw HttpException('Status ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final newsArray = data['news'] as List<dynamic>? ?? [];

      final articles = newsArray
          .map((item) => _parseArticle(item as Map<String, dynamic>, category))
          .where((a) => a != null)
          .cast<NewsArticle>()
          .toList();

      if (articles.isEmpty) {
        return _getFallbackArticles(category);
      }

      // Cache successful results
      _cache[cacheKey] = _CacheEntry(
        articles: articles,
        fetchedAt: DateTime.now(),
      );

      return articles;
    } catch (e) {
      // If we have stale cache, return it
      if (cached != null) return cached.articles;
      // Fallback to rich offline mock articles
      return _getFallbackArticles(category);
    }
  }

  /// Parse a single article from Currents API response.
  NewsArticle? _parseArticle(
    Map<String, dynamic> json,
    NewsCategory category,
  ) {
    try {
      final id = json['id'] as String? ?? '';
      final title = json['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final description = json['description'] as String? ?? '';
      final imageUrl = json['image'] as String? ?? '';
      final author = json['author'] as String? ?? 'Unknown';
      final published = json['published'] as String? ?? '';
      final url = json['url'] as String? ?? '';

      // Parse categories from the API to map to our enum
      final apiCategories = (json['category'] as List<dynamic>?)
              ?.map((c) => c.toString().toLowerCase())
              .toList() ??
          [];

      final mappedCategory = category != NewsCategory.all
          ? category
          : _inferCategory(apiCategories);

      // Estimate read time from description length
      final wordCount = description.split(' ').length;
      final readMinutes = (wordCount / 200).ceil().clamp(1, 15);

      // Format the date
      String formattedDate;
      try {
        final dt = DateTime.parse(published);
        formattedDate = _formatDate(dt);
      } catch (_) {
        formattedDate = published;
      }

      return NewsArticle(
        id: id.isNotEmpty ? id : url.hashCode.toString(),
        title: title,
        summary: description.length > 200
            ? '${description.substring(0, 200)}...'
            : description,
        content: description,
        imageUrl: imageUrl,
        category: mappedCategory,
        publishDate: formattedDate,
        author: author,
        readTime: '$readMinutes min read',
        sourceUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// Try to infer our category from the API's category tags.
  NewsCategory _inferCategory(List<String> apiCategories) {
    for (final cat in apiCategories) {
      if (cat.contains('tech') || cat.contains('programming')) {
        return NewsCategory.tech;
      }
      if (cat.contains('game') || cat.contains('gaming')) {
        return NewsCategory.gaming;
      }
      if (cat.contains('education') || cat.contains('academia')) {
        return NewsCategory.education;
      }
      if (cat.contains('entertainment') || cat.contains('movie')) {
        return NewsCategory.entertainment;
      }
      if (cat.contains('sport')) {
        return NewsCategory.sports;
      }
      if (cat.contains('science')) {
        return NewsCategory.science;
      }
      if (cat.contains('health') || cat.contains('medical')) {
        return NewsCategory.health;
      }
      if (cat.contains('business') || cat.contains('finance') || cat.contains('economy')) {
        return NewsCategory.business;
      }
      if (cat.contains('world') || cat.contains('general')) {
        return NewsCategory.global;
      }
    }
    return NewsCategory.global;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Clear the cache (useful for pull-to-refresh).
  void clearCache() => _cache.clear();

  List<NewsArticle> _getFallbackArticles(NewsCategory category) {
    final allFallback = [
      const NewsArticle(
        id: 'fallback_1',
        title: 'Next-Gen AI Models Revolutionize Real-Time Gaming & Voice Interactions',
        summary: 'State-of-the-art multimodal AI agents now power instant voice responses, dynamic NPC behaviors, and hyper-realistic gaming worlds.',
        content: 'Researchers and game developers have unveiled groundbreaking advancements in real-time voice AI and procedural world synthesis. By leveraging ultra-low latency transformer models, players can converse naturally with game environments in under 150 milliseconds.',
        imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
        category: NewsCategory.tech,
        publishDate: 'Jul 4, 2026',
        author: 'Tech Daily',
        readTime: '3 min read',
        sourceUrl: 'https://techcrunch.com',
      ),
      const NewsArticle(
        id: 'fallback_2',
        title: 'Global Esports Championship Reaches Record 50 Million Concurrent Viewers',
        summary: 'The world finals delivered intense match moments and unmatched arena atmosphere as underdog teams claimed victory.',
        content: 'This year\'s World Championship broke previous broadcast records, drawing millions of viewers worldwide. With strategic plays and clutch turnarounds, the grand finals set a new standard for competitive gaming history.',
        imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800',
        category: NewsCategory.gaming,
        publishDate: 'Jul 3, 2026',
        author: 'Esports Central',
        readTime: '4 min read',
        sourceUrl: 'https://ign.com',
      ),
      const NewsArticle(
        id: 'fallback_3',
        title: 'Breakthrough Quantum Computing Chips Achieved Unprecedented Fidelity',
        summary: 'Engineers achieve 99.9% gate fidelity on a 1,000-qubit processor, opening new doors for cryptography and molecular simulation.',
        content: 'Quantum processing hardware has hit a major milestone. The latest room-temperature silicon quantum chip handles complex error correction natively, paving the way for practical industrial applications.',
        imageUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800',
        category: NewsCategory.science,
        publishDate: 'Jul 2, 2026',
        author: 'Science Pulse',
        readTime: '5 min read',
        sourceUrl: 'https://sciencedaily.com',
      ),
      const NewsArticle(
        id: 'fallback_4',
        title: 'Streaming Platforms Adopt High-Definition Spatial Audio for Live Concerts',
        summary: 'Music enthusiasts can now experience 360-degree immersive acoustic performance directly from their mobile devices.',
        content: 'With multi-channel spatial audio encoding, live concert broadcasts now simulate full stadium acoustic reverberation, allowing listeners to reposition their virtual seat inside the venue.',
        imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800',
        category: NewsCategory.entertainment,
        publishDate: 'Jul 2, 2026',
        author: 'Media Wire',
        readTime: '3 min read',
        sourceUrl: 'https://billboard.com',
      ),
      const NewsArticle(
        id: 'fallback_5',
        title: 'Modern Developer Learning Paths Focus on Edge Computing & Distributed Systems',
        summary: 'Educational platforms report a 200% surge in enrollment for reactive microservices and real-time backend architecture courses.',
        content: 'As applications scale globally, developers are prioritizing low-latency edge compute, event-driven designs, and high-concurrency languages to deliver instantaneous user experiences.',
        imageUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800',
        category: NewsCategory.education,
        publishDate: 'Jul 1, 2026',
        author: 'Dev Insider',
        readTime: '4 min read',
        sourceUrl: 'https://dev.to',
      ),
      const NewsArticle(
        id: 'fallback_6',
        title: 'Global Tech Markets Experience Strong Growth Surrounding AI Ecosystems',
        summary: 'Venture investments in real-time collaboration platforms and developer productivity toolings hit record quarter highs.',
        content: 'Investor confidence remains high across developer infrastructure and enterprise communication suites, driven by demand for end-to-end security and real-time collaboration features.',
        imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800',
        category: NewsCategory.business,
        publishDate: 'Jul 1, 2026',
        author: 'Financial Times',
        readTime: '3 min read',
        sourceUrl: 'https://bloomberg.com',
      ),
      const NewsArticle(
        id: 'fallback_7',
        title: 'Wearable Health Trackers Integrate Real-Time Stress & Hydration Monitoring',
        summary: 'Next-gen sensors utilize non-invasive optical specs to provide continuous metabolic feedback to users.',
        content: 'Biometric wearables continue to evolve rapidly. The newest sensor algorithms alert users to micro-hydration changes and optical heart rate variations before physical fatigue sets in.',
        imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800',
        category: NewsCategory.health,
        publishDate: 'Jun 30, 2026',
        author: 'Health Tech Daily',
        readTime: '4 min read',
        sourceUrl: 'https://medicalnewstoday.com',
      ),
    ];

    if (category == NewsCategory.all) return allFallback;
    final filtered = allFallback.where((a) => a.category == category).toList();
    return filtered.isNotEmpty ? filtered : allFallback;
  }
}

class _CacheEntry {
  final List<NewsArticle> articles;
  final DateTime fetchedAt;

  _CacheEntry({required this.articles, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > NewsService._cacheTtl;
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}
