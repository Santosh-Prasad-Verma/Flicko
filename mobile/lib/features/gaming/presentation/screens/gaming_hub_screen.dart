import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class GamingHubScreen extends StatelessWidget {
  const GamingHubScreen({super.key});

  static const Color _neon = Color(0xFF52B788);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _white.withValues(alpha: 0.1), height: 1.0),
        ),
        title: Text(
          'GAMING HUB',
          style: GoogleFonts.epilogue(
            color: _white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _white),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: _neon),
              ),
              child: const Icon(Icons.person, size: 18, color: _neon),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              ActivityCard(
                title: 'CHESS',
                tag: 'STRATEGIC',
                tagColor: _neon,
                description: 'Engage in classic tactical warfare. Sharpen your mind with real-time multiplayer Chess and test yourself against expert bots.',
                imageUrl: 'https://images.unsplash.com/photo-1529692236671-f1f6e9460272?q=80&w=500&auto=format&fit=crop',
                onTap: () => context.push('/gaming/matchmaking?activity=Chess'),
              ),
              const SizedBox(height: 24),
              ActivityCard(
                title: 'POKER',
                tag: 'CARD GAME',
                tagColor: const Color(0xFFFFCDD2),
                description: 'High stakes and bluffing. Join lobbies of varying skill levels, invite real friends, or practice with smart AI players.',
                imageUrl: 'https://images.unsplash.com/photo-1511193311914-0346f16efe90?q=80&w=500&auto=format&fit=crop',
                onTap: () => context.push('/gaming/matchmaking?activity=Poker'),
              ),
              const SizedBox(height: 24),
              ActivityCard(
                title: 'DRAWING',
                tag: 'CREATIVE',
                tagColor: const Color(0xFFE0E0E0),
                description: 'Unleash your creativity in collaborative canvas sessions. Match up with random artists or create custom rooms.',
                imageUrl: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=500&auto=format&fit=crop',
                onTap: () => context.push('/gaming/matchmaking?activity=Drawing'),
              ),
              const SizedBox(height: 100), // Bottom padding for the button
            ],
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => context.push('/gaming/matchmaking?activity=Chess'),
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: _neon,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'QUICK START ACTIVITY',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
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

class ActivityCard extends StatelessWidget {
  final String title;
  final String tag;
  final Color tagColor;
  final String description;
  final String imageUrl;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.description,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0E),
          border: Border.all(
            color: const Color(0xFFFBF9FA).withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFFFBF9FA).withValues(alpha: 0.1))),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.2),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.videogame_asset_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.epilogue(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFFBF9FA),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.1),
                          border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: tagColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF71717A),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
