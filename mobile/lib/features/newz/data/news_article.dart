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
  final String? sourceUrl;

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
    this.sourceUrl,
  });

  /// Whether the image is a network URL (from API) vs a local asset.
  bool get isNetworkImage =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  /// Whether this article has a valid image.
  bool get hasImage => imageUrl.isNotEmpty;
}
