import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Edit Profile Screen - Dark Brutalist Premium Style
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
  List<String> _bannerColors = const ['#C8FF00', '#0A0A0A'];
  String _avatarDecoration = 'none';
  bool _isLoading = false;
  bool _hasChanges = false;

  static final List<Map<String, dynamic>> _bannerColorPresets = [
    {
      'id': 'lime',
      'label': 'Lime',
      'colors': const ['#C8FF00', '#0A0A0A']
    },
    {
      'id': 'blurple',
      'label': 'Blurple',
      'colors': const ['#5865F2', '#3A45C3']
    },
    {
      'id': 'green',
      'label': 'Green',
      'colors': const ['#57F287', '#2D7D46']
    },
    {
      'id': 'yellow',
      'label': 'Yellow',
      'colors': const ['#FEE75C', '#D4A017']
    },
    {
      'id': 'fuchsia',
      'label': 'Fuchsia',
      'colors': const ['#EB459E', '#A03070']
    },
    {
      'id': 'red',
      'label': 'Red',
      'colors': const ['#ED4245', '#A12D2F']
    },
    {
      'id': 'white',
      'label': 'White',
      'colors': const ['#FFFFFF', '#D0D0D0']
    },
    {
      'id': 'black',
      'label': 'Black',
      'colors': const ['#23272A', '#111111']
    },
    {
      'id': 'teal',
      'label': 'Teal',
      'colors': const ['#1ABC9C', '#117864']
    },
    {
      'id': 'navy',
      'label': 'Navy',
      'colors': const ['#34495E', '#1C2833']
    },
    {
      'id': 'sunset',
      'label': 'Sunset',
      'colors': const ['#FF6B6B', '#FF8E53']
    },
    {
      'id': 'ocean',
      'label': 'Ocean',
      'colors': const ['#667EEA', '#764BA2']
    },
    {
      'id': 'forest',
      'label': 'Forest',
      'colors': const ['#11998E', '#38EF7D']
    },
    {
      'id': 'candy',
      'label': 'Candy',
      'colors': const ['#FC5C7D', '#6A82FB']
    },
    {
      'id': 'midnight',
      'label': 'Midnight',
      'colors': const ['#2C3E50', '#4CA1AF']
    },
    {
      'id': 'fire',
      'label': 'Fire',
      'colors': const ['#F12711', '#F5AF19']
    },
    {
      'id': 'lavender',
      'label': 'Lavender',
      'colors': const ['#C471F5', '#FA71CD']
    },
  ];

  static final List<Map<String, dynamic>> _avatarDecorations = [
    {'id': 'none', 'label': 'None', 'color': null},
    {'id': 'neon-ring', 'label': 'Neon Ring', 'color': '#C8FF00'},
    {'id': 'verified', 'label': 'Verified', 'color': '#FFFFFF'},
    {'id': 'glow-fx', 'label': 'Glow FX', 'color': '#57F287'},
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
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _isLoading = true);
    try {
      final appwriteService = ref.read(appwriteStorageServiceProvider);
      final url = await appwriteService.uploadAttachment(
          File(picked.path), 'avatar', 'profile');
      setState(() {
        _avatarUrl = url;
        _hasChanges = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload avatar: $e'),
              backgroundColor: const Color(FlickoColors.danger)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _isLoading = true);
    try {
      final appwriteService = ref.read(appwriteStorageServiceProvider);
      final url = await appwriteService.uploadAttachment(
          File(picked.path), 'banner', 'profile');
      setState(() {
        _bannerUrl = url;
        _hasChanges = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload banner: $e'),
              backgroundColor: const Color(FlickoColors.danger)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.maybeWhen(
        authenticated: (user, _) => user, orElse: () => null);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateProfile(user.id, {
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'pronouns': _pronounsController.text.trim(),
        'avatar_url': _avatarUrl,
        'banner_url': _bannerUrl,
        'banner_colors': _bannerColors,
        'avatar_decoration': _avatarDecoration,
      });
      ref.read(authNotifierProvider.notifier).refreshProfile();
      if (mounted) {
        if (context.canPop())
          context.pop();
        else
          context.go('/profile/settings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: const Color(FlickoColors.danger)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFieldChanged() => setState(() => _hasChanges = true);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    return authState.maybeWhen(
      authenticated: (user, profile) {
        _initializeFromProfile(profile);
        return _buildScreen(context, profile);
      },
      orElse: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  Widget _buildScreen(BuildContext context, UserModel? profile) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          height: 80 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top, left: 16, right: 16),
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(bottom: BorderSide(color: Colors.white, width: 4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/profile/settings'),
              ),
              Text(
                'EDIT PROFILE',
                style: GoogleFonts.epilogue(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              _buildBannerAndAvatarSection(profile),
              const SizedBox(height: 24),
              _buildSectionHeader('CREDENTIALS'),
              const SizedBox(height: 12),
              _buildSectionLabel('DISPLAY NAME'),
              _buildTextField(
                controller: _displayNameController,
                hintText: 'Add custom display name...',
                maxLength: 32,
                onChanged: (_) => _onFieldChanged(),
              ),
              const SizedBox(height: 20),
              _buildSectionLabel('USERNAME'),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(color: const Color(0xFF333333), width: 4),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '@${profile?.username.toUpperCase() ?? "USER"}',
                        style: GoogleFonts.epilogue(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC8FF00),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x80C8FF00),
                              blurRadius: 15,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionLabel('ABOUT ME'),
              _buildTextField(
                controller: _bioController,
                hintText: 'Enter a short bio...',
                maxLength: 190,
                maxLines: 4,
                onChanged: (_) => _onFieldChanged(),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('AVATAR_DECORATION'),
              _buildAvatarDecorationPicker(),
              const SizedBox(height: 32),
              _buildSectionHeader('BANNER_COLOR'),
              _buildBannerColorPicker(),
              const SizedBox(height: 32),
              _buildSectionHeader('LOCATION'),
              Container(
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.white, width: 4)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFC8FF00), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pronounsController,
                        onChanged: (_) => _onFieldChanged(),
                        style: GoogleFonts.epilogue(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add your location...',
                          hintStyle: GoogleFonts.epilogue(
                              color: Colors.white.withValues(alpha: 0.2)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('NETWORK LINKS'),
              _buildLinkCard('PERSONAL WEBSITE', Icons.language),
              const SizedBox(height: 12),
              _buildLinkCard('SOCIAL PROFILE', Icons.terminal),
              const SizedBox(height: 40),
              _buildFooter(),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                  color: Color(0xFFC8FF00), backgroundColor: Colors.black),
            ),
        ],
      ),
      floatingActionButton: _hasChanges && !_isLoading
          ? FloatingActionButton(
              onPressed: _saveProfile,
              backgroundColor: const Color(0xFFC8FF00),
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.check, color: Colors.black, size: 36),
            )
          : null,
    );
  }

  Widget _buildBannerAndAvatarSection(UserModel? profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Personalize your identity across Flicko'.toUpperCase(),
            style: GoogleFonts.epilogue(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 160,
                child: GestureDetector(
                  onTap: _pickBanner,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _bannerUrl == null
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(int.parse(_bannerColors[0]
                                          .replaceFirst('#', '0xFF'))),
                                      Color(int.parse(_bannerColors[1]
                                          .replaceFirst('#', '0xFF'))),
                                    ],
                                  ),
                                ),
                              )
                            : _bannerUrl!.startsWith('http')
                                ? Image.network(_bannerUrl!, fit: BoxFit.cover)
                                : Image.file(File(_bannerUrl!),
                                    fit: BoxFit.cover),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'CHANGE BANNER',
                                  style: GoogleFonts.epilogue(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
              ),
              Positioned(
                top: 100,
                left: 16,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFFC8FF00), offset: Offset(6, 6))
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildAvatarImage(110),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color:
                                const Color(0xFFC8FF00).withValues(alpha: 0.85),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.black, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.epilogue(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFC8FF00),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
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
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        counterStyle:
            GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2)),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF333333), width: 4),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF333333), width: 4),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFC8FF00), width: 4),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  Widget _buildAvatarDecorationPicker() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _avatarDecorations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final decoration = _avatarDecorations[index];
          final isSelected = _avatarDecoration == decoration['id'];
          final color = decoration['color'] != null
              ? Color(int.parse(
                  (decoration['color'] as String).replaceFirst('#', '0xFF')))
              : null;
          return GestureDetector(
            onTap: () => setState(() {
              _avatarDecoration = decoration['id'] as String;
              _hasChanges = true;
            }),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC8FF00)
                      : const Color(0xFF333333),
                  width: isSelected ? 4 : 2,
                ),
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
                          border: Border.all(color: color, width: 3)),
                      child: const Icon(Icons.person,
                          size: 16, color: Colors.white),
                    )
                  else
                    const Icon(Icons.person, size: 32, color: Colors.white),
                  const SizedBox(height: 6),
                  Text(
                    (decoration['label'] as String).toUpperCase(),
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? const Color(0xFFC8FF00)
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _bannerColorPresets.length.clamp(0, 8),
      itemBuilder: (context, index) {
        final preset = _bannerColorPresets[index];
        final colors = preset['colors'] as List<String>;
        final isSelected = _bannerColors[0] == colors[0];
        return GestureDetector(
          onTap: () => setState(() {
            _bannerColors = colors;
            _hasChanges = true;
          }),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(int.parse(colors[0].replaceFirst('#', '0xFF'))),
                  Color(int.parse(colors[1].replaceFirst('#', '0xFF'))),
                ],
              ),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFF333333),
                width: isSelected ? 4 : 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkCard(String title, IconData icon) {
    return InkWell(
      onTap: () => _showLinkEditDialog(title),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: const Color(0xFF333333), width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  color: Colors.white,
                  child: Icon(icon, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.epilogue(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFFC8FF00), size: 16),
          ],
        ),
      ),
    );
  }

  void _showLinkEditDialog(String title) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white, width: 4),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'UPDATE $title',
          style: GoogleFonts.epilogue(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter URL below:',
              style: GoogleFonts.inter(
                  color: const Color(0xFFC8FF00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFFC8FF00),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.black,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF333333), width: 4),
                  borderRadius: BorderRadius.zero,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF333333), width: 4),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFC8FF00), width: 4),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL',
                style: GoogleFonts.epilogue(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('$title updated!', style: GoogleFonts.inter()),
                    backgroundColor: const Color(FlickoColors.success)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC8FF00),
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.white, width: 2),
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Text('SAVE',
                style: GoogleFonts.epilogue(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white, width: 2))),
      padding: const EdgeInsets.only(top: 24, bottom: 60),
      child: Text(
        'SYSTEM VERSION: FLICKO_E.44.02\nENCRYPTION: 256-BIT_PRO_ACTIVE\nIDENTITY_STATUS: ELITE_SECURED',
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildAvatarImage(double size) {
    if (_avatarUrl == null) {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFF0A0A0A),
        child: Icon(Icons.person,
            size: size * 0.4, color: Colors.white.withValues(alpha: 0.5)),
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
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: const Color(0xFF0A0A0A),
        child: Icon(Icons.person,
            size: size * 0.4, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}
