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


import 'package:mobile/features/sonic_music/Screens/Home/saavn.dart';
import 'package:mobile/features/sonic_music/Screens/Search/search.dart';
import 'package:mobile/features/sonic_music/Screens/Library/liked.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String _activeCategory = 'All';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildOutlinedHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildCategoryPill(String label, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC0EC54) : const Color(0xFF13101C),
          borderRadius: BorderRadius.circular(30),
          border: isActive
              ? null
              : Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: isActive ? const Color(0xFF07040A) : Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool rotated = MediaQuery.sizeOf(context).height < screenWidth;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07040A),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF381559).withOpacity(0.35),
            const Color(0xFF07040A),
            const Color(0xFF07040A),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            NestedScrollView(
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              headerSliverBuilder: (
                BuildContext context,
                bool innerBoxScrolled,
              ) {
                return <Widget>[
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final authState = ref.watch(authNotifierProvider);
                        final profileName = authState.maybeWhen(
                          authenticated: (user, profile) => profile?.displayName ?? profile?.username,
                          orElse: () => null,
                        );
                        final avatarUrl = authState.maybeWhen(
                          authenticated: (user, profile) => profile?.avatarUrl,
                          orElse: () => null,
                        );
                        final String displayName = profileName ?? (Hive.box('settings').get('name')?.toString() ?? 'Guest');
                        final String firstWordName = displayName.split(' ')[0];

                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Avatar & outlined search/heart
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                   GestureDetector(
                                     onTap: () {
                                       Scaffold.of(context).openDrawer();
                                     },
                                     child: Container(
                                       width: 42,
                                       height: 42,
                                       decoration: BoxDecoration(
                                         shape: BoxShape.circle,
                                         color: Colors.white.withOpacity(0.04),
                                         border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
                                       ),
                                       child: const Icon(
                                         Icons.menu_rounded,
                                         color: Colors.white,
                                         size: 22,
                                       ),
                                     ),
                                   ),
                                  Row(
                                    children: [
                                      _buildOutlinedHeaderButton(
                                        icon: CupertinoIcons.search,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const SearchPage(
                                              query: '',
                                              fromHome: true,
                                              autofocus: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildOutlinedHeaderButton(
                                        icon: CupertinoIcons.heart,
                                        onTap: () async {
                                          await Hive.openBox('Favorite Songs');
                                          if (context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const LikedSongs(
                                                  playlistName: 'Favorite Songs',
                                                  showName: 'Favorite Songs',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Hi, User
                              Text(
                                'Hi, $firstWordName',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 32,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Categories horizontal scrolling pills
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildCategoryPill(
                                      'All',
                                      isActive: _activeCategory == 'All',
                                      onTap: () => setState(() => _activeCategory = 'All'),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildCategoryPill(
                                      'New Release',
                                      isActive: _activeCategory == 'New Release',
                                      onTap: () => setState(() => _activeCategory = 'New Release'),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildCategoryPill(
                                      'Trending',
                                      isActive: _activeCategory == 'Trending',
                                      onTap: () => setState(() => _activeCategory = 'Trending'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ];
              },
              body: SaavnHomePage(activeCategory: _activeCategory),
            ),

          ],
        ),
      ),
    );
  }
}
