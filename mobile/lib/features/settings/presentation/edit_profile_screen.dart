import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/data/services/appwrite_storage_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Edit Profile Screen
///
/// Full-screen profile editor with banner, overlapping avatar,
/// inline profile card preview, and grouped input fields.
/// Supports avatar upload, banner upload, and profile customization.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _pronounsController;

  String? _avatarUrl;
  String? _bannerUrl;
  List<String> _bannerColors = const ['#5865F2', '#3A45C3'];
  String _avatarDecoration = 'none';

  bool _isLoading = false;
  bool _hasChanges = false;

  // Banner color presets
  static final List<Map<String, dynamic>> _bannerColorPresets = [
    {'id': 'blurple', 'label': 'Blurple', 'colors': const ['#5865F2', '#3A45C3']},
    {'id': 'green', 'label': 'Green', 'colors': const ['#57F287', '#2D7D46']},
    {'id': 'yellow', 'label': 'Yellow', 'colors': const ['#FEE75C', '#D4A017']},
    {'id': 'fuchsia', 'label': 'Fuchsia', 'colors': const ['#EB459E', '#A03070']},
    {'id': 'red', 'label': 'Red', 'colors': const ['#ED4245', '#A12D2F']},
    {'id': 'white', 'label': 'White', 'colors': const ['#FFFFFF', '#D0D0D0']},
    {'id': 'black', 'label': 'Black', 'colors': const ['#23272A', '#111111']},
    {'id': 'teal', 'label': 'Teal', 'colors': const ['#1ABC9C', '#117864']},
    {'id': 'navy', 'label': 'Navy', 'colors': const ['#34495E', '#1C2833']},
    {'id': 'sunset', 'label': 'Sunset', 'colors': const ['#FF6B6B', '#FF8E53']},
    {'id': 'ocean', 'label': 'Ocean', 'colors': const ['#667EEA', '#764BA2']},
    {'id': 'forest', 'label': 'Forest', 'colors': const ['#11998E', '#38EF7D']},
    {'id': 'candy', 'label': 'Candy', 'colors': const ['#FC5C7D', '#6A82FB']},
    {'id': 'midnight', 'label': 'Midnight', 'colors': const ['#2C3E50', '#4CA1AF']},
    {'id': 'fire', 'label': 'Fire', 'colors': const ['#F12711', '#F5AF19']},
    {'id': 'lavender', 'label': 'Lavender', 'colors': const ['#C471F5', '#FA71CD']},
  ];

  // Avatar decoration presets
  static final List<Map<String, dynamic>> _avatarDecorations = [
    {'id': 'none', 'label': 'None', 'color': null},
    {'id': 'gold-ring', 'label': 'Gold Ring', 'color': '#FFD700'},
    {'id': 'blurple-ring', 'label': 'Blurple', 'color': '#5865F2'},
    {'id': 'green-glow', 'label': 'Green Glow', 'color': '#57F287'},
    {'id': 'red-ring', 'label': 'Red Ring', 'color': '#ED4245'},
    {'id': 'cyan-glow', 'label': 'Cyan', 'color': '#00CECE'},
    {'id': 'pink-ring', 'label': 'Pink', 'color': '#EB459E'},
    {'id': 'purple-ring', 'label': 'Purple', 'color': '#9B59B6'},
    {'id': 'orange-ring', 'label': 'Orange', 'color': '#E67E22'},
  ];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _pronounsController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _pronounsController.dispose();
    super.dispose();
  }

  void _initializeFromProfile(UserModel? profile) {
    if (!_hasChanges && profile != null) {
      if (_displayNameController.text.isEmpty) {
        _displayNameController.text = profile.displayName ?? profile.username;
      }
      if (_bioController.text.isEmpty) {
        _bioController.text = profile.bio ?? '';
      }
      if (_pronounsController.text.isEmpty) {
        _pronounsController.text = profile.pronouns ?? '';
      }
      _avatarUrl ??= profile.avatarUrl;
      _bannerUrl ??= profile.bannerUrl;
      if (profile.bannerColors != null && profile.bannerColors!.length >= 2) {
        _bannerColors = profile.bannerColors!;
      }
      _avatarDecoration = profile.avatarDecoration ?? 'none';
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      setState(() => _isLoading = true);
      
      try {
        final appwriteService = ref.read(appwriteStorageServiceProvider);
        
        // Debug check
        debugPrint('Appwrite configuration check: ${appwriteService.isConfigured}');
        
        if (!appwriteService.isConfigured) {
          throw Exception('Media storage is not properly configured. Please check your Appwrite Project ID and Bucket ID.');
        }

        final file = File(picked.path);
        debugPrint('Uploading avatar file: ${file.path}, size: ${await file.length()} bytes');
        
        final result = await appwriteService.uploadImage(file);
        final uploadedUrl = result['url'];
        debugPrint('Avatar upload successful: $uploadedUrl');

        setState(() {
          _avatarUrl = uploadedUrl;
          _hasChanges = true;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Avatar upload error details: $e');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload avatar: $e'),
              backgroundColor: const Color(FlickoColors.danger),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      setState(() => _isLoading = true);
      
      try {
        final appwriteService = ref.read(appwriteStorageServiceProvider);
        if (!appwriteService.isConfigured) {
          throw Exception('Appwrite not configured');
        }

        final file = File(picked.path);
        final result = await appwriteService.uploadImage(file);
        final uploadedUrl = result['url'];

        setState(() {
          _bannerUrl = uploadedUrl;
          _hasChanges = true;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload banner: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateProfile(user.id, {
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'pronouns': _pronounsController.text.trim(),
        'avatar': _avatarUrl,
        'banner': _bannerUrl,
        'banner_colors': _bannerColors,
        'avatar_decoration': _avatarDecoration,
      });

      // Refresh auth state to get updated profile
      ref.invalidate(authNotifierProvider);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save profile: $e',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onFieldChanged() {
    setState(() => _hasChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return authState.maybeWhen(
      authenticated: (user, profile) {
        _initializeFromProfile(profile);
        return _buildScreen(context, profile);
      },
      orElse: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, UserModel? profile) {
    final displayName = _displayNameController.text.isNotEmpty
        ? _displayNameController.text
        : profile?.username ?? 'User';

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _hasChanges ? _saveProfile : null,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: _hasChanges
                      ? const Color(FlickoColors.blurple)
                      : const Color(FlickoColors.textMuted),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Section
          _buildBannerSection(),
          const SizedBox(height: 16),

          // Profile Card Preview
          _buildProfilePreview(displayName, profile?.username ?? 'user'),
          const SizedBox(height: 24),

          // Input Fields
          _buildSectionHeader('DISPLAY NAME'),
          _buildTextField(
            controller: _displayNameController,
            hintText: 'What should people call you?',
            maxLength: 32,
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('PRONOUNS'),
          _buildTextField(
            controller: _pronounsController,
            hintText: 'Add your pronouns',
            maxLength: 20,
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('ABOUT ME'),
          _buildTextField(
            controller: _bioController,
            hintText: 'Tell the world about yourself',
            maxLength: 190,
            maxLines: 4,
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: 24),

          // Avatar Decoration
          _buildSectionHeader('AVATAR DECORATION'),
          _buildAvatarDecorationPicker(),
          const SizedBox(height: 24),

          // Banner Color
          _buildSectionHeader('BANNER COLOR'),
          _buildBannerColorPicker(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBannerSection() {
    return SizedBox(
      height: 180, // Banner (120) + Avatar overlap (50) + padding
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          GestureDetector(
            onTap: _pickBanner,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _bannerUrl == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(int.parse(_bannerColors[0].replaceFirst('#', '0xFF'))),
                          Color(int.parse(_bannerColors[1].replaceFirst('#', '0xFF'))),
                        ],
                      )
                    : null,
                image: _bannerUrl != null
                    ? DecorationImage(
                        image: _bannerUrl!.startsWith('http')
                            ? NetworkImage(_bannerUrl!) as ImageProvider
                            : FileImage(File(_bannerUrl!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Change Banner',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Change Avatar Button
          Positioned(
            left: 16,
            bottom: 10, // Adjusted to be fully within the 180 height (120 banner - overlapping)
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(FlickoColors.bgPrimary),
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildAvatarImage(88),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.blurple),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(FlickoColors.bgPrimary),
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePreview(String displayName, String username) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: _avatarDecoration != 'none'
                      ? Border.all(
                          color: Color(int.parse(
                            (_avatarDecorations.firstWhere(
                              (d) => d['id'] == _avatarDecoration,
                              orElse: () => {'color': '#5865F2'},
                            )['color'] as String).replaceFirst('#', '0xFF'),
                          )),
                          width: 3,
                        )
                      : null,
                ),
                child: ClipOval(
                  child: _buildAvatarImage(48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 14,
                      ),
                    ),
                    if (_pronounsController.text.isNotEmpty)
                      Text(
                        _pronounsController.text,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_bioController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _bioController.text,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int? maxLength,
    int? maxLines,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines ?? 1,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        color: const Color(FlickoColors.textPrimary),
      ),
      decoration: InputDecoration(
        hintText: hintText,
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
    );
  }

  Widget _buildAvatarDecorationPicker() {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _avatarDecorations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final decoration = _avatarDecorations[index];
          final isSelected = _avatarDecoration == decoration['id'];
          final color = decoration['color'] != null
              ? Color(int.parse((decoration['color'] as String).replaceFirst('#', '0xFF')))
              : null;

          return GestureDetector(
            onTap: () {
              setState(() {
                _avatarDecoration = decoration['id'] as String;
                _hasChanges = true;
              });
            },
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(FlickoColors.blurple), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (color != null)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 3),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(FlickoColors.textSecondary),
                      ),
                    )
                  else
                    const Icon(
                      Icons.person,
                      size: 32,
                      color: Color(FlickoColors.textSecondary),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    decoration['label'] as String,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerColorPicker() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bannerColorPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = _bannerColorPresets[index];
          final isSelected = _bannerColors[0] == (preset['colors'] as List<String>)[0];
          final colors = preset['colors'] as List<String>;

          return GestureDetector(
            onTap: () {
              setState(() {
                _bannerColors = colors;
                _hasChanges = true;
              });
            },
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(FlickoColors.blurple), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(int.parse(colors[0].replaceFirst('#', '0xFF'))),
                          Color(int.parse(colors[1].replaceFirst('#', '0xFF'))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset['label'] as String,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarImage(double size) {
    if (_avatarUrl == null) {
      return Container(
        width: size,
        height: size,
        color: const Color(FlickoColors.blurple),
        child: Icon(Icons.person, size: size * 0.5, color: Colors.white),
      );
    }

    final imageProvider = _avatarUrl!.startsWith('http')
        ? NetworkImage(_avatarUrl!) as ImageProvider
        : FileImage(File(_avatarUrl!));

    return Image(
      image: imageProvider,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: const Color(FlickoColors.blurple),
        child: Icon(Icons.person, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}
