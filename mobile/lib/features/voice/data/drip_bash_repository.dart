import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dart_des/dart_des.dart';
import '../domain/music_models.dart';

/// Drip Bash Repository - BlackHole-style music streaming
///
/// Uses direct JioSaavn API (www.jiosaavn.com/api.php) with DES decryption
/// and youtube_explode_dart for YouTube audio streams.
abstract class DripBashRepository {
  Future<List<Track>> searchYouTube(String query, {int limit});
  Future<List<Track>> searchSaavn(String query, {int limit});
  Future<CategorizedSearchResults> searchSaavnCategorized(String query);
  Future<List<Track>> fetchAlbumSongs(String albumId);
  Future<String?> getStreamingUrl(String videoId);
  Future<String?> getSaavnStreamingUrl(String songId);
}

final dripBashRepositoryProvider = Provider<DripBashRepository>((ref) {
  return DripBashRepositoryImpl();
});

class DripBashRepositoryImpl implements DripBashRepository {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': '*/*',
    },
  ));

  YoutubeExplode? _yt;
  YoutubeExplode _getYoutube() { _yt ??= YoutubeExplode(); return _yt!; }

  // ─── JioSaavn Direct API (BlackHole pattern) ────────────────────────────────

  static const _saavnBase = 'www.jiosaavn.com';
  static const _saavnApiPath = '/api.php';
  static const _saavnBaseParams = '_format=json&_marker=0&api_version=4&ctx=web6dot0';
  static const _desKey = '38346591';

  // Endpoints matching BlackHole's api.dart
  static const _endpoints = {
    'getResults': '__call=search.getResults',
    'albumResults': '__call=search.getAlbumResults',
    'artistResults': '__call=search.getArtistResults',
    'albumDetails': '__call=content.getAlbumDetails',
    'songDetails': '__call=song.getDetails',
    'autocomplete': '__call=autocomplete.get',
  };

  /// DES decrypt encrypted_media_url (BlackHole FormatResponse.decode)
  String _decryptMediaUrl(String input) {
    final DES desECB = DES(key: _desKey.codeUnits);
    final Uint8List encrypted = base64.decode(input);
    final List<int> decrypted = desECB.decrypt(encrypted);
    final String decoded = utf8.decode(decrypted)
        .replaceAll(RegExp(r'\.mp4.*'), '.mp4')
        .replaceAll(RegExp(r'\.m4a.*'), '.m4a')
        .replaceAll(RegExp(r'\.mp3.*'), '.mp3');
    return decoded.replaceAll('http:', 'https:');
  }

  /// Make request to JioSaavn direct API
  Future<Map<String, dynamic>?> _saavnRequest(String params, {bool useV4 = true}) async {
    try {
      final apiStr = useV4 ? _saavnBaseParams : _saavnBaseParams.replaceAll('&api_version=4', '');
      final uri = Uri.https(_saavnBase, _saavnApiPath, Uri.splitQueryString('$apiStr&$params'));
      final res = await _dio.getUri(uri, options: Options(headers: {'cookie': 'L=english'}));
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is String) return json.decode(res.data as String) as Map<String, dynamic>;
        return res.data as Map<String, dynamic>;
      }
    } catch (e) { dev.log('Saavn request error: $e', name: 'drip-bash'); }
    return null;
  }

  // ─── JioSaavn Search ────────────────────────────────────────────────────────

  @override
  Future<List<Track>> searchSaavn(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final params = 'p=1&q=${Uri.encodeComponent(query)}&n=$limit&${_endpoints['getResults']}';
      final data = await _saavnRequest(params);
      if (data == null) return _searchSaavnFallback(query, limit);
      final results = (data['results'] as List?) ?? [];
      return results.whereType<Map>().map((item) => _mapSaavnSong(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      dev.log('Saavn search error: $e', name: 'drip-bash');
      return _searchSaavnFallback(query, limit);
    }
  }

  @override
  Future<CategorizedSearchResults> searchSaavnCategorized(String query) async {
    if (query.trim().isEmpty) return const CategorizedSearchResults.empty();
    try {
      // Use autocomplete.get for categorized results (BlackHole fetchSearchResults)
      final params = '${_endpoints['autocomplete']}&cc=in&includeMetaTags=1&query=${Uri.encodeComponent(query)}';
      final data = await _saavnRequest(params, useV4: false);

      final categories = <SearchCategory>[];

      if (data != null) {
        // Parse albums
        final albumData = data['albums']?['data'] as List?;
        if (albumData != null && albumData.isNotEmpty) {
          categories.add(SearchCategory(
            title: 'Albums',
            items: albumData.whereType<Map>().map((a) => _mapSaavnAlbumResult(Map<String, dynamic>.from(a))).toList(),
          ));
        }

        // Parse artists
        final artistData = data['artists']?['data'] as List?;
        if (artistData != null && artistData.isNotEmpty) {
          categories.add(SearchCategory(
            title: 'Artists',
            items: artistData.whereType<Map>().map((a) => _mapSaavnArtistResult(Map<String, dynamic>.from(a))).toList(),
          ));
        }
      }

      // Fetch songs separately (like BlackHole does)
      final songParams = 'p=1&q=${Uri.encodeComponent(query)}&n=5&${_endpoints['getResults']}';
      final songData = await _saavnRequest(songParams);
      if (songData != null) {
        final songResults = (songData['results'] as List?) ?? [];
        if (songResults.isNotEmpty) {
          categories.insert(0, SearchCategory(
            title: 'Songs',
            items: songResults.whereType<Map>().map((s) => _mapSaavnSong(Map<String, dynamic>.from(s))).toList(),
          ));
        }
      }

      if (categories.isEmpty) {
        final fallback = await searchSaavn(query);
        if (fallback.isNotEmpty) return CategorizedSearchResults(categories: [SearchCategory(title: 'Songs', items: fallback)]);
        return const CategorizedSearchResults.empty();
      }

      return CategorizedSearchResults(categories: categories);
    } catch (e) {
      dev.log('Categorized search error: $e', name: 'drip-bash');
      final songs = await searchSaavn(query);
      if (songs.isEmpty) return const CategorizedSearchResults.empty();
      return CategorizedSearchResults(categories: [SearchCategory(title: 'Songs', items: songs)]);
    }
  }

  // ─── JioSaavn Streaming URL ─────────────────────────────────────────────────

  @override
  Future<String?> getSaavnStreamingUrl(String songId) async {
    try {
      // Use song.getDetails endpoint (like BlackHole)
      final params = '${_endpoints['songDetails']}&pids=$songId';
      final data = await _saavnRequest(params);
      if (data == null) return _getSaavnStreamingUrlFallback(songId);

      // Response has songs keyed by ID
      final songData = data[songId] as Map<String, dynamic>? ?? (data['songs'] is List ? (data['songs'] as List).firstOrNull as Map<String, dynamic>? : null);
      if (songData == null) return _getSaavnStreamingUrlFallback(songId);

      // Decrypt encrypted_media_url (BlackHole's core streaming mechanism)
      final encUrl = songData['encrypted_media_url']?.toString() ?? songData['more_info']?['encrypted_media_url']?.toString();
      if (encUrl != null && encUrl.isNotEmpty) {
        final decrypted = _decryptMediaUrl(encUrl);
        // Replace quality to get 320kbps
        final highQuality = decrypted.replaceAll('_96.', '_320.').replaceAll('_160.', '_320.');
        dev.log('Decrypted Saavn URL (320kbps)', name: 'drip-bash');
        return highQuality;
      }

      return _getSaavnStreamingUrlFallback(songId);
    } catch (e) {
      dev.log('Saavn streaming error: $e', name: 'drip-bash');
      return _getSaavnStreamingUrlFallback(songId);
    }
  }

  // ─── Album Songs ────────────────────────────────────────────────────────────

  @override
  Future<List<Track>> fetchAlbumSongs(String albumId) async {
    try {
      // Use content.getAlbumDetails (like BlackHole)
      final params = '${_endpoints['albumDetails']}&cc=in&albumid=$albumId';
      final data = await _saavnRequest(params);
      if (data == null) return _fetchAlbumSongsFallback(albumId);

      final songList = data['list'] as List?;
      if (songList == null || songList.isEmpty) return _fetchAlbumSongsFallback(albumId);

      return songList.whereType<Map>().map((item) => _mapSaavnAlbumSong(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      dev.log('Album songs error: $e', name: 'drip-bash');
      return _fetchAlbumSongsFallback(albumId);
    }
  }

  // ─── YouTube Search & Streaming ─────────────────────────────────────────────

  @override
  Future<List<Track>> searchYouTube(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final searchList = await _getYoutube().search.search(query);
      return searchList.take(limit).map((video) => Track(
        id: video.id.value,
        name: video.title,
        artistName: video.author,
        durationMs: video.duration?.inMilliseconds,
        imageUrl: video.thumbnails.highResUrl,
        externalUrl: video.url,
        source: 'youtube',
      )).toList();
    } catch (e) {
      dev.log('YouTube search error: $e', name: 'drip-bash');
      return _searchInvidious(query, limit);
    }
  }

  @override
  Future<String?> getStreamingUrl(String videoId) async {
    try {
      // BlackHole pattern: getManifest -> audioOnly -> sort by bitrate
      final StreamManifest manifest = await _getYoutube().videos.streamsClient.getManifest(VideoId(videoId));
      final List<AudioOnlyStreamInfo> sortedStreamInfo = manifest.audioOnly.toList()
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));

      if (sortedStreamInfo.isNotEmpty) {
        // Highest bitrate = last item (like BlackHole quality == 'High')
        final best = sortedStreamInfo.last;
        dev.log('YT audio stream: ${best.bitrate.kiloBitsPerSecond.round()}kbps ${best.codec.subtype}', name: 'drip-bash');
        return best.url.toString();
      }

      // Fallback to muxed
      final muxed = manifest.muxed.sortByVideoQuality().lastOrNull;
      return muxed?.url.toString();
    } catch (e) {
      dev.log('YT streaming error: $e', name: 'drip-bash');
      return _getInvidiousStreamingUrl(videoId);
    }
  }

  // ─── Fallback: saavn.dev mirror ─────────────────────────────────────────────

  Future<List<Track>> _searchSaavnFallback(String query, int limit) async {
    try {
      final url = 'https://saavn.dev/api/search/songs?query=${Uri.encodeComponent(query)}&limit=$limit';
      final res = await _dio.get(url);
      if (res.statusCode != 200) return [];
      final results = (res.data['data']?['results'] as List?) ?? [];
      return results.whereType<Map>().map((item) => _mapSaavnDevItem(Map<String, dynamic>.from(item))).toList();
    } catch (e) { return []; }
  }

  Future<String?> _getSaavnStreamingUrlFallback(String songId) async {
    try {
      final res = await _dio.get('https://saavn.dev/api/songs/$songId');
      if (res.statusCode != 200) return null;
      final songData = res.data['data'] as Map<String, dynamic>?;
      if (songData == null) return null;
      final downloadUrl = songData['downloadUrl'] as List?;
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        for (final item in downloadUrl.reversed) {
          final u = (item as Map<String, dynamic>?)?['url'] as String?;
          if (u != null) return u;
        }
      }
      return songData['url'] as String?;
    } catch (_) { return null; }
  }

  Future<List<Track>> _fetchAlbumSongsFallback(String albumId) async {
    try {
      final res = await _dio.get('https://saavn.dev/api/albums?id=$albumId');
      if (res.statusCode != 200) return [];
      final songs = (res.data['data']?['songs'] as List?) ?? [];
      return songs.whereType<Map>().map((item) => _mapSaavnDevItem(Map<String, dynamic>.from(item))).toList();
    } catch (_) { return []; }
  }

  // ─── Fallback: Invidious API ────────────────────────────────────────────────

  Future<List<Track>> _searchInvidious(String query, int limit) async {
    final instances = ['https://inv.nadeko.net', 'https://invidious.nerdvpn.de', 'https://invidious.jing.rocks'];
    for (final instance in instances) {
      try {
        final res = await _dio.get('$instance/api/v1/search?q=${Uri.encodeComponent(query)}&type=video',
            options: Options(receiveTimeout: const Duration(seconds: 10)));
        if (res.statusCode == 200 && res.data is List) {
          return (res.data as List).take(limit).whereType<Map>().map((item) => _mapInvidiousItem(Map<String, dynamic>.from(item))).toList();
        }
      } catch (_) { continue; }
    }
    return [];
  }

  Future<String?> _getInvidiousStreamingUrl(String videoId) async {
    final instances = ['https://inv.nadeko.net', 'https://invidious.nerdvpn.de'];
    for (final instance in instances) {
      try {
        final res = await _dio.get('$instance/api/v1/videos/$videoId', options: Options(receiveTimeout: const Duration(seconds: 10)));
        if (res.statusCode != 200) continue;
        final adaptiveFormats = (res.data as Map)['adaptiveFormats'] as List? ?? [];
        String? audioUrl;
        int maxBitrate = 0;
        for (final f in adaptiveFormats) {
          final type = (f['type'] as String?) ?? '';
          if (!type.startsWith('audio/')) continue;
          final bitrate = (f['bitrate'] as num?)?.toInt() ?? 0;
          if (bitrate > maxBitrate) { maxBitrate = bitrate; audioUrl = f['url'] as String?; }
        }
        if (audioUrl != null) return audioUrl;
      } catch (_) { continue; }
    }
    return null;
  }

  // ─── Mappers: Direct JioSaavn API ───────────────────────────────────────────

  /// Map a song from search.getResults (direct API format)
  Track _mapSaavnSong(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = _unescape(item['title']?.toString() ?? item['song']?.toString() ?? 'Unknown');

    // Extract artist from more_info.artistMap or primary_artists
    String artist = 'Unknown Artist';
    final moreInfo = item['more_info'] as Map<String, dynamic>?;
    if (moreInfo != null) {
      final artistMap = moreInfo['artistMap'] as Map<String, dynamic>?;
      if (artistMap != null) {
        final primary = artistMap['primary_artists'] as List?;
        if (primary != null && primary.isNotEmpty) {
          artist = primary.map((a) => a['name']?.toString() ?? '').where((n) => n.isNotEmpty).join(', ');
        }
      }
      if (artist == 'Unknown Artist') artist = moreInfo['music']?.toString() ?? 'Unknown Artist';
    }

    final album = moreInfo?['album']?.toString();
    final durationSec = int.tryParse(moreInfo?['duration']?.toString() ?? '');
    final image = _getImageUrl(item['image']?.toString() ?? '');

    return Track(
      id: id, name: _unescape(title), artistName: _unescape(artist),
      albumName: album != null ? _unescape(album) : null,
      durationMs: durationSec != null ? durationSec * 1000 : null,
      imageUrl: image, source: 'saavn',
      externalUrl: item['perma_url']?.toString(),
    );
  }

  /// Map album song from content.getAlbumDetails (different format)
  Track _mapSaavnAlbumSong(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = _unescape(item['song']?.toString() ?? item['title']?.toString() ?? 'Unknown');
    final artist = _unescape(item['primary_artists']?.toString() ?? item['singers']?.toString() ?? 'Unknown Artist');
    final album = item['album']?.toString();
    final durationSec = int.tryParse(item['duration']?.toString() ?? '');
    final image = _getImageUrl(item['image']?.toString() ?? '');

    return Track(
      id: id, name: title, artistName: artist,
      albumName: album != null ? _unescape(album) : null,
      durationMs: durationSec != null ? durationSec * 1000 : null,
      imageUrl: image, source: 'saavn',
      externalUrl: item['perma_url']?.toString(),
    );
  }

  /// Map album from autocomplete results
  Track _mapSaavnAlbumResult(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = _unescape(item['title']?.toString() ?? 'Unknown Album');
    String artist = '';
    final moreInfo = item['more_info'] as Map<String, dynamic>?;
    if (moreInfo != null) {
      final artistMap = moreInfo['artistMap'] as Map<String, dynamic>?;
      if (artistMap != null) {
        final primary = artistMap['primary_artists'] as List?;
        if (primary != null && primary.isNotEmpty) artist = _unescape(primary[0]['name']?.toString() ?? '');
      }
      if (artist.isEmpty) artist = _unescape(moreInfo['music']?.toString() ?? 'Various Artists');
    }
    final image = _getImageUrl(item['image']?.toString() ?? '');

    return Track(id: id, name: title, artistName: artist, albumName: title, imageUrl: image, source: 'saavn_album');
  }

  /// Map artist from autocomplete results
  Track _mapSaavnArtistResult(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = _unescape(item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown Artist');
    final image = _getImageUrl(item['image']?.toString() ?? '');
    return Track(id: id, name: name, artistName: name, imageUrl: image, source: 'saavn_artist');
  }

  // ─── Mappers: saavn.dev fallback ────────────────────────────────────────────

  Track _mapSaavnDevItem(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = _unescape(item['name']?.toString() ?? 'Unknown');
    final artists = item['artists']?['primary'] as List?;
    final artist = artists != null && artists.isNotEmpty
        ? artists.map((a) => a['name'] as String?).whereType<String>().join(', ')
        : 'Unknown Artist';
    final album = item['album']?['name']?.toString();
    final images = item['image'] as List?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) imageUrl = (images.last as Map?)?['url'] as String?;
    final durationSec = item['duration'] as int?;

    return Track(
      id: id, name: name, artistName: _unescape(artist),
      albumName: album != null ? _unescape(album) : null,
      durationMs: durationSec != null ? durationSec * 1000 : null,
      imageUrl: imageUrl, source: 'saavn',
      externalUrl: item['url'] as String?,
    );
  }

  Track _mapInvidiousItem(Map<String, dynamic> item) {
    final videoId = item['videoId'] as String? ?? '';
    final thumbnails = item['videoThumbnails'] as List?;
    String? imageUrl;
    if (thumbnails != null) {
      for (final t in thumbnails) {
        final q = (t as Map)['quality'] as String?;
        if (q == 'medium' || q == 'high') { imageUrl = t['url'] as String?; break; }
      }
      imageUrl ??= thumbnails.isNotEmpty ? (thumbnails.last as Map)['url'] as String? : null;
    }
    final durationSec = item['lengthSeconds'] as int?;

    return Track(
      id: videoId, name: item['title']?.toString() ?? 'Unknown',
      artistName: item['author']?.toString() ?? 'Unknown Artist',
      durationMs: durationSec != null ? durationSec * 1000 : null,
      imageUrl: imageUrl, source: 'youtube',
      externalUrl: 'https://youtube.com/watch?v=$videoId',
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Convert low-res image URL to high-res (BlackHole getImageUrl pattern)
  String _getImageUrl(String url) {
    if (url.isEmpty) return url;
    return url.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
  }

  String _unescape(String input) {
    return input
        .replaceAll('&amp;', '&').replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'").replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>').replaceAll('&nbsp;', ' ');
  }

  void dispose() { _yt?.close(); _yt = null; }
}
