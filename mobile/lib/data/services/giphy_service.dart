import 'dart:convert';
import '../../core/config/app_config.dart';
import 'package:http/http.dart' as http;

/// GIPHY Service for GIF search and trending
/// 
/// Provides access to GIPHY API for searching and browsing GIFs.
/// Used in the GIF picker for chat messages.
class GiphyService {
  late final String _apiKey;
  late final String _baseUrl;
  
  // Rate limiting
  static const int _maxRequestsPerHour = 1000;
  int _requestCount = 0;
  DateTime _lastReset = DateTime.now();

  GiphyService() {
    _apiKey = AppConfig.giphyApiKey;
    _baseUrl = 'https://api.giphy.com/v1/gifs';
  }

  /// Reset rate limit counters
  void _resetRateLimitIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastReset).inHours >= 1) {
      _requestCount = 0;
      _lastReset = now;
    }
  }

  /// Check if rate limit is exceeded
  bool _isRateLimited() {
    _resetRateLimitIfNeeded();
    return _requestCount >= _maxRequestsPerHour;
  }

  /// Increment request counter
  void _incrementRequestCount() {
    _requestCount++;
  }

  /// Fetch trending GIFs
  /// 
  /// [limit] - Number of GIFs to fetch (default: 25, max: 100)
  /// [offset] - Pagination offset (default: 0)
  /// Returns a list of trending GIFs
  Future<List<GiphyGif>> getTrendingGifs({
    int limit = 25,
    int offset = 0,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GIPHY API key not configured');
    }

    if (_isRateLimited()) {
      throw Exception('Rate limit exceeded. Please try again later.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'api_key': _apiKey,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'rating': 'pg-13', // Safe for general use
      });

      final response = await http.get(uri);
      _incrementRequestCount();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final gifs = data['data'] as List;
        return gifs.map((gif) => GiphyGif.fromJson(gif)).toList();
      } else {
        throw Exception('Failed to fetch trending GIFs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('GIPHY API error: $e');
    }
  }

  /// Search for GIFs
  /// 
  /// [query] - Search query string
  /// [limit] - Number of GIFs to fetch (default: 25, max: 100)
  /// [offset] - Pagination offset (default: 0)
  /// Returns a list of matching GIFs
  Future<List<GiphyGif>> searchGifs(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GIPHY API key not configured');
    }

    if (_isRateLimited()) {
      throw Exception('Rate limit exceeded. Please try again later.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'api_key': _apiKey,
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'rating': 'pg-13',
      });

      final response = await http.get(uri);
      _incrementRequestCount();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final gifs = data['data'] as List;
        return gifs.map((gif) => GiphyGif.fromJson(gif)).toList();
      } else {
        throw Exception('Failed to search GIFs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('GIPHY API error: $e');
    }
  }

  /// Get GIF categories
  /// 
  /// Returns a list of available GIF categories
  Future<List<String>> getCategories() async {
    // GIPHY doesn't have a direct categories endpoint
    // Return common categories for filtering
    return [
      'reactions',
      'entertainment',
      'sports',
      'stickers',
      'artists',
      'gaming',
      'anime',
      'cartoons',
      'memes',
      'animals',
    ];
  }

  /// Check if GIPHY is properly configured
  bool get isConfigured => _apiKey.isNotEmpty;
}

/// GIPHY GIF model
class GiphyGif {
  final String id;
  final String title;
  final String url;
  final String? originalUrl;
  final String? fixedHeightUrl;
  final String? fixedWidthUrl;
  final String? previewUrl;

  GiphyGif({
    required this.id,
    required this.title,
    required this.url,
    this.originalUrl,
    this.fixedHeightUrl,
    this.fixedWidthUrl,
    this.previewUrl,
  });

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    
    return GiphyGif(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      originalUrl: images?['original']?['url'] as String?,
      fixedHeightUrl: images?['fixed_height']?['url'] as String?,
      fixedWidthUrl: images?['fixed_width']?['url'] as String?,
      previewUrl: images?['preview_gif']?['url'] as String?,
    );
  }

  /// Get the best URL for display based on context
  String get displayUrl => fixedHeightUrl ?? originalUrl ?? url;
  
  /// Get the preview URL for thumbnails
  String get thumbnailUrl => previewUrl ?? displayUrl;
}
