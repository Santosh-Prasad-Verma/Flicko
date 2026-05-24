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

import 'package:mobile/features/sonic_music/Helpers/format.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

class SaavnAPI {
  List preferredLanguages = Hive.box('settings')
      .get('preferredLanguage', defaultValue: ['Hindi']) as List;
  Map<String, String> headers = {};
  String baseUrl = 'www.jiosaavn.com';
  String apiStr = '/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0';
  Box settingsBox = Hive.box('settings');
  static const String saavnFallbackHost = 'saavn.dev';
  Map<String, String> endpoints = {
    'homeData': '__call=webapi.getLaunchData',
    'topSearches': '__call=content.getTopSearches',
    'fromToken': '__call=webapi.get',
    'featuredRadio': '__call=webradio.createFeaturedStation',
    'artistRadio': '__call=webradio.createArtistStation',
    'entityRadio': '__call=webradio.createEntityStation',
    'radioSongs': '__call=webradio.getSong',
    'songDetails': '__call=song.getDetails',
    'playlistDetails': '__call=playlist.getDetails',
    'albumDetails': '__call=content.getAlbumDetails',
    'getResults': '__call=search.getResults',
    'albumResults': '__call=search.getAlbumResults',
    'artistResults': '__call=search.getArtistResults',
    'playlistResults': '__call=search.getPlaylistResults',
    'getReco': '__call=reco.getreco',
    'getAlbumReco': '__call=reco.getAlbumReco', // still not used
    'artistOtherTopSongs':
        '__call=search.artistOtherTopSongs', // still not used
  };

  Future<Response> getResponse(
    String params, {
    bool usev4 = true,
    bool useProxy = false,
  }) async {
    final String baseQuery = apiStr.split('?').last;
    final String query = usev4
        ? '$baseQuery&$params'
        : '$baseQuery&$params'.replaceAll('&api_version=4', '');
    final Uri url = Uri(
      scheme: 'https',
      host: baseUrl,
      path: '/api.php',
      query: query,
    );
    preferredLanguages =
        preferredLanguages.map((lang) => lang.toLowerCase()).toList();
    final String languageHeader = 'L=${preferredLanguages.join('%2C')}';
    headers = {
      'cookie': languageHeader,
      'Accept': '*/*',
      'Referer': 'https://www.jiosaavn.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    if (useProxy && settingsBox.get('useProxy', defaultValue: false) as bool) {
      final String proxyIP =
          settingsBox.get('proxyIp', defaultValue: '103.47.67.134').toString();
      final proxyHeaders = Map<String, String>.from(headers);
      proxyHeaders['X-FORWARDED-FOR'] = proxyIP;
      return get(url, headers: proxyHeaders).onError((error, stackTrace) {
        return Response(
          {
            'status': 'failure',
            'error': error.toString(),
          }.toString(),
          404,
        );
      });
    }
    return get(url, headers: headers).onError((error, stackTrace) {
      return Response(
        {
          'status': 'failure',
          'error': error.toString(),
        }.toString(),
        404,
      );
    });
  }

  Future<Map> fetchHomePageData() async {
    Map result = {};
    try {
      final res = await getResponse(endpoints['homeData']!, useProxy: false);
      if (res.statusCode == 200) {
        final Map data = json.decode(res.body) as Map;
        result = await FormatResponse.formatHomePageData(data);
      }
    } catch (e) {
      Logger.root.severe('Error in fetchHomePageData: $e');
    }
    return result;
  }

  Future<Map> getSongFromToken(
    String token,
    String type, {
    int n = 10,
    int p = 1,
  }) async {
    if (n == -1) {
      // loop through until all songs are fetch
      final String params =
          "token=$token&type=$type&n=5&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = json.decode(res.body) as Map;
          final String count = getMain['list_count'].toString();
          final String params2 =
              "token=$token&type=$type&n=$count&p=$p&${endpoints['fromToken']}";
          final res2 = await getResponse(params2);
          if (res2.statusCode == 200) {
            final Map getMain2 = json.decode(res2.body) as Map;
            final List responseList = ((type == 'album' || type == 'playlist')
                ? getMain2['list']
                : getMain2['songs']) as List;
            final result = {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
              'title': getMain2['title'],
            };
            return result;
          } else {
            Logger.root.severe(
              'getSongFromToken with -1 got res2 with ${res2.statusCode}: ${res2.body}',
            );
          }
        } else {
          Logger.root.severe(
            'getSongFromToken with -1 got ${res.statusCode}: ${res.body}',
          );
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken with -1: $e');
      }
      return {'songs': List.empty()};
    } else {
      final String params =
          "token=$token&type=$type&n=$n&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = json.decode(res.body) as Map;
          if (getMain['status'] == 'failure') {
            Logger.root.severe('Error in getSongFromToken response: $getMain');
            return {'songs': List.empty()};
          }
          if (type == 'album' || type == 'playlist') {
            return getMain;
          }
          if (type == 'show') {
            final List responseList = getMain['episodes'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
            };
          }
          if (type == 'mix') {
            final List responseList = getMain['list'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
            };
          }
          final List responseList = getMain['songs'] as List;
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, type),
            'title': getMain['title'],
          };
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken: $e');
      }
      return {'songs': List.empty()};
    }
  }

  Future<List> getReco(String pid) async {
    final String params = "${endpoints['getReco']}&pid=$pid";
    final res = await getResponse(params);
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final List getMain = json.decode(res.body) as List;
      return FormatResponse.formatSongsResponse(getMain, 'song');
    } else {
      Logger.root.warning(
        'Error in getReco returned status: ${res.statusCode}, response: ${res.body}',
      );
    }
    return List.empty();
  }

  Future<String?> createRadio({
    required List<String> names,
    required String stationType,
    String? language,
  }) async {
    String? params;
    if (stationType == 'featured') {
      params =
          "name=${names[0]}&language=$language&${endpoints['featuredRadio']}";
    }
    if (stationType == 'artist') {
      params =
          "name=${names[0]}&query=${names[0]}&language=$language&${endpoints['artistRadio']}";
    }
    if (stationType == 'entity') {
      params =
          'entity_id=${names.map((e) => '"$e"').toList()}&entity_type=queue&${endpoints["entityRadio"]}';
    }

    final res = await getResponse(params!);
    if (res.statusCode == 200) {
      final Map getMain = json.decode(res.body) as Map;
      return getMain['stationid']?.toString();
    }
    return null;
  }

  Future<List> getRadioSongs({
    required String stationId,
    int count = 20,
    int next = 1,
  }) async {
    if (count > 0) {
      final String params =
          "stationid=$stationId&k=$count&next=$next&${endpoints['radioSongs']}";
      final res = await getResponse(params, useProxy: false);
      if (res.statusCode == 200) {
        final Map getMain = json.decode(res.body) as Map;
        final List responseList = [];
        if (getMain['error'] != null && getMain['error'] != '') {
          return [];
        }
        for (int i = 0; i < count; i++) {
          responseList.add(getMain[i.toString()]['song']);
        }
        return FormatResponse.formatSongsResponse(responseList, 'song');
      }
      return [];
    }
    return [];
  }

  Future<List<String>> getTopSearches() async {
    try {
      final res = await getResponse(endpoints['topSearches']!);
      if (res.statusCode == 200) {
        final List getMain = json.decode(res.body) as List;
        return getMain.map((element) {
          return element['title'].toString();
        }).toList();
      }
    } catch (e) {
      Logger.root.severe('Error in getTopSearches: $e');
    }
    return List.empty();
  }

  Future<Map> fetchSongSearchResults({
    required String searchQuery,
    int count = 20,
    int page = 1,
  }) async {
    final String params =
        'p=$page&q=${Uri.encodeQueryComponent(searchQuery)}&n=$count&${endpoints["getResults"]}';
    try {
      final res = await getResponse(params, useProxy: false);
      if (res.statusCode == 200) {
        final Map getMain = json.decode(res.body) as Map;
        final List responseList = getMain['results'] as List;
        final finalSongs =
            await FormatResponse.formatSongsResponse(responseList, 'song');
        if (finalSongs.length > count) {
          finalSongs.removeRange(count, finalSongs.length);
        }
        if (finalSongs.isNotEmpty) {
          return {
            'songs': finalSongs,
            'error': '',
          };
        }
        final fallbackSongs = await _fetchSongSearchResultsFromSaavnDev(
          searchQuery: searchQuery,
          count: count,
          page: page,
        );
        if (fallbackSongs.isNotEmpty) {
          return {
            'songs': fallbackSongs,
            'error': '',
          };
        }
        return {
          'songs': finalSongs,
          'error': '',
        };
      } else {
        final fallbackSongs = await _fetchSongSearchResultsFromSaavnDev(
          searchQuery: searchQuery,
          count: count,
          page: page,
        );
        if (fallbackSongs.isNotEmpty) {
          return {
            'songs': fallbackSongs,
            'error': '',
          };
        }
        return {
          'songs': List.empty(),
          'error': res.body,
        };
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSongSearchResults: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<List<Map>> _fetchSongSearchResultsFromSaavnDev({
    required String searchQuery,
    required int count,
    required int page,
  }) async {
    try {
      final url = Uri.https(saavnFallbackHost, '/api/search/songs', {
        'query': searchQuery,
        'page': page.toString(),
        'limit': count.toString(),
      });
      final res = await get(url, headers: headers);
      if (res.statusCode != 200 || res.body.isEmpty) {
        Logger.root.warning(
          'Saavn fallback search returned ${res.statusCode}: ${res.body}',
        );
        return List.empty();
      }

      final decoded = json.decode(res.body);
      final data = decoded is Map ? decoded['data'] : null;
      final results = data is Map ? data['results'] : data;
      if (results is! List) return List.empty();

      final songs = results
          .whereType<Map>()
          .map(_formatSaavnDevSong)
          .where((song) => song['url']?.toString().isNotEmpty == true)
          .toList();
      if (songs.length > count) {
        return songs.sublist(0, count);
      }
      return songs;
    } catch (e) {
      Logger.root.warning('Saavn fallback search failed: $e');
      return List.empty();
    }
  }

  Map _formatSaavnDevSong(Map song) {
    final album = song['album'];
    final artists = song['artists'];
    final image = _pickSaavnValue(song['image']);
    final streamUrl = _pickSaavnValue(song['downloadUrl'], preferHigh: true);
    final artist = _artistNames(artists);
    final language = _capitalize(song['language']?.toString() ?? '');

    return {
      'id': song['id'],
      'type': 'song',
      'album': album is Map ? album['name'] : song['album'] ?? '',
      'year': song['year'],
      'duration': song['duration'] ?? '180',
      'language': language.isEmpty ? 'Hindi' : language,
      'genre': language.isEmpty ? 'Hindi' : language,
      '320kbps': streamUrl.contains('_320.') || streamUrl.contains('320'),
      'has_lyrics': song['hasLyrics'] ?? false,
      'lyrics_snippet': '',
      'release_date': song['releaseDate'],
      'album_id': album is Map ? album['id'] : null,
      'subtitle': artist.isEmpty
          ? (album is Map ? album['name']?.toString() ?? '' : '')
          : '$artist - ${album is Map ? album['name'] ?? '' : ''}',
      'title': song['name'] ?? song['title'] ?? '',
      'artist': artist.isEmpty ? 'Unknown' : artist,
      'album_artist': artist,
      'image': image,
      'perma_url': song['url'],
      'url': streamUrl,
    };
  }

  String _pickSaavnValue(dynamic values, {bool preferHigh = false}) {
    if (values is String) return values;
    if (values is! List || values.isEmpty) return '';

    final maps = values.whereType<Map>().toList();
    if (maps.isEmpty) return '';
    Map selected = maps.last;
    if (preferHigh) {
      selected = maps.firstWhere(
        (item) => item['quality']?.toString().contains('320') == true,
        orElse: () => maps.last,
      );
    }
    return (selected['url'] ?? selected['link'] ?? '').toString();
  }

  String _artistNames(dynamic artists) {
    if (artists is String) return artists;
    if (artists is! Map) return '';

    final allArtists = artists['primary'] ?? artists['all'];
    if (allArtists is List) {
      return allArtists
          .whereType<Map>()
          .map((artist) => artist['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');
    }
    return '';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<List<Map<String, dynamic>>> fetchSearchResults(
    String searchQuery,
  ) async {
    final Map<String, List> result = {};
    final Map<int, String> position = {};
    List searchedSongList = [];
    List searchedAlbumList = [];
    List searchedPlaylistList = [];
    List searchedArtistList = [];
    List searchedTopQueryList = [];

    final String params =
        '__call=autocomplete.get&cc=in&includeMetaTags=1&query=${Uri.encodeQueryComponent(searchQuery)}';

    final res = await getResponse(params, usev4: false, useProxy: false);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      if (getMain is Map) {
        if (getMain['albums'] != null &&
            getMain['albums'] is Map &&
            getMain['albums']['data'] != null) {
          final List albumResponseList = getMain['albums']['data'] as List;
          if (getMain['albums']['position'] != null) {
            position[getMain['albums']['position'] as int] = 'Albums';
          }
          searchedAlbumList = await FormatResponse.formatAlbumResponse(
              albumResponseList, 'album');
          if (searchedAlbumList.isNotEmpty) {
            result['Albums'] = searchedAlbumList;
          }
        }

        if (getMain['playlists'] != null &&
            getMain['playlists'] is Map &&
            getMain['playlists']['data'] != null) {
          final List playlistResponseList =
              getMain['playlists']['data'] as List;
          if (getMain['playlists']['position'] != null) {
            position[getMain['playlists']['position'] as int] = 'Playlists';
          }
          searchedPlaylistList = await FormatResponse.formatAlbumResponse(
            playlistResponseList,
            'playlist',
          );
          if (searchedPlaylistList.isNotEmpty) {
            result['Playlists'] = searchedPlaylistList;
          }
        }

        if (getMain['artists'] != null &&
            getMain['artists'] is Map &&
            getMain['artists']['data'] != null) {
          final List artistResponseList = getMain['artists']['data'] as List;
          if (getMain['artists']['position'] != null) {
            position[getMain['artists']['position'] as int] = 'Artists';
          }
          searchedArtistList = await FormatResponse.formatAlbumResponse(
            artistResponseList,
            'artist',
          );
          if (searchedArtistList.isNotEmpty) {
            result['Artists'] = searchedArtistList;
          }
        }

        searchedSongList = (await SaavnAPI().fetchSongSearchResults(
              searchQuery: searchQuery,
              count: 5,
            ))['songs'] as List? ??
            [];
        if (searchedSongList.isNotEmpty) {
          result['Songs'] = searchedSongList;
        }

        final topQueryData =
            getMain['topquery'] != null && getMain['topquery'] is Map
                ? getMain['topquery']['data']
                : null;
        final List topQuery = topQueryData is List ? topQueryData : [];

        if (topQuery.isNotEmpty &&
            (topQuery[0]['type'] != 'playlist' ||
                topQuery[0]['type'] == 'artist' ||
                topQuery[0]['type'] == 'album')) {
          if (getMain['topquery'] != null &&
              getMain['topquery']['position'] != null) {
            position[getMain['topquery']['position'] as int] = 'Top Result';
          }
          if (getMain['songs'] != null &&
              getMain['songs'] is Map &&
              getMain['songs']['position'] != null) {
            position[getMain['songs']['position'] as int] = 'Songs';
          }

          final String topQueryType = topQuery[0]['type']?.toString() ?? '';
          switch (topQueryType) {
            case 'artist':
              searchedTopQueryList =
                  await FormatResponse.formatAlbumResponse(topQuery, 'artist');
            case 'album':
              searchedTopQueryList =
                  await FormatResponse.formatAlbumResponse(topQuery, 'album');
            case 'playlist':
              searchedTopQueryList = await FormatResponse.formatAlbumResponse(
                  topQuery, 'playlist');
            default:
              break;
          }
          if (searchedTopQueryList.isNotEmpty) {
            result['Top Result'] = searchedTopQueryList;
          }
        } else {
          if (topQuery.isNotEmpty && topQuery[0]['type'] == 'song') {
            if (getMain['topquery'] != null &&
                getMain['topquery']['position'] != null) {
              position[getMain['topquery']['position'] as int] = 'Songs';
            }
          } else {
            if (getMain['songs'] != null &&
                getMain['songs'] is Map &&
                getMain['songs']['position'] != null) {
              position[getMain['songs']['position'] as int] = 'Songs';
            }
          }
        }
      }
    }

    final sortedKeys = position.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final List<Map<String, dynamic>> finalList = [];
    for (final entry in sortedKeys) {
      if (result.containsKey(entry.value)) {
        finalList.add({'title': entry.value, 'items': result[entry.value]});
      }
    }
    if (finalList.isEmpty) {
      final songs = (await fetchSongSearchResults(
            searchQuery: searchQuery,
            count: 20,
          ))['songs'] as List? ??
          [];
      if (songs.isNotEmpty) {
        finalList.add({'title': 'Songs', 'items': songs});
      }
    }
    return finalList;
  }

  Future<List<Map>> fetchAlbums({
    required String searchQuery,
    required String type,
    int count = 20,
    int page = 1,
  }) async {
    String? params;
    if (type == 'playlist') {
      params =
          'p=$page&q=${Uri.encodeQueryComponent(searchQuery)}&n=$count&${endpoints["playlistResults"]}';
    }
    if (type == 'album') {
      params =
          'p=$page&q=${Uri.encodeQueryComponent(searchQuery)}&n=$count&${endpoints["albumResults"]}';
    }
    if (type == 'artist') {
      params =
          'p=$page&q=${Uri.encodeQueryComponent(searchQuery)}&n=$count&${endpoints["artistResults"]}';
    }

    final res = await getResponse(params!);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      final List responseList = getMain['results'] as List;
      return FormatResponse.formatAlbumResponse(responseList, type);
    }
    return List.empty();
  }

  Future<Map> fetchAlbumSongs(String albumId) async {
    final String params = '${endpoints['albumDetails']}&cc=in&albumid=$albumId';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final getMain = json.decode(res.body);
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, 'album'),
            'error': '',
          };
        }
      }
      Logger.root.severe('Songs not found in fetchAlbumSongs: ${res.body}');
      return {
        'songs': List.empty(),
        'error': '',
      };
    } catch (e) {
      Logger.root.severe('Error in fetchAlbumSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<Map<String, List>> fetchArtistSongs({
    required String artistToken,
    String category = '',
    String sortOrder = '',
  }) async {
    final Map<String, List> data = {};
    final String params =
        '${endpoints["fromToken"]}&type=artist&p=&n_song=50&n_album=50&sub_type=&category=$category&sort_order=$sortOrder&includeMetaTags=0&token=$artistToken';
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body) as Map;
      final List topSongsResponseList = getMain['topSongs'] as List;
      final List latestReleaseResponseList = getMain['latest_release'] as List;
      final List topAlbumsResponseList = getMain['topAlbums'] as List;
      final List singlesResponseList = getMain['singles'] as List;
      final List dedicatedResponseList =
          getMain['dedicated_artist_playlist'] as List;
      final List featuredResponseList =
          getMain['featured_artist_playlist'] as List;
      final List similarArtistsResponseList = getMain['similarArtists'] as List;

      final List topSongsSearchedList =
          await FormatResponse.formatSongsResponse(
        topSongsResponseList,
        'song',
      );
      if (topSongsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topSongs']?['title']?.toString() ??
            'Top Songs'] = topSongsSearchedList;
      }

      final List latestReleaseSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        latestReleaseResponseList,
      );
      if (latestReleaseSearchedList.isNotEmpty) {
        data[getMain['modules']?['latest_release']?['title']?.toString() ??
            'Latest Releases'] = latestReleaseSearchedList;
      }

      final List topAlbumsSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        topAlbumsResponseList,
      );
      if (topAlbumsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topAlbums']?['title']?.toString() ??
            'Top Albums'] = topAlbumsSearchedList;
      }

      final List singlesSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        singlesResponseList,
      );
      if (singlesSearchedList.isNotEmpty) {
        data[getMain['modules']?['singles']?['title']?.toString() ??
            'Singles'] = singlesSearchedList;
      }

      final List dedicatedSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        dedicatedResponseList,
      );
      if (dedicatedSearchedList.isNotEmpty) {
        data[getMain['modules']?['dedicated_artist_playlist']?['title']
                ?.toString() ??
            'Dedicated Playlists'] = dedicatedSearchedList;
      }

      final List featuredSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        featuredResponseList,
      );
      if (featuredSearchedList.isNotEmpty) {
        data[getMain['modules']?['featured_artist_playlist']?['title']
                ?.toString() ??
            'Featured Playlists'] = featuredSearchedList;
      }

      final List similarArtistsSearchedList =
          await FormatResponse.formatSimilarArtistsResponse(
        similarArtistsResponseList,
      );
      if (similarArtistsSearchedList.isNotEmpty) {
        data[getMain['modules']?['similarArtists']?['title']?.toString() ??
            'Similar Artists'] = similarArtistsSearchedList;
      }
    }
    return data;
  }

  Future<Map> fetchPlaylistSongs(String playlistId) async {
    final String params =
        '${endpoints["playlistDetails"]}&cc=in&listid=$playlistId';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final getMain = json.decode(res.body);
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          return {
            'songs': await FormatResponse.formatSongsResponse(
              responseList,
              'playlist',
            ),
            'error': '',
          };
        }
        return {
          'songs': List.empty(),
          'error': '',
        };
      } else {
        return {
          'songs': List.empty(),
          'error': res.body,
        };
      }
    } catch (e) {
      Logger.root.severe('Error in fetchPlaylistSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<Map> fetchSongDetails(String songId) async {
    final String params = 'pids=$songId&${endpoints["songDetails"]}';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final Map data = json.decode(res.body) as Map;
        final songs = data['songs'];
        if (songs is! List || songs.isEmpty) {
          Logger.root
              .warning('Song details not found for $songId: ${res.body}');
          return {};
        }
        return await FormatResponse.formatSingleSongResponse(
          songs[0] as Map,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSongDetails: $e');
    }
    return {};
  }
}
