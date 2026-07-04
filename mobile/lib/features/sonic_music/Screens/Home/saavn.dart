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

import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/features/sonic_music/APIs/api.dart';
import 'package:mobile/features/sonic_music/CustomWidgets/snackbar.dart';
import 'package:mobile/features/sonic_music/Helpers/extensions.dart';
import 'package:mobile/features/sonic_music/Helpers/format.dart';
import 'package:mobile/features/sonic_music/Helpers/image_resolution_modifier.dart';
import 'package:mobile/features/sonic_music/Screens/Common/song_list.dart';
import 'package:mobile/features/sonic_music/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

bool fetched = false;
List preferredLanguage = Hive.box('settings')
    .get('preferredLanguage', defaultValue: ['Hindi']) as List;
List likedRadio =
    Hive.box('settings').get('likedRadio', defaultValue: []) as List;
Map data = Hive.box('cache').get('homepage', defaultValue: {}) as Map;
List lists = ['recent', 'playlist', ...?data['collections'] as List?];

class SaavnHomePage extends StatefulWidget {
  final String activeCategory;
  const SaavnHomePage({super.key, this.activeCategory = 'All'});

  @override
  _SaavnHomePageState createState() => _SaavnHomePageState();
}

class _SaavnHomePageState extends State<SaavnHomePage>
    with AutomaticKeepAliveClientMixin<SaavnHomePage> {
  List recentList =
      Hive.box('cache').get('recentSongs', defaultValue: []) as List;
  Map likedArtists =
      Hive.box('settings').get('likedArtists', defaultValue: {}) as Map;
  List blacklistedHomeSections = Hive.box('settings')
      .get('blacklistedHomeSections', defaultValue: []) as List;
  List playlistNames =
      Hive.box('settings').get('playlistNames')?.toList() as List? ??
          ['Favorite Songs'];
  Map playlistDetails =
      Hive.box('settings').get('playlistDetails', defaultValue: {}) as Map;
  int recentIndex = 0;
  int playlistIndex = 1;

  Future<void> getHomePageData() async {
    Map recievedData = await SaavnAPI().fetchHomePageData();
    if (recievedData.isNotEmpty) {
      Hive.box('cache').put('homepage', recievedData);
      data = recievedData;
      lists = ['recent', 'playlist', ...?data['collections'] as List?];
      lists.insert((lists.length / 2).round(), 'likedArtists');
    }
    setState(() {});
    recievedData = await FormatResponse.formatPromoLists(data);
    if (recievedData.isNotEmpty) {
      Hive.box('cache').put('homepage', recievedData);
      data = recievedData;
      lists = ['recent', 'playlist', ...?data['collections'] as List?];
      lists.insert((lists.length / 2).round(), 'likedArtists');
    }
    setState(() {});
  }

  String getSubTitle(Map item) {
    final type = item['type'];
    switch (type) {
      case 'charts':
        return '';
      case 'radio_station':
        return 'Radio • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle']?.toString().unescape()}';
      case 'playlist':
        return 'Playlist • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'song':
        return 'Single • ${item['artist']?.toString().unescape()}';
      case 'mix':
        return 'Mix • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'show':
        return 'Podcast • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'album':
        final List? artistList = item['more_info']?['artistMap']?['artists'] as List?;
        final artists = artistList?.map((artist) => artist['name']).toList();
        if (artists != null) {
          return 'Album • ${artists.join(', ').toString().unescape()}';
        } else if (item['subtitle'] != null && item['subtitle'] != '') {
          return 'Album • ${item['subtitle']?.toString().unescape()}';
        }
        return 'Album';
      default:
        final List? artistList = item['more_info']?['artistMap']?['artists'] as List?;
        final artists = artistList?.map((artist) => artist['name']).toList();
        return artists?.join(', ').toString().unescape() ?? '';
    }
  }

  int likedCount() {
    return Hive.box('Favorite Songs').length;
  }

  void _playPlaylistOrAlbum(Map item) async {
    ShowSnackBar().showSnackBar(
      context,
      'Loading playlist tracks...',
      duration: const Duration(seconds: 2),
    );
    try {
      String token = item['perma_url'].toString().split('/').last;
      String type = item['type'].toString();
      Map songsMap = await SaavnAPI().getSongFromToken(token, type);
      final List? songs = songsMap['songs'] as List?;
      if (songs != null && songs.isNotEmpty) {
        PlayerInvoke.init(
          songsList: songs,
          index: 0,
          isOffline: false,
        );
        ShowSnackBar().showSnackBar(
          context,
          'Playing: ${item['title']}',
          duration: const Duration(seconds: 2),
        );
      } else {
        ShowSnackBar().showSnackBar(
          context,
          'Failed to load songs.',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      ShowSnackBar().showSnackBar(
        context,
        'Error: $e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  List _getCuratedItems() {
    final List curated = [];
    if (data['top_playlists'] != null && (data['top_playlists'] as List).isNotEmpty) {
      curated.addAll(data['top_playlists'] as List);
    }
    if (data['charts'] != null && (data['charts'] as List).isNotEmpty) {
      curated.addAll(data['charts'] as List);
    }
    if (data['new_albums'] != null && (data['new_albums'] as List).isNotEmpty) {
      curated.addAll(data['new_albums'] as List);
    }
    return curated;
  }

  Widget _buildCuratedTrendingCarousel() {
    final curatedItems = _getCuratedItems();
    if (curatedItems.isEmpty) return const SizedBox();

    final List<Map<String, dynamic>> carouselStyles = [
      {
        'bgColor': const Color(0xFFCBB6FC),
        'textColor': const Color(0xFF0F071B),
        'btnColor': const Color(0xFF45226E),
      },
      {
        'bgColor': const Color(0xFFFFD1B3),
        'textColor': const Color(0xFF2C1405),
        'btnColor': const Color(0xFF8E3E15),
      },
      {
        'bgColor': const Color(0xFFBFF6EB),
        'textColor': const Color(0xFF04241E),
        'btnColor': const Color(0xFF0D6E5C),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            'Curated & trending',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: PageController(viewportFraction: 0.9),
            itemCount: curatedItems.length,
            itemBuilder: (context, index) {
              final item = curatedItems[index] as Map;
              final style = carouselStyles[index % carouselStyles.length];
              final String title = item['title']?.toString().unescape() ?? '';
              final String subtitle = getSubTitle(item);
              final Color bgColor = style['bgColor'] as Color;
              final Color textColor = style['textColor'] as Color;
              final Color btnColor = style['btnColor'] as Color;
              final String imageUrl = getImageUrl(item['image']?.toString(), quality: 'high');

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => SongsListPage(listItem: item),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: 0,
                          top: 0,
                          width: 150,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.transparent, Colors.black],
                              ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(color: Colors.transparent),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      title,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 170,
                                    child: Text(
                                      subtitle,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _playPlaylistOrAlbum(item),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: btnColor,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(Icons.favorite_border_rounded, color: textColor.withOpacity(0.65), size: 20),
                                  const SizedBox(width: 14),
                                  Icon(Icons.download_outlined, color: textColor.withOpacity(0.65), size: 20),
                                  const SizedBox(width: 14),
                                  Icon(Icons.more_horiz_rounded, color: textColor.withOpacity(0.65), size: 20),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopDailyPlaylistsSection() {
    final curatedItems = _getCuratedItems();
    if (curatedItems.isEmpty) return const SizedBox();

    final displayedItems = curatedItems.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top daily playlists',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/playlists');
                },
                child: Text(
                  'See all',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: displayedItems.length,
          itemBuilder: (context, index) {
            final item = displayedItems[index] as Map;
            final title = item['title']?.toString().unescape() ?? 'Unknown Playlist';
            final subTitle = getSubTitle(item);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) => SongsListPage(listItem: item),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item['image'].toString(),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 64,
                          height: 64,
                          color: Colors.white.withOpacity(0.05),
                          child: const Icon(Icons.music_note, color: Colors.white30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subTitle,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _playPlaylistOrAlbum(item),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List recommendations = [];
  List oldFavorites = [];

  Future<void> fetchPersonalizedRecommendations() async {
    try {
      if (recentList.isNotEmpty) {
        final lastSong = recentList.first as Map;
        final lastSongId = lastSong['id'].toString();
        final List reco = await SaavnAPI().getReco(lastSongId);
        if (reco.isNotEmpty) {
          recommendations = reco;
          setState(() {});
        }
      } else {
        final List reco = await SaavnAPI().getReco('fHI8X4OX27U');
        if (reco.isNotEmpty) {
          recommendations = reco;
          setState(() {});
        }
      }
    } catch (e) {
      Logger.root.severe('Error in fetchPersonalizedRecommendations: $e');
    }
  }

  void getOldFavorites() {
    final box = Hive.box('Favorite Songs');
    if (box.isNotEmpty) {
      oldFavorites = box.values.toList();
    }
  }

  Widget _buildQuickplaySection() {
    final listToUse = recentList.isNotEmpty ? recentList : (data['new_trending'] as List? ?? []);
    if (listToUse.isEmpty) return const SizedBox();
    final items = listToUse.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Quickplay',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.3,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map;
              return GestureDetector(
                onTap: () {
                  PlayerInvoke.init(
                    songsList: [item],
                    index: 0,
                    isOffline: false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item['image'].toString(),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title']?.toString().unescape() ?? 'Unknown Song',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['artist']?.toString().unescape() ?? 'Unknown Artist',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyPlayedSection() {
    if (recentList.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Recently played',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recentList.length,
            itemBuilder: (context, index) {
              final item = recentList[index] as Map;
              return GestureDetector(
                onTap: () {
                  PlayerInvoke.init(
                    songsList: [item],
                    index: 0,
                    isOffline: false,
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingSongsSection() {
    final songs = data['new_trending'] as List?;
    if (songs == null || songs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Trending songs',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final item = songs[index] as Map;
              return GestureDetector(
                onTap: () {
                  PlayerInvoke.init(
                    songsList: [item],
                    index: 0,
                    isOffline: false,
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarSection() {
    if (recommendations.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Similar to your interest',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final item = recommendations[index] as Map;
              return GestureDetector(
                onTap: () {
                  PlayerInvoke.init(
                    songsList: [item],
                    index: 0,
                    isOffline: false,
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityPlaylistsSection() {
    final playlists = data['top_playlists'] as List?;
    if (playlists == null || playlists.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Trending community playlists',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final item = playlists[index] as Map;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => SongsListPage(listItem: item),
                    ),
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBiggestHitsSection() {
    final hits = data['charts'] as List?;
    if (hits == null || hits.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            "India's biggest hits",
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: hits.length,
            itemBuilder: (context, index) {
              final item = hits[index] as Map;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => SongsListPage(listItem: item),
                    ),
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFreshFindsSection() {
    final finds = data['new_albums'] as List?;
    if (finds == null || finds.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Fresh finds',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: finds.length,
            itemBuilder: (context, index) {
              final item = finds[index] as Map;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => SongsListPage(listItem: item),
                    ),
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOldFavoritesSection() {
    if (oldFavorites.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Old favorites',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: oldFavorites.length,
            itemBuilder: (context, index) {
              final item = oldFavorites[index] as Map;
              return GestureDetector(
                onTap: () {
                  PlayerInvoke.init(
                    songsList: [item],
                    index: 0,
                    isOffline: false,
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'].toString(),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString().unescape() ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _handleRefresh() async {
    setState(() {
      fetched = false;
    });
    await getHomePageData();
    await fetchPersonalizedRecommendations();
    getOldFavorites();
    setState(() {
      fetched = true;
    });
  }

  @override
  void dispose() {
    fetched = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!fetched) {
      getHomePageData();
      fetchPersonalizedRecommendations();
      getOldFavorites();
      fetched = true;
    }
    
    final bool showTrending = widget.activeCategory == 'All' || widget.activeCategory == 'Trending';
    final bool showNewRelease = widget.activeCategory == 'All' || widget.activeCategory == 'New Release';
    final bool showPersonal = widget.activeCategory == 'All';

    return (data.isEmpty && recentList.isEmpty)
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: const Color(0xFF13101C),
            color: const Color(0xFFC0EC54),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTrending) _buildCuratedTrendingCarousel().animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                  if (showTrending) _buildTopDailyPlaylistsSection().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
                  if (showPersonal) _buildRecentlyPlayedSection().animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0),
                  if (showPersonal) _buildQuickplaySection().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
                  if (showTrending) _buildTrendingSongsSection().animate().fadeIn(duration: 550.ms).slideY(begin: 0.05, end: 0),
                  if (showTrending) _buildCommunityPlaylistsSection().animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0),
                  if (showPersonal) _buildSimilarSection().animate().fadeIn(duration: 650.ms).slideY(begin: 0.05, end: 0),
                  if (showTrending) _buildBiggestHitsSection().animate().fadeIn(duration: 700.ms).slideY(begin: 0.05, end: 0),
                  if (showNewRelease) _buildFreshFindsSection().animate().fadeIn(duration: 750.ms).slideY(begin: 0.05, end: 0),
                  if (showPersonal) _buildOldFavoritesSection().animate().fadeIn(duration: 800.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }
}
