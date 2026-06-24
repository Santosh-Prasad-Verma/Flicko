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
      return [];
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

      // Cache successful results
      _cache[cacheKey] = _CacheEntry(
        articles: articles,
        fetchedAt: DateTime.now(),
      );

      return articles;
    } catch (e) {
      // If we have stale cache, return it rather than showing an error
      if (cached != null) return cached.articles;
      rethrow;
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
