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

import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/snackbar.dart';
import 'package:mobile/features/sonic_music/Helpers/lyrics.dart';
import 'package:mobile/features/sonic_music/Services/ext_storage_provider.dart';
import 'package:mobile/features/sonic_music/Services/youtube_services.dart';
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:mobile/features/sonic_music/Services/yt_music.dart';

class Download with ChangeNotifier {
  static final Map<String, Download> _instances = {};
  final String id;

  factory Download(String id) {
    if (_instances.containsKey(id)) {
      return _instances[id]!;
    } else {
      final instance = Download._internal(id);
      _instances[id] = instance;
      return instance;
    }
  }

  Download._internal(this.id);

  int? rememberOption;
  final ValueNotifier<bool> remember = ValueNotifier<bool>(false);
  String preferredDownloadQuality = Hive.box('settings')
      .get('downloadQuality', defaultValue: '320 kbps') as String;
  String preferredYtDownloadQuality = Hive.box('settings')
      .get('ytDownloadQuality', defaultValue: 'High') as String;
  String downloadFormat = Hive.box('settings')
      .get('downloadFormat', defaultValue: 'm4a')
      .toString();
  bool createDownloadFolder = Hive.box('settings')
      .get('createDownloadFolder', defaultValue: false) as bool;
  bool createYoutubeFolder = Hive.box('settings')
      .get('createYoutubeFolder', defaultValue: false) as bool;
  double? progress = 0.0;
  String lastDownloadId = '';
  bool downloadLyrics =
      Hive.box('settings').get('downloadLyrics', defaultValue: false) as bool;
  bool download = true;

  Future<void> prepareDownload(
    BuildContext context,
    Map data, {
    bool createFolder = false,
    String? folderName,
  }) async {
    Logger.root.info('Preparing download for ${data['title']}');
    download = true;
    if (Platform.isAndroid || Platform.isIOS) {
      Logger.root.info('Requesting storage permission');
      PermissionStatus status = await Permission.storage.status;
      if (status.isDenied) {
        Logger.root.info('Request denied');
        await [
          Permission.storage,
          Permission.accessMediaLocation,
          Permission.mediaLibrary,
        ].request();
      }
      status = await Permission.storage.status;
      if (status.isPermanentlyDenied) {
        Logger.root.info('Request permanently denied');
        await openAppSettings();
      }
    }
    final RegExp avoid = RegExp(r'[\.\\\*\:\"\?#/;\|]');
    data['title'] = data['title'].toString().split('(From')[0].trim();

    String filename = '';
    final int downFilename =
        Hive.box('settings').get('downFilename', defaultValue: 0) as int;
    if (downFilename == 0) {
      filename = '${data["title"]} - ${data["artist"]}';
    } else if (downFilename == 1) {
      filename = '${data["artist"]} - ${data["title"]}';
    } else {
      filename = '${data["title"]}';
    }
    // String filename = '${data["title"]} - ${data["artist"]}';
    String dlPath =
        Hive.box('settings').get('downloadPath', defaultValue: '') as String;
    Logger.root.info('Cached Download path: $dlPath');
    if (filename.length > 200) {
      final String temp = filename.substring(0, 200);
      final List tempList = temp.split(', ');
      tempList.removeLast();
      filename = tempList.join(', ');
    }

    filename = '${filename.replaceAll(avoid, "").replaceAll("  ", " ")}.m4a';
    if (dlPath == '' || (Platform.isAndroid && (dlPath.startsWith('/storage/') || dlPath == '/storage/emulated/0/Music'))) {
      Logger.root.info('Cached Download path is empty or old external, getting new path');
      final String? temp = await ExtStorageProvider.getExtStorage(
        dirName: 'Music',
        writeAccess: true,
      );
      dlPath = temp!;
      Hive.box('settings').put('downloadPath', dlPath);
    }
    Logger.root.info('New Download path: $dlPath');
    if (data['url'].toString().contains('google') && createYoutubeFolder) {
      Logger.root.info('Youtube audio detected, creating Youtube folder');
      dlPath = '$dlPath/YouTube';
      if (!await Directory(dlPath).exists()) {
        Logger.root.info('Creating Youtube folder');
        await Directory(dlPath).create();
      }
    }

    if (createFolder && createDownloadFolder && folderName != null) {
      final String foldername = folderName.replaceAll(avoid, '');
      dlPath = '$dlPath/$foldername';
      if (!await Directory(dlPath).exists()) {
        Logger.root.info('Creating folder $foldername');
        await Directory(dlPath).create();
      }
    }

    final bool exists = await File('$dlPath/$filename').exists();
    if (exists) {
      Logger.root.info('File already exists');
      if (remember.value == true && rememberOption != null) {
        switch (rememberOption) {
          case 0:
            lastDownloadId = data['id'].toString();
          case 1:
            if (!context.mounted) return;
            downloadSong(context, dlPath, filename, data);
          case 2:
            while (await File('$dlPath/$filename').exists()) {
              filename = filename.replaceAll('.m4a', ' (1).m4a');
            }
          default:
            lastDownloadId = data['id'].toString();
            break;
        }
      } else {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              title: Text(
                AppLocalizations.of(context)!.alreadyExists,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '"${data['title']}" ${AppLocalizations.of(context)!.downAgain}',
                    softWrap: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
              actions: [
                Column(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: remember,
                      builder: (
                        BuildContext context,
                        bool rememberValue,
                        Widget? child,
                      ) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Checkbox(
                                activeColor:
                                    Theme.of(context).colorScheme.secondary,
                                value: rememberValue,
                                onChanged: (bool? value) {
                                  remember.value = value ?? false;
                                },
                              ),
                              Text(
                                AppLocalizations.of(context)!.rememberChoice,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                            onPressed: () {
                              lastDownloadId = data['id'].toString();
                              Navigator.pop(context);
                              rememberOption = 0;
                            },
                            child: Text(
                              AppLocalizations.of(context)!.no,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              Hive.box('downloads').delete(data['id']);
                              downloadSong(context, dlPath, filename, data);
                              rememberOption = 1;
                            },
                            child:
                                Text(AppLocalizations.of(context)!.yesReplace),
                          ),
                          const SizedBox(width: 5.0),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              while (await File('$dlPath/$filename').exists()) {
                                filename =
                                    filename.replaceAll('.m4a', ' (1).m4a');
                              }
                              rememberOption = 2;
                              if (!context.mounted) return;
                              downloadSong(context, dlPath, filename, data);
                            },
                            child: Text(
                              AppLocalizations.of(context)!.yes,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.secondary ==
                                            Colors.white
                                        ? Colors.black
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      }
    } else {
      if (!context.mounted) return;
      downloadSong(context, dlPath, filename, data);
    }
  }

  Future<void> downloadSong(
    BuildContext context,
    String? dlPath,
    String fileName,
    Map data,
  ) async {
    Logger.root.info('processing download');
    progress = null;
    notifyListeners();
    String? filepath;
    late String filepath2;
    String? appPath;
    final List<int> bytes = [];
    String lyrics = '';
    final artname = fileName.replaceAll('.m4a', '.jpg');
    if (!Platform.isWindows) {
      Logger.root.info('Getting App Path for storing image');
      appPath = Hive.box('settings').get('tempDirPath')?.toString();
      appPath ??= (await getTemporaryDirectory()).path;
    } else {
      final Directory? temp = await getDownloadsDirectory();
      appPath = temp!.path;
    }

    try {
      Logger.root.info('Creating audio file $dlPath/$fileName');
      await File('$dlPath/$fileName')
          .create(recursive: true)
          .then((value) => filepath = value.path);
      Logger.root.info('Creating image file $appPath/$artname');
      await File('$appPath/$artname')
          .create(recursive: true)
          .then((value) => filepath2 = value.path);
    } catch (e) {
      Logger.root
          .info('Error creating files, requesting additional permission');
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.manageExternalStorage.status;
        if (status.isDenied) {
          Logger.root.info(
            'ManageExternalStorage permission is denied, requesting permission',
          );
          await [
            Permission.manageExternalStorage,
          ].request();
        }
        status = await Permission.manageExternalStorage.status;
        if (status.isPermanentlyDenied) {
          Logger.root.info(
            'ManageExternalStorage Request is permanently denied, opening settings',
          );
          await openAppSettings();
        }
      }

      Logger.root.info('Retrying to create audio file');
      await File('$dlPath/$fileName')
          .create(recursive: true)
          .then((value) => filepath = value.path);

      Logger.root.info('Retrying to create image file');
      await File('$appPath/$artname')
          .create(recursive: true)
          .then((value) => filepath2 = value.path);
    }
    String kUrl = data['url'].toString();

    if (!data['url'].toString().contains('google')) {
      Logger.root.info('Fetching jiosaavn download url with preferred quality');
      kUrl = kUrl.replaceAll(
        '_96.',
        "_${preferredDownloadQuality.replaceAll(' kbps', '')}.",
      );
    }

    int total = 0;
    int recieved = 0;
    Client? client;
    Stream<List<int>> stream;
    
    try {
      if (data['url'].toString().contains('google')) {
        try {
          final AudioOnlyStreamInfo streamInfo =
              (await YouTubeServices.instance.getStreamInfo(data['id'].toString()))
                  .last;
          total = streamInfo.size.totalBytes;
          stream = YouTubeServices.instance.getStreamClient(streamInfo);
        } catch (e) {
          Logger.root.severe('youtube_explode failed to get stream, trying fallback to getSongData: $e');
          final Map ytData = await YtMusicService().getSongData(videoId: data['id'].toString());
          if (ytData['url'] != null && ytData['url'].toString().isNotEmpty) {
            kUrl = ytData['url'].toString();
            Logger.root.info('Fallback URL found: $kUrl');
            client = Client();
            final response = await client.send(Request('GET', Uri.parse(kUrl)));
            total = response.contentLength ?? 0;
            stream = response.stream.asBroadcastStream();
          } else {
            throw Exception('Unable to resolve YouTube streaming URL.');
          }
        }
      } else {
        Logger.root.info('Connecting to Client for JioSaavn');
        try {
          client = Client();
          final response = await client.send(Request('GET', Uri.parse(kUrl)));
          if (response.statusCode == 403) {
            throw Exception('JioSaavn CDN returned 403 Forbidden.');
          }
          total = response.contentLength ?? 0;
          stream = response.stream.asBroadcastStream();
        } catch (e) {
          Logger.root.warning('JioSaavn download failed ($e), falling back to YouTube for download');
          final query = '${data['title']} ${data['artist']}';
          final List<Map> searchResults = await YtMusicService().search(query, filter: 'songs');
          if (searchResults.isNotEmpty && searchResults[0]['items'].isNotEmpty) {
            final Map firstResult = searchResults[0]['items'][0] as Map;
            final String videoId = firstResult['id'].toString();
            data['id'] = videoId;
            data['url'] = 'google';
            try {
              final AudioOnlyStreamInfo streamInfo =
                  (await YouTubeServices.instance.getStreamInfo(videoId))
                      .last;
              total = streamInfo.size.totalBytes;
              stream = YouTubeServices.instance.getStreamClient(streamInfo);
            } catch (ye) {
              Logger.root.severe('youtube_explode failed on download fallback, trying getSongData: $ye');
              final Map ytData = await YtMusicService().getSongData(videoId: videoId);
              if (ytData['url'] != null && ytData['url'].toString().isNotEmpty) {
                kUrl = ytData['url'].toString();
                client = Client();
                final response = await client.send(Request('GET', Uri.parse(kUrl)));
                total = response.contentLength ?? 0;
                stream = response.stream.asBroadcastStream();
              } else {
                throw Exception('Unable to resolve YouTube fallback URL.');
              }
            }
          } else {
            rethrow;
          }
        }
      }

      Logger.root.info('Client connected, Starting download');
      stream.listen(
        (value) {
          bytes.addAll(value);
          try {
            recieved += value.length;
            progress = recieved / total;
            notifyListeners();
            if (!download && client != null) {
              client.close();
            }
          } catch (e) {
            Logger.root.severe('Error in download progress stream: $e');
          }
        },
        onError: (err) {
          Logger.root.severe('Stream error during download: $err');
          if (context.mounted) {
            _handleDownloadError(context, filepath, filepath2, err.toString());
          }
        },
        onDone: () async {
          try {
            if (download) {
              Logger.root.info('Download complete, modifying file');
              final file = File(filepath!);
              await file.writeAsBytes(bytes);

              final clientImage = HttpClient();
              final HttpClientRequest request2 =
                  await clientImage.getUrl(Uri.parse(data['image'].toString()));
              final HttpClientResponse response2 = await request2.close();
              final bytes2 = await consolidateHttpClientResponseBytes(response2);
              final File file2 = File(filepath2);

              file2.writeAsBytesSync(bytes2);
              try {
                Logger.root.info('Checking if lyrics required');
                if (downloadLyrics) {
                  Logger.root.info('downloading lyrics');
                  final Map res = await Lyrics.getLyrics(
                    id: data['id'].toString(),
                    title: data['title'].toString(),
                    artist: data['artist'].toString(),
                    saavnHas: data['has_lyrics'] == 'true',
                  );
                  lyrics = res['lyrics'].toString();
                }
              } catch (e) {
                Logger.root.severe('Error fetching lyrics: $e');
                lyrics = '';
              }

              Logger.root.info('Getting audio tags');
              if (Platform.isAndroid) {
                try {
                  final Tag tag = Tag(
                    title: data['title'].toString(),
                    artist: data['artist'].toString(),
                    albumArtist: data['album_artist']?.toString() ??
                        data['artist']?.toString().split(', ')[0] ??
                        '',
                    artwork: filepath2,
                    album: data['album'].toString(),
                    genre: data['language'].toString(),
                    year: data['year'].toString(),
                    lyrics: lyrics,
                    comment: 'BlackHole',
                  );
                  Logger.root.info('Started tag editing');
                  final tagger = Audiotagger();
                  await tagger.writeTags(
                    path: filepath!,
                    tag: tag,
                  );
                } catch (e) {
                  Logger.root.severe('Error editing tags: $e');
                }
              } else {
                if (data['language'].toString() == 'YouTube') {
                  await MetadataGod.writeMetadata(
                    file: filepath!,
                    metadata: Metadata(
                      title: data['title'].toString(),
                      artist: data['artist'].toString(),
                      albumArtist: data['album_artist']?.toString() ??
                          data['artist']?.toString().split(', ')[0] ??
                          '',
                      album: data['album'].toString(),
                      genre: data['language'].toString(),
                      year: int.parse(data['year'].toString()),
                      durationMs: int.parse(data['duration'].toString()) * 1000,
                      fileSize: BigInt.from(file.lengthSync()),
                      picture: Picture(
                        data: bytes2,
                        mimeType: 'image/jpeg',
                      ),
                    ),
                  );
                }
              }
              Logger.root.info('Closing connection & notifying listeners');
              if (client != null) client.close();
              lastDownloadId = data['id'].toString();
              progress = 0.0;
              notifyListeners();

              Logger.root.info('Putting data to downloads database');
              final songData = {
                'id': data['id'].toString(),
                'title': data['title'].toString(),
                'subtitle': data['subtitle'].toString(),
                'artist': data['artist'].toString(),
                'albumArtist': data['album_artist']?.toString() ??
                    data['artist']?.toString().split(', ')[0],
                'album': data['album'].toString(),
                'genre': data['language'].toString(),
                'year': data['year'].toString(),
                'lyrics': lyrics,
                'duration': data['duration'],
                'release_date': data['release_date'].toString(),
                'album_id': data['album_id'].toString(),
                'perma_url': data['perma_url'].toString(),
                'quality': preferredDownloadQuality,
                'path': filepath,
                'image': filepath2,
                'image_url': data['image'].toString(),
                'from_yt': data['language'].toString() == 'YouTube',
                'dateAdded': DateTime.now().toString(),
              };
              Hive.box('downloads').put(songData['id'].toString(), songData);

              Logger.root.info('Everything done, showing snackbar');
              if (context.mounted) {
                ShowSnackBar().showSnackBar(
                  context,
                  '"${data['title']}" ${AppLocalizations.of(context)!.downed}',
                );
              }
            } else {
              download = true;
              progress = 0.0;
              if (filepath != null) {
                final file = File(filepath!);
                if (file.existsSync()) file.deleteSync();
              }
              final file2 = File(filepath2);
              if (file2.existsSync()) file2.deleteSync();
            }
          } catch (e) {
            Logger.root.severe('Error finalizing download: $e');
            if (context.mounted) {
              _handleDownloadError(context, filepath, filepath2, e.toString());
            }
          }
        },
      );
    } catch (e) {
      Logger.root.severe('Error setting up download: $e');
      if (context.mounted) {
        _handleDownloadError(context, filepath, filepath2, e.toString());
      }
    }
  }

  void _handleDownloadError(BuildContext context, String? filepath, String? filepath2, String errorMsg) {
    download = true;
    progress = 0.0;
    notifyListeners();
    try {
      if (filepath != null) {
        final file = File(filepath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
      if (filepath2 != null) {
        final file2 = File(filepath2);
        if (file2.existsSync()) {
          file2.deleteSync();
        }
      }
    } catch (_) {}
    if (context.mounted) {
      ShowSnackBar().showSnackBar(
        context,
        'Download Failed: $errorMsg',
      );
    }
  }
}
