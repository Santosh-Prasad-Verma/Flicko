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
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/add_playlist.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/copy_clipboard.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/download_button.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/empty_screen.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/equalizer.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/like_button.dart';
import 'package:mobile/features/sonic_music/Helpers/playlist.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/seek_bar.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/snackbar.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/textinput_dialog.dart';
import 'package:mobile/features/sonic_music/Helpers/audio_service_helper.dart';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:mobile/features/sonic_music/Helpers/dominant_color.dart';
import 'package:mobile/features/sonic_music/Helpers/lyrics.dart';
import 'package:mobile/features/sonic_music/Helpers/mediaitem_converter.dart';
import 'package:mobile/features/sonic_music/Screens/Common/song_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:mobile/features/sonic_music/APIs/api.dart';
import 'package:mobile/features/sonic_music/Helpers/extensions.dart';
import 'package:mobile/features/sonic_music/Services/yt_music.dart';
import 'package:mobile/features/sonic_music/Services/player_service.dart';
import 'package:mobile/features/sonic_music/Models/song_item.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_lyric/lyrics_reader_widget.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});
  @override
  _PlayScreenState createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final String gradientType = Hive.box('settings')
      .get('gradientType', defaultValue: 'halfDark')
      .toString();
  final bool getLyricsOnline =
      Hive.box('settings').get('getLyricsOnline', defaultValue: true) as bool;

  final MyTheme currentTheme = GetIt.I<MyTheme>();
  final ValueNotifier<List<Color?>?> gradientColor =
      ValueNotifier<List<Color?>?>(GetIt.I<MyTheme>().playGradientColor);
  final PanelController _panelController = PanelController();
  final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  late Duration _time;

  bool isSharePopupShown = false;

  void sleepTimer(int time) {
    audioHandler.customAction('sleepTimer', {'time': time});
  }

  void sleepCounter(int count) {
    audioHandler.customAction('sleepCounter', {'count': count});
  }

  Future<dynamic> setTimer(
    BuildContext context,
    BuildContext? scaffoldContext,
  ) {
    return showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Center(
            child: Text(
              AppLocalizations.of(context)!.selectDur,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          children: [
            Center(
              child: SizedBox(
                height: 200,
                width: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    primaryColor: Theme.of(context).colorScheme.secondary,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    onTimerDurationChanged: (value) {
                      _time = value;
                    },
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: () {
                    sleepTimer(0);
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                const SizedBox(
                  width: 10,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor:
                        Theme.of(context).colorScheme.secondary == Colors.white
                            ? Colors.black
                            : Colors.white,
                  ),
                  onPressed: () {
                    sleepTimer(_time.inMinutes);
                    Navigator.pop(context);
                    ShowSnackBar().showSnackBar(
                      context,
                      '${AppLocalizations.of(context)!.sleepTimerSetFor} ${_time.inMinutes} ${AppLocalizations.of(context)!.minutes}',
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.ok),
                ),
                const SizedBox(
                  width: 20,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> setCounter() async {
    showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context)!.enterSongsCount,
      initialText: '',
      keyboardType: TextInputType.number,
      onSubmitted: (String value, BuildContext context) {
        sleepCounter(
          int.parse(value),
        );
        Navigator.pop(context);
        ShowSnackBar().showSnackBar(
          context,
          '${AppLocalizations.of(context)!.sleepTimerSetFor} $value ${AppLocalizations.of(context)!.songs}',
        );
      },
    );
  }

  void updateBackgroundColors(List<Color?> value) {
    gradientColor.value = value;
    return;
  }

  String format(String msg) {
    return '${msg[0].toUpperCase()}${msg.substring(1)}'.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      direction: DismissDirection.down,
      background: const ColoredBox(color: Colors.transparent),
      key: const Key('playScreen'),
      onDismissed: (direction) {
        Navigator.pop(context);
      },
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final MediaItem? mediaItem = snapshot.data;
          if (mediaItem == null) return const SizedBox();
          final offline =
              !mediaItem.extras!['url'].toString().startsWith('http');
          if (mediaItem.artUri != null && mediaItem.artUri.toString() != '') {
            mediaItem.artUri.toString().startsWith('file')
                ? getColors(
                    imageProvider: FileImage(
                      File(
                        mediaItem.artUri!.toFilePath(),
                      ),
                    ),
                  ).then((value) => updateBackgroundColors(value))
                : getColors(
                    imageProvider: CachedNetworkImageProvider(
                      mediaItem.artUri.toString(),
                    ),
                  ).then((value) => updateBackgroundColors(value));
          }
          return ValueListenableBuilder(
            valueListenable: gradientColor,
            child: SafeArea(
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(Icons.expand_more_rounded, size: 28),
                    tooltip: AppLocalizations.of(context)!.back,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  title: const Text(''),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.cast_rounded),
                      tooltip: "Cast",
                      onPressed: () {
                        ShowSnackBar().showSnackBar(
                          context,
                          "Casting not supported in this device.",
                        );
                      },
                    ),
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.more_vert_rounded),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(15.0),
                        ),
                      ),
                      onSelected: (int? value) {
                        if (value == 10) {
                          showSongInfo(mediaItem, context);
                        }
                        if (value == 5) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) => SongsListPage(
                                listItem: {
                                  'type': 'album',
                                  'id': mediaItem.extras?['album_id'],
                                  'title': mediaItem.album,
                                  'image': mediaItem.artUri,
                                },
                              ),
                            ),
                          );
                        }
                        if (value == 4) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return const Equalizer();
                            },
                          );
                        }
                        if (value == 3) {
                          launchUrl(
                            Uri.parse(
                              mediaItem.genre == 'YouTube'
                                  ? 'https://youtube.com/watch?v=${mediaItem.id}'
                                  : 'https://www.youtube.com/results?search_query=${mediaItem.title} by ${mediaItem.artist}',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                        if (value == 1) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return SimpleDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                title: Text(
                                  AppLocalizations.of(context)!.sleepTimer,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(10.0),
                                children: [
                                  ListTile(
                                    title: Text(
                                      AppLocalizations.of(context)!.sleepDur,
                                    ),
                                    subtitle: Text(
                                      AppLocalizations.of(context)!.sleepDurSub,
                                    ),
                                    dense: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      setTimer(
                                        context,
                                        null,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                      AppLocalizations.of(context)!.sleepAfter,
                                    ),
                                    subtitle: Text(
                                      AppLocalizations.of(context)!
                                          .sleepAfterSub,
                                    ),
                                    dense: true,
                                    isThreeLine: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      setCounter();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        if (value == 20) {
                          Feedback.forLongPress(context);
                          audioHandler.customAction(
                              'switchToYouTube', {'id': mediaItem.id});
                          ShowSnackBar().showSnackBar(
                            context,
                            'Switching to YouTube Source...',
                          );
                        }
                        if (value == 21) {
                          Feedback.forLongPress(context);
                          audioHandler.customAction(
                              'switchToSaavn', {'id': mediaItem.id});
                          ShowSnackBar().showSnackBar(
                            context,
                            'Switching to JioSaavn Source...',
                          );
                        }
                        if (value == 0) {
                          AddToPlaylist().addToPlaylist(context, mediaItem);
                        }
                      },
                      itemBuilder: (context) => offline
                          ? [
                              if (mediaItem.extras?['album_id'] != null)
                                PopupMenuItem(
                                  value: 5,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.album_rounded,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Text(
                                        AppLocalizations.of(context)!.viewAlbum,
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.timer,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      AppLocalizations.of(context)!.sleepTimer,
                                    ),
                                  ],
                                ),
                              ),
                              if (Hive.box('settings').get(
                                'supportEq',
                                defaultValue: false,
                              ) as bool)
                                PopupMenuItem(
                                  value: 4,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.equalizer_rounded,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Text(
                                        AppLocalizations.of(context)!.equalizer,
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 10,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      AppLocalizations.of(context)!.songInfo,
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : [
                              if (mediaItem.extras?['album_id'] != null)
                                PopupMenuItem(
                                  value: 5,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.album_rounded,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Text(
                                        AppLocalizations.of(context)!.viewAlbum,
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 0,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.playlist_add_rounded,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .addToPlaylist,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.timer,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      AppLocalizations.of(context)!.sleepTimer,
                                    ),
                                  ],
                                ),
                              ),
                              if (Hive.box('settings').get(
                                'supportEq',
                                defaultValue: false,
                              ) as bool)
                                PopupMenuItem(
                                  value: 4,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.equalizer_rounded,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Text(
                                        AppLocalizations.of(context)!.equalizer,
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 3,
                                child: Row(
                                  children: [
                                    Icon(
                                      MdiIcons.youtube,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      mediaItem.genre == 'YouTube'
                                          ? AppLocalizations.of(
                                              context,
                                            )!
                                              .watchVideo
                                          : AppLocalizations.of(
                                              context,
                                            )!
                                              .searchVideo,
                                    ),
                                  ],
                                ),
                              ),
                              if (mediaItem.genre == 'YouTube')
                                PopupMenuItem(
                                  value: 21,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.music_note_rounded,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 10.0),
                                      const Text(
                                        'Switch to JioSaavn',
                                      ),
                                    ],
                                  ),
                                )
                              else
                                PopupMenuItem(
                                  value: 20,
                                  child: Row(
                                    children: [
                                      Icon(
                                        MdiIcons.youtube,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                      const SizedBox(width: 10.0),
                                      const Text(
                                        'Switch to YouTube',
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 10,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      AppLocalizations.of(context)!.songInfo,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
                body: LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                  ) {
                    if (constraints.maxWidth > constraints.maxHeight) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Artwork
                          ArtWorkWidget(
                            cardKey: cardKey,
                            mediaItem: mediaItem,
                            width: min(
                              constraints.maxHeight / 0.9,
                              constraints.maxWidth / 1.8,
                            ),
                            audioHandler: audioHandler,
                            offline: offline,
                            getLyricsOnline: getLyricsOnline,
                          ),

                          // title and controls
                          NameNControls(
                            mediaItem: mediaItem,
                            offline: offline,
                            width: constraints.maxWidth / 2,
                            height: constraints.maxHeight,
                            panelController: _panelController,
                            audioHandler: audioHandler,
                            cardKey: cardKey,
                          ),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight - 20,
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                // Artwork
                                ArtWorkWidget(
                                  cardKey: cardKey,
                                  mediaItem: mediaItem,
                                  width: constraints.maxWidth,
                                  audioHandler: audioHandler,
                                  offline: offline,
                                  getLyricsOnline: getLyricsOnline,
                                ),
                                const SizedBox(height: 12),
                                // title and controls
                                Expanded(
                                  child: NameNControls(
                                    mediaItem: mediaItem,
                                    offline: offline,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight -
                                        (constraints.maxWidth * 0.85) -
                                        28,
                                    panelController: _panelController,
                                    audioHandler: audioHandler,
                                    cardKey: cardKey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RelatedSongsSection(
                            mediaItem: mediaItem,
                            audioHandler: audioHandler,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            builder:
                (BuildContext context, List<Color?>? value, Widget? child) {
              final Color domColor = value?[0] ?? const Color(0xFF2B0C0A);
              // Blend dominant album color with Flicko green base for a
              // solid glassmorphic look (no transparent see-through).
              final Color greenBase = Color.lerp(
                domColor,
                const Color(0xFF0A1A0F),
                0.65,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? RadialGradient(
                          center: const Alignment(0, -0.5),
                          radius: 1.4,
                          colors: [
                            Color.lerp(domColor, const Color(0xFF1B3A20), 0.5)!,
                            greenBase,
                            const Color(0xFF060E08),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(domColor, const Color(0xFF3D6B45), 0.4)!
                                .withValues(alpha: 0.9),
                            const Color(0xFFF0F5F1),
                          ],
                        ),
                ),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class QueueState {
  static const QueueState empty =
      QueueState([], 0, [], AudioServiceRepeatMode.none);

  final List<MediaItem> queue;
  final int? queueIndex;
  final List<int>? shuffleIndices;
  final AudioServiceRepeatMode repeatMode;

  const QueueState(
    this.queue,
    this.queueIndex,
    this.shuffleIndices,
    this.repeatMode,
  );

  bool get hasPrevious =>
      repeatMode != AudioServiceRepeatMode.none || (queueIndex ?? 0) > 0;
  bool get hasNext =>
      repeatMode != AudioServiceRepeatMode.none ||
      (queueIndex ?? 0) + 1 < queue.length;

  List<int> get indices =>
      shuffleIndices ?? List.generate(queue.length, (i) => i);
}

class ControlButtons extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final bool shuffle;
  final bool miniplayer;
  final List buttons;
  final Color? dominantColor;

  const ControlButtons(
    this.audioHandler, {super.key, 
    this.shuffle = false,
    this.miniplayer = false,
    this.buttons = const ['Previous', 'Play/Pause', 'Next'],
    this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    final MediaItem mediaItem = audioHandler.mediaItem.value!;
    final bool online = mediaItem.extras!['url'].toString().startsWith('http');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.min,
      children: buttons.map((e) {
        switch (e) {
          case 'Like':
            return !online
                ? const SizedBox()
                : miniplayer
                    ? ValueListenableBuilder(
                        valueListenable:
                            Hive.box('Favorite Songs').listenable(),
                        builder:
                            (BuildContext context, Box box, Widget? widget) {
                          return LikeButton(
                            mediaItem: mediaItem,
                            size: 22.0,
                          );
                        },
                      )
                    : LikeButton(
                        mediaItem: mediaItem,
                        size: 22.0,
                      );
          case 'Previous':
            return StreamBuilder<QueueState>(
              stream: audioHandler.queueState,
              builder: (context, snapshot) {
                final queueState = snapshot.data;
                final resetOnSkip = Hive.box('settings')
                    .get('resetOnSkip', defaultValue: false) as bool;
                return IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: miniplayer ? 24.0 : 45.0,
                  tooltip: AppLocalizations.of(context)!.skipPrevious,
                  color: dominantColor ?? Theme.of(context).iconTheme.color,
                  onPressed: ((queueState?.hasPrevious ?? true) || resetOnSkip)
                      ? audioHandler.skipToPrevious
                      : null,
                );
              },
            );
          case 'Play/Pause':
            return SizedBox(
              height: miniplayer ? 40.0 : 65.0,
              width: miniplayer ? 40.0 : 65.0,
              child: StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, snapshot) {
                  final playbackState = snapshot.data;
                  final processingState = playbackState?.processingState;
                  final playing = playbackState?.playing ?? true;
                  return Stack(
                    children: [
                      if (processingState == AudioProcessingState.loading ||
                          processingState == AudioProcessingState.buffering)
                        Center(
                          child: SizedBox(
                            height: miniplayer ? 40.0 : 65.0,
                            width: miniplayer ? 40.0 : 65.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).iconTheme.color!,
                              ),
                            ),
                          ),
                        ),
                      if (miniplayer)
                        Center(
                          child: playing
                              ? IconButton(
                                  tooltip: AppLocalizations.of(context)!.pause,
                                  onPressed: audioHandler.pause,
                                  icon: const Icon(
                                    Icons.pause_rounded,
                                  ),
                                  color: Theme.of(context).iconTheme.color,
                                )
                              : IconButton(
                                  tooltip: AppLocalizations.of(context)!.play,
                                  onPressed: audioHandler.play,
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                  ),
                                  color: Theme.of(context).iconTheme.color,
                                ),
                        )
                      else
                        Center(
                          child: SizedBox(
                            height: 59,
                            width: 59,
                            child: Center(
                              child: playing
                                  ? FloatingActionButton(
                                      elevation: 10,
                                      tooltip:
                                          AppLocalizations.of(context)!.pause,
                                      backgroundColor: Colors.white,
                                      onPressed: audioHandler.pause,
                                      child: const Icon(
                                        Icons.pause_rounded,
                                        size: 40.0,
                                        color: Colors.black,
                                      ),
                                    )
                                  : FloatingActionButton(
                                      elevation: 10,
                                      tooltip:
                                          AppLocalizations.of(context)!.play,
                                      backgroundColor: Colors.white,
                                      onPressed: audioHandler.play,
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 40.0,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          case 'Next':
            return StreamBuilder<QueueState>(
              stream: audioHandler.queueState,
              builder: (context, snapshot) {
                final queueState = snapshot.data;
                return IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: miniplayer ? 24.0 : 45.0,
                  tooltip: AppLocalizations.of(context)!.skipNext,
                  color: dominantColor ?? Theme.of(context).iconTheme.color,
                  onPressed: queueState?.hasNext ?? true
                      ? audioHandler.skipToNext
                      : null,
                );
              },
            );
          case 'Download':
            return !online
                ? const SizedBox()
                : DownloadButton(
                    size: 20.0,
                    icon: 'download',
                    data: MediaItemConverter.mediaItemToMap(mediaItem),
                  );
          default:
            break;
        }
        return const SizedBox();
      }).toList(),
    );
  }
}

abstract class AudioPlayerHandler implements AudioHandler {
  Stream<QueueState> get queueState;
  Future<void> moveQueueItem(int currentIndex, int newIndex);
  ValueStream<double> get volume;
  Future<void> setVolume(double volume);
  ValueStream<double> get speed;
}

class NowPlayingStream extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final ScrollController? scrollController;
  final PanelController? panelController;
  final bool head;
  final double headHeight;

  const NowPlayingStream({super.key, 
    required this.audioHandler,
    this.scrollController,
    this.panelController,
    this.head = false,
    this.headHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueueState>(
      stream: audioHandler.queueState,
      builder: (context, snapshot) {
        final queueState = snapshot.data ?? QueueState.empty;
        final queue = queueState.queue;
        final int queueStateIndex = queueState.queueIndex ?? 0;

        return ReorderableListView.builder(
          header: SizedBox(
            height: head ? headHeight : 0,
          ),
          onReorder: (int oldIndex, int newIndex) {
            if (oldIndex < newIndex) {
              newIndex--;
            }
            audioHandler.moveQueueItem(
              queueStateIndex + oldIndex,
              queueStateIndex + newIndex,
            );
          },
          scrollController: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 10),
          shrinkWrap: true,
          itemCount: queue.length - queueStateIndex,
          itemBuilder: (context, index) {
            final currentItem = queue[queueStateIndex + index];
            final bool isRecommended = currentItem.extras?['addedByAutoplay'] as bool? ?? false;
            
            bool isFirstRecommendation = false;
            if (isRecommended && index > 0) {
              final prevItem = queue[queueStateIndex + index - 1];
              final bool prevRecommended = prevItem.extras?['addedByAutoplay'] as bool? ?? false;
              if (!prevRecommended) {
                isFirstRecommendation = true;
              }
            }

            final Widget tile = Dismissible(
              key: ValueKey(
                '${currentItem.id}#${queueStateIndex + index}',
              ),
              direction: (queueStateIndex + index) == queueState.queueIndex
                  ? DismissDirection.none
                  : DismissDirection.horizontal,
              onDismissed: (dir) {
                audioHandler.removeQueueItemAt(queueStateIndex + index);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: ListTileTheme(
                      selectedColor: Theme.of(context).colorScheme.secondary,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        selected:
                            queueStateIndex + index == queueState.queueIndex,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: (queueStateIndex + index ==
                                  queueState.queueIndex)
                              ? [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.bar_chart_rounded,
                                    ),
                                    tooltip:
                                        AppLocalizations.of(context)!.playing,
                                    onPressed: () {},
                                  ),
                                ]
                              : [
                                  if (queue[queueStateIndex + index]
                                      .extras!['url']
                                      .toString()
                                      .startsWith('http')) ...[
                                    LikeButton(
                                      mediaItem: queue[queueStateIndex + index],
                                    ),
                                    DownloadButton(
                                      icon: 'download',
                                      size: 25.0,
                                      data: {
                                        'id': queue[queueStateIndex + index].id,
                                        'artist': queue[queueStateIndex + index]
                                            .artist
                                            .toString(),
                                        'album': queue[queueStateIndex + index]
                                            .album
                                            .toString(),
                                        'image': queue[queueStateIndex + index]
                                            .artUri
                                            .toString(),
                                        'duration':
                                            queue[queueStateIndex + index]
                                                .duration!
                                                .inSeconds
                                                .toString(),
                                        'title': queue[queueStateIndex + index]
                                            .title,
                                        'url': queue[queueStateIndex + index]
                                            .extras?['url']
                                            .toString(),
                                        'year': queue[queueStateIndex + index]
                                            .extras?['year']
                                            .toString(),
                                        'language':
                                            queue[queueStateIndex + index]
                                                .extras?['language']
                                                .toString(),
                                        'genre': queue[queueStateIndex + index]
                                            .genre
                                            ?.toString(),
                                        '320kbps':
                                            queue[queueStateIndex + index]
                                                .extras?['320kbps'],
                                        'has_lyrics':
                                            queue[queueStateIndex + index]
                                                .extras?['has_lyrics'],
                                        'release_date':
                                            queue[queueStateIndex + index]
                                                .extras?['release_date'],
                                        'album_id':
                                            queue[queueStateIndex + index]
                                                .extras?['album_id'],
                                        'subtitle':
                                            queue[queueStateIndex + index]
                                                .extras?['subtitle'],
                                        'perma_url':
                                            queue[queueStateIndex + index]
                                                .extras?['perma_url'],
                                      },
                                    ),
                                  ],
                                  ReorderableDragStartListener(
                                    key: Key(
                                      '${queue[queueStateIndex + index].id}#${queueStateIndex + index}',
                                    ),
                                    index: index,
                                    enabled: (queueStateIndex + index) !=
                                        queueState.queueIndex,
                                    child:
                                        const Icon(Icons.drag_handle_rounded),
                                  ),
                                ],
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (queue[queueStateIndex + index]
                                    .extras?['addedByAutoplay'] as bool? ??
                                false)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RotatedBox(
                                        quarterTurns: 3,
                                        child: Text(
                                          AppLocalizations.of(context)!.addedBy,
                                          textAlign: TextAlign.start,
                                          style: const TextStyle(
                                            fontSize: 5.0,
                                          ),
                                        ),
                                      ),
                                      RotatedBox(
                                        quarterTurns: 3,
                                        child: Text(
                                          AppLocalizations.of(context)!
                                              .autoplay,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontSize: 8.0,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 5.0,
                                  ),
                                ],
                              ),
                            Card(
                              elevation: 3,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (queue[queueStateIndex + index].artUri ==
                                      null)
                                  ? const SizedBox.square(
                                      dimension: 50,
                                      child: Image(
                                        image: AssetImage('assets/cover.jpg'),
                                      ),
                                    )
                                  : SizedBox.square(
                                      dimension: 50,
                                      child: queue[queueStateIndex + index]
                                              .artUri
                                              .toString()
                                              .startsWith('file:')
                                          ? Image(
                                              fit: BoxFit.cover,
                                              image: FileImage(
                                                File(
                                                  queue[queueStateIndex + index]
                                                      .artUri!
                                                      .toFilePath(),
                                                ),
                                              ),
                                            )
                                          : CachedNetworkImage(
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (BuildContext context, _,
                                                          __) =>
                                                      const Image(
                                                fit: BoxFit.cover,
                                                image: AssetImage(
                                                  'assets/cover.jpg',
                                                ),
                                              ),
                                              placeholder:
                                                  (BuildContext context, _) =>
                                                      const Image(
                                                fit: BoxFit.cover,
                                                image: AssetImage(
                                                  'assets/cover.jpg',
                                                ),
                                              ),
                                              imageUrl:
                                                  queue[queueStateIndex + index]
                                                      .artUri
                                                      .toString(),
                                            ),
                                    ),
                            ),
                          ],
                        ),
                        title: Text(
                          queue[queueStateIndex + index].title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight:
                                queueStateIndex + index == queueState.queueIndex
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          queue[queueStateIndex + index].artist!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12.0,
                          ),
                        ),
                        onTap: () {
                          audioHandler.skipToQueueItem(queueStateIndex + index);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            if (isFirstRecommendation) {
              return Column(
                key: ValueKey('rec_header_wrapper_${currentItem.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.white10),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF52B788),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "You Might Also Like",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Recommended based on your queue",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  tile,
                ],
              );
            }
            return tile;
          },
        );
      },
    );
  }
}

class RelatedSongsSection extends StatefulWidget {
  final MediaItem mediaItem;
  final AudioPlayerHandler audioHandler;

  const RelatedSongsSection({
    super.key,
    required this.mediaItem,
    required this.audioHandler,
  });

  @override
  _RelatedSongsSectionState createState() => _RelatedSongsSectionState();
}

class _RelatedSongsSectionState extends State<RelatedSongsSection> {
  List<Map> relatedSongs = [];
  bool loading = true;
  String currentId = '';

  @override
  void initState() {
    super.initState();
    currentId = widget.mediaItem.id;
    _fetchRelated();
  }

  @override
  void didUpdateWidget(covariant RelatedSongsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaItem.id != currentId) {
      currentId = widget.mediaItem.id;
      _fetchRelated();
    }
  }

  Future<void> _fetchRelated() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });
    try {
      final artist = widget.mediaItem.artist ?? "Unknown";
      List<Map> topList = [];
      List<Map> similarList = [];

      if (widget.mediaItem.genre != 'YouTube') {
        // JioSaavn
        final searchRes = await SaavnAPI()
            .fetchSongSearchResults(searchQuery: artist, count: 25);
        if (searchRes['songs'] != null) {
          topList = List<Map>.from(searchRes['songs'] as List);
        }
        final List reco = await SaavnAPI().getReco(widget.mediaItem.id);
        similarList = List<Map>.from(reco);
      } else {
        // YouTube
        final List<SongItem> ytSongs =
            await YtMusicService().searchSongs(artist);
        topList = ytSongs
            .map((e) => {
                  'id': e.id,
                  'title': e.title,
                  'subtitle': e.artists.join(', '),
                  'artist': e.artists.join(', '),
                  'image': e.image,
                  'duration': e.duration.inSeconds,
                  'url': e.url,
                  'genre': 'YouTube',
                  'album': e.album,
                  'has_lyrics': e.hasLyrics,
                })
            .toList();

        // Similar songs from YouTube
        similarList = topList.reversed.toList();
      }

      // Merge and deduplicate by song id and normalized title+artist
      final seenIds = <String>{};
      final seenTitles = <String>{};
      final List<Map> merged = [];
      for (final song in [...similarList, ...topList]) {
        final songId = song['id']?.toString() ?? '';
        final title = (song['title'] ?? song['name'] ?? '').toString().toLowerCase().trim();
        final artist = (song['artist'] ?? song['artistName'] ?? song['subtitle'] ?? '').toString().toLowerCase().trim();
        final titleArtistKey = '$title-$artist';

        if (songId.isNotEmpty && seenIds.add(songId)) {
          if (title.isEmpty || seenTitles.add(titleArtistKey)) {
            merged.add(song);
          }
        }
        if (merged.length >= 50) break;
      }

      if (mounted) {
        setState(() {
          relatedSongs = merged;
          loading = false;
        });
      }
    } catch (e) {
      Logger.root.severe('Error in _fetchRelated: $e');
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _formatDuration(dynamic durationSec) {
    if (durationSec == null) return "3:23";
    final int totalSec = int.tryParse(durationSec.toString()) ?? 180;
    final int minutes = totalSec ~/ 60;
    final int seconds = totalSec % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSongList(List<Map> songs) {
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Text(
            "No songs found",
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: songs.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.white.withOpacity(0.04),
        height: 1,
        indent: 70,
      ),
      itemBuilder: (context, index) {
        final entry = songs[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () {
            PlayerInvoke.init(
              songsList: songs,
              index: index,
              isOffline: false,
            );
          },
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: entry['image'].toString(),
                fit: BoxFit.cover,
                errorWidget: (context, _, __) =>
                    const Icon(Icons.music_note, color: Colors.white54),
                placeholder: (context, _) =>
                    Container(color: Colors.white.withOpacity(0.05)),
              ),
            ),
          ),
          title: Text(
            entry['title'].toString().unescape(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            (entry['subtitle'] ?? entry['artist'] ?? "Unknown")
                .toString()
                .unescape(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          trailing: Text(
            _formatDuration(entry['duration']),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 80.0, top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single consolidated "Related Songs" card
          ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.07),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 18,
                          width: 3.5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Related Songs",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 11.5),
                      child: Text(
                        "Based on your listening choices",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSongList(relatedSongs),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassLyricUI extends LyricUI {
  final double defaultSize;
  final double defaultExtSize;
  final double otherMainSize;
  final double bias;
  final double lineGap;
  final double inlineGap;
  final LyricAlign lyricAlign;
  final LyricBaseLine lyricBaseLine;
  final bool highlight;
  final HighlightDirection highlightDirection;

  GlassLyricUI({
    this.defaultSize = 19,
    this.defaultExtSize = 14,
    this.otherMainSize = 16,
    this.bias = 0.5,
    this.lineGap = 20,
    this.inlineGap = 20,
    this.lyricAlign = LyricAlign.CENTER,
    this.lyricBaseLine = LyricBaseLine.CENTER,
    this.highlight = true,
    this.highlightDirection = HighlightDirection.LTR,
  });

  @override
  TextStyle getPlayingExtTextStyle() =>
      TextStyle(color: Colors.white70, fontSize: defaultExtSize);

  @override
  TextStyle getOtherExtTextStyle() => TextStyle(
        color: Colors.white30,
        fontSize: defaultExtSize,
      );

  @override
  TextStyle getOtherMainTextStyle() => TextStyle(
      color: Colors.white.withOpacity(0.35),
      fontSize: otherMainSize,
      fontWeight: FontWeight.w500);

  @override
  TextStyle getPlayingMainTextStyle() => const TextStyle(
        color: Colors.white,
        fontSize: 19.0,
        fontWeight: FontWeight.bold,
      );

  @override
  double getInlineSpace() => inlineGap;

  @override
  double getLineSpace() => lineGap;

  @override
  double getPlayingLineBias() => bias;

  @override
  LyricAlign getLyricHorizontalAlign() => lyricAlign;

  @override
  LyricBaseLine getBiasBaseLine() => lyricBaseLine;

  @override
  bool enableHighlight() => highlight;

  @override
  HighlightDirection getHighlightDirection() => highlightDirection;
}

class ArtWorkWidget extends StatefulWidget {
  final GlobalKey<FlipCardState> cardKey;
  final MediaItem mediaItem;
  final bool offline;
  final bool getLyricsOnline;
  final double width;
  final AudioPlayerHandler audioHandler;

  const ArtWorkWidget({super.key, 
    required this.cardKey,
    required this.mediaItem,
    required this.width,
    this.offline = false,
    required this.getLyricsOnline,
    required this.audioHandler,
  });

  @override
  _ArtWorkWidgetState createState() => _ArtWorkWidgetState();
}

class _ArtWorkWidgetState extends State<ArtWorkWidget> {
  final ValueNotifier<bool> dragging = ValueNotifier<bool>(false);
  final ValueNotifier<bool> tapped = ValueNotifier<bool>(false);
  final ValueNotifier<int> doubletapped = ValueNotifier<int>(0);
  final ValueNotifier<bool> done = ValueNotifier<bool>(false);
  final ValueNotifier<String> lyricsSource = ValueNotifier<String>('');
  Map lyrics = {
    'id': '',
    'lyrics': '',
    'source': '',
    'type': '',
  };
  final lyricUI = GlassLyricUI();
  LyricsReaderModel? lyricsReaderModel;
  bool flipped = false;

  late final Stream<List<dynamic>> _lyricsPositionStream =
      Rx.combineLatest2<Duration, PlaybackState, List<dynamic>>(
        AudioService.position,
        widget.audioHandler.playbackState,
        (position, state) => [position, state.playing],
      ).distinct();

  bool get saavnHasLyrics {
    final value = widget.mediaItem.extras?['has_lyrics'];
    return value == true || value?.toString().toLowerCase() == 'true';
  }

  void fetchLyrics() {
    Logger.root.info('Fetching lyrics for ${widget.mediaItem.title}');
    done.value = false;
    lyricsSource.value = '';
    if (widget.offline) {
      Lyrics.getOffLyrics(
        widget.mediaItem.extras!['url'].toString(),
      ).then((value) {
        if (value == '' && widget.getLyricsOnline) {
          Lyrics.getLyrics(
            id: widget.mediaItem.id,
            saavnHas: saavnHasLyrics,
            title: widget.mediaItem.title,
            artist: widget.mediaItem.artist.toString(),
          ).then((Map value) {
            lyrics['lyrics'] = value['lyrics'];
            final String lyricsText = lyrics['lyrics'].toString();
            final bool isLrc = lyricsText.contains(RegExp(r'\[\d{2}:\d{2}'));
            lyrics['type'] = isLrc ? 'lrc' : 'text';
            lyrics['source'] = value['source'];
            lyrics['id'] = widget.mediaItem.id;
            done.value = true;
            lyricsSource.value = lyrics['source'].toString();
            lyricsReaderModel = LyricsModelBuilder.create()
                .bindLyricToMain(lyrics['lyrics'].toString())
                .getModel();
          });
        } else {
          Logger.root.info('Lyrics found offline');
          lyrics['lyrics'] = value;
          final String lyricsText = lyrics['lyrics'].toString();
          final bool isLrc = lyricsText.contains(RegExp(r'\[\d{2}:\d{2}'));
          lyrics['type'] = isLrc ? 'lrc' : 'text';
          lyrics['source'] = 'Local';
          lyrics['id'] = widget.mediaItem.id;
          done.value = true;
          lyricsSource.value = lyrics['source'].toString();
          lyricsReaderModel = LyricsModelBuilder.create()
              .bindLyricToMain(lyrics['lyrics'].toString())
              .getModel();
        }
      });
    } else {
      Lyrics.getLyrics(
        id: widget.mediaItem.id,
        saavnHas: saavnHasLyrics,
        title: widget.mediaItem.title,
        artist: widget.mediaItem.artist.toString(),
      ).then((Map value) {
        if (widget.mediaItem.id != value['id']) {
          done.value = true;
          return;
        }
        lyrics['lyrics'] = value['lyrics'];
        final String lyricsText = lyrics['lyrics'].toString();
        final bool isLrc = lyricsText.contains(RegExp(r'\[\d{2}:\d{2}'));
        lyrics['type'] = isLrc ? 'lrc' : 'text';
        lyrics['source'] = value['source'];
        lyrics['id'] = widget.mediaItem.id;
        done.value = true;
        lyricsSource.value = lyrics['source'].toString();
        lyricsReaderModel = LyricsModelBuilder.create()
            .bindLyricToMain(lyrics['lyrics'].toString())
            .getModel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (flipped && lyrics['id'] != widget.mediaItem.id) {
      fetchLyrics();
    }
    return SizedBox(
      height: widget.width * 0.85,
      width: widget.width * 0.85,
      child: Hero(
        tag: 'currentArtwork',
        child: FlipCard(
          key: widget.cardKey,
          flipOnTouch: false,
          onFlipDone: (value) {
            flipped = value;
            if (flipped && lyrics['id'] != widget.mediaItem.id) {
              fetchLyrics();
            }
          },
          back: GestureDetector(
            onTap: () => widget.cardKey.currentState!.toggleCard(),
            onDoubleTap: () => widget.cardKey.currentState!.toggleCard(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                          ).createShader(
                            Rect.fromLTRB(0, 0, rect.width, rect.height),
                          );
                        },
                        blendMode: BlendMode.dstIn,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              vertical: 60,
                              horizontal: 20,
                            ),
                            child: ValueListenableBuilder(
                              valueListenable: done,
                              child: const CircularProgressIndicator(),
                              builder: (
                                BuildContext context,
                                bool value,
                                Widget? child,
                              ) {
                                return value
                                    ? lyrics['lyrics'] == ''
                                        ? emptyScreen(
                                            context,
                                            0,
                                            ':( ',
                                            100.0,
                                            AppLocalizations.of(context)!
                                                .lyrics,
                                            60.0,
                                            AppLocalizations.of(context)!
                                                .notAvailable,
                                            20.0,
                                            useWhite: true,
                                          )
                                        : lyrics['type'] == 'text'
                                            ? SelectableText(
                                                lyrics['lyrics'].toString(),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 16.0,
                                                ),
                                              )
                                            : StreamBuilder<List<dynamic>>(
                                                stream: _lyricsPositionStream,
                                                builder: (context, snapshot) {
                                                  final list = snapshot.data ?? [Duration.zero, false];
                                                  final position = list[0] as Duration;
                                                  final playing = list[1] as bool;
                                                  return LyricsReader(
                                                    model: lyricsReaderModel,
                                                    position:
                                                        position.inMilliseconds,
                                                    lyricUi: GlassLyricUI(),
                                                    playing: playing,
                                                    size: Size(
                                                      widget.width * 0.85,
                                                      widget.width * 0.85,
                                                    ),
                                                    emptyBuilder: () => Center(
                                                      child: Text(
                                                        'Lyrics Not Found',
                                                        style: lyricUI
                                                            .getOtherMainTextStyle(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                    : child!;
                              },
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: lyricsSource,
                        child: const CircularProgressIndicator(),
                        builder: (
                          BuildContext context,
                          String value,
                          Widget? child,
                        ) {
                          if (value == '') {
                            return const SizedBox();
                          }
                          return Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                'Powered by $value',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                        fontSize: 10.0, color: Colors.white70),
                              ),
                            ),
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Card(
                          elevation: 10.0,
                          margin: const EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          color: Theme.of(context).cardColor.withOpacity(0.6),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: AppLocalizations.of(context)!.copy,
                            onPressed: () {
                              Feedback.forLongPress(context);
                              copyToClipboard(
                                context: context,
                                text: lyrics['lyrics'].toString(),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            color: Theme.of(context)
                                .iconTheme
                                .color!
                                .withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          front: StreamBuilder<QueueState>(
            stream: widget.audioHandler.queueState,
            builder: (context, snapshot) {
              final queueState = snapshot.data ?? QueueState.empty;

              final bool enabled = Hive.box('settings')
                  .get('enableGesture', defaultValue: true) as bool;
              final volumeGestureEnabled = Hive.box('settings')
                  .get('volumeGestureEnabled', defaultValue: false) as bool;

              return ValueListenableBuilder(
                valueListenable: dragging,
                child: StreamBuilder<double>(
                  stream: widget.audioHandler.volume,
                  builder: (context, snapshot) {
                    final double volumeValue = snapshot.data ?? 1.0;
                    return Center(
                      child: SizedBox(
                        width: 60.0,
                        height: widget.width * 0.7,
                        child: Card(
                          color: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.fitHeight,
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: HiddenThumbComponentShape(),
                                        activeTrackColor: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        inactiveTrackColor: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.4),
                                        trackShape:
                                            const RoundedRectSliderTrackShape(),
                                        disabledActiveTrackColor:
                                            Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                        disabledInactiveTrackColor:
                                            Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.4),
                                      ),
                                      child: ExcludeSemantics(
                                        child: Slider(
                                          value:
                                              widget.audioHandler.volume.value,
                                          onChanged: null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 20.0,
                                ),
                                child: Icon(
                                  volumeValue == 0
                                      ? Icons.volume_off_rounded
                                      : volumeValue > 0.6
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_down_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                builder: (context, bool value, Widget? child) {
                  return GestureDetector(
                    onTap: () {
                      if (dragging.value) {
                        dragging.value = false;
                      } else if (enabled) {
                        tapped.value = true;
                        Future.delayed(const Duration(seconds: 3), () async {
                          tapped.value = false;
                        });
                        Feedback.forTap(context);
                      }
                    },
                    onDoubleTapDown: (details) {
                      if (details.globalPosition.dx <= widget.width * 2 / 5) {
                        widget.audioHandler.customAction('rewind');
                        doubletapped.value = -1;
                        Future.delayed(const Duration(milliseconds: 500),
                            () async {
                          doubletapped.value = 0;
                        });
                      }

                      if (details.globalPosition.dx > widget.width * 2 / 5 &&
                          details.globalPosition.dx < widget.width * 3 / 5) {
                        widget.cardKey.currentState!.toggleCard();
                      }

                      if (details.globalPosition.dx >= widget.width * 3 / 5) {
                        widget.audioHandler.customAction('fastForward');
                        doubletapped.value = 1;
                        Future.delayed(const Duration(milliseconds: 500),
                            () async {
                          doubletapped.value = 0;
                        });
                      }

                      Feedback.forLongPress(context);
                    },
                    onHorizontalDragEnd: !enabled
                        ? null
                        : (DragEndDetails details) {
                            if ((details.primaryVelocity ?? 0) > 100) {
                              if (queueState.hasPrevious) {
                                widget.audioHandler.skipToPrevious();
                                Feedback.forTap(context);
                              }
                            } else if ((details.primaryVelocity ?? 0) < -100) {
                              if (queueState.hasNext) {
                                widget.audioHandler.skipToNext();
                                Feedback.forTap(context);
                              }
                            }
                          },
                    onLongPress: !enabled
                        ? null
                        : () {
                            if (!widget.offline) {
                              Feedback.forLongPress(context);
                              AddToPlaylist()
                                  .addToPlaylist(context, widget.mediaItem);
                            }
                          },
                    onVerticalDragStart: enabled && volumeGestureEnabled
                        ? (_) {
                            dragging.value = true;
                          }
                        : null,
                    onVerticalDragEnd: !enabled
                        ? null
                        : (_) {
                            dragging.value = false;
                          },
                    onVerticalDragUpdate: !enabled || !dragging.value
                        ? null
                        : (DragUpdateDetails details) {
                            if (details.delta.dy != 0.0) {
                              double volume = widget.audioHandler.volume.value;
                              volume -= details.delta.dy / 150;
                              if (volume < 0) {
                                volume = 0;
                              }
                              if (volume > 1.0) {
                                volume = 1.0;
                              }
                              widget.audioHandler.setVolume(volume);
                            }
                          },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Card(
                          elevation: 10.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: widget.mediaItem.artUri
                                  .toString()
                                  .startsWith('file')
                              ? Image(
                                  fit: BoxFit.contain,
                                  width: widget.width * 0.85,
                                  gaplessPlayback: true,
                                  errorBuilder: (
                                    BuildContext context,
                                    Object exception,
                                    StackTrace? stackTrace,
                                  ) {
                                    return const Image(
                                      fit: BoxFit.cover,
                                      image: AssetImage('assets/cover.jpg'),
                                    );
                                  },
                                  image: FileImage(
                                    File(
                                      widget.mediaItem.artUri!.toFilePath(),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  fit: BoxFit.contain,
                                  errorWidget: (BuildContext context, _, __) =>
                                      const Image(
                                    fit: BoxFit.cover,
                                    image: AssetImage('assets/cover.jpg'),
                                  ),
                                  placeholder: (BuildContext context, _) =>
                                      const Image(
                                    fit: BoxFit.cover,
                                    image: AssetImage('assets/cover.jpg'),
                                  ),
                                  imageUrl: widget.mediaItem.artUri.toString(),
                                  width: widget.width * 0.85,
                                ),
                        ),

                        Visibility(
                          visible: value,
                          child: child!,
                        ),
                        ValueListenableBuilder(
                          valueListenable: tapped,
                          child: GestureDetector(
                            onTap: () {
                              tapped.value = false;
                            },
                            child: Card(
                              color: Colors.black26,
                              elevation: 0.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.4),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: IconButton(
                                          tooltip: AppLocalizations.of(context)!
                                              .songInfo,
                                          onPressed: () {
                                            showSongInfo(
                                              widget.mediaItem,
                                              context,
                                            );
                                          },
                                          icon: const Icon(Icons.info_rounded),
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: IconButton(
                                              onPressed: () {
                                                tapped.value = false;
                                                dragging.value = true;
                                              },
                                              icon: const Icon(
                                                Icons.volume_up_rounded,
                                              ),
                                              color: Theme.of(context)
                                                  .iconTheme
                                                  .color,
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: IconButton(
                                              tooltip:
                                                  AppLocalizations.of(context)!
                                                      .addToPlaylist,
                                              onPressed: () {
                                                AddToPlaylist().addToPlaylist(
                                                  context,
                                                  widget.mediaItem,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.playlist_add_rounded,
                                              ),
                                              color: Theme.of(context)
                                                  .iconTheme
                                                  .color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          builder: (context, bool value, Widget? child) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Visibility(visible: value, child: child!),
                            );
                          },
                        ),
                        ValueListenableBuilder(
                          valueListenable: doubletapped,
                          child: const Icon(
                            Icons.forward_10_rounded,
                            size: 60.0,
                          ),
                          builder: (
                            BuildContext context,
                            int value,
                            Widget? child,
                          ) {
                            return Visibility(
                              visible: value != 0,
                              child: Card(
                                color: Colors.transparent,
                                elevation: 0.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox.expand(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: value == 1
                                            ? [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.4),
                                                Colors.black.withOpacity(0.7),
                                              ]
                                            : [
                                                Colors.black.withOpacity(0.7),
                                                Colors.black.withOpacity(0.4),
                                                Colors.transparent,
                                              ],
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Visibility(
                                          visible: value == -1,
                                          child: const Icon(
                                            Icons.replay_10_rounded,
                                            size: 60.0,
                                          ),
                                        ),
                                        const SizedBox(),
                                        Visibility(
                                          visible: value == 1,
                                          child: child!,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class NameNControls extends StatefulWidget {
  final MediaItem mediaItem;
  final bool offline;
  final double width;
  final double height;
  final PanelController panelController;
  final AudioPlayerHandler audioHandler;
  final GlobalKey<FlipCardState> cardKey;

  const NameNControls({
    super.key,
    required this.width,
    required this.height,
    required this.mediaItem,
    required this.audioHandler,
    required this.panelController,
    required this.cardKey,
    this.offline = false,
  });

  @override
  _NameNControlsState createState() => _NameNControlsState();
}

class _NameNControlsState extends State<NameNControls> {
  double _panelPosition = 0.0;
  String _streamingQuality = 'HQ • 320 kbps';
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _updateQuality();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateQuality(results: results);
    });
  }

  @override
  void didUpdateWidget(NameNControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaItem.id != oldWidget.mediaItem.id || widget.offline != oldWidget.offline) {
      _updateQuality();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _updateQuality({List<ConnectivityResult>? results}) async {
    if (widget.offline) {
      if (mounted) {
        setState(() {
          _streamingQuality = 'Offline';
        });
      }
      return;
    }

    final List<ConnectivityResult> connectionResults = results ?? await Connectivity().checkConnectivity();
    final bool isWifi = connectionResults.contains(ConnectivityResult.wifi);
    final String quality;
    if (widget.mediaItem.genre == 'YouTube') {
      final ytQuality = Hive.box('settings').get('ytQuality', defaultValue: 'High').toString();
      quality = 'YT • $ytQuality';
    } else {
      if (isWifi) {
        final wifiQuality = Hive.box('settings').get('streamingWifiQuality', defaultValue: '320 kbps').toString();
        quality = 'HQ • $wifiQuality';
      } else {
        final mobileQuality = Hive.box('settings').get('streamingQuality', defaultValue: '96 kbps').toString();
        quality = mobileQuality == '320 kbps' ? 'HQ • 320 kbps' : 'SQ • $mobileQuality';
      }
    }
    if (mounted) {
      setState(() {
        _streamingQuality = quality;
      });
    }
  }

  late final Stream<Duration> _bufferedPositionStream =
      widget.audioHandler.playbackState
          .map((state) => state.bufferedPosition)
          .distinct();
  late final Stream<Duration?> _durationStream =
      widget.audioHandler.mediaItem.map((item) => item?.duration).distinct();
  late final Stream<PositionData> _positionDataStream =
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        AudioService.position,
        _bufferedPositionStream,
        _durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      ).distinct();

  @override
  Widget build(BuildContext context) {
    // Redesigned YouTube Music Layout
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(
                bottom: 60.0), // Spacing for sliding panel handle
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                /// Left-aligned Title & Artist Info Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.mediaItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.mediaItem.artist ?? "Unknown Artist",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.offline ? Icons.download_done_rounded : Icons.music_note_rounded,
                                        size: 12,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _streamingQuality,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(0.8),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron right button to show details/options
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: Colors.white70, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) => SongsListPage(
                                listItem: {
                                  'type': 'album',
                                  'id': widget.mediaItem.extras?['album_id'],
                                  'title': widget.mediaItem.album,
                                  'image': widget.mediaItem.artUri,
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                /// Action Buttons Row (Download & Lyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Download Button replacing Like Button
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DownloadButton(
                              data: MediaItemConverter.mediaItemToMap(widget.mediaItem),
                              icon: 'download',
                              size: 18.0,
                            ),
                            const Text(
                              "Download",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Lyrics Button
                      GestureDetector(
                        onTap: () =>
                            widget.cardKey.currentState!.toggleCard(),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 18, color: Colors.white70),
                              SizedBox(width: 6),
                              Text(
                                "Lyrics",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// Seekbar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(
                    width: widget.width * 0.95,
                    child: StreamBuilder<PositionData>(
                      stream: _positionDataStream,
                      builder: (context, snapshot) {
                        final positionData = snapshot.data ??
                            PositionData(
                              Duration.zero,
                              Duration.zero,
                              widget.mediaItem.duration ?? Duration.zero,
                            );
                        return SeekBar(
                          duration: positionData.duration,
                          position: positionData.position,
                          bufferedPosition: positionData.bufferedPosition,
                          offline: widget.offline,
                          onChangeEnd: (newPosition) {
                            widget.audioHandler.seek(newPosition);
                          },
                          audioHandler: widget.audioHandler,
                        );
                      },
                    ),
                  ),
                ),

                /// Playback Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle
                      StreamBuilder<bool>(
                        stream: widget.audioHandler.playbackState
                            .map((state) =>
                                state.shuffleMode ==
                                AudioServiceShuffleMode.all)
                            .distinct(),
                        builder: (context, snapshot) {
                          final shuffleEnabled = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: shuffleEnabled
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              size: 24,
                            ),
                            onPressed: () async {
                              await widget.audioHandler.setShuffleMode(
                                shuffleEnabled
                                    ? AudioServiceShuffleMode.none
                                    : AudioServiceShuffleMode.all,
                              );
                            },
                          );
                        },
                      ),

                      // Previous
                      StreamBuilder<QueueState>(
                        stream: widget.audioHandler.queueState,
                        builder: (context, snapshot) {
                          final queueState = snapshot.data;
                          final resetOnSkip = Hive.box('settings')
                              .get('resetOnSkip', defaultValue: false) as bool;
                          final hasPrevious = queueState?.hasPrevious ?? true;
                          return IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: 36,
                            color: hasPrevious || resetOnSkip
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            onPressed: (hasPrevious || resetOnSkip)
                                ? widget.audioHandler.skipToPrevious
                                : null,
                          );
                        },
                      ),

                      // Large White Play/Pause Circle
                      SizedBox(
                        height: 72,
                        width: 72,
                        child: StreamBuilder<PlaybackState>(
                          stream: widget.audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final playbackState = snapshot.data;
                            final processingState =
                                playbackState?.processingState;
                            final playing = playbackState?.playing ?? true;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                if (processingState ==
                                        AudioProcessingState.loading ||
                                    processingState ==
                                        AudioProcessingState.buffering)
                                  SizedBox(
                                    height: 70,
                                    width: 70,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.secondary),
                                      strokeWidth: 3.0,
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: playing
                                      ? widget.audioHandler.pause
                                      : widget.audioHandler.play,
                                  child: Container(
                                    height: 64,
                                    width: 64,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.33),
                                          blurRadius: 16.0,
                                          spreadRadius: 2.0,
                                          offset: const Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 38.0,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Next
                      StreamBuilder<QueueState>(
                        stream: widget.audioHandler.queueState,
                        builder: (context, snapshot) {
                          final queueState = snapshot.data;
                          final hasNext = queueState?.hasNext ?? true;
                          return IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 36,
                            color: hasNext
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            onPressed:
                                hasNext ? widget.audioHandler.skipToNext : null,
                          );
                        },
                      ),

                      // Repeat
                      StreamBuilder<AudioServiceRepeatMode>(
                        stream: widget.audioHandler.playbackState
                            .map((state) => state.repeatMode)
                            .distinct(),
                        builder: (context, snapshot) {
                          final repeatMode =
                              snapshot.data ?? AudioServiceRepeatMode.none;
                          final icons = [
                            Icon(Icons.repeat_rounded,
                                color: Colors.white.withOpacity(0.5), size: 24),
                            const Icon(Icons.repeat_rounded,
                                color: Colors.white, size: 24),
                            const Icon(Icons.repeat_one_rounded,
                                color: Colors.white, size: 24),
                          ];
                          const cycleModes = [
                            AudioServiceRepeatMode.none,
                            AudioServiceRepeatMode.all,
                            AudioServiceRepeatMode.one,
                          ];
                          const texts = ['None', 'All', 'One'];
                          final index = cycleModes.indexOf(repeatMode);
                          return IconButton(
                            icon: icons[index],
                            onPressed: () async {
                              await Hive.box('settings').put(
                                'repeatMode',
                                texts[(index + 1) % texts.length],
                              );
                              await widget.audioHandler.setRepeatMode(
                                cycleModes[
                                    (cycleModes.indexOf(repeatMode) + 1) %
                                        cycleModes.length],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// Sliding Up Queue Panel (YT Music style)
          SlidingUpPanel(
            minHeight: 56.0,
            maxHeight: widget.height * 0.8,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16.0,
                spreadRadius: 2.0,
              )
            ],
            color: Colors.transparent,
            controller: widget.panelController,
            onPanelSlide: (position) {
              setState(() {
                _panelPosition = position;
              });
            },
            panelBuilder: (ScrollController scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 20.0,
                    sigmaY: 20.0,
                  ),
                  child: Container(
                    color: const Color(0xFF0A0A0A),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Drag handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Dynamic Top Bar based on panel position
                        if (_panelPosition > 0.3) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Playing from",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.mediaItem.album?.isNotEmpty == true
                                          ? widget.mediaItem.album!
                                          : (widget.mediaItem.genre == 'YouTube'
                                              ? 'YouTube Music'
                                              : 'Sonic Music'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                // Save Button
                                GestureDetector(
                                  onTap: () {
                                    AddToPlaylist().addToPlaylist(
                                        context, widget.mediaItem);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.playlist_add_rounded,
                                            size: 16, color: Colors.white),
                                        const SizedBox(width: 4),
                                        const Text("Save",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                        ] else ...[
                          Center(
                            child: Text(
                              widget.mediaItem.album?.isNotEmpty == true
                                  ? widget.mediaItem.album!
                                  : (widget.mediaItem.genre == 'YouTube'
                                      ? 'YouTube Music'
                                      : 'Sonic Music'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: NowPlayingStream(
                            head: false,
                            audioHandler: widget.audioHandler,
                            scrollController: scrollController,
                            panelController: widget.panelController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    required this.color,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 50),
          painter: WaveformPainter(
            animationValue: _controller.value,
            isPlaying: widget.isPlaying,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final Color color;

  WaveformPainter({
    required this.animationValue,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    final int barCount = 35;
    final double barWidth = width / barCount;
    final double spacing = 2.0;

    for (int i = 0; i < barCount; i++) {
      double baseHeight = 8.0;
      if (isPlaying) {
        final sin1 = sin((i * 0.3) + (animationValue * pi * 4));
        final sin2 = cos((i * 0.5) - (animationValue * pi * 2));
        baseHeight += (sin1.abs() * 18.0) + (sin2.abs() * 12.0);
      } else {
        baseHeight += sin(i * 0.5).abs() * 4.0;
      }

      final double x = i * barWidth;
      final double y = height - baseHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + spacing, y, barWidth - (spacing * 2), baseHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color;
  }
}
