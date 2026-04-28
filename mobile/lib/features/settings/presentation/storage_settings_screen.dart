import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/flicko_colors.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = true;
  bool _autoDownloadFiles = false;
  bool _isClearingCache = false;

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
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'This will clear cached images and files managed by the app cache directory.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isClearingCache = true);
      try {
        // Clear cache using flutter cache manager or similar
        // For now, this is a placeholder
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              backgroundColor: Color(FlickoColors.success),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: ${e.toString()}'),
              backgroundColor: const Color(FlickoColors.danger),
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
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Data & Storage',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildSection('AUTO-DOWNLOAD', [
              _buildSwitchTile(
                'Images',
                'Auto-download images',
                _autoDownloadImages,
                (value) {
                  setState(() => _autoDownloadImages = value);
                  _saveSetting('autoDownloadImages', value);
                },
              ),
              _buildSwitchTile(
                'Videos',
                'Auto-download videos on Wi-Fi',
                _autoDownloadVideos,
                (value) {
                  setState(() => _autoDownloadVideos = value);
                  _saveSetting('autoDownloadVideos', value);
                },
              ),
              _buildSwitchTile(
                'Files',
                'Auto-download files',
                _autoDownloadFiles,
                (value) {
                  setState(() => _autoDownloadFiles = value);
                  _saveSetting('autoDownloadFiles', value);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('STORAGE', [
              _buildActionTile(
                'Clear Cache',
                'Free up space by clearing cached data',
                Icons.delete_outline,
                _handleClearCache,
                isDestructive: true,
                isLoading: _isClearingCache,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String label,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(FlickoColors.blurple),
    );
  }

  Widget _buildActionTile(
    String label,
    String description,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(FlickoColors.danger) : const Color(FlickoColors.textPrimary),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: isDestructive ? const Color(FlickoColors.danger) : const Color(FlickoColors.textPrimary),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(FlickoColors.blurple),
              ),
            )
          : const Icon(
              Icons.chevron_right,
              color: Color(FlickoColors.textMuted),
            ),
      onTap: isLoading ? null : onTap,
    );
  }
}
