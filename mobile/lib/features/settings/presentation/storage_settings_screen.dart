import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Data & Storage Settings Screen (Sleek Brutalist Black/Neon Theme)
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState
    extends ConsumerState<StorageSettingsScreen> {
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = true;
  bool _autoDownloadFiles = false;
  bool _isClearingCache = false;

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
        _autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? true;
        _autoDownloadFiles = prefs.getBool('autoDownloadFiles') ?? false;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'CLEAR CACHE',
          style: GoogleFonts.epilogue(
            color: Colors.red,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
        content: Text(
          'This will clear cached images and files managed by the app cache directory.',
          style: GoogleFonts.inter(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: _textWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isClearingCache = true);

      try {
        // Clear cached network images
        await DefaultCacheManager().emptyCache();

        // Clear temporary files
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final tempFiles = tempDir.listSync(recursive: true);
          for (final file in tempFiles) {
            try {
              if (file is File) {
                await file.delete();
              } else if (file is Directory) {
                await file.delete(recursive: true);
              }
            } catch (_) {
              // Ignore file locked or permissions issues for individual temp files
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearingCache = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeroSection(),
                      const SizedBox(height: 48),
                      _buildAutoDownloadSection(),
                      const SizedBox(height: 40),
                      _buildStorageSection(),
                      const SizedBox(height: 48),
                      _buildFooterData(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border.fromBorderSide(BorderSide(color: Colors.transparent)),
              ),
              child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'APP SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'STORAGE MANAGEMENT',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'DATA &\nSTORAGE',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 0.9,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(color: _neonGreen),
              child: Text(
                'STORAGE',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANAGE DATA USAGE',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Auto-download, cache & storage',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoDownloadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUTO-DOWNLOAD',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildAccessCard(
          title: 'IMAGES',
          subtitle: 'Auto-download images in conversations.',
          badge: 'MEDIA',
          toggleWidget: _buildHardwareToggle(_autoDownloadImages, (val) {
            setState(() => _autoDownloadImages = val);
            _saveSetting('autoDownloadImages', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'VIDEOS',
          subtitle: 'Auto-download videos on Wi-Fi.',
          badge: 'MEDIA',
          toggleWidget: _buildHardwareToggle(_autoDownloadVideos, (val) {
            setState(() => _autoDownloadVideos = val);
            _saveSetting('autoDownloadVideos', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'FILES',
          subtitle: 'Auto-download document attachments.',
          badge: 'DOCS',
          toggleWidget: _buildHardwareToggle(_autoDownloadFiles, (val) {
            setState(() => _autoDownloadFiles = val);
            _saveSetting('autoDownloadFiles', val);
          }),
        ),
      ],
    );
  }

  Widget _buildStorageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STORAGE',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        GestureDetector(
          onTap: _isClearingCache ? null : _handleClearCache,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'CLEAR CACHE',
                            style: GoogleFonts.epilogue(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'DESTRUCTIVE',
                              style: GoogleFonts.spaceMono(
                                color: Colors.red.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Free up space by clearing cached data.',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _isClearingCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _neonGreen,
                        ),
                      )
                    : Icon(Icons.delete_outline,
                        color: Colors.red.withValues(alpha: 0.6), size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          color: _neonGreen.withValues(alpha: 0.2),
          margin: const EdgeInsets.only(bottom: 24),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _neonGreen.withValues(alpha: 0.05),
            border: Border.symmetric(
              horizontal: BorderSide(color: _textWhite.withValues(alpha: 0.05)),
            ),
          ),
          child: Center(
            child: Text(
              'FLICKO // PREFERENCES SECURE',
              style: GoogleFonts.spaceMono(
                color: _textWhite.withValues(alpha: 0.3),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessCard({
    required String title,
    required String subtitle,
    required String badge,
    required Widget toggleWidget,
    bool usePrimaryBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(
          color: usePrimaryBadge
              ? _neonGreen.withValues(alpha: 0.4)
              : _textWhite.withValues(alpha: 0.05),
          width: usePrimaryBadge ? 1.5 : 1,
        ),
        boxShadow: usePrimaryBadge
            ? [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.epilogue(
                        color: _textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: usePrimaryBadge ? _neonGreen : Colors.transparent,
                        border: usePrimaryBadge
                            ? null
                            : Border.all(
                                color: _textWhite.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.spaceMono(
                          color: usePrimaryBadge
                              ? Colors.black
                              : _textWhite.withValues(alpha: 0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          toggleWidget,
        ],
      ),
    );
  }

  Widget _buildHardwareToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? _neonGreen : const Color(0xFF141416),
          border: Border.all(
            color: value ? _neonGreen : _textWhite.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 26 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? Colors.black : const Color(0xFF71717A),
                ),
                child: Center(
                  child: Container(
                    width: 2,
                    height: 8,
                    color: value
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
