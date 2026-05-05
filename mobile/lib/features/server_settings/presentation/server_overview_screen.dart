import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/repositories/server_repository.dart';
import '../../../../data/services/appwrite_storage_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Server Overview Settings Screen
///
/// Edit server name, icon, banner, and basic settings.
/// Mirrors React Native overview.tsx
class ServerOverviewScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerOverviewScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerOverviewScreen> createState() => _ServerOverviewScreenState();
}

class _ServerOverviewScreenState extends ConsumerState<ServerOverviewScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _iconUrl;
  String? _bannerUrl;
  bool _isLoading = false;
  bool _isOwner = false;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _loadServerData();
  }

  Future<void> _loadServerData() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(serverRepositoryProvider);
      final server = await repository.getServer(widget.serverId);
      if (server != null) {
        _nameController.text = server.name;
        _descriptionController.text = server.description ?? '';
        _iconUrl = server.iconUrl;
        _bannerUrl = server.bannerUrl;
        _ownerId = server.ownerId;

        // Check ownership
        final authState = ref.read(authNotifierProvider);
        final currentUserId = authState.maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => null,
        );
        _isOwner = _ownerId == currentUserId;
      }
    } catch (e) {
      debugPrint('Error loading server data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final storage = ref.read(appwriteStorageServiceProvider);
        final result = await storage.uploadImage(File(image.path));
        setState(() => _iconUrl = result['url']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final storage = ref.read(appwriteStorageServiceProvider);
        final result = await storage.uploadImage(File(image.path));
        setState(() => _bannerUrl = result['url']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(serverRepositoryProvider);
      await repository.updateServer(widget.serverId, {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'icon': _iconUrl,
        'banner': _bannerUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Changes saved!', style: GoogleFonts.inter()),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Overview',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isOwner)
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.blurple),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server Banner
          _buildBannerSection(),
          const SizedBox(height: 24),

          // Server Icon
          _buildIconSection(),
          const SizedBox(height: 24),

          // Server Name
          _buildTextField(
            label: 'SERVER NAME',
            controller: _nameController,
            maxLength: 100,
          ),
          const SizedBox(height: 16),

          // Server Description
          _buildTextField(
            label: 'DESCRIPTION',
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 120,
            hint: 'Describe your server',
          ),
          const SizedBox(height: 32),

          // Server Stats
          _buildStatsSection(),
        ],
      ),
    );
  }

  Widget _buildBannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVER BANNER',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isOwner ? _pickBanner : null,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              image: _bannerUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _bannerUrl == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate,
                          color: Color(FlickoColors.textMuted),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Banner',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Change button
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVER ICON',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isOwner ? _pickIcon : null,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(50),
              image: _iconUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_iconUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _iconUrl == null
                ? const Center(
                    child: Icon(
                      Icons.add_a_photo,
                      color: Color(FlickoColors.textMuted),
                      size: 32,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.black26,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Minimum size: 128x128px. Recommended: 512x512px.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int? maxLength,
    int maxLines = 1,
    String? hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled && _isOwner,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
            ),
            filled: true,
            fillColor: const Color(FlickoColors.bgSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            counterStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server Stats',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Members', '42'),
          const Divider(color: Color(FlickoColors.bgTertiary)),
          _buildStatRow('Channels', '12'),
          const Divider(color: Color(FlickoColors.bgTertiary)),
          _buildStatRow('Roles', '5'),
          const Divider(color: Color(FlickoColors.bgTertiary)),
          _buildStatRow('Created', 'Apr 23, 2024'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
