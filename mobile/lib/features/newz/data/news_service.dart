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
    final now = DateTime.now();
    String dateStr(int daysAgo) {
      final dt = now.subtract(Duration(days: daysAgo));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    final allFallback = [
      NewsArticle(
        id: 'news_tech_1',
        title: 'Next-Gen AI Models Revolutionize Real-Time Gaming & Voice Interactions',
        summary: 'State-of-the-art multimodal AI agents now power instant voice responses, dynamic NPC behaviors, and hyper-realistic gaming worlds.',
        content: 'Researchers and game developers have unveiled groundbreaking advancements in real-time voice AI and procedural world synthesis. By leveraging ultra-low latency transformer models, players can converse naturally with game environments in under 150 milliseconds.',
        imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
        category: NewsCategory.tech,
        publishDate: dateStr(0),
        author: 'Tech Daily',
        readTime: '3 min read',
        sourceUrl: 'https://techcrunch.com',
      ),
      NewsArticle(
        id: 'news_tech_2',
        title: 'Silicon Photonics Breakthrough Enables 10x Faster Data Center Connections',
        summary: 'Optical interconnects replace traditional copper wires, reducing latency and energy consumption across global cloud clusters.',
        content: 'Major hardware manufacturers have announced mass production of silicon photonic chips. By using light instead of electricity to transmit data between server racks, throughput jumps tenfold while power draw drops by 40%.',
        imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        category: NewsCategory.tech,
        publishDate: dateStr(1),
        author: 'Wired Tech',
        readTime: '4 min read',
        sourceUrl: 'https://wired.com',
      ),
      NewsArticle(
        id: 'news_tech_3',
        title: 'Open Source Spatial Audio Protocol Standardized for Web Browsers',
        summary: 'WebXR working group releases universal standard for high-fidelity 3D spatial acoustics in progressive web applications.',
        content: 'The new browser audio standard allows web developers to render 360-degree positional audio using hardware acceleration without requiring third-party plugins or native desktop wrappers.',
        imageUrl: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=800',
        category: NewsCategory.tech,
        publishDate: dateStr(2),
        author: 'Web Dev Times',
        readTime: '3 min read',
        sourceUrl: 'https://dev.to',
      ),
      NewsArticle(
        id: 'news_gaming_1',
        title: 'Global Esports Championship Reaches Record 50 Million Concurrent Viewers',
        summary: 'The world finals delivered intense match moments and unmatched arena atmosphere as underdog teams claimed victory.',
        content: 'This year\'s World Championship broke previous broadcast records, drawing millions of viewers worldwide. With strategic plays and clutch turnarounds, the grand finals set a new standard for competitive gaming history.',
        imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800',
        category: NewsCategory.gaming,
        publishDate: dateStr(0),
        author: 'Esports Central',
        readTime: '4 min read',
        sourceUrl: 'https://ign.com',
      ),
      NewsArticle(
        id: 'news_gaming_2',
        title: 'Next-Gen Game Engines Introduce AI Procedural Quest Generation',
        summary: 'Game narrative design leaps forward as engines generate dynamic storylines adapted in real time to player choices.',
        content: 'Developers demonstrated dynamic narrative engines where questlines, voice acting, and dialogue trees are computed procedurally on the fly based on player reputation and historical choices.',
        imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800',
        category: NewsCategory.gaming,
        publishDate: dateStr(1),
        author: 'Polygon',
        readTime: '5 min read',
        sourceUrl: 'https://polygon.com',
      ),
      NewsArticle(
        id: 'news_gaming_3',
        title: 'Cross-Platform VR Haptics Gear Unveiled for Competitive Arena Games',
        summary: 'Ultra-lightweight haptic vests and gloves deliver tactile force feedback with millisecond precision.',
        content: 'Hardware pioneers revealed new consumer haptic accessories featuring high-density micro-actuators that simulate recoil, impacts, and environmental textures directly on the player\'s body.',
        imageUrl: 'https://images.unsplash.com/photo-1592478411213-6153e4ebc07d?w=800',
        category: NewsCategory.gaming,
        publishDate: dateStr(2),
        author: 'VR Focus',
        readTime: '3 min read',
        sourceUrl: 'https://kotaku.com',
      ),
      NewsArticle(
        id: 'news_science_1',
        title: 'Breakthrough Quantum Computing Chips Achieved Unprecedented Fidelity',
        summary: 'Engineers achieve 99.9% gate fidelity on a 1,000-qubit processor, opening new doors for cryptography and molecular simulation.',
        content: 'Quantum processing hardware has hit a major milestone. The latest room-temperature silicon quantum chip handles complex error correction natively, paving the way for practical industrial applications.',
        imageUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800',
        category: NewsCategory.science,
        publishDate: dateStr(0),
        author: 'Science Pulse',
        readTime: '5 min read',
        sourceUrl: 'https://sciencedaily.com',
      ),
      NewsArticle(
        id: 'news_science_2',
        title: 'James Webb Space Telescope Identifies Potential Atmospheric Water Vapor on Exoplanet',
        summary: 'Spectroscopic analysis reveals clear signatures of water vapor and methane in the atmosphere of a habitable-zone planet.',
        content: 'Astronomers processing transmission spectra from the Webb Space Telescope confirmed rich atmospheric composition in a Earth-sized exoplanet orbiting a quiet red dwarf star 40 light-years away.',
        imageUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
        category: NewsCategory.science,
        publishDate: dateStr(1),
        author: 'Astro Science',
        readTime: '6 min read',
        sourceUrl: 'https://nasa.gov',
      ),
      NewsArticle(
        id: 'news_entertainment_1',
        title: 'Streaming Platforms Adopt High-Definition Spatial Audio for Live Concerts',
        summary: 'Music enthusiasts can now experience 360-degree immersive acoustic performance directly from their mobile devices.',
        content: 'With multi-channel spatial audio encoding, live concert broadcasts now simulate full stadium acoustic reverberation, allowing listeners to reposition their virtual seat inside the venue.',
        imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800',
        category: NewsCategory.entertainment,
        publishDate: dateStr(0),
        author: 'Media Wire',
        readTime: '3 min read',
        sourceUrl: 'https://billboard.com',
      ),
      NewsArticle(
        id: 'news_entertainment_2',
        title: 'Interactive Virtual Film Festivals Premiere Award-Winning VR Shorts',
        summary: 'Filmmakers showcase immersive cinematic experiences where audiences control perspective and branching storylines.',
        content: 'This year\'s independent film festival featured VR narrative shorts that merge cinematic directing with real-time graphics rendering, winning critical acclaim for emotional immersion.',
        imageUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
        category: NewsCategory.entertainment,
        publishDate: dateStr(2),
        author: 'Cinema Today',
        readTime: '4 min read',
        sourceUrl: 'https://variety.com',
      ),
      NewsArticle(
        id: 'news_education_1',
        title: 'Modern Developer Learning Paths Focus on Edge Computing & Distributed Systems',
        summary: 'Educational platforms report a 200% surge in enrollment for reactive microservices and real-time backend architecture courses.',
        content: 'As applications scale globally, developers are prioritizing low-latency edge compute, event-driven designs, and high-concurrency languages to deliver instantaneous user experiences.',
        imageUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800',
        category: NewsCategory.education,
        publishDate: dateStr(0),
        author: 'Dev Insider',
        readTime: '4 min read',
        sourceUrl: 'https://dev.to',
      ),
      NewsArticle(
        id: 'news_education_2',
        title: 'Universities Launch Open Access Interactive Coding & Systems Labs',
        summary: 'Top computer science departments publish free cloud environments for learning web architecture and cloud security.',
        content: 'Students and self-taught software engineers can now access interactive sandboxes to build distributed databases, design API gateways, and practice hands-on cybersecurity scenarios.',
        imageUrl: 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
        category: NewsCategory.education,
        publishDate: dateStr(1),
        author: 'Academic Computing',
        readTime: '5 min read',
        sourceUrl: 'https://mit.edu',
      ),
      NewsArticle(
        id: 'news_business_1',
        title: 'Global Tech Markets Experience Strong Growth Surrounding AI Ecosystems',
        summary: 'Venture investments in real-time collaboration platforms and developer productivity toolings hit record quarter highs.',
        content: 'Investor confidence remains high across developer infrastructure and enterprise communication suites, driven by demand for end-to-end security and real-time collaboration features.',
        imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800',
        category: NewsCategory.business,
        publishDate: dateStr(0),
        author: 'Financial Times',
        readTime: '3 min read',
        sourceUrl: 'https://bloomberg.com',
      ),
      NewsArticle(
        id: 'news_business_2',
        title: 'Fintech Platforms Upgrade to Real-Time Instant Settlement Networks',
        summary: 'Cross-border payment clearing times drop from days to seconds with cryptographic validation protocols.',
        content: 'Commercial banks and digital payment providers are migrating core ledgers to high-speed settlement engines, allowing instant global money transfers with lower transaction fees.',
        imageUrl: 'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=800',
        category: NewsCategory.business,
        publishDate: dateStr(2),
        author: 'Business Digest',
        readTime: '4 min read',
        sourceUrl: 'https://wsj.com',
      ),
      NewsArticle(
        id: 'news_health_1',
        title: 'Wearable Health Trackers Integrate Real-Time Stress & Hydration Monitoring',
        summary: 'Next-gen sensors utilize non-invasive optical specs to provide continuous metabolic feedback to users.',
        content: 'Biometric wearables continue to evolve rapidly. The newest sensor algorithms alert users to micro-hydration changes and optical heart rate variations before physical fatigue sets in.',
        imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800',
        category: NewsCategory.health,
        publishDate: dateStr(0),
        author: 'Health Tech Daily',
        readTime: '4 min read',
        sourceUrl: 'https://medicalnewstoday.com',
      ),
      NewsArticle(
        id: 'news_health_2',
        title: 'AI Drug Discovery Platform Predicts Target Protein Binding Structures',
        summary: 'Biotech researchers accelerate therapeutic candidate identification by screening billions of molecular compounds digitally.',
        content: 'Deep learning models trained on structural biology databases have successfully designed novel peptide candidates that bind selectively to target receptors, cutting initial discovery timelines by over 70%.',
        imageUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800',
        category: NewsCategory.health,
        publishDate: dateStr(1),
        author: 'BioTech World',
        readTime: '5 min read',
        sourceUrl: 'https://nature.com',
      ),
      NewsArticle(
        id: 'news_sports_1',
        title: 'Smart Stadiums Deploy Ultra-Wideband Radar for Real-Time Player Biometrics',
        summary: 'Sports analytics platforms broadcast instantaneous acceleration, sprint speeds, and heart rate telemetry during live games.',
        content: 'Fans and coaches can now view real-time performance heatmaps and physical fatigue metrics during professional athletic competitions thanks to millimeter-wave radar sensors installed across stadium ceilings.',
        imageUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=800',
        category: NewsCategory.sports,
        publishDate: dateStr(0),
        author: 'Sports Tech Journal',
        readTime: '3 min read',
        sourceUrl: 'https://espn.com',
      ),
      NewsArticle(
        id: 'news_sports_2',
        title: 'High-Altitude Training Centers Adopt Atmospheric Simulation Capsules',
        summary: 'Olympic athletes utilize controlled oxygen environments to boost aerobic endurance without traveling to mountain ranges.',
        content: 'Sports scientists have built environmental chambers that regulate barometric pressure and oxygen concentration, enabling endurance athletes to simulate high-altitude conditioning right inside their training facilities.',
        imageUrl: 'https://images.unsplash.com/photo-1517649763962-0c623266010b?w=800',
        category: NewsCategory.sports,
        publishDate: dateStr(2),
        author: 'Athlete Performance',
        readTime: '4 min read',
        sourceUrl: 'https://sportsillustrated.com',
      ),
      NewsArticle(
        id: 'news_global_1',
        title: 'International Climate Summit Agrees on Renewable Grid Interconnection Standards',
        summary: 'Over 40 countries ratify unified protocols for continental clean energy transmission networks.',
        content: 'Delegates at the global climate summit completed negotiations on cross-border electrical grid standards, enabling excess wind and solar energy generated in coastal regions to be routed seamlessly across continental distances.',
        imageUrl: 'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=800',
        category: NewsCategory.global,
        publishDate: dateStr(0),
        author: 'World News Report',
        readTime: '4 min read',
        sourceUrl: 'https://reuters.com',
      ),
      NewsArticle(
        id: 'news_global_2',
        title: 'Global Satellite Constellation Reaches Universal Low-Latency Broadband Coverage',
        summary: 'Remote maritime and rural regions gain access to gigabit internet via low-Earth-orbit satellite meshes.',
        content: 'Aerospace providers confirmed full operational status of low-Earth-orbit satellite networks, providing stable high-speed connectivity to isolated schools, research stations, and maritime vessels across the globe.',
        imageUrl: 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800',
        category: NewsCategory.global,
        publishDate: dateStr(1),
        author: 'Global Tech Post',
        readTime: '5 min read',
        sourceUrl: 'https://apnews.com',
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
