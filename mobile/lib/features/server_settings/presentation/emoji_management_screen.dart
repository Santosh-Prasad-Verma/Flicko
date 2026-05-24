import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/appwrite_storage_service.dart';
import 'package:mobile/core/config/app_config.dart';

/// Emoji data model
class _ServerEmoji {
  final String id;
  final String name;
  final String imageUrl;
  final String objectName;
  final String creatorId;
  final String? creatorUsername;
  final DateTime createdAt;

  _ServerEmoji({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.objectName,
    required this.creatorId,
    this.creatorUsername,
    required this.createdAt,
  });

  factory _ServerEmoji.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return _ServerEmoji(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['url'] as String,
      objectName: json['object_name'] as String? ?? '',
      creatorId: json['created_by'] as String,
      creatorUsername: creator?['username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Emoji Management Screen
///
/// Upload, view, and manage custom emojis for a server.
class EmojiManagementScreen extends ConsumerStatefulWidget {
  final String serverId;

  const EmojiManagementScreen({super.key, required this.serverId});

  @override
  ConsumerState<EmojiManagementScreen> createState() => _EmojiManagementScreenState();
}

class _EmojiManagementScreenState extends ConsumerState<EmojiManagementScreen> {
  final _client = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  List<_ServerEmoji> _emojis = [];

  // Upload state
  bool _showUploadSheet = false;
  bool _isUploading = false;
  String _newName = '';
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('server_emojis')
          .select('*, creator:profiles!created_by(username)')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _emojis = (response as List)
            .map((r) => _ServerEmoji.fromJson(r as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading emojis: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 128,
        maxHeight: 128,
        imageQuality: 95,
      );
      if (image == null) return;

      setState(() {
        _selectedImage = image;
        if (_newName.isEmpty) {
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

  Future<void> _uploadEmoji() async {
    if (_selectedImage == null || _newName.trim().isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final ext = _selectedImage!.name.split('.').last.toLowerCase();
      final mimeType = ext == 'gif' ? 'image/gif' : 'image/$ext';
      final fileName = 'emoji_${_newName.trim().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload via Appwrite storage
      final imageUrl = await AppwriteStorageService.instance.uploadFile(
        bucketId: AppConfig.appwriteBucketId,
        fileName: fileName,
        fileBytes: bytes,
        mimeType: mimeType,
      );

      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _client.from('server_emojis').insert({
        'server_id': widget.serverId,
        'name': _newName.trim(),
        'url': imageUrl,
        'object_name': fileName,
        'created_by': userId,
      });

      HapticFeedback.mediumImpact();

      setState(() {
        _showUploadSheet = false;
        _selectedImage = null;
        _newName = '';
      });

      await _loadEmojis();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emoji "$_newName" uploaded!'),
            backgroundColor: const Color(FlickoColors.success),
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

  Future<void> _deleteEmoji(_ServerEmoji emoji) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Emoji',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                emoji.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete "${emoji.name}"?',
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
      await _client.from('server_emojis').delete().eq('id', emoji.id);
      HapticFeedback.lightImpact();
      await _loadEmojis();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting emoji: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Emoji',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: () => setState(() => _showUploadSheet = !_showUploadSheet),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(FlickoColors.blurple)))
          : RefreshIndicator(
              onRefresh: _loadEmojis,
              color: const Color(FlickoColors.blurple),
              child: _emojis.isEmpty ? _buildEmptyState() : _buildEmojiGrid(),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_emotions_outlined,
                    size: 48, color: Color(FlickoColors.textMuted)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Emojis Yet',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload custom emojis for your server members to use.',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showUploadSheet = true),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Upload Emoji',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.blurple),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _emojis.length,
      itemBuilder: (context, index) {
        final emoji = _emojis[index];
        return _buildEmojiCard(emoji);
      },
    );
  }

  Widget _buildEmojiCard(_ServerEmoji emoji) {
    return GestureDetector(
      onLongPress: () => _deleteEmoji(emoji),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  emoji.imageUrl,
                  fit: BoxFit.contain,
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
              padding: const EdgeInsets.all(4),
              child: Text(
                ':${emoji.name}:',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              Text(
                'Upload Emoji',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(FlickoColors.textMuted).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select an image',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'PNG, 128x128px recommended',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _newName = v),
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Emoji Name',
                  labelStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  hintText: 'e.g. party_cat',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                maxLength: 30,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _showUploadSheet = false;
                        _selectedImage = null;
                        _newName = '';
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.bgTertiary),
                        foregroundColor:
                            const Color(FlickoColors.textPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedImage == null ||
                              _newName.trim().isEmpty ||
                              _isUploading)
                          ? null
                          : _uploadEmoji,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.blurple),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
