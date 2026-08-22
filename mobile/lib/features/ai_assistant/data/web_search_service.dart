import 'dart:async';
import 'dart:convert';
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

  AuraWebSearchService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 Flicko/2.0',
                },
              ),
            );

  bool _isValidCustomKey(String key, List<String> dummyKeys) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    for (final dummy in dummyKeys) {
      if (trimmed == dummy || trimmed.contains('dev-2wrvRq') || trimmed == '049f558ea6932c85ab7dcb3a30f6fdefd719a2f3') {
        return false;
      }
    }
    return true;
  }

  Future<AuraWebSearchResult?> search(String query, {int maxResults = 4}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    // 1. Try Primary Search Provider: Tavily AI API (if valid key configured)
    final tavilyKey = AppConfig.tavilyApiKey.trim();
    if (_isValidCustomKey(tavilyKey, ['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'])) {
      try {
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

          if (answer.isNotEmpty || searchItems.isNotEmpty) {
            debugPrint('[WebSearch] Tavily AI search succeeded for "$cleanQuery" (${searchItems.length} results)');
            return AuraWebSearchResult(
              query: cleanQuery,
              summary: answer,
              provider: 'Tavily AI',
              sources: sources,
              searchItems: searchItems,
            );
          }
        }
      } catch (e) {
        debugPrint('[WebSearch] Tavily AI search failed: $e. Falling back...');
      }
    }

    // 2. Try Fallback: Serper.dev Google Search API (if valid key configured)
    final serperKey = AppConfig.serperApiKey.trim();
    if (_isValidCustomKey(serperKey, ['049f558ea6932c85ab7dcb3a30f6fdefd719a2f3'])) {
      try {
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

          if (searchItems.isNotEmpty) {
            final combinedSummary = snippetsList.take(2).join(' ');
            debugPrint('[WebSearch] Serper.dev search succeeded for "$cleanQuery" (${searchItems.length} results)');
            return AuraWebSearchResult(
              query: cleanQuery,
              summary: combinedSummary,
              provider: 'Serper.dev (Google Search)',
              sources: sources,
              searchItems: searchItems,
            );
          }
        }
      } catch (e) {
        debugPrint('[WebSearch] Serper.dev search failed: $e. Falling back...');
      }
    }

    // 3. Resilient Free Provider: DuckDuckGo Instant Answer API
    try {
      final ddgUrl = 'https://api.duckduckgo.com/?q=${Uri.encodeComponent(cleanQuery)}&format=json&no_html=1&skip_disambig=1';
      final response = await _dio.get(ddgUrl);

      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }

        if (data is Map<String, dynamic>) {
          final heading = (data['Heading'] as String?) ?? '';
          final abstractText = (data['AbstractText'] as String?) ?? '';
          final abstractUrl = (data['AbstractURL'] as String?) ?? '';
          final relatedTopics = (data['RelatedTopics'] as List<dynamic>?) ?? [];

          final sources = <String>[];
          final searchItems = <Map<String, String>>[];

          if (abstractText.isNotEmpty) {
            if (abstractUrl.isNotEmpty) sources.add(abstractUrl);
            searchItems.add({
              'title': heading.isNotEmpty ? heading : cleanQuery,
              'url': abstractUrl,
              'snippet': abstractText,
            });
          }

          for (final topic in relatedTopics.take(maxResults)) {
            if (topic is Map<String, dynamic>) {
              final text = (topic['Text'] as String?) ?? '';
              final firstUrl = (topic['FirstURL'] as String?) ?? '';
              if (text.isNotEmpty) {
                if (firstUrl.isNotEmpty) sources.add(firstUrl);
                searchItems.add({
                  'title': text.split(' - ').first,
                  'url': firstUrl,
                  'snippet': text,
                });
              }
            }
          }

          if (searchItems.isNotEmpty || abstractText.isNotEmpty) {
            debugPrint('[WebSearch] DuckDuckGo Instant Answer succeeded for "$cleanQuery"');
            return AuraWebSearchResult(
              query: cleanQuery,
              summary: abstractText.isNotEmpty ? abstractText : (searchItems.first['snippet'] ?? ''),
              provider: 'DuckDuckGo',
              sources: sources,
              searchItems: searchItems,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[WebSearch] DuckDuckGo Instant Answer failed: $e. Trying Wikipedia API...');
    }

    // 4. Resilient Free Provider: Wikipedia Search & Knowledge API
    try {
      final wikiUrl =
          'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(cleanQuery)}&format=json&utf8=1&srlimit=$maxResults';
      final response = await _dio.get(wikiUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final queryObj = data['query'] as Map<String, dynamic>?;
        final searchList = (queryObj?['search'] as List<dynamic>?) ?? [];

        final sources = <String>[];
        final searchItems = <Map<String, String>>[];
        final snippets = <String>[];

        for (final item in searchList) {
          if (item is Map<String, dynamic>) {
            final title = (item['title'] as String?) ?? '';
            final pageId = item['pageid'];
            final rawSnippet = (item['snippet'] as String?) ?? '';
            final cleanSnippet = rawSnippet.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            final pageUrl = pageId != null ? 'https://en.wikipedia.org/?curid=$pageId' : 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}';

            if (title.isNotEmpty && cleanSnippet.isNotEmpty) {
              sources.add(pageUrl);
              snippets.add(cleanSnippet);
              searchItems.add({
                'title': title,
                'url': pageUrl,
                'snippet': cleanSnippet,
              });
            }
          }
        }

        if (searchItems.isNotEmpty) {
          final summary = snippets.take(2).join(' ');
          debugPrint('[WebSearch] Wikipedia knowledge search succeeded for "$cleanQuery" (${searchItems.length} results)');
          return AuraWebSearchResult(
            query: cleanQuery,
            summary: summary,
            provider: 'DuckDuckGo / Web Knowledge',
            sources: sources,
            searchItems: searchItems,
          );
        }
      }
    } catch (e) {
      debugPrint('[WebSearch] Wikipedia API search failed: $e');
    }

    return null;
  }
}

final auraWebSearchServiceProvider = Provider<AuraWebSearchService>((ref) {
  return AuraWebSearchService();
});
