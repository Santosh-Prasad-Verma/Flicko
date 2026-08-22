/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mobile/features/sonic_music/Services/yt_music.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeServices {
  static const String searchAuthority = 'www.youtube.com';
  static const Map paths = {
    'search': '/results',
    'channel': '/channel',
    'music': '/music',
    'playlist': '/playlist',
  };
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  };
  final YoutubeExplode yt = YoutubeExplode();

  YouTubeServices._privateConstructor();

  static final YouTubeServices _instance =
      YouTubeServices._privateConstructor();

  static YouTubeServices get instance {
    return _instance;
  }

  Future<List<Video>> getPlaylistSongs(String id) async {
    final List<Video> results = await yt.playlists.getVideos(id).toList();
    return results;
  }

  Future<Video?> getVideoFromId(String id) async {
    try {
      final Video result = await yt.videos.get(id);
      return result;
    } catch (e) {
      Logger.root.severe('Error while getting video from id', e);
      return null;
    }
  }

  Future<Map?> formatVideoFromId({
    required String id,
    Map? data,
    bool? getUrl,
  }) async {
    final Video? vid = await getVideoFromId(id);
    if (vid == null) {
      return null;
    }
    final Map? response = await formatVideo(
      video: vid,
      quality: Hive.box('settings')
          .get(
            'ytQuality',
            defaultValue: 'Low',
          )
          .toString(),
      data: data,
      getUrl: getUrl ?? true,
      // preferM4a: Hive.box(
      //         'settings')
      //     .get('preferM4a',
      //         defaultValue:
      //             true) as bool
    );
    return response;
  }

  Future<Map?> refreshLink(String id, {bool useYTM = true}) async {
    String quality;
    try {
      quality =
          Hive.box('settings').get('ytQuality', defaultValue: 'Low').toString();
    } catch (e) {
      quality = 'Low';
    }
    if (useYTM) {
      try {
        final Map res = await YtMusicService().getSongData(
          videoId: id,
          quality: quality,
        );
        if (_hasPlayableUrl(res)) return res;
        Logger.root.warning('YtMusic returned no playable URL for $id');
      } catch (e) {
        Logger.root.warning('YtMusic refresh failed for $id: $e');
      }
    }

    try {
      final Video? res = await getVideoFromId(id);
      if (res == null) {
        return null;
      }
      final Map? data = await formatVideo(video: res, quality: quality);
      if (data != null && _hasPlayableUrl(data)) return data;
    } catch (e) {
      Logger.root.severe('youtube_explode refresh failed for $id', e);
    }
    return null;
  }

  bool _hasPlayableUrl(Map data) {
    final url = data['url']?.toString() ?? '';
    return url.startsWith('http') && !url.contains('/watch?');
  }

  Future<Playlist> getPlaylistDetails(String id) async {
    final Playlist metadata = await yt.playlists.get(id);
    return metadata;
  }

  Future<Map?> _extractInitialData(String html) async {
    return await Isolate.run(() {
      final markers = [
        'var ytInitialData =',
        'window["ytInitialData"] =',
        'ytInitialData =',
      ];
      for (final marker in markers) {
        final markerIndex = html.indexOf(marker);
        if (markerIndex == -1) continue;

        final start = html.indexOf('{', markerIndex);
        if (start == -1) continue;

        var depth = 0;
        var inString = false;
        var escaped = false;
        final len = html.length;
        for (var i = start; i < len; i++) {
          final code = html.codeUnitAt(i);
          if (escaped) {
            escaped = false;
            continue;
          }
          if (code == 92) { // '\\'
            escaped = true;
            continue;
          }
          if (code == 34) { // '"'
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (code == 123) depth++; // '{'
          if (code == 125) {        // '}'
            depth--;
            if (depth == 0) {
              final jsonText = html.substring(start, i + 1);
              final decoded = json.decode(jsonText);
              return decoded is Map ? decoded : null;
            }
          }
        }
      }
      return null;
    });
  }

  Future<Map<String, List>> getMusicHome() async {
    final Uri link = Uri.https(
      searchAuthority,
      paths['music'].toString(),
    );
    try {
      final Response response = await get(link, headers: headers);
      if (response.statusCode != 200) {
        return {};
      }
      final Map? data = await _extractInitialData(response.body);
      if (data == null) {
        Logger.root.warning('Unable to parse YouTube Music home payload');
        return {};
      }

      final List result = data['contents']['twoColumnBrowseResultsRenderer']
              ['tabs'][0]['tabRenderer']['content']['sectionListRenderer']
          ['contents'] as List;

      final List headResult = data['header']['carouselHeaderRenderer']
          ['contents'][0]['carouselItemRenderer']['carouselItems'] as List;

      final List shelfRenderer = result.map((element) {
        return element['itemSectionRenderer']['contents'][0]['shelfRenderer'];
      }).toList();

      final List finalResult = shelfRenderer.map((element) {
        final playlistItems = element['title']['runs'][0]['text'].trim() ==
                    'Charts' ||
                element['title']['runs'][0]['text'].trim() == 'Classements'
            ? formatChartItems(
                element['content']['horizontalListRenderer']['items'] as List,
              )
            : element['title']['runs'][0]['text']
                        .toString()
                        .contains('Music Videos') ||
                    element['title']['runs'][0]['text']
                        .toString()
                        .contains('Nouveaux clips') ||
                    element['title']['runs'][0]['text']
                        .toString()
                        .contains('En Musique Avec Moi') ||
                    element['title']['runs'][0]['text']
                        .toString()
                        .contains('Performances Uniques')
                ? formatVideoItems(
                    element['content']['horizontalListRenderer']['items']
                        as List,
                  )
                : formatItems(
                    element['content']['horizontalListRenderer']['items']
                        as List,
                  );
        if (playlistItems.isNotEmpty) {
          return {
            'title': element['title']['runs'][0]['text'],
            'playlists': playlistItems,
          };
        } else {
          Logger.root.severe(
            "got null in getMusicHome for '${element['title']['runs'][0]['text']}'",
          );
          return null;
        }
      }).toList();

      final List finalHeadResult = formatHeadItems(headResult);
      finalResult.removeWhere((element) => element == null);

      return {'body': finalResult, 'head': finalHeadResult};
    } catch (e) {
      Logger.root.severe('Error in getMusicHome: $e');
      return {};
    }
  }

  Future<List> getSearchSuggestions({required String query}) async {
    const baseUrl =
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=';
    // 'https://invidious.snopyta.org/api/v1/search/suggestions?q=';
    final Uri link = Uri.parse(baseUrl + query);
    try {
      final Response response = await get(link, headers: headers);
      if (response.statusCode != 200) {
        return [];
      }
      final unescape = HtmlUnescape();
      // final Map res = jsonDecode(response.body) as Map;
      final List res = (jsonDecode(response.body) as List)[1] as List;
      // return (res['suggestions'] as List).map((e) => unescape.convert(e.toString())).toList();
      return res.map((e) => unescape.convert(e.toString())).toList();
    } catch (e) {
      Logger.root.severe('Error in getSearchSuggestions: $e');
      return [];
    }
  }

  List formatVideoItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['gridVideoRenderer']['title']['simpleText'],
          'type': 'video',
          'description': e['gridVideoRenderer']['shortBylineText']['runs'][0]
              ['text'],
          'count': e['gridVideoRenderer']['shortViewCountText']['simpleText'],
          'videoId': e['gridVideoRenderer']['videoId'],
          'firstItemId': e['gridVideoRenderer']['videoId'],
          'image':
              e['gridVideoRenderer']['thumbnail']['thumbnails'].last['url'],
          'imageMin': e['gridVideoRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['gridVideoRenderer']['thumbnail']['thumbnails'][1]
              ['url'],
          'imageStandard': e['gridVideoRenderer']['thumbnail']['thumbnails'][2]
              ['url'],
          'imageMax':
              e['gridVideoRenderer']['thumbnail']['thumbnails'].last['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatVideoItems: $e');
      return List.empty();
    }
  }

  List formatChartItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['gridPlaylistRenderer']['title']['runs'][0]['text'],
          'type': 'chart',
          'description': e['gridPlaylistRenderer']['shortBylineText']['runs'][0]
              ['text'],
          'count': e['gridPlaylistRenderer']['videoCountText']['runs'][0]
              ['text'],
          'playlistId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['playlistId'],
          'firstItemId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'image': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageStandard': e['gridPlaylistRenderer']['thumbnail']['thumbnails']
              [0]['url'],
          'imageMax': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatChartItems: $e');
      return List.empty();
    }
  }

  List formatItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['compactStationRenderer']['title']['simpleText'],
          'type': 'playlist',
          'description': e['compactStationRenderer']['description']
              ['simpleText'],
          'count': e['compactStationRenderer']['videoCountText']['runs'][0]
              ['text'],
          'playlistId': e['compactStationRenderer']['navigationEndpoint']
              ['watchEndpoint']['playlistId'],
          'firstItemId': e['compactStationRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'image': e['compactStationRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['compactStationRenderer']['thumbnail']['thumbnails']
              [0]['url'],
          'imageStandard': e['compactStationRenderer']['thumbnail']
              ['thumbnails'][1]['url'],
          'imageMax': e['compactStationRenderer']['thumbnail']['thumbnails'][2]
              ['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatItems: $e');
      return List.empty();
    }
  }

  List formatHeadItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['defaultPromoPanelRenderer']['title']['runs'][0]['text'],
          'type': 'video',
          'description':
              (e['defaultPromoPanelRenderer']['description']['runs'] as List)
                  .map((e) => e['text'])
                  .toList()
                  .join(),
          'videoId': e['defaultPromoPanelRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'firstItemId': e['defaultPromoPanelRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'image': e['defaultPromoPanelRenderer']
                          ['largeFormFactorBackgroundThumbnail']
                      ['thumbnailLandscapePortraitRenderer']['landscape']
                  ['thumbnails']
              .last['url'],
          'imageMedium': e['defaultPromoPanelRenderer']
                      ['largeFormFactorBackgroundThumbnail']
                  ['thumbnailLandscapePortraitRenderer']['landscape']
              ['thumbnails'][1]['url'],
          'imageStandard': e['defaultPromoPanelRenderer']
                      ['largeFormFactorBackgroundThumbnail']
                  ['thumbnailLandscapePortraitRenderer']['landscape']
              ['thumbnails'][2]['url'],
          'imageMax': e['defaultPromoPanelRenderer']
                          ['largeFormFactorBackgroundThumbnail']
                      ['thumbnailLandscapePortraitRenderer']['landscape']
                  ['thumbnails']
              .last['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatHeadItems: $e');
      return List.empty();
    }
  }

  Future<Map?> formatVideo({
    required Video video,
    required String quality,
    Map? data,
    bool getUrl = true,
    // bool preferM4a = true,
  }) async {
    if (video.duration?.inSeconds == null) return null;
    List<String> allUrls = [];
    List<Map> urlsData = [];
    String finalUrl = '';
    String expireAt = '0';
    if (getUrl) {
      urlsData = await getYtStreamUrls(video.id.value);
      if (urlsData.isNotEmpty) {
        final Map finalUrlData =
            quality == 'High' ? urlsData.last : urlsData.first;
        finalUrl = finalUrlData['url'].toString();
        expireAt = finalUrlData['expireAt'].toString();
        allUrls = urlsData.map((e) => e['url'].toString()).toList();
      }
    }
    return {
      'id': video.id.value,
      'album': (data?['album'] ?? '') != ''
          ? data!['album']
          : video.author.replaceAll('- Topic', '').trim(),
      'duration': video.duration?.inSeconds.toString(),
      'title':
          (data?['title'] ?? '') != '' ? data!['title'] : video.title.trim(),
      'artist': (data?['artist'] ?? '') != ''
          ? data!['artist']
          : video.author.replaceAll('- Topic', '').trim(),
      'image': video.thumbnails.maxResUrl,
      'secondImage': video.thumbnails.highResUrl,
      'language': 'YouTube',
      'genre': 'YouTube',
      'expire_at': expireAt,
      'url': finalUrl,
      'allUrls': allUrls,
      'urlsData': urlsData,
      'year': video.uploadDate?.year.toString(),
      '320kbps': 'false',
      'has_lyrics': 'false',
      'release_date': video.publishDate.toString(),
      'album_id': video.channelId.value,
      'subtitle':
          (data?['subtitle'] ?? '') != '' ? data!['subtitle'] : video.author,
      'perma_url': video.url,
    };
  }

  Future<List<Map>> fetchSearchResults(String query) async {
    final List<Video> searchResults = await yt.search.search(query);
    final List<Map> videoResult = [];
    for (final Video vid in searchResults) {
      final res = await formatVideo(video: vid, quality: 'High', getUrl: false);
      if (res != null) videoResult.add(res);
    }
    return [
      {
        'title': 'Videos',
        'items': videoResult,
        'allowViewAll': false,
      }
    ];
  }

  String getExpireAt(String url) {
    final match = RegExp(r'[?&]expire=([^&]+)').firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600 * 5.5)
              .toString();
    }
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600 * 5.5)
        .toString();
  }

  Future<List<Map>> getYtStreamUrls(String videoId) async {
    try {
      List<Map> urlData = [];

      // check cache first
      if (Hive.box('ytlinkcache').containsKey(videoId)) {
        final cachedData = Hive.box('ytlinkcache').get(videoId);
        if (cachedData is List) {
          int minExpiredAt = 0;
          for (final e in cachedData) {
            final int cachedExpiredAt = int.parse(e['expireAt'].toString());
            if (minExpiredAt == 0 || cachedExpiredAt < minExpiredAt) {
              minExpiredAt = cachedExpiredAt;
            }
          }

          if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) + 350 >
              minExpiredAt) {
            // cache expired
            urlData = await getUri(videoId);
          } else {
            // giving cache link
            Logger.root.info('cache found for $videoId');
            urlData = List<Map>.from(cachedData);
          }
        } else {
          // old version cache is present
          urlData = await getUri(videoId);
        }
      } else {
        //cache not present
        urlData = await getUri(videoId);
      }

      try {
        await Hive.box('ytlinkcache')
            .put(
              videoId,
              urlData,
            )
            .onError(
              (error, stackTrace) => Logger.root.severe(
                'Hive Error in formatVideo, you probably forgot to open box.\nError: $error',
              ),
            );
      } catch (e) {
        Logger.root.severe(
          'Hive Error in formatVideo, you probably forgot to open box.\nError: $e',
        );
      }

      return urlData;
    } catch (e) {
      Logger.root.severe('Error in getYtStreamUrls: $e');
      return [];
    }
  }

  Future<List<Map>> getUri(
    String videoId,
    // {bool preferM4a = true}
  ) async {
    final List<AudioOnlyStreamInfo> sortedStreamInfo =
        await getStreamInfo(videoId);
    return sortedStreamInfo
        .map(
          (e) => {
            'bitrate': e.bitrate.kiloBitsPerSecond.round().toString(),
            'codec': e.codec.subtype,
            'qualityLabel': e.qualityLabel,
            'size': e.size.totalMegaBytes.toStringAsFixed(2),
            'url': e.url.toString(),
            'expireAt': getExpireAt(e.url.toString()),
          },
        )
        .toList();
  }

  Future<List<AudioOnlyStreamInfo>> getStreamInfo(
    String videoId, {
    bool onlyMp4 = false,
  }) async {
    final StreamManifest manifest =
        await yt.videos.streamsClient.getManifest(VideoId(videoId));
    final List<AudioOnlyStreamInfo> sortedStreamInfo = manifest.audioOnly
        .toList()
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
    if (onlyMp4 || Platform.isIOS || Platform.isMacOS) {
      final List<AudioOnlyStreamInfo> m4aStreams = sortedStreamInfo
          .where((element) => element.audioCodec.contains('mp4'))
          .toList();

      if (m4aStreams.isNotEmpty) {
        return m4aStreams;
      }
    }

    return sortedStreamInfo;
  }

  Stream<List<int>> getStreamClient(
    AudioOnlyStreamInfo streamInfo,
  ) {
    return yt.videos.streamsClient.get(streamInfo);
  }
}
