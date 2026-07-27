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

import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/image_card.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MiniPlayer extends StatefulWidget {
  static const MiniPlayer _instance = MiniPlayer._internal();

  factory MiniPlayer() {
    return _instance;
  }

  const MiniPlayer._internal();

  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool rotated = screenHeight < screenWidth;
    return SafeArea(
      top: false,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          final MediaItem? mediaItem = snapshot.data;
          if (mediaItem == null) return const SizedBox();

          final List preferredMiniButtons = Hive.box('settings').get(
            'preferredMiniButtons',
            defaultValue: ['Like', 'Play/Pause', 'Next'],
          )?.toList() as List;

          final bool isLocal =
              mediaItem.artUri?.toString().startsWith('file:') ?? false;

          final bool useDense = Hive.box('settings').get(
                'useDenseMini',
                defaultValue: false,
              ) as bool ||
              rotated;

          return Dismissible(
            key: const Key('miniplayer'),
            direction: DismissDirection.vertical,
            confirmDismiss: (DismissDirection direction) {
              if (direction == DismissDirection.down) {
                audioHandler.stop();
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) => const PlayScreen(),
                  ),
                );
              }
                          return Future.value(false);
            },
            child: Dismissible(
              key: Key(mediaItem.id),
              confirmDismiss: (DismissDirection direction) {
                if (direction == DismissDirection.startToEnd) {
                  audioHandler.skipToPrevious();
                } else {
                  audioHandler.skipToNext();
                }
                              return Future.value(false);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.0),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: 16.0,
                      sigmaY: 16.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        miniplayerTile(
                          context: context,
                          preferredMiniButtons: preferredMiniButtons,
                          useDense: useDense,
                          title: mediaItem.title,
                          subtitle: mediaItem.artist ?? '',
                          imagePath: (isLocal
                                  ? mediaItem.artUri?.toFilePath()
                                  : mediaItem.artUri?.toString()) ??
                              '',
                          isLocalImage: isLocal,
                          isDummy: false,
                        ),
                        positionSlider(
                          mediaItem.duration?.inSeconds.toDouble(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ListTile miniplayerTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imagePath,
    required List preferredMiniButtons,
    bool useDense = false,
    bool isLocalImage = false,
    bool isDummy = false,
  }) {
    return ListTile(
      dense: useDense,
      onTap: isDummy
          ? null
          : () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (_, __, ___) => const PlayScreen(),
                ),
              );
            },
      title: Text(
        isDummy ? 'Now Playing' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isDummy ? 'Unknown' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Hero(
        tag: 'currentArtwork',
        child: imageCard(
          elevation: 8,
          boxDimension: useDense ? 40.0 : 50.0,
          localImage: isLocalImage,
          imageUrl: isLocalImage ? imagePath : imagePath,
        ),
      ),
      trailing: isDummy
          ? null
          : ControlButtons(
              audioHandler,
              miniplayer: true,
              buttons: isLocalImage
                  ? ['Like', 'Play/Pause', 'Next']
                  : preferredMiniButtons,
            ),
    );
  }

  StreamBuilder<Duration> positionSlider(double? maxDuration) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data;
        return ((position?.inSeconds.toDouble() ?? 0) < 0.0 ||
                ((position?.inSeconds.toDouble() ?? 0) >
                    (maxDuration ?? 180.0)))
            ? const SizedBox()
            : SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).colorScheme.secondary,
                  inactiveTrackColor: Colors.transparent,
                  trackHeight: 0.5,
                  thumbColor: Theme.of(context).colorScheme.secondary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 1.0,
                  ),
                  overlayColor: Colors.transparent,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 2.0,
                  ),
                ),
                child: Center(
                  child: Slider(
                    inactiveColor: Colors.transparent,
                    // activeColor: Colors.white,
                    value: position?.inSeconds.toDouble() ?? 0,
                    max: maxDuration ?? 180.0,
                    onChanged: (newPosition) {
                      audioHandler.seek(
                        Duration(
                          seconds: newPosition.round(),
                        ),
                      );
                    },
                  ),
                ),
              );
      },
    );
  }
}
