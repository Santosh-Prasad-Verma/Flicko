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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/voice/services/flicko_audio_handler.dart';
import 'package:mobile/features/sonic_music/APIs/api.dart';
import 'package:mobile/features/sonic_music/Helpers/mediaitem_converter.dart';
import 'package:mobile/features/sonic_music/Helpers/playlist.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';
import 'package:mobile/features/sonic_music/Services/isolate_service.dart';
import 'package:mobile/features/sonic_music/Services/yt_music.dart';
import 'package:mobile/features/sonic_music/Services/youtube_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerHandlerImpl extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioPlayerHandler {
  int? count;
  Timer? _sleepTimer;
  bool recommend = true;
  bool loadStart = true;
  bool useDown = true;
  AndroidEqualizerParameters? _equalizerParams;

  late AudioPlayer? _player;
  late String connectionType = 'mobile';
  late String preferredQuality;
  late String preferredWifiQuality;
  late String preferredMobileQuality;
  late List<int> preferredCompactNotificationButtons = [1, 2, 3];
  late bool resetOnSkip;
  // late String? stationId = '';
  // late List<String> stationNames = [];
  // late String stationType = 'entity';
  late bool cacheSong;
  final _equalizer = AndroidEqualizer();

  Box? downloadsBox =
      Hive.isBoxOpen('downloads') ? Hive.box('downloads') : null;
  final List<String> refreshLinks = [];
  bool jobRunning = false;
  String _lastRetriedId = '';
  final Set<String> _retryingIds = {};
  final Set<String> _forceDirectPlayIds = {};
  static const Map<String, String> _youtubeStreamHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  };

  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject.seeded(<MediaItem>[]);
  final _playlist = ConcatenatingAudioSource(children: []);
  @override
  final BehaviorSubject<double> volume = BehaviorSubject.seeded(1.0);
  @override
  final BehaviorSubject<double> speed = BehaviorSubject.seeded(1.0);
  final _mediaItemExpando = Expando<MediaItem>();

  Stream<List<IndexedAudioSource>> get _effectiveSequence => Rx.combineLatest3<
              List<IndexedAudioSource>?,
              List<int>?,
              bool,
              List<IndexedAudioSource>?>(_player!.sequenceStream,
          _player!.shuffleIndicesStream, _player!.shuffleModeEnabledStream,
          (sequence, shuffleIndices, shuffleModeEnabled) {
        if (sequence == null) return [];
        if (!shuffleModeEnabled) return sequence;
        if (shuffleIndices == null) return null;
        if (shuffleIndices.length != sequence.length) return null;
        return shuffleIndices.map((i) => sequence[i]).toList();
      }).whereType<List<IndexedAudioSource>>();

  int? getQueueIndex(
    int? currentIndex,
    List<int>? shuffleIndices, {
    bool shuffleModeEnabled = false,
  }) {
    final effectiveIndices = _player!.effectiveIndices ?? [];
    final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
    for (var i = 0; i < effectiveIndices.length; i++) {
      shuffleIndicesInv[effectiveIndices[i]] = i;
    }
    return (shuffleModeEnabled &&
            ((currentIndex ?? 0) < shuffleIndicesInv.length))
        ? shuffleIndicesInv[currentIndex ?? 0]
        : currentIndex;
  }

  @override
  Stream<QueueState> get queueState =>
      Rx.combineLatest3<List<MediaItem>, PlaybackState, List<int>, QueueState>(
        queue,
        playbackState,
        _player!.shuffleIndicesStream.whereType<List<int>>(),
        (queue, playbackState, shuffleIndices) => QueueState(
          queue,
          playbackState.queueIndex,
          playbackState.shuffleMode == AudioServiceShuffleMode.all
              ? shuffleIndices
              : null,
          playbackState.repeatMode,
        ),
      ).where(
        (state) =>
            state.shuffleIndices == null ||
            state.queue.length == state.shuffleIndices!.length,
      );

  AudioPlayerHandlerImpl() {
    _init();
  }

  void _activateDelegate() {
    try {
      if (GetIt.I.isRegistered<FlickoAudioHandler>()) {
        final handler = GetIt.I<FlickoAudioHandler>();
        if (handler.delegate != this) {
          handler.setDelegate(this);
        }
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    _activateDelegate();
    Logger.root.info('starting audio service');
    if (Hive.isBoxOpen('settings')) {
      preferredCompactNotificationButtons = Hive.box('settings').get(
        'preferredCompactNotificationButtons',
        defaultValue: [1, 2, 3],
      ) as List<int>;
      if (preferredCompactNotificationButtons.length > 3) {
        preferredCompactNotificationButtons = [1, 2, 3];
      }
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await startService();

    await startBackgroundProcessing();

    speed.debounceTime(const Duration(milliseconds: 250)).listen((speed) {
      playbackState.add(playbackState.value.copyWith(speed: speed));
    });

    Logger.root.info('checking connectivity & setting quality');

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final ConnectivityResult result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result == ConnectivityResult.mobile) {
        connectionType = 'mobile';
        Logger.root.info(
          'player | switched to mobile data, changing quality to $preferredMobileQuality',
        );
        preferredQuality = preferredMobileQuality;
      } else if (result == ConnectivityResult.wifi) {
        connectionType = 'wifi';
        Logger.root.info(
          'player | wifi connected, changing quality to $preferredWifiQuality',
        );
        preferredQuality = preferredWifiQuality;
      } else if (result == ConnectivityResult.none) {
        Logger.root.severe(
          'player | internet connection not available',
        );
      } else {
        Logger.root.info(
          'player | unidentified network connection',
        );
      }
    });

    preferredMobileQuality = Hive.box('settings')
        .get('streamingQuality', defaultValue: '96 kbps')
        .toString();
    preferredWifiQuality = Hive.box('settings')
        .get('streamingWifiQuality', defaultValue: '320 kbps')
        .toString();
    preferredQuality = connectionType == 'wifi'
        ? preferredWifiQuality
        : preferredMobileQuality;
    resetOnSkip =
        Hive.box('settings').get('resetOnSkip', defaultValue: false) as bool;
    cacheSong =
        Hive.box('settings').get('cacheSong', defaultValue: true) as bool;
    recommend =
        Hive.box('settings').get('autoplay', defaultValue: true) as bool;
    loadStart =
        Hive.box('settings').get('loadStart', defaultValue: true) as bool;

    mediaItem.whereType<MediaItem>().listen((item) {
      if (count != null) {
        count = count! - 1;
        if (count! <= 0) {
          count = null;
          stop();
        }
      }

      if (item.artUri.toString().startsWith('http')) {
        addRecentlyPlayed(item);
        _recentSubject.add([item]);

        if (recommend && item.extras!['autoplay'] as bool) {
          final List<MediaItem> mediaQueue = queue.value;
          final int index = mediaQueue.indexOf(item);
          final int queueLength = mediaQueue.length;
          if (queueLength - index < 5) {
            Logger.root.info('less than 5 songs remaining, adding more songs');
            Future.delayed(const Duration(seconds: 1), () async {
              if (item == mediaItem.value) {
                if (item.genre != 'YouTube') {
                  final List value = await SaavnAPI().getReco(item.id);
                  value.shuffle();
                  // final List value = await SaavnAPI().getRadioSongs(
                  //     stationId: stationId!, count: queueLength - index - 20);

                  for (int i = 0; i < value.length; i++) {
                    final element = MediaItemConverter.mapToMediaItem(
                      value[i] as Map,
                      addedByAutoplay: true,
                    );
                    if (!mediaQueue.contains(element)) {
                      addQueueItem(element);
                    }
                  }
                } else {
                  final res = await YtMusicService().getWatchPlaylist(
                    videoId: item.id,
                    limit: 15,
                  );
                  Logger.root.info('Recieved recommendations: $res');
                  refreshLinks.addAll(res);
                  if (!jobRunning) {
                    refreshJob();
                  }
                }
              }
            });
          }
        }
      }
    });

    Rx.combineLatest4<int?, List<MediaItem>, bool, List<int>?, MediaItem?>(
        _player!.currentIndexStream,
        queue,
        _player!.shuffleModeEnabledStream,
        _player!.shuffleIndicesStream,
        (index, queue, shuffleModeEnabled, shuffleIndices) {
      final queueIndex = getQueueIndex(
        index,
        shuffleIndices,
        shuffleModeEnabled: shuffleModeEnabled,
      );
      return (queueIndex != null && queueIndex < queue.length)
          ? queue[queueIndex]
          : null;
    }).whereType<MediaItem>().distinct().listen(mediaItem.add);

    // Propagate all events from the audio player to AudioService clients.
    _player!.playbackEventStream
        .listen(_broadcastState, onError: _playbackError);

    _player!.shuffleModeEnabledStream
        .listen((enabled) => _broadcastState(_player!.playbackEvent));

    _player!.loopModeStream
        .listen((event) => _broadcastState(_player!.playbackEvent));

    _player!.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
        _player!.seek(Duration.zero, index: 0);
      }
    });
    // Broadcast the current queue.
    _effectiveSequence
        .map(
          (sequence) =>
              sequence.map((source) => _mediaItemExpando[source]!).toList(),
        )
        .pipe(queue);

    try {
      if (loadStart) {
        final List lastQueueList = await Hive.box('cache')
            .get('lastQueue', defaultValue: [])?.toList() as List;

        final int lastIndex =
            await Hive.box('cache').get('lastIndex', defaultValue: 0) as int;

        final int lastPos =
            await Hive.box('cache').get('lastPos', defaultValue: 0) as int;

        if (lastQueueList.isNotEmpty &&
            lastQueueList.first['genre'] != 'YouTube') {
          final List<MediaItem> lastQueue = lastQueueList
              .map((e) => MediaItemConverter.mapToMediaItem(e as Map))
              .toList();
          if (lastQueue.isEmpty) {
            await _player!
                .setAudioSource(_playlist, preload: false)
                .onError((error, stackTrace) {
              _onError(error, stackTrace, stopService: true);
              return null;
            });
          } else {
            await _playlist.addAll(_itemsToSources(lastQueue));
            try {
              await _player!
                  .setAudioSource(
                _playlist,
                // commented out due to some bug in audio_service which causes app to freeze
                // instead manually seeking after audiosource initialised

                // initialIndex: lastIndex,
                // initialPosition: Duration(seconds: lastPos),
              )
                  .onError((error, stackTrace) {
                _onError(error, stackTrace, stopService: true);
                return null;
              });
              if (lastIndex != 0 || lastPos > 0) {
                await _player!
                    .seek(Duration(seconds: lastPos), index: lastIndex);
              }
            } catch (e) {
              Logger.root.severe('Error while setting last audiosource', e);
              await _player!
                  .setAudioSource(_playlist, preload: false)
                  .onError((error, stackTrace) {
                _onError(error, stackTrace, stopService: true);
                return null;
              });
            }
          }
        } else {
          await _player!
              .setAudioSource(_playlist, preload: false)
              .onError((error, stackTrace) {
            _onError(error, stackTrace, stopService: true);
            return null;
          });
        }
      } else {
        await _player!
            .setAudioSource(_playlist, preload: false)
            .onError((error, stackTrace) {
          _onError(error, stackTrace, stopService: true);
          return null;
        });
      }
    } catch (e) {
      Logger.root.severe('Error while loading last queue', e);
      await _player!
          .setAudioSource(_playlist, preload: false)
          .onError((error, stackTrace) {
        _onError(error, stackTrace, stopService: true);
        return null;
      });
    }
    if (!jobRunning) {
      refreshJob();
    }
  }

  Future<void> refreshJob() async {
    jobRunning = true;
    while (refreshLinks.isNotEmpty) {
      addIdToBackgroundProcessingIsolate(refreshLinks.removeAt(0));
    }
    jobRunning = false;
  }

  Future<void> refreshLink(Map newData) async {
    if (!_hasPlayableRemoteUrl(newData)) {
      Logger.root.warning(
        'player | received refresh data without a playable URL for ${newData['title'] ?? newData['id']}',
      );
      return;
    }
    Logger.root.info('player | received new link for ${newData['title']}');
    final MediaItem newItem = MediaItemConverter.mapToMediaItem(newData);
    // final String? boxName = mediaItem.extras!['playlistBox']?.toString();
    // if (boxName != null) {
    //   Logger.root.info('linked with playlist $boxName');
    //   if (Hive.box(mediaItem.extras!['playlistBox'].toString())
    //       .containsKey(mediaItem.id)) {
    //     Logger.root.info('updating item in playlist $boxName');
    //     Hive.box(mediaItem.extras!['playlistBox'].toString()).put(
    //       mediaItem.id,
    //       MediaItemConverter.mediaItemToMap(newItem),
    //     );
    //     // put(
    //     //   mediaItem.id,
    //     //   MediaItemConverter.mediaItemToMap(newItem),
    //     // );
    //   }
    // }
    // Logger.root.info('player | inserting refreshed item');
    // late AudioSource audioSource;
    // if (cacheSong) {
    //   audioSource = LockCachingAudioSource(
    //     Uri.parse(
    //       newItem.extras!['url'].toString(),
    //     ),
    //   );
    // } else {
    //   audioSource = AudioSource.uri(
    //     Uri.parse(
    //       newItem.extras!['url'].toString(),
    //     ),
    //   );
    // }
    // final index = queue.value.indexWhere((item) => item.id == newItem.id);
    // _mediaItemExpando[audioSource] = newItem;
    // _playlist
    // .removeAt(index)
    // .then((value) =>
    // _playlist.insert(index, audioSource));
    addQueueItem(newItem);
  }

  bool _hasPlayableRemoteUrl(Map? data) {
    final url = data?['url']?.toString() ?? '';
    return _isPlayableRemoteUrl(url);
  }

  bool _isPlayableRemoteUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    return trimmed.startsWith('http') &&
        !trimmed.contains('/watch?') &&
        !trimmed.contains('example.com/dummy');
  }

  String? _saavnStreamUrl(MediaItem mediaItem) {
    final rawUrl = mediaItem.extras?['url']?.toString();
    if (!_isPlayableRemoteUrl(rawUrl)) {
      Logger.root.warning(
        'Skipping JioSaavn source with missing URL: ${mediaItem.id} ${mediaItem.title}',
      );
      return null;
    }
    final quality = preferredQuality.replaceAll(' kbps', '');
    final has320 = mediaItem.extras?['320kbps'] == true ||
        mediaItem.extras?['320kbps']?.toString().toLowerCase() == 'true';
    if (quality == '320' && !has320) {
      return rawUrl;
    }
    return rawUrl!.replaceAll(
      '_96.',
      '_$quality.',
    );
  }

  AudioSource? _itemToSource(MediaItem mediaItem) {
    AudioSource? audioSource;
    try {
      if (mediaItem.artUri.toString().startsWith('file:')) {
        audioSource =
            AudioSource.uri(Uri.file(mediaItem.extras!['url'].toString()));
      } else {
        if (downloadsBox != null &&
            downloadsBox!.containsKey(mediaItem.id) &&
            useDown) {
          Logger.root.info('Found ${mediaItem.id} in downloads');
          audioSource = AudioSource.uri(
            Uri.file(
              (downloadsBox!.get(mediaItem.id) as Map)['path'].toString(),
            ),
            tag: mediaItem.id,
          );
        } else {
          if (mediaItem.genre == 'YouTube') {
            final rawUrl = mediaItem.extras?['url']?.toString();
            final int expiredAt =
                int.parse((mediaItem.extras!['expire_at'] ?? '0').toString());
            if (!_isPlayableRemoteUrl(rawUrl) ||
                (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 350 >
                    expiredAt) {
              // Logger.root.info(
              //   'player | youtube link expired for ${mediaItem.title}, searching cache',
              // );
              if (Hive.box('ytlinkcache').containsKey(mediaItem.id)) {
                final cachedData = Hive.box('ytlinkcache').get(mediaItem.id);
                if (cachedData is List) {
                  int minExpiredAt = 0;
                  for (final e in cachedData) {
                    final int cachedExpiredAt =
                        int.parse(e['expireAt'].toString());
                    if (minExpiredAt == 0 || cachedExpiredAt < minExpiredAt) {
                      minExpiredAt = cachedExpiredAt;
                    }
                  }

                  if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) + 350 >
                      minExpiredAt) {
                    Logger.root.info(
                      'youtube link expired for ${mediaItem.title}, refreshing',
                    );
                    refreshLinks.add(mediaItem.id);
                    if (!jobRunning) {
                      refreshJob();
                    }
                  } else {
                    Logger.root.info(
                      'youtube link found in cache for ${mediaItem.title}',
                    );
                    final cachedUrl = cachedData.last['url']?.toString();
                    if (_isPlayableRemoteUrl(cachedUrl)) {
                      audioSource = AudioSource.uri(
                        Uri.parse(cachedUrl!),
                        headers: _youtubeStreamHeaders,
                      );
                      mediaItem.extras!['url'] = cachedUrl;
                      _mediaItemExpando[audioSource] = mediaItem;
                      return audioSource;
                    }
                    Logger.root.warning(
                      'cached youtube link was not playable for ${mediaItem.title}, refreshing',
                    );
                    refreshLinks.add(mediaItem.id);
                    if (!jobRunning) {
                      refreshJob();
                    }
                  }
                } else {
                  Logger.root.info(
                    'old youtube link cache found for ${mediaItem.title}, refreshing',
                  );
                  refreshLinks.add(mediaItem.id);
                  if (!jobRunning) {
                    refreshJob();
                  }
                }
              } else {
                Logger.root.info(
                  'youtube link not found in cache for ${mediaItem.title}, refreshing',
                );
                refreshLinks.add(mediaItem.id);
                if (!jobRunning) {
                  refreshJob();
                }
              }
            } else {
              audioSource = AudioSource.uri(
                Uri.parse(rawUrl!),
                headers: _youtubeStreamHeaders,
              );
              _mediaItemExpando[audioSource] = mediaItem;
              return audioSource;
            }
          } else {
            final streamUrl = _saavnStreamUrl(mediaItem);
            if (streamUrl == null) return null;
            if (_forceDirectPlayIds.contains(mediaItem.id)) {
              Logger.root.warning(
                'Forcing direct play for track: ${mediaItem.title}',
              );
            }
            audioSource = AudioSource.uri(
              Uri.parse(streamUrl),
            );
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error while creating audiosource', e);
    }
    if (audioSource != null) {
      _mediaItemExpando[audioSource] = mediaItem;
    }
    return audioSource;
  }

  List<AudioSource> _itemsToSources(List<MediaItem> mediaItems) {
    preferredMobileQuality = Hive.box('settings')
        .get('streamingQuality', defaultValue: '96 kbps')
        .toString();
    preferredWifiQuality = Hive.box('settings')
        .get('streamingWifiQuality', defaultValue: '320 kbps')
        .toString();
    preferredQuality = connectionType == 'wifi'
        ? preferredWifiQuality
        : preferredMobileQuality;
    cacheSong =
        Hive.box('settings').get('cacheSong', defaultValue: true) as bool;
    useDown = Hive.box('settings').get('useDown', defaultValue: true) as bool;
    return mediaItems.map(_itemToSource).whereType<AudioSource>().toList();
  }

  @override
  Future<void> onTaskRemoved() async {
    final bool stopForegroundService = Hive.box('settings')
        .get('stopForegroundService', defaultValue: true) as bool;
    if (stopForegroundService) {
      await stop();
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        return _recentSubject.value;
      default:
        return queue.value;
    }
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        final stream = _recentSubject.map((_) => <String, dynamic>{});
        return _recentSubject.hasValue
            ? stream.shareValueSeeded(<String, dynamic>{})
            : stream.shareValue();
      default:
        return Stream.value(queue.value)
            .map((_) => <String, dynamic>{})
            .shareValue();
    }
  }

  Future<void> startService() async {
    bool withPipeline = false;
    if (Hive.isBoxOpen('settings')) {
      withPipeline =
          Hive.box('settings').get('supportEq', defaultValue: false) as bool;
    }
    if (withPipeline && Platform.isAndroid) {
      Logger.root.info('starting with eq pipeline');
      final AudioPipeline pipeline = AudioPipeline(
        androidAudioEffects: [
          _equalizer,
        ],
      );
      _player = AudioPlayer(audioPipeline: pipeline);

      // Enable equalizer if used earlier
      Logger.root.info('setting eq enabled');
      final eqValue =
          Hive.box('settings').get('setEqualizer', defaultValue: false) as bool;
      _equalizer.setEnabled(eqValue);

      // set equalizer params & bands
      _equalizer.parameters.then((value) {
        Logger.root.info('setting eq params');
        _equalizerParams ??= value;

        final List<AndroidEqualizerBand> bands = _equalizerParams!.bands;
        bands.map(
          (e) {
            final gain = Hive.box('settings')
                .get('equalizerBand${e.index}', defaultValue: 0.5) as double;
            _equalizerParams!.bands[e.index].setGain(gain);
          },
        );
      });
    } else {
      Logger.root.info('starting without eq pipeline');
      _player = AudioPlayer();
    }
  }

  Future<void> addRecentlyPlayed(MediaItem mediaitem) async {
    Logger.root.info('adding ${mediaitem.id} to recently played');
    List recentList = await Hive.box('cache')
        .get('recentSongs', defaultValue: [])?.toList() as List;

    final Map songStats =
        await Hive.box('stats').get(mediaitem.id, defaultValue: {}) as Map;

    final Map mostPlayed =
        await Hive.box('stats').get('mostPlayed', defaultValue: {}) as Map;

    songStats['lastPlayed'] = DateTime.now().millisecondsSinceEpoch;
    songStats['playCount'] =
        songStats['playCount'] == null ? 1 : songStats['playCount'] + 1;
    songStats['isYoutube'] = mediaitem.genre == 'YouTube';
    songStats['title'] = mediaitem.title;
    songStats['artist'] = mediaitem.artist;
    songStats['album'] = mediaitem.album;
    songStats['id'] = mediaitem.id;
    Hive.box('stats').put(mediaitem.id, songStats);
    if ((songStats['playCount'] as int) >
        (mostPlayed['playCount'] as int? ?? 0)) {
      Hive.box('stats').put('mostPlayed', songStats);
    }
    Logger.root.info('adding ${mediaitem.id} data to stats');

    final Map item = MediaItemConverter.mediaItemToMap(mediaitem);
    recentList.insert(0, item);

    final jsonList = recentList.map((item) => jsonEncode(item)).toList();
    final uniqueJsonList = jsonList.toSet().toList();
    recentList = uniqueJsonList.map((item) => jsonDecode(item)).toList();

    if (recentList.length > 30) {
      recentList = recentList.sublist(0, 30);
    }
    Hive.box('cache').put('recentSongs', recentList);
  }

  Future<void> addLastQueue(List<MediaItem> queue) async {
    if (queue.isNotEmpty && queue.first.genre != 'YouTube') {
      Logger.root.info('saving last queue');
      final lastQueue =
          queue.map((item) => MediaItemConverter.mediaItemToMap(item)).toList();
      Hive.box('cache').put('lastQueue', lastQueue);
    }
  }

  Future<void> skipToMediaItem(String? id, int? idx) async {
    if (idx == null && id == null) return;
    _activateDelegate();
    final index = idx ?? queue.value.indexWhere((item) => item.id == id);
    if (index != -1) {
      _player!.seek(
        Duration.zero,
        index: _player!.shuffleModeEnabled
            ? _player!.shuffleIndices![index]
            : index,
      );
    } else {
      Logger.root.severe('skipToMediaItem: MediaItem not found');
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    try {
      final res = _itemToSource(mediaItem);
      if (res != null) {
        await _playlist.add(res);
      }
    } catch (e) {
      Logger.root.severe('Error in addQueueItem: $e');
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    try {
      await _playlist.addAll(_itemsToSources(mediaItems));
    } catch (e) {
      Logger.root.severe('Error in addQueueItems: $e');
    }
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    try {
      final res = _itemToSource(mediaItem);
      if (res != null) {
        await _playlist.insert(index, res);
      }
    } catch (e) {
      Logger.root.severe('Error in insertQueueItem: $e');
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    try {
      await _playlist.clear();
    } catch (e) {
      Logger.root.severe('Error clearing playlist in updateQueue: $e');
    }
    try {
      await _playlist.addAll(_itemsToSources(newQueue));
    } catch (e) {
      Logger.root.severe('Error adding sources in updateQueue: $e');
    }
    // addLastQueue(newQueue);
    // stationId = '';
    // stationNames = newQueue.map((e) => e.id).toList();
    // SaavnAPI()
    //     .createRadio(names: stationNames, stationType: stationType)
    //     .then((value) async {
    //   stationId = value;
    //   final List songsList = await SaavnAPI()
    //       .getRadioSongs(stationId: stationId!, count: 20 - newQueue.length);

    //   for (int i = 0; i < songsList.length; i++) {
    //     final element = MediaItemConverter.mapToMediaItem(
    //       songsList[i] as Map,
    //       addedByAutoplay: true,
    //     );
    //     if (!queue.value.contains(element)) {
    //       addQueueItem(element);
    //     }
    //   }
    // });
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    _mediaItemExpando[_player!.sequence![index]] = mediaItem;
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    try {
      final index = queue.value.indexOf(mediaItem);
      if (index != -1) {
        await _playlist.removeAt(index);
      }
    } catch (e) {
      Logger.root.severe('Error in removeQueueItem: $e');
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    try {
      if (index >= 0 && index < _playlist.length) {
        await _playlist.removeAt(index);
      }
    } catch (e) {
      Logger.root.severe('Error in removeQueueItemAt: $e');
    }
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    try {
      if (currentIndex >= 0 &&
          currentIndex < _playlist.length &&
          newIndex >= 0 &&
          newIndex < _playlist.length) {
        await _playlist.move(currentIndex, newIndex);
      }
    } catch (e) {
      Logger.root.severe('Error in moveQueueItem: $e');
    }
  }

  @override
  Future<void> skipToNext() {
    _activateDelegate();
    return _player!.seekToNext();
  }

  /// This is called when the user presses the "like" button.
  @override
  Future<void> fastForward() async {
    if (mediaItem.value?.id != null) {
      addItemToPlaylist('Favorite Songs', mediaItem.value!);
      _broadcastState(_player!.playbackEvent);
    }
  }

  @override
  Future<void> rewind() async {
    if (mediaItem.value?.id != null) {
      removeLiked(mediaItem.value!.id);
      _broadcastState(_player!.playbackEvent);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    _activateDelegate();
    resetOnSkip =
        Hive.box('settings').get('resetOnSkip', defaultValue: false) as bool;
    if (resetOnSkip) {
      if ((_player?.position.inSeconds ?? 5) <= 5) {
        _player!.seekToPrevious();
      } else {
        _player!.seek(Duration.zero);
      }
    } else {
      _player!.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;
    _activateDelegate();

    _player!.seek(
      Duration.zero,
      index:
          _player!.shuffleModeEnabled ? _player!.shuffleIndices![index] : index,
    );
  }

  @override
  Future<void> play() {
    _activateDelegate();
    return _player!.play();
  }

  @override
  Future<void> pause() async {
    _player!.pause();
    await Hive.box('cache').put('lastIndex', _player!.currentIndex);
    await Hive.box('cache').put('lastPos', _player!.position.inSeconds);
    await addLastQueue(queue.value);
  }

  @override
  Future<void> seek(Duration position) {
    _activateDelegate();
    return _player!.seek(position);
  }

  @override
  Future<void> stop() async {
    Logger.root.info('stopping player');
    await _player!.stop();
    await playbackState.firstWhere(
      (state) => state.processingState == AudioProcessingState.idle,
    );
    Logger.root.info('caching last index and position');
    await Hive.box('cache').put('lastIndex', _player!.currentIndex);
    await Hive.box('cache').put('lastPos', _player!.position.inSeconds);
    await addLastQueue(queue.value);
  }

  @override
  Future customAction(String name, [Map<String, dynamic>? extras]) {
    if (name == 'sleepTimer') {
      _sleepTimer?.cancel();
      if (extras?['time'] != null &&
          extras!['time'].runtimeType == int &&
          extras['time'] > 0 as bool) {
        _sleepTimer = Timer(Duration(minutes: extras['time'] as int), () {
          stop();
        });
      }
    }
    if (name == 'sleepCounter') {
      if (extras?['count'] != null &&
          extras!['count'].runtimeType == int &&
          extras['count'] > 0 as bool) {
        count = extras['count'] as int;
      }
    }

    if (name == 'setBandGain') {
      final bandIdx = extras!['band'] as int;
      final gain = extras['gain'] as double;
      _equalizerParams!.bands[bandIdx].setGain(gain);
    }

    if (name == 'setEqualizer') {
      _equalizer.setEnabled(extras!['value'] as bool);
    }

    if (name == 'fastForward') {
      try {
        const stepInterval = Duration(seconds: 10);
        Duration newPosition = _player!.position + stepInterval;
        if (newPosition < Duration.zero) newPosition = Duration.zero;
        if (newPosition > _player!.duration!) newPosition = _player!.duration!;
        _player!.seek(newPosition);
      } catch (e) {
        Logger.root.severe('Error in fastForward', e);
      }
    }

    if (name == 'rewind') {
      try {
        const stepInterval = Duration(seconds: 10);
        Duration newPosition = _player!.position - stepInterval;
        if (newPosition < Duration.zero) newPosition = Duration.zero;
        if (newPosition > _player!.duration!) newPosition = _player!.duration!;
        _player!.seek(newPosition);
      } catch (e) {
        Logger.root.severe('Error in rewind', e);
      }
    }

    if (name == 'getEqualizerParams') {
      return getEqParms();
    }

    if (name == 'refreshLink') {
      if (extras?['newData'] != null) {
        refreshLink(extras!['newData'] as Map);
      }
    }

    if (name == 'skipToMediaItem') {
      skipToMediaItem(extras!['id'] as String?, extras['index'] as int?);
    }

    if (name == 'switchToYouTube') {
      final String? id = extras?['id'] as String?;
      if (id != null) {
        final index = queue.value.indexWhere((element) => element.id == id);
        if (index != -1) {
          fallbackToYouTube(queue.value[index]);
        }
      }
    }

    if (name == 'switchToSaavn') {
      final String? id = extras?['id'] as String?;
      if (id != null) {
        final index = queue.value.indexWhere((element) => element.id == id);
        if (index != -1) {
          fallbackToSaavn(queue.value[index]);
        }
      }
    }
    return super.customAction(name, extras);
  }

  Future<Map> getEqParms() async {
    _equalizerParams ??= await _equalizer.parameters;
    final List<AndroidEqualizerBand> bands = _equalizerParams!.bands;
    final List<Map> bandList = bands
        .map(
          (e) => {
            'centerFrequency': e.centerFrequency,
            'gain': e.gain,
            'index': e.index,
          },
        )
        .toList();

    return {
      'maxDecibels': _equalizerParams!.maxDecibels,
      'minDecibels': _equalizerParams!.minDecibels,
      'bands': bandList,
    };
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all;
    if (enabled) {
      await _player!.shuffle();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: mode));
    await _player!.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    await _player!.setLoopMode(LoopMode.values[repeatMode.index]);
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed.add(speed);
    await _player!.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume.add(volume);
    await _player!.setVolume(volume);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        _handleMediaActionPressed();
      case MediaButton.next:
        await skipToNext();
      case MediaButton.previous:
        await skipToPrevious();
    }
  }

  late BehaviorSubject<int> _tappedMediaActionNumber;
  Timer? _timer;

  void _handleMediaActionPressed() {
    if (_timer == null) {
      _tappedMediaActionNumber = BehaviorSubject.seeded(1);
      _timer = Timer(const Duration(milliseconds: 800), () {
        final tappedNumber = _tappedMediaActionNumber.value;
        switch (tappedNumber) {
          case 1:
            if (playbackState.value.playing) {
              pause();
            } else {
              play();
            }
          case 2:
            skipToNext();
          case 3:
            skipToPrevious();
          default:
            break;
        }
        _tappedMediaActionNumber.close();
        _timer!.cancel();
        _timer = null;
      });
    } else {
      final current = _tappedMediaActionNumber.value;
      _tappedMediaActionNumber.add(current + 1);
    }
  }

  Future<void> _replaceQueueItemAndRestart(
    int index,
    MediaItem replacement,
    String reason,
  ) async {
    if (index < 0 || index >= queue.value.length) return;
    final bool restartCurrent = _player!.currentIndex == index;
    if (restartCurrent) {
      try {
        await _player!.stop();
      } catch (e) {
        Logger.root.warning('Unable to stop player before $reason: $e');
      }
    }

    final List<MediaItem> currentQueue = List<MediaItem>.from(queue.value);
    currentQueue[index] = replacement;
    await updateQueue(currentQueue);

    if (restartCurrent && index < _playlist.length) {
      await _player!.seek(Duration.zero, index: index);
      await _player!.play();
    }
  }

  Future<void> fallbackToYouTube(MediaItem item) async {
    Logger.root.info('Fallback to YouTube triggered for song: ${item.title}');
    try {
      final query = '${item.title} ${item.artist}';
      final List<Map> searchResults =
          await YtMusicService().search(query, filter: 'songs');
      final items =
          searchResults.isEmpty ? const [] : searchResults[0]['items'] as List?;
      if (items == null || items.isEmpty) return;

      final Map firstResult = items[0] as Map;
      final String videoId = firstResult['id'].toString();
      if (videoId.isEmpty || videoId == 'null') return;

      final Map? ytData = await YouTubeServices.instance.refreshLink(videoId);
      if (!_hasPlayableRemoteUrl(ytData)) return;

      final MediaItem fallbackItem = MediaItem(
        id: videoId,
        album: item.album,
        artist: item.artist,
        duration: item.duration,
        title: item.title,
        artUri: item.artUri,
        genre: 'YouTube',
        extras: {
          ...item.extras ?? {},
          'url': ytData!['url'],
          'genre': 'YouTube',
          'expire_at': ytData['expire_at'],
          'perma_url': 'https://youtube.com/watch?v=$videoId',
        },
      );

      final index = queue.value.indexWhere((qItem) => qItem.id == item.id);
      await _replaceQueueItemAndRestart(
        index,
        fallbackItem,
        'YouTube fallback',
      );
    } catch (e) {
      Logger.root.severe('Error in fallbackToYouTube: $e');
    }
  }

  Future<void> fallbackToSaavn(MediaItem item) async {
    Logger.root.info('Switching to JioSaavn source for: ${item.title}');
    try {
      final Map searchResults = await SaavnAPI().fetchSongSearchResults(
        searchQuery: '${item.title} ${item.artist}',
        count: 5,
      );
      final songs = searchResults['songs'];
      if (songs is! List || songs.isEmpty) return;

      final Map firstSong = songs[0] as Map;
      if (!_hasPlayableRemoteUrl(firstSong)) return;
      final MediaItem saavnItem = MediaItemConverter.mapToMediaItem(firstSong);

      final index = queue.value.indexWhere((qItem) => qItem.id == item.id);
      await _replaceQueueItemAndRestart(
        index,
        saavnItem,
        'JioSaavn fallback',
      );
    } catch (e) {
      Logger.root.severe('Error in fallbackToSaavn: $e');
    }
  }

  void _playbackError(dynamic err) {
    final String code = (err is PlatformException) ? err.code : err.toString();
    final String message =
        (err is PlatformException) ? (err.message ?? '') : '';
    Logger.root.severe('Error from audioservice: $code', err);
    if (err is PlatformException &&
        code == 'abort' &&
        message == 'Connection aborted') {
      return;
    }
    _onError(err, null);
  }

  Future<void> retryYouTubeSong(MediaItem item) async {
    Logger.root.info('Retrying YouTube song after failure: ${item.title}');
    try {
      final Map? ytData = await YouTubeServices.instance.refreshLink(
        item.id,
      );
      if (!_hasPlayableRemoteUrl(ytData)) return;

      final MediaItem updatedItem = MediaItem(
        id: item.id,
        album: item.album,
        artist: item.artist,
        duration: item.duration,
        title: item.title,
        artUri: item.artUri,
        genre: 'YouTube',
        extras: {
          ...item.extras ?? {},
          'url': ytData!['url'],
          'genre': 'YouTube',
          'expire_at': ytData['expire_at'],
          'perma_url': 'https://youtube.com/watch?v=${item.id}',
        },
      );

      final index = queue.value.indexWhere((qItem) => qItem.id == item.id);
      await _replaceQueueItemAndRestart(index, updatedItem, 'YouTube retry');
      Logger.root.info(
        'Successfully refreshed and retried YouTube song: ${item.title}',
      );
    } catch (e) {
      Logger.root.severe('Error in retryYouTubeSong: $e');
    } finally {
      _retryingIds.remove(item.id);
    }
  }

  Future<void> _retryJioSaavnSongDirect(MediaItem item) async {
    Logger.root.info(
      'Retrying JioSaavn song with direct play after failure: ${item.title}',
    );
    try {
      final index = queue.value.indexWhere((qItem) => qItem.id == item.id);
      await _replaceQueueItemAndRestart(index, item, 'JioSaavn direct retry');
      Logger.root.info(
        'Successfully switched to direct play for JioSaavn song: ${item.title}',
      );
    } catch (e) {
      Logger.root.severe('Error in _retryJioSaavnSongDirect: $e');
    }
  }

  void _onError(
    dynamic err,
    StackTrace? stacktrace, {
    bool stopService = false,
  }) {
    final String code = (err is PlatformException) ? err.code : err.toString();
    Logger.root.severe('Error in _onError: $code', err);
    final currentItem = mediaItem.value;
    if (currentItem != null) {
      final bool isLocal = currentItem.artUri?.toString().startsWith('file:') ==
              true ||
          currentItem.extras?['url']?.toString().startsWith('/') == true ||
          currentItem.extras?['url']?.toString().startsWith('file:') == true;

      if (currentItem.genre != 'YouTube' && !isLocal) {
        if (!_forceDirectPlayIds.contains(currentItem.id)) {
          _forceDirectPlayIds.add(currentItem.id);
          Logger.root.info(
              'Playback error detected for JioSaavn song caching. Retrying with direct play...');
          _retryJioSaavnSongDirect(currentItem);
          return;
        }
        Logger.root.info(
            'Playback error detected for JioSaavn song in direct play. Automatically falling back to YouTube...');
        fallbackToYouTube(currentItem);
        return;
      } else if (currentItem.genre == 'YouTube') {
        if (_retryingIds.contains(currentItem.id)) {
          Logger.root.warning(
              'YouTube song ${currentItem.title} retry already in progress.');
          return;
        }
        if (_lastRetriedId == currentItem.id) {
          Logger.root.warning(
              'YouTube song ${currentItem.title} already retried. Stopping to avoid infinite loop.');
          if (stopService) stop();
          return;
        }
        _lastRetriedId = currentItem.id;
        _retryingIds.add(currentItem.id);
        Logger.root.info(
            'Playback error detected for YouTube song. Automatically refreshing and retrying...');
        retryYouTubeSong(currentItem);
        return;
      }
    }
    if (stopService) stop();
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player!.playing;
    if (playing ||
        _player!.processingState == ProcessingState.buffering ||
        _player!.processingState == ProcessingState.loading) {
      _activateDelegate();
    }
    bool liked = false;
    if (mediaItem.value != null) {
      liked = checkPlaylist('Favorite Songs', mediaItem.value!.id);
    }
    final queueIndex = getQueueIndex(
      event.currentIndex,
      _player!.shuffleIndices,
      shuffleModeEnabled: _player!.shuffleModeEnabled,
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          // workaround to add like button
          if (!Platform.isIOS)
            if (liked) MediaControl.rewind else MediaControl.fastForward,
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          if (!Platform.isIOS) MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: preferredCompactNotificationButtons,
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player!.processingState]!,
        playing: playing,
        updatePosition: _player!.position,
        bufferedPosition: _player!.bufferedPosition,
        speed: _player!.speed,
        queueIndex: queueIndex,
      ),
    );
  }
}
