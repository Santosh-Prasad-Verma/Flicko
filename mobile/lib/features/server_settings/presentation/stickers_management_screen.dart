import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import '../../../../data/services/appwrite_storage_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Sticker data model
class _ServerSticker {
  final String id;
  final String name;
  final String? description;
  final String imageUrl;
  final String? appwriteFileId;
  final String? appwriteBucketId;
  final String? tags;
  final String creatorId;
  final String? creatorUsername;
  final DateTime createdAt;

  _ServerSticker({
    required this.id,
    required this.name,
    this.description,
    required this.imageUrl,
    this.appwriteFileId,
    this.appwriteBucketId,
    this.tags,
    required this.creatorId,
    this.creatorUsername,
    required this.createdAt,
  });

  factory _ServerSticker.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return _ServerSticker(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      appwriteFileId: json['appwrite_file_id'] as String?,
      appwriteBucketId: json['appwrite_bucket_id'] as String?,
      tags: json['tags'] as String?,
      creatorId: json['creator_id'] as String,
      creatorUsername: creator?['username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Sticker Management Screen
///
/// Upload, view, and manage custom stickers for a server.
/// Replaces the placeholder `StickersSettingsScreen`.
/// Matches `mobile/app/server/[serverId]/settings/stickers.tsx`.
class StickersManagementScreen extends ConsumerStatefulWidget {
  final String serverId;

  const StickersManagementScreen({super.key, required this.serverId});

  @override
  ConsumerState<StickersManagementScreen> createState() =>
      _StickersManagementScreenState();
}

class _StickersManagementScreenState
    extends ConsumerState<StickersManagementScreen> {
  final _client = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  List<_ServerSticker> _stickers = [];

  // Upload state
  bool _showUploadSheet = false;
  bool _isUploading = false;
  String _newName = '';
  String _newDescription = '';
  String _newTag = '';
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('stickers')
          .select('*, creator:profiles!creator_id(username)')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _stickers = (response as List)
            .map((r) => _ServerSticker.fromJson(r as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stickers: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 95,
      );
      if (image == null) return;

      setState(() {
        _selectedImage = image;
        if (_newName.isEmpty) {
          // Auto-fill name from filename
          final fileName =
              image.name.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_ ]'), '');
          _newName = fileName.length > 30 ? fileName.substring(0, 30) : fileName;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadSticker() async {
    if (_selectedImage == null || _newName.trim().isEmpty) return;

    setState(() => _isUploading = true);
    try {
      // Upload via Appwrite storage
      final appwriteService = ref.read(appwriteStorageServiceProvider);
      final result = await appwriteService.uploadImage(
        File(_selectedImage!.path),
      );

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      await _client.from('stickers').insert({
        'server_id': widget.serverId,
        'name': _newName.trim(),
        'description': _newDescription.trim().isEmpty ? null : _newDescription.trim(),
        'image_url': result['url'],
        'appwrite_file_id': result['fileId'],
        'appwrite_bucket_id': result['bucketId'],
        'tags': _newTag.trim().isEmpty ? null : _newTag.trim(),
        'creator_id': userId,
      });

      HapticFeedback.mediumImpact();

      setState(() {
        _showUploadSheet = false;
        _selectedImage = null;
        _newName = '';
        _newDescription = '';
        _newTag = '';
      });

      await _loadStickers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sticker "$_newName" uploaded!'),
            backgroundColor: const Color(FlickoColors.green),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteSticker(_ServerSticker sticker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Sticker',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(FlickoRadius.md),
              child: Image.network(
                sticker.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: FlickoSpacing.md),
            Text(
              'Are you sure you want to delete "${sticker.name}"?',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.red)),
            child: Text('Delete',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('stickers').delete().eq('id', sticker.id);
      HapticFeedback.lightImpact();
      await _loadStickers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting sticker: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Stickers',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: () =>
                setState(() => _showUploadSheet = !_showUploadSheet),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(FlickoColors.blurple)))
          : RefreshIndicator(
              onRefresh: _loadStickers,
              color: const Color(FlickoColors.blurple),
              child: _stickers.isEmpty
                  ? _buildEmptyState()
                  : _buildStickerGrid(),
            ),
      bottomSheet: _showUploadSheet ? _buildUploadSheet() : null,
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(FlickoSpacing.xl),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image_outlined,
                    size: 48, color: Color(FlickoColors.textMuted)),
              ),
              const SizedBox(height: FlickoSpacing.lg),
              Text(
                'No Stickers Yet',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: FlickoSpacing.sm),
              Text(
                'Upload custom stickers for your server members to use.',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FlickoSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showUploadSheet = true),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Upload Sticker',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.blurple),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FlickoSpacing.xl,
                    vertical: FlickoSpacing.sm + 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(FlickoSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: FlickoSpacing.sm,
        mainAxisSpacing: FlickoSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemCount: _stickers.length,
      itemBuilder: (context, index) {
        final sticker = _stickers[index];
        return _buildStickerCard(sticker);
      },
    );
  }

  Widget _buildStickerCard(_ServerSticker sticker) {
    return GestureDetector(
      onLongPress: () => _deleteSticker(sticker),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(FlickoRadius.lg),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(FlickoRadius.lg)),
                child: Image.network(
                  sticker.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(FlickoColors.bgTertiary),
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Color(FlickoColors.textMuted), size: 24),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FlickoSpacing.sm),
              child: Column(
                children: [
                  Text(
                    sticker.name,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sticker.creatorUsername != null
                        ? 'by ${sticker.creatorUsername}'
                        : _timeAgo(sticker.createdAt),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSheet() {
    return Container(
      padding: const EdgeInsets.all(FlickoSpacing.xl),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.textMuted).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: FlickoSpacing.lg),

              Text(
                'Upload Sticker',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: FlickoSpacing.md),

              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    borderRadius: BorderRadius.circular(FlickoRadius.lg),
                    border: Border.all(
                      color: const Color(FlickoColors.textMuted).withValues(alpha: 0.3),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(FlickoRadius.lg),
                          child: Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.contain,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined,
                                color: Color(FlickoColors.blurple), size: 36),
                            const SizedBox(height: FlickoSpacing.sm),
                            Text(
                              'Tap to select an image',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'PNG, JPEG, GIF (max 320×320)',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: FlickoSpacing.md),

              // Sticker name
              TextField(
                onChanged: (v) => setState(() => _newName = v),
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Sticker Name',
                  labelStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  hintText: 'e.g. party_cat',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: FlickoSpacing.md, vertical: FlickoSpacing.sm),
                ),
                maxLength: 30,
              ),

              // Description
              TextField(
                onChanged: (v) => setState(() => _newDescription = v),
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  hintText: 'Describe this sticker',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: FlickoSpacing.md, vertical: FlickoSpacing.sm),
                ),
                maxLength: 100,
              ),

              // Tag
              TextField(
                onChanged: (v) => setState(() => _newTag = v),
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Related Emoji/Tag (optional)',
                  labelStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  hintText: '😺 or :party_cat:',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: FlickoSpacing.md, vertical: FlickoSpacing.sm),
                ),
                maxLength: 30,
              ),

              const SizedBox(height: FlickoSpacing.md),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _showUploadSheet = false;
                        _selectedImage = null;
                        _newName = '';
                        _newDescription = '';
                        _newTag = '';
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.bgTertiary),
                        foregroundColor:
                            const Color(FlickoColors.textPrimary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter()),
                    ),
                  ),
                  const SizedBox(width: FlickoSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedImage == null ||
                              _newName.trim().isEmpty ||
                              _isUploading)
                          ? null
                          : _uploadSticker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.blurple),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor:
                            const Color(FlickoColors.bgTertiary),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Upload',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
