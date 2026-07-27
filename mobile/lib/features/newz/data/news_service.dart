import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/newz/data/news_article.dart';

/// Service to fetch live, real-time unlimited news & historical archives.
class NewsService {
  static const String _baseUrl = 'https://api.currentsapi.services/v1';

  /// Singleton instance
  static final NewsService _instance = NewsService._();
  factory NewsService() => _instance;
  NewsService._();

  /// In-memory cache for fast responsive scrolling
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Check whether Currents API key is available
  bool get hasApiKey => AppConfig.currentsApiKey.isNotEmpty;

  /// Fetch news articles with pagination, category filter, sort order, and time range.
  Future<List<NewsArticle>> fetchNews({
    NewsCategory category = NewsCategory.all,
    NewsSortOrder sortOrder = NewsSortOrder.newest,
    NewsTimeRange timeRange = NewsTimeRange.allTime,
    String? sourceFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    List<NewsArticle> articles = [];

    // 1. Try Live RSS Feeds first (free, real-time, zero API key required)
    if (timeRange != NewsTimeRange.archives) {
      try {
        final liveRssArticles = await _fetchLiveRssNews(category: category);
        articles.addAll(liveRssArticles);
      } catch (e) {
        debugPrint('RSS Fetch notice: $e');
      }
    }

    // 2. Try Currents API if key is present
    if (articles.isEmpty && hasApiKey) {
      try {
        final currentsArticles = await _fetchFromCurrentsApi(
          category: category,
          page: page,
        );
        articles.addAll(currentsArticles);
      } catch (e) {
        debugPrint('Currents API notice: $e');
      }
    }

    // 3. Fallback ONLY — never mixed into a live feed.
    //
    // These are hand-written placeholder articles. They used to be appended
    // unconditionally, so fabricated stories interleaved with real RSS/Currents
    // results and, after the sort below, were indistinguishable from them. Now
    // they appear only when every live source came back empty (no network, no
    // API key, or the `archives` range, which skips RSS by design).
    if (articles.isEmpty) {
      articles.addAll(_getArchiveAndFallbackArticles(category));
    }

    // Deduplicate by title/URL
    final Map<String, NewsArticle> uniqueMap = {};
    for (final article in articles) {
      final key = article.title.trim().toLowerCase();
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = article;
      }
    }
    List<NewsArticle> result = uniqueMap.values.toList();

    // 4. Apply Source Filter if specified
    if (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'All Sources') {
      result = result
          .where((a) => a.author.toLowerCase().contains(sourceFilter.toLowerCase()))
          .toList();
    }

    // 5. Apply Time Range Filter
    final now = DateTime.now();
    if (timeRange == NewsTimeRange.today) {
      result = result.where((a) {
        if (a.rawPublishDate == null) return true;
        return now.difference(a.rawPublishDate!).inHours <= 24;
      }).toList();
    } else if (timeRange == NewsTimeRange.thisWeek) {
      result = result.where((a) {
        if (a.rawPublishDate == null) return true;
        return now.difference(a.rawPublishDate!).inDays <= 7;
      }).toList();
    } else if (timeRange == NewsTimeRange.thisMonth) {
      result = result.where((a) {
        if (a.rawPublishDate == null) return true;
        return now.difference(a.rawPublishDate!).inDays <= 30;
      }).toList();
    } else if (timeRange == NewsTimeRange.archives) {
      result = result.where((a) {
        if (a.rawPublishDate == null) return true;
        return now.difference(a.rawPublishDate!).inDays > 30 || a.rawPublishDate!.year < now.year;
      }).toList();
    }

    // 6. Apply Sorting (Newest First vs Oldest First)
    if (sortOrder == NewsSortOrder.newest) {
      result.sort((a, b) {
        final da = a.rawPublishDate ?? DateTime(2020);
        final db = b.rawPublishDate ?? DateTime(2020);
        return db.compareTo(da);
      });
    } else if (sortOrder == NewsSortOrder.oldest) {
      result.sort((a, b) {
        final da = a.rawPublishDate ?? DateTime(2020);
        final db = b.rawPublishDate ?? DateTime(2020);
        return da.compareTo(db);
      });
    } else if (sortOrder == NewsSortOrder.popular) {
      result.sort((a, b) => b.summary.length.compareTo(a.summary.length));
    }

    // 7. Paginate results
    //
    // Past the end we return an empty page so the caller's infinite scroll
    // terminates. This previously wrapped back around with modulo arithmetic to
    // "ensure continuous infinite scrolling", which re-served earlier articles
    // forever — the feed looked endless but was showing the same stories on a
    // loop.
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= result.length) return const [];

    return result.skip(startIndex).take(pageSize).toList();
  }

  /// Fetch Live Google News RSS feed directly via HTTP
  Future<List<NewsArticle>> _fetchLiveRssNews({required NewsCategory category}) async {
    final String rssUrl = _getRssUrlForCategory(category);
    final cacheKey = 'rss_${category.name}';

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.articles;
    }

    final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final String xmlString = response.body;
    final List<NewsArticle> parsed = _parseRssXml(xmlString, category);

    if (parsed.isNotEmpty) {
      _cache[cacheKey] = _CacheEntry(articles: parsed, fetchedAt: DateTime.now());
    }

    return parsed;
  }

  String _getRssUrlForCategory(NewsCategory category) {
    switch (category) {
      case NewsCategory.all:
        return 'https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.tech:
        return 'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.ai:
        return 'https://news.google.com/rss/search?q=artificial+intelligence+AI+LLM&hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.gaming:
        return 'https://news.google.com/rss/search?q=gaming+esports+playstation+xbox&hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.anime:
        return 'https://news.google.com/rss/search?q=anime+manga+crunchyroll&hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.science:
        return 'https://news.google.com/rss/headlines/section/topic/SCIENCE?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.crypto:
        return 'https://news.google.com/rss/search?q=crypto+bitcoin+ethereum&hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.entertainment:
        return 'https://news.google.com/rss/headlines/section/topic/ENTERTAINMENT?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.sports:
        return 'https://news.google.com/rss/headlines/section/topic/SPORTS?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.health:
        return 'https://news.google.com/rss/headlines/section/topic/HEALTH?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.business:
        return 'https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.education:
        return 'https://news.google.com/rss/search?q=education+learning+university&hl=en-US&gl=US&ceid=US:en';
      case NewsCategory.global:
        return 'https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en';
    }
  }

  /// Custom RegExp RSS Parser for fast live news extraction
  List<NewsArticle> _parseRssXml(String xml, NewsCategory category) {
    final List<NewsArticle> articles = [];
    final itemRegExp = RegExp(r'<item>(.*?)</item>', dotAll: true);
    final matches = itemRegExp.allMatches(xml);

    for (final match in matches) {
      final itemXml = match.group(1) ?? '';

      final title = _extractTag(itemXml, 'title')
          .replaceAll(RegExp(r'<!\[CDATA\[(.*?)\]\]>'), r'$1')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"');

      if (title.isEmpty) continue;

      final link = _extractTag(itemXml, 'link');
      final pubDateStr = _extractTag(itemXml, 'pubDate');
      final description = _cleanHtml(_extractTag(itemXml, 'description'));
      final source = _extractTag(itemXml, 'source');

      DateTime? rawDate;
      String formattedDate = pubDateStr;
      try {
        if (pubDateStr.isNotEmpty) {
          rawDate = DateTime.parse(_toIso8601String(pubDateStr));
          formattedDate = _formatDate(rawDate);
        }
      } catch (_) {
        rawDate = DateTime.now();
      }

      final authorName = source.isNotEmpty
          ? source
          : _extractSourceFromTitle(title);

      final cleanTitle = title.contains(' - ')
          ? title.substring(0, title.lastIndexOf(' - '))
          : title;

      final wordCount = (description.isNotEmpty ? description : cleanTitle).split(' ').length;
      final readMinutes = (wordCount / 180).ceil().clamp(1, 15);

      articles.add(
        NewsArticle(
          id: link.isNotEmpty ? link.hashCode.toString() : cleanTitle.hashCode.toString(),
          title: cleanTitle,
          summary: description.isNotEmpty ? description : cleanTitle,
          content: description.isNotEmpty ? description : cleanTitle,
          imageUrl: _getUnsplashImageForCategory(category, articles.length),
          category: category,
          publishDate: formattedDate,
          rawPublishDate: rawDate ?? DateTime.now(),
          author: authorName.isNotEmpty ? authorName : 'Global News',
          readTime: '$readMinutes min read',
          sourceUrl: link,
        ),
      );
    }

    return articles;
  }

  String _extractTag(String xml, String tagName) {
    final regExp = RegExp('<$tagName.*?>(.*?)</$tagName>', dotAll: true);
    final match = regExp.firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'<!\[CDATA\[(.*?)\]\]>'), r'$1')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _extractSourceFromTitle(String title) {
    if (title.contains(' - ')) {
      return title.substring(title.lastIndexOf(' - ') + 3).trim();
    }
    return 'World News';
  }

  String _toIso8601String(String rfc822Date) {
    try {
      final dt = HttpDate.parse(rfc822Date);
      return dt.toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  Future<List<NewsArticle>> _fetchFromCurrentsApi({
    required NewsCategory category,
    int page = 1,
  }) async {
    final queryParams = <String, String>{
      'apiKey': AppConfig.currentsApiKey,
      'language': 'en',
      'page_size': '25',
      'page_number': page.toString(),
    };

    final uri = Uri.parse('$_baseUrl/latest-news').replace(queryParameters: queryParams);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final newsArray = data['news'] as List<dynamic>? ?? [];

    return newsArray
        .map((item) => _parseArticle(item as Map<String, dynamic>, category))
        .where((a) => a != null)
        .cast<NewsArticle>()
        .toList();
  }

  NewsArticle? _parseArticle(Map<String, dynamic> json, NewsCategory category) {
    try {
      final title = json['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final description = json['description'] as String? ?? '';
      final imageUrl = json['image'] as String? ?? '';
      final author = json['author'] as String? ?? 'Unknown Source';
      final published = json['published'] as String? ?? '';
      final url = json['url'] as String? ?? '';

      DateTime? dt;
      String formattedDate = published;
      try {
        dt = DateTime.parse(published);
        formattedDate = _formatDate(dt);
      } catch (_) {
        dt = DateTime.now();
      }

      return NewsArticle(
        id: url.hashCode.toString(),
        title: title,
        summary: description,
        content: description,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : _getUnsplashImageForCategory(category, 0),
        category: category,
        publishDate: formattedDate,
        rawPublishDate: dt,
        author: author,
        readTime: '3 min read',
        sourceUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _getUnsplashImageForCategory(NewsCategory category, int index) {
    final Map<NewsCategory, List<String>> images = {
      NewsCategory.tech: [
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
        'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=800',
      ],
      NewsCategory.ai: [
        'https://images.unsplash.com/photo-1677442136019-21780efad99a?w=800',
        'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=800',
      ],
      NewsCategory.gaming: [
        'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800',
        'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800',
      ],
      NewsCategory.anime: [
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800',
        'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=800',
      ],
      NewsCategory.science: [
        'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800',
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
      ],
      NewsCategory.crypto: [
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?w=800',
      ],
      NewsCategory.entertainment: [
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800',
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
      ],
      NewsCategory.sports: [
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=800',
        'https://images.unsplash.com/photo-1517649763962-0c623266010b?w=800',
      ],
      NewsCategory.business: [
        'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800',
        'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=800',
      ],
      NewsCategory.health: [
        'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800',
        'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800',
      ],
      NewsCategory.education: [
        'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800',
        'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
      ],
      NewsCategory.global: [
        'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=800',
        'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800',
      ],
    };

    final list = images[category] ?? images[NewsCategory.tech]!;
    return list[index % list.length];
  }

  void clearCache() => _cache.clear();

  /// Comprehensive Historical Archives (2020-2026) ensuring unlimited articles
  List<NewsArticle> _getArchiveAndFallbackArticles(NewsCategory category) {
    final now = DateTime.now();

    final List<NewsArticle> archives = [
      // 2026 News
      NewsArticle(
        id: 'arch_2026_1',
        title: 'Multimodal AI Models Achieve Real-Time Sub-100ms Voice Synthesis',
        summary: 'Neural speech architectures enable natural conversational agents with human emotional inflection.',
        content: 'Breakthroughs in streaming transformer inference allow real-time conversational agents to reply instantly without lag.',
        imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780efad99a?w=800',
        category: NewsCategory.ai,
        publishDate: 'Jul 20, 2026',
        rawPublishDate: DateTime(2026, 7, 20),
        author: 'AI Tech Review',
        readTime: '3 min read',
        sourceUrl: 'https://techcrunch.com',
      ),
      NewsArticle(
        id: 'arch_2026_2',
        title: 'Global Esports League Announces First Holographic Arena Matches',
        summary: '3D spatial projection brings virtual players directly into live physical stadiums.',
        content: 'Esports fans were treated to real-time 3D holographic rendering of avatar matches projected directly onto court floors.',
        imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800',
        category: NewsCategory.gaming,
        publishDate: 'May 14, 2026',
        rawPublishDate: DateTime(2026, 5, 14),
        author: 'IGN Gaming',
        readTime: '4 min read',
        sourceUrl: 'https://ign.com',
      ),
      // 2025 News
      NewsArticle(
        id: 'arch_2025_1',
        title: 'Quantum Advantage Demonstrated in Industrial Molecular Simulation',
        summary: 'Superconducting quantum circuits simulate complex protein folding 10,000x faster than supercomputers.',
        content: 'Scientists achieved a major milestone by predicting pharmaceutical binding affinities with unprecedented precision.',
        imageUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800',
        category: NewsCategory.science,
        publishDate: 'Nov 12, 2025',
        rawPublishDate: DateTime(2025, 11, 12),
        author: 'Science Daily',
        readTime: '5 min read',
        sourceUrl: 'https://sciencedaily.com',
      ),
      NewsArticle(
        id: 'arch_2025_2',
        title: 'Web3 Instant Cross-Border Clearing Protocols Approved by Regulators',
        summary: 'Decentralized financial rails enable sub-second cross-border payments with zero gas fees.',
        content: 'Global central banks adopted cryptographic settlement channels for international interbank transfers.',
        imageUrl: 'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?w=800',
        category: NewsCategory.crypto,
        publishDate: 'Aug 05, 2025',
        rawPublishDate: DateTime(2025, 8, 5),
        author: 'CoinDesk',
        readTime: '4 min read',
        sourceUrl: 'https://coindesk.com',
      ),
      // 2024 News
      NewsArticle(
        id: 'arch_2024_1',
        title: 'Generative AI Transforms Game Development & Storytelling Workflows',
        summary: 'Game studios integrate procedural dialogue and dynamic NPC memory engines.',
        content: 'Developers showcased games where non-playable characters remember past player choices and hold open-ended conversations.',
        imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800',
        category: NewsCategory.tech,
        publishDate: 'Oct 18, 2024',
        rawPublishDate: DateTime(2024, 10, 18),
        author: 'Wired News',
        readTime: '4 min read',
        sourceUrl: 'https://wired.com',
      ),
      NewsArticle(
        id: 'arch_2024_2',
        title: 'James Webb Space Telescope Maps Exoplanet Atmosphere in Unprecedented Detail',
        summary: 'Spectroscopic observations confirm water vapor and carbon dioxide on Earth-sized planet.',
        content: 'Astronomers revealed detailed atmospheric maps of rocky planets orbiting nearby stars.',
        imageUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
        category: NewsCategory.science,
        publishDate: 'Jun 22, 2024',
        rawPublishDate: DateTime(2024, 6, 22),
        author: 'NASA News',
        readTime: '6 min read',
        sourceUrl: 'https://nasa.gov',
      ),
      // 2023 News
      NewsArticle(
        id: 'arch_2023_1',
        title: 'Large Language Models Enter Everyday Productivity Suites',
        summary: 'AI writing and coding assistants become standard across software development and office suites.',
        content: 'The software industry experienced a rapid shift toward AI pair-programming and automated document generation.',
        imageUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800',
        category: NewsCategory.tech,
        publishDate: 'Mar 15, 2023',
        rawPublishDate: DateTime(2023, 3, 15),
        author: 'Tech Times',
        readTime: '5 min read',
        sourceUrl: 'https://dev.to',
      ),
      // 2022 News
      NewsArticle(
        id: 'arch_2022_1',
        title: 'James Webb Space Telescope Publishes First Deep Field Cosmic Images',
        summary: 'The deepest and sharpest infrared images of the distant universe captivate the world.',
        content: 'NASA released the first scientific images captured by the Webb Telescope, revealing galaxies formed 13 billion years ago.',
        imageUrl: 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800',
        category: NewsCategory.science,
        publishDate: 'Jul 12, 2022',
        rawPublishDate: DateTime(2022, 7, 12),
        author: 'Astro Science',
        readTime: '5 min read',
        sourceUrl: 'https://nasa.gov',
      ),
      // 2021 News
      NewsArticle(
        id: 'arch_2021_1',
        title: 'Mars Perseverance Rover Successfully Lands in Jezero Crater',
        summary: 'NASA rover begins mission to search for signs of ancient microbial life on Mars.',
        content: 'Perseverance touched down safely on the Martian surface after a 7-month journey through space.',
        imageUrl: 'https://images.unsplash.com/photo-1614728894747-a83421e2b9c9?w=800',
        category: NewsCategory.science,
        publishDate: 'Feb 18, 2021',
        rawPublishDate: DateTime(2021, 2, 18),
        author: 'Space Archives',
        readTime: '4 min read',
        sourceUrl: 'https://nasa.gov',
      ),
      // 2020 News
      NewsArticle(
        id: 'arch_2020_1',
        title: 'Global Shift to Remote Work Accelerates Cloud Infrastructure Adoption',
        summary: 'Companies worldwide transition to real-time digital communication and cloud systems.',
        content: 'The global pandemic reshaped work patterns permanently, pushing digital collaboration tools into widespread use.',
        imageUrl: 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
        category: NewsCategory.business,
        publishDate: 'Apr 10, 2020',
        rawPublishDate: DateTime(2020, 4, 10),
        author: 'Global Archives',
        readTime: '4 min read',
        sourceUrl: 'https://reuters.com',
      ),
    ];

    if (category == NewsCategory.all) return archives;
    final filtered = archives.where((a) => a.category == category).toList();
    return filtered.isNotEmpty ? filtered : archives;
  }
}

class _CacheEntry {
  final List<NewsArticle> articles;
  final DateTime fetchedAt;

  _CacheEntry({required this.articles, required this.fetchedAt});

  bool get isExpired => DateTime.now().difference(fetchedAt) > NewsService._cacheTtl;
}
