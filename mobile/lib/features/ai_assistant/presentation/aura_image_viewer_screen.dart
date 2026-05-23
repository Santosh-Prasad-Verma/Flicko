import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AuraImageViewerScreen extends StatefulWidget {
  final String imageUrl;

  const AuraImageViewerScreen({super.key, required this.imageUrl});

  @override
  State<AuraImageViewerScreen> createState() => _AuraImageViewerScreenState();
}

class _AuraImageViewerScreenState extends State<AuraImageViewerScreen> {
  ColorFilter? _activeFilter;
  String _activeFilterName = 'Original';
  bool _isDownloading = false;

  static const Color _bgBlack = Color(0xFF000000);
  static const Color _cardGrey = Color(0xFF111115);
  static const Color _borderGrey = Color(0xFF222228);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF8E8E93);
  static const Color _accentPink = Color(0xFFFF007F);

  // Creative visual matrices for ColorFiltered
  final Map<String, ColorFilter> _filters = {
    'Original': const ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]),
    'Cyberpunk': const ColorFilter.matrix([
      1.2, 0.1, 0.3, 0.0, 30,
      0.1, 0.8, 0.8, 0.0, -10,
      0.5, 0.1, 1.4, 0.0, 40,
      0.0, 0.0, 0.0, 1.0, 0,
    ]),
    'Emerald Matrix': const ColorFilter.matrix([
      0.3, 0.0, 0.0, 0.0, 0,
      0.0, 1.3, 0.0, 0.0, 30,
      0.0, 0.0, 0.3, 0.0, 0,
      0.0, 0.0, 0.0, 1.0, 0,
    ]),
    'Monochrome Noir': const ColorFilter.matrix([
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0,      0,      0,      1, 0,
    ]),
    'Retro Sepia': const ColorFilter.matrix([
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0,     0,     0,     1, 0,
    ]),
  };

  Future<void> _downloadAndSaveImage() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/aura_saved_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await dio.download(widget.imageUrl, path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image downloaded successfully to temporary storage:\n$path',
              style: GoogleFonts.spaceMono(fontSize: 11),
            ),
            backgroundColor: _accentPink,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _shareImage() async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/share_image.jpg';
      
      await dio.download(widget.imageUrl, path);
      
      final xFile = XFile(path);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Created using Aura AI Assistant',
          files: [xFile],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: AppBar(
        backgroundColor: _bgBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textWhite),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'IMAGE VIEWER & FILTERS',
          style: GoogleFonts.spaceGrotesk(
            color: _textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderGrey, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.5,
                child: ColorFiltered(
                  colorFilter: _activeFilter ?? _filters['Original']!,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: _accentPink));
                    },
                  ),
                ),
              ),
            ),
          ),
          _buildFilterToolbar(),
          _buildActionToolbar(),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _cardGrey,
        border: Border(
          top: BorderSide(color: _borderGrey),
          bottom: BorderSide(color: _borderGrey),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: _filters.keys.map((filterName) {
          final isSelected = _activeFilterName == filterName;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeFilterName = filterName;
                _activeFilter = _filters[filterName];
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? _accentPink.withValues(alpha: 0.12) : Colors.black,
                border: Border.all(
                  color: isSelected ? _accentPink : _borderGrey,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  filterName,
                  style: GoogleFonts.spaceGrotesk(
                    color: isSelected ? Colors.white : _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      color: _bgBlack,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            _isDownloading ? Icons.sync_rounded : Icons.save_alt_rounded,
            'SAVE',
            _isDownloading ? null : _downloadAndSaveImage,
          ),
          _buildActionButton(
            Icons.share_rounded,
            'SHARE',
            _shareImage,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _cardGrey,
            border: Border.all(color: _borderGrey),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, color: _textWhite, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: _textWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
