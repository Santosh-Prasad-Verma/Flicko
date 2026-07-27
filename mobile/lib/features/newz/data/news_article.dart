import 'package:flutter/material.dart';

enum NewsCategory {
  all,
  tech,
  ai,
  gaming,
  anime,
  science,
  crypto,
  entertainment,
  sports,
  health,
  business,
  education,
  global,
}

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.all:
        return 'All News';
      case NewsCategory.tech:
        return 'Technology';
      case NewsCategory.ai:
        return 'AI & Robotics';
      case NewsCategory.gaming:
        return 'Gaming';
      case NewsCategory.anime:
        return 'Anime & Manga';
      case NewsCategory.science:
        return 'Science & Space';
      case NewsCategory.crypto:
        return 'Crypto & Web3';
      case NewsCategory.entertainment:
        return 'Entertainment';
      case NewsCategory.sports:
        return 'Sports';
      case NewsCategory.health:
        return 'Health';
      case NewsCategory.business:
        return 'Business';
      case NewsCategory.education:
        return 'Education';
      case NewsCategory.global:
        return 'World';
    }
  }

  IconData get icon {
    switch (this) {
      case NewsCategory.all:
        return Icons.grid_view_rounded;
      case NewsCategory.tech:
        return Icons.memory_rounded;
      case NewsCategory.ai:
        return Icons.smart_toy_rounded;
      case NewsCategory.gaming:
        return Icons.sports_esports_rounded;
      case NewsCategory.anime:
        return Icons.movie_filter_rounded;
      case NewsCategory.science:
        return Icons.science_rounded;
      case NewsCategory.crypto:
        return Icons.currency_bitcoin_rounded;
      case NewsCategory.entertainment:
        return Icons.movie_rounded;
      case NewsCategory.sports:
        return Icons.sports_soccer_rounded;
      case NewsCategory.health:
        return Icons.health_and_safety_rounded;
      case NewsCategory.business:
        return Icons.business_center_rounded;
      case NewsCategory.education:
        return Icons.school_rounded;
      case NewsCategory.global:
        return Icons.language_rounded;
    }
  }
}

enum NewsSortOrder {
  newest,
  oldest,
  popular,
}

extension NewsSortOrderExtension on NewsSortOrder {
  String get displayName {
    switch (this) {
      case NewsSortOrder.newest:
        return '⚡ Newest First (Latest)';
      case NewsSortOrder.oldest:
        return '⏳ Oldest First (Archives)';
      case NewsSortOrder.popular:
        return '🔥 Most Popular';
    }
  }
}

enum NewsTimeRange {
  allTime,
  today,
  thisWeek,
  thisMonth,
  archives, // Very old news (2020 - 2025)
}

extension NewsTimeRangeExtension on NewsTimeRange {
  String get displayName {
    switch (this) {
      case NewsTimeRange.allTime:
        return '🌐 All Time';
      case NewsTimeRange.today:
        return '⚡ Past 24 Hours (Latest)';
      case NewsTimeRange.thisWeek:
        return '🗓️ This Week';
      case NewsTimeRange.thisMonth:
        return '📆 Past Month';
      case NewsTimeRange.archives:
        return '📜 Archives (Historical / Very Old)';
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
  final DateTime? rawPublishDate;
  final String author;
  final String readTime;
  final String? sourceUrl;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.imageUrl,
    required this.category,
    required this.publishDate,
    this.rawPublishDate,
    required this.author,
    required this.readTime,
    this.sourceUrl,
  });

  /// Whether the image is a network URL (from API) vs a local asset.
  bool get isNetworkImage =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  /// Whether this article has a valid image.
  bool get hasImage => imageUrl.isNotEmpty;
}
