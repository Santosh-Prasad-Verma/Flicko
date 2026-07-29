import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';

class AuraWebSearchResult {
  final String query;
  final String summary;
  final String provider; // 'tavily' or 'serper'
  final List<String> sources;
  final List<Map<String, String>> searchItems;

  const AuraWebSearchResult({
    required this.query,
    required this.summary,
    required this.provider,
    required this.sources,
    required this.searchItems,
  });

  bool get hasResults => summary.isNotEmpty || searchItems.isNotEmpty;

  String get formattedForPrompt {
    if (summary.isEmpty && searchItems.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('[Live Web Search Results via $provider for: "$query"]');
    if (summary.isNotEmpty) {
      buffer.writeln('Summary: $summary');
    }
    for (int i = 0; i < searchItems.length; i++) {
      final item = searchItems[i];
      buffer.writeln('${i + 1}. ${item['title']}: ${item['snippet']} (${item['url']})');
    }
    return buffer.toString().trim();
  }

  String get voiceSummary {
    if (summary.isNotEmpty) {
      return summary.replaceAll(RegExp(r'\[\d+\]'), '').trim();
    }
    if (searchItems.isNotEmpty) {
      return searchItems.map((e) => e['snippet'] ?? '').where((s) => s.isNotEmpty).take(2).join(' ');
    }
    return '';
  }
}

class AuraWebSearchService {
  final Dio _dio;

  AuraWebSearchService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 8)));

  Future<AuraWebSearchResult?> search(String query, {int maxResults = 3}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    // 1. Try Primary Search Provider: Tavily AI API
    try {
      final tavilyKey = AppConfig.tavilyApiKey.isNotEmpty
          ? AppConfig.tavilyApiKey
          : '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';

      final response = await _dio.post(
        'https://api.tavily.com/search',
        data: {
          'api_key': tavilyKey,
          'query': cleanQuery,
          'search_depth': 'basic',
          'include_answer': true,
          'max_results': maxResults,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final answer = (data['answer'] as String?)?.trim() ?? '';
        final results = (data['results'] as List<dynamic>?) ?? [];
        final sources = <String>[];
        final searchItems = <Map<String, String>>[];

        for (final item in results) {
          if (item is Map<String, dynamic>) {
            final title = (item['title'] as String?) ?? '';
            final url = (item['url'] as String?) ?? '';
            final snippet = (item['content'] as String?) ?? '';
            if (url.isNotEmpty) sources.add(url);
            searchItems.add({
              'title': title,
              'url': url,
              'snippet': snippet,
            });
          }
        }

        debugPrint('[WebSearch] Tavily AI search succeeded for "$cleanQuery" (${searchItems.length} results)');
        return AuraWebSearchResult(
          query: cleanQuery,
          summary: answer,
          provider: 'Tavily AI',
          sources: sources,
          searchItems: searchItems,
        );
      }
    } catch (e) {
      debugPrint('[WebSearch] Tavily AI search failed/exhausted: $e. Falling back to Serper.dev...');
    }

    // 2. Automatic Fallback Provider: Serper.dev Google Search API
    try {
      final serperKey = AppConfig.serperApiKey.isNotEmpty
          ? AppConfig.serperApiKey
          : '049f558ea6932c85ab7dcb3a30f6fdefd719a2f3';

      final response = await _dio.post(
        'https://google.serper.dev/search',
        options: Options(
          headers: {
            'X-API-KEY': serperKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'q': cleanQuery,
          'num': maxResults,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final organic = (data['organic'] as List<dynamic>?) ?? [];
        final sources = <String>[];
        final searchItems = <Map<String, String>>[];
        final snippetsList = <String>[];

        for (final item in organic) {
          if (item is Map<String, dynamic>) {
            final title = (item['title'] as String?) ?? '';
            final link = (item['link'] as String?) ?? '';
            final snippet = (item['snippet'] as String?) ?? '';
            if (link.isNotEmpty) sources.add(link);
            if (snippet.isNotEmpty) snippetsList.add(snippet);
            searchItems.add({
              'title': title,
              'url': link,
              'snippet': snippet,
            });
          }
        }

        final combinedSummary = snippetsList.take(2).join(' ');
        debugPrint('[WebSearch] Serper.dev fallback search succeeded for "$cleanQuery" (${searchItems.length} results)');

        return AuraWebSearchResult(
          query: cleanQuery,
          summary: combinedSummary,
          provider: 'Serper.dev (Google Search)',
          sources: sources,
          searchItems: searchItems,
        );
      }
    } catch (e) {
      debugPrint('[WebSearch] Both Tavily and Serper web searches failed: $e');
    }

    return null;
  }
}

final auraWebSearchServiceProvider = Provider<AuraWebSearchService>((ref) {
  return AuraWebSearchService();
});
