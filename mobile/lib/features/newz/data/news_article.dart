import 'package:flutter/material.dart';

enum NewsCategory {
  all,
  tech,
  gaming,
  updates,
  global,
}

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.all:
        return 'ALL';
      case NewsCategory.tech:
        return 'TECH';
      case NewsCategory.gaming:
        return 'GAMING';
      case NewsCategory.updates:
        return 'UPDATES';
      case NewsCategory.global:
        return 'GLOBAL';
    }
  }

  IconData get icon {
    switch (this) {
      case NewsCategory.all:
        return Icons.grid_view_rounded;
      case NewsCategory.tech:
        return Icons.biotech_rounded;
      case NewsCategory.gaming:
        return Icons.sports_esports_rounded;
      case NewsCategory.updates:
        return Icons.system_update_alt_rounded;
      case NewsCategory.global:
        return Icons.language_rounded;
    }
  }
}

class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String imageUrl;
  final NewsCategory category;
  final String publishDate;
  final String author;
  final String readTime;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.imageUrl,
    required this.category,
    required this.publishDate,
    required this.author,
    required this.readTime,
  });

  static const List<NewsArticle> mockArticles = [
    NewsArticle(
      id: 'news-1',
      title: 'Flicko v2.4 Release: Aura AI Web Navigation Unleashed',
      summary: 'Our edge AI assistant now has online web search capabilities to answer queries with up-to-the-minute real-world info.',
      content: 'We are thrilled to announce Flicko v2.4, our biggest update this season. In this release, we have integrated a custom DuckDuckGo search loop inside the Aura AI Edge Function, allowing Aura to fetch and process live web pages in real-time. Additionally, we have stripped Chess from our Gaming Hub to focus entirely on local and multiplayer Ludo Royale. Experience ultra-fast chat synchronization, optimized CPU layouts, and lower battery consumption across devices.',
      imageUrl: 'assets/images/gaming/cyber_ninja.png',
      category: NewsCategory.updates,
      publishDate: 'June 21, 2026',
      author: 'Flicko Core Team',
      readTime: '3 min read',
    ),
    NewsArticle(
      id: 'news-2',
      title: 'Ludo Royale Grand Championship Kicks Off This Weekend',
      summary: 'Join thousands of board game enthusiasts in the ultimate Ludo competition with massive neon cosmetics up for grabs.',
      content: 'Flicko Gaming Hub is proud to host the first annual Ludo Royale Grand Championship! Play matches, increase your ELO rating, and unlock exclusive rewards. The top 50 players on the global leaderboard by Sunday evening will receive the rare Gold Crucible Badge to display on their Flicko profiles. Best of all, all matches played locally or online will contribute to your profile statistics.',
      imageUrl: 'assets/ludo/images/card-logo.png',
      category: NewsCategory.gaming,
      publishDate: 'June 20, 2026',
      author: 'Valkyrie (Pro Lead)',
      readTime: '2 min read',
    ),
    NewsArticle(
      id: 'news-3',
      title: 'Decentralized AI Agents and the Future of Messaging Protocols',
      summary: 'How Edge Functions and open-weight LLMs are transforming private channels into collaborative autonomous spaces.',
      content: 'Traditional messaging networks rely on centralized bots that operate in isolated clouds. With Flicko, we are introducing decentralization concepts directly to the front-end interface. By deploying lightweight, sandboxed models directly onto local client nodes and invoking edge instances for complex reasoning, we are creating private, serverless-first team environments where security is guaranteed and computational latency is reduced by up to 40%.',
      imageUrl: 'assets/images/about_developer.html',
      category: NewsCategory.tech,
      publishDate: 'June 18, 2026',
      author: 'Dr. Tarun Prasad',
      readTime: '5 min read',
    ),
    NewsArticle(
      id: 'news-4',
      title: 'Global Trends: The Rise of Minimalist UI in High-Fidelity Social Hubs',
      summary: 'Why developers are moving away from heavy futuristic particle trails and neon glows towards sleek, ultra-clean glassmorphic cards.',
      content: 'In 2026, web and mobile aesthetics are undergoing a major shift. The era of over-the-top, spinning circular indicators, neon glows, and customizer-heavy color pickers is winding down. Users now value fast-loading interfaces, structural clarity, high typographic hierarchy, and responsive minimalism. Discover how the latest Flutter SDK enables developers to design premium dark modes using frosted backdrops without compromising rendering pipeline performance.',
      imageUrl: 'assets/cover.jpg',
      category: NewsCategory.global,
      publishDate: 'June 15, 2026',
      author: 'Design Studio',
      readTime: '4 min read',
    ),
  ];
}
