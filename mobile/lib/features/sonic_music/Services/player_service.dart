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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:mobile/features/sonic_music/APIs/api.dart';
import 'package:mobile/features/sonic_music/Helpers/mediaitem_converter.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';
import 'package:mobile/features/sonic_music/Services/youtube_services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

// ignore: avoid_classes_with_only_static_members
class PlayerInvoke {
  static final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  static bool _hasPlayableRemoteUrl(Map? data) {
    final url = data?['url']?.toString() ?? '';
    return url.startsWith('http') &&
        !url.contains('/watch?') &&
        !url.contains('example.com/dummy');
  }

  static Future<void> _refreshSaavnItemIfNeeded(Map playItem) async {
    if (playItem['genre'] == 'YouTube' || _hasPlayableRemoteUrl(playItem)) {
      return;
    }

    final id = playItem['id']?.toString() ?? '';
    Map refreshed = {};
    if (id.isNotEmpty && id != 'null') {
      refreshed = await SaavnAPI().fetchSongDetails(id);
    }

    if (!_hasPlayableRemoteUrl(refreshed)) {
      final query =
          '${playItem['title'] ?? ''} ${playItem['artist'] ?? ''}'.trim();
      if (query.isNotEmpty) {
        final search = await SaavnAPI().fetchSongSearchResults(
          searchQuery: query,
          count: 1,
        );
        final songs = search['songs'];
        if (songs is List && songs.isNotEmpty) {
          refreshed = songs.first as Map;
        }
      }
    }

    if (_hasPlayableRemoteUrl(refreshed)) {
      playItem
        ..['id'] = refreshed['id']
        ..['url'] = refreshed['url']
        ..['title'] = refreshed['title'] ?? playItem['title']
        ..['artist'] = refreshed['artist'] ?? playItem['artist']
        ..['album'] = refreshed['album'] ?? playItem['album']
        ..['duration'] = refreshed['duration'] ?? playItem['duration']
        ..['image'] = refreshed['image'] ?? playItem['image']
        ..['language'] = refreshed['language'] ?? playItem['language']
        ..['genre'] = refreshed['genre'] ?? refreshed['language']
        ..['has_lyrics'] = refreshed['has_lyrics'] ?? playItem['has_lyrics']
        ..['320kbps'] = refreshed['320kbps'] ?? playItem['320kbps']
        ..['perma_url'] = refreshed['perma_url'] ?? playItem['perma_url'];
      Logger.root.info('Refreshed playable Saavn URL for ${playItem['title']}');
    } else {
      Logger.root.warning(
        'Unable to refresh playable Saavn URL for ${playItem['title'] ?? id}',
      );
    }
  }

  static Future<void> init({
    required List songsList,
    required int index,
    bool fromMiniplayer = false,
    bool? isOffline,
    bool recommend = true,
    bool fromDownloads = false,
    bool shuffle = false,
    String? playlistBox,
  }) async {
    final int globalIndex = index < 0 ? 0 : index;
    bool? offline = isOffline;
    final List finalList = songsList.toList();
    if (shuffle) finalList.shuffle();
    if (offline == null) {
      if (audioHandler.mediaItem.value?.extras!['url'].startsWith('http')
          as bool) {
        offline = false;
      } else {
        offline = true;
      }
    }

    if (!fromMiniplayer) {
      if (Platform.isIOS) {
        // Don't know why but it fixes the playback issue with iOS Side
        audioHandler.stop();
      }
      if (offline) {
        fromDownloads
            ? setDownValues(finalList, globalIndex)
            : (Platform.isWindows || Platform.isLinux)
                ? setOffDesktopValues(finalList, globalIndex)
                : setOffValues(finalList, globalIndex);
      } else {
        setValues(
          finalList,
          globalIndex,
          recommend: recommend,
          // playlistBox: playlistBox,
        );
      }
    }
  }

  static Future<MediaItem> setTags(
    SongModel response,
    Directory tempDir,
  ) async {
    String playTitle = response.title;
    playTitle == ''
        ? playTitle = response.displayNameWOExt
        : playTitle = response.title;
    String playArtist = response.artist!;
    playArtist == '<unknown>'
        ? playArtist = 'Unknown'
        : playArtist = response.artist!;

    final String playAlbum = response.album!;
    final int playDuration = response.duration ?? 180000;
    final String imagePath = '${tempDir.path}/${response.displayNameWOExt}.png';

    final MediaItem tempDict = MediaItem(
      id: response.id.toString(),
      album: playAlbum,
      duration: Duration(milliseconds: playDuration),
      title: playTitle.split('(')[0],
      artist: playArtist,
      genre: response.genre,
      artUri: Uri.file(imagePath),
      extras: {
        'url': response.data,
        'date_added': response.dateAdded,
        'date_modified': response.dateModified,
        'size': response.size,
        'year': response.getMap['year'],
      },
    );
    return tempDict;
  }

  static void setOffDesktopValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final File file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final List<MediaItem> queue = [];
      queue.addAll(
        response.map(
          (song) => MediaItem(
            id: song['id'].toString(),
            album: song['album'].toString(),
            artist: song['artist'].toString(),
            duration: Duration(
              seconds: int.parse(
                (song['duration'] == null || song['duration'] == 'null')
                    ? '180'
                    : song['duration'].toString(),
              ),
            ),
            title: song['title'].toString(),
            artUri: Uri.file(file.path),
            genre: song['genre'].toString(),
            extras: {
              'url': song['path'].toString(),
              'subtitle': song['subtitle'],
              'quality': song['quality'],
            },
          ),
        ),
      );
      updateNplay(queue, index);
    });
  }

  static void setOffValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final File file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final List<MediaItem> queue = [];
      for (int i = 0; i < response.length; i++) {
        queue.add(
          await setTags(response[i] as SongModel, tempDir),
        );
      }
      updateNplay(queue, index);
    });
  }

  static void setDownValues(List response, int index) {
    final List<MediaItem> queue = [];
    queue.addAll(
      response.map(
        (song) => MediaItemConverter.downMapToMediaItem(song as Map),
      ),
    );
    updateNplay(queue, index);
  }

  static Future<void> refreshYtLink(Map playItem) async {
    // final bool cacheSong =
    // Hive.box('settings').get('cacheSong', defaultValue: true) as bool;
    final int expiredAt = int.parse((playItem['expire_at'] ?? '0').toString());
    if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) + 350 > expiredAt) {
      Logger.root.info(
        'before service | youtube link expired for ${playItem["title"]}',
      );
      if (Hive.box('ytlinkcache').containsKey(playItem['id'])) {
        final cache = await Hive.box('ytlinkcache').get(playItem['id']);
        if (cache is List) {
          int minExpiredAt = 0;
          for (final e in cache) {
            final int cachedExpiredAt = int.parse(e['expireAt'].toString());
            if (minExpiredAt == 0 || cachedExpiredAt < minExpiredAt) {
              minExpiredAt = cachedExpiredAt;
            }
          }

          if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) + 350 >
              minExpiredAt) {
            // cache expired
            Logger.root
                .info('youtube link expired in cache for ${playItem["title"]}');
            final newData = await YouTubeServices.instance
                .refreshLink(playItem['id'].toString());
            Logger.root.info(
              'before service | received new link for ${playItem["title"]}',
            );
            if (_hasPlayableRemoteUrl(newData)) {
              final data = newData!;
              playItem['url'] = data['url'];
              playItem['duration'] = data['duration'];
              playItem['expire_at'] = data['expire_at'];
            } else {
              Logger.root.warning(
                'before service | no playable YouTube link for ${playItem["title"]}',
              );
            }
          } else {
            // giving cache link
            Logger.root
                .info('youtube link found in cache for ${playItem["title"]}');
            playItem['url'] = cache.last['url'];
            playItem['expire_at'] = cache.last['expireAt'];
          }
        } else {
          final newData = await YouTubeServices.instance
              .refreshLink(playItem['id'].toString());
          Logger.root.info(
            'before service | received new link for ${playItem["title"]}',
          );
          if (_hasPlayableRemoteUrl(newData)) {
            final data = newData!;
            playItem['url'] = data['url'];
            playItem['duration'] = data['duration'];
            playItem['expire_at'] = data['expire_at'];
          } else {
            Logger.root.warning(
              'before service | no playable YouTube link for ${playItem["title"]}',
            );
          }
        }
      } else {
        final newData = await YouTubeServices.instance
            .refreshLink(playItem['id'].toString());
        Logger.root.info(
          'before service | received new link for ${playItem["title"]}',
        );
        if (_hasPlayableRemoteUrl(newData)) {
          final data = newData!;
          playItem['url'] = data['url'];
          playItem['duration'] = data['duration'];
          playItem['expire_at'] = data['expire_at'];
        } else {
          Logger.root.warning(
            'before service | no playable YouTube link for ${playItem["title"]}',
          );
        }
      }
    }
  }

  static Future<void> setValues(
    List response,
    int index, {
    bool recommend = true,
    // String? playlistBox,
  }) async {
    final List<MediaItem> queue = [];
    final Map playItem = response[index] as Map;
    final Map? nextItem =
        index == response.length - 1 ? null : response[index + 1] as Map;
    if (playItem['genre'] == 'YouTube') {
      await refreshYtLink(playItem);
    } else {
      await _refreshSaavnItemIfNeeded(playItem);
    }
    if (nextItem != null && nextItem['genre'] == 'YouTube') {
      await refreshYtLink(nextItem);
    } else if (nextItem != null) {
      await _refreshSaavnItemIfNeeded(nextItem);
    }

    queue.addAll(
      response.map(
        (song) => MediaItemConverter.mapToMediaItem(
          song as Map,
          autoplay: recommend,
          // playlistBox: playlistBox,
        ),
      ),
    );
    await updateNplay(queue, index);
  }

  static Future<void> updateNplay(List<MediaItem> queue, int index) async {
    await audioHandler.updateQueue(queue);
    await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    await audioHandler.customAction('skipToMediaItem', {'index': index});
    await audioHandler.play();
    final String repeatMode =
        Hive.box('settings').get('repeatMode', defaultValue: 'None').toString();
    final bool enforceRepeat =
        Hive.box('settings').get('enforceRepeat', defaultValue: false) as bool;
    if (enforceRepeat) {
      switch (repeatMode) {
        case 'None':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        case 'All':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        case 'One':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        default:
          break;
      }
    } else {
      audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
      Hive.box('settings').put('repeatMode', 'None');
    }
  }
}
