import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/data/services/appwrite_storage_service.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Server Overview Settings Screen
///
/// Edit server name, icon, banner, and basic settings.
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
  static const Color _neonGreen = Color(FlickoColors.brandLime);
  static const Color _bgBlack = Color(FlickoColors.bgPrimary);
  static const Color _textWhite = Color(FlickoColors.textPrimary);
  static const Color _textMuted = Color(FlickoColors.textMuted);

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _iconUrl;
  String? _bannerUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingIcon = false;
  bool _isUploadingBanner = false;
  bool _hasChanges = false;
  String? _errorMessage;

  int _membersCount = 0;
  int _channelsCount = 0;
  int _rolesCount = 0;
  String _createdDateStr = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadServerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadServerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      // Fetch server details
      final serverData = await client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .single();

      // Fetch members count
      final membersRes = await client
          .from('server_members')
          .select('id')
          .eq('server_id', widget.serverId);

      // Fetch channels count
      final channelsRes = await client
          .from('channels')
          .select('id')
          .eq('server_id', widget.serverId);

      // Fetch roles count
      final rolesRes = await client
          .from('roles')
          .select('id')
          .eq('server_id', widget.serverId);

      final createdAtStr = serverData['created_at'] as String?;
      String formattedDate = 'Unknown';
      if (createdAtStr != null) {
        final date = DateTime.parse(createdAtStr);
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        formattedDate = '${months[date.month - 1]} ${date.day}, ${date.year}';
      }

      setState(() {
        _nameController.text = serverData['name'] ?? '';
        _descriptionController.text = serverData['description'] ?? '';
        _iconUrl = serverData['icon'];
        _bannerUrl = serverData['banner'];
        _membersCount = membersRes.length;
        _channelsCount = channelsRes.length;
        _rolesCount = rolesRes.length;
        _createdDateStr = formattedDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickIcon() async {
    if (_isUploadingIcon) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingIcon = true);
      try {
        final url = await AppwriteStorageService.instance.uploadImage(File(image.path));
        setState(() {
          _iconUrl = url;
          _isUploadingIcon = false;
          _hasChanges = true;
        });
      } catch (e) {
        setState(() => _isUploadingIcon = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading icon: $e', style: GoogleFonts.spaceMono()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickBanner() async {
    if (_isUploadingBanner) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingBanner = true);
      try {
        final url = await AppwriteStorageService.instance.uploadImage(File(image.path));
        setState(() {
          _bannerUrl = url;
          _isUploadingBanner = false;
          _hasChanges = true;
        });
      } catch (e) {
        setState(() => _isUploadingBanner = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading banner: $e', style: GoogleFonts.spaceMono()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server name cannot be empty', style: GoogleFonts.spaceMono()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('servers').update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': _iconUrl,
        'banner': _bannerUrl,
      }).eq('id', widget.serverId);

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Changes saved successfully!', style: GoogleFonts.spaceMono()),
            backgroundColor: _neonGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e', style: GoogleFonts.spaceMono()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
          color: _neonGreen,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
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
                icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
                onPressed: () => context.pop(),
              ),
              Text(
                'SERVER OVERVIEW',
                style: GoogleFonts.epilogue(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.0,
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: _neonGreen, strokeWidth: 2),
                    ),
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                  color: _neonGreen, backgroundColor: Colors.black),
            ),
        ],
      ),
      floatingActionButton: _hasChanges && !_isLoading && _errorMessage == null
          ? FloatingActionButton(
              onPressed: _saveChanges,
              backgroundColor: _neonGreen,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.check, color: Colors.black, size: 36),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load details',
                style: GoogleFonts.epilogue(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(
                  color: _textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonGreen,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  'Retry',
                  style: GoogleFonts.epilogue(fontWeight: FontWeight.w900),
                ),
                onPressed: _loadServerData,
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const SizedBox.shrink(); // Using top progress bar instead
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('MEDIA'),
        _buildMediaSection(),
        const SizedBox(height: 32),
        
        _buildSectionHeader('DETAILS'),
        const SizedBox(height: 12),
        _buildSectionLabel('SERVER NAME'),
        _buildTextField(
          controller: _nameController,
          maxLength: 100,
          hint: 'Enter server name',
        ),
        const SizedBox(height: 24),
        _buildSectionLabel('DESCRIPTION'),
        _buildTextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 190,
          hint: 'Describe your server...',
        ),
        const SizedBox(height: 32),
        
        _buildSectionHeader('SERVER STATS'),
        const SizedBox(height: 12),
        _buildStatsSection(),
        const SizedBox(height: 80), // padding for FAB
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Personalize your server identity'.toUpperCase(),
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
                        if (_bannerUrl != null)
                          Image.network(_bannerUrl!, fit: BoxFit.cover)
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(FlickoColors.brandLime), Color(FlickoColors.bgPrimary)],
                              ),
                            ),
                          ),
                        if (_isUploadingBanner)
                          const Center(
                            child: CircularProgressIndicator(color: _neonGreen),
                          )
                        else
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.white, size: 16),
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
                  onTap: _pickIcon,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(color: _neonGreen, offset: Offset(6, 6))
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_iconUrl != null)
                          Image.network(_iconUrl!, fit: BoxFit.cover)
                        else if (!_isUploadingIcon)
                          Center(
                            child: Icon(
                              Icons.add_a_photo_rounded,
                              color: _textWhite.withValues(alpha: 0.3),
                              size: 32,
                            ),
                          ),
                        if (_isUploadingIcon)
                          const Center(
                            child: CircularProgressIndicator(color: _neonGreen, strokeWidth: 2),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: _neonGreen.withValues(alpha: 0.85),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
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

  Widget _buildTextField({
    required TextEditingController controller,
    int? maxLength,
    int? maxLines,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
      onChanged: (_) => _onFieldChanged(),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF333333), width: 4),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF333333), width: 4),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(FlickoColors.brandLime), width: 4),
          borderRadius: BorderRadius.zero,
        ),
        counterStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: const Color(0xFF333333), width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: _neonGreen, size: 24),
                const SizedBox(width: 12),
                Text(
                  'AT A GLANCE',
                  style: GoogleFonts.epilogue(
                    color: _textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333333), height: 4, thickness: 4),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow('Members', _membersCount.toString()),
                const SizedBox(height: 16),
                _buildStatRow('Channels', _channelsCount.toString()),
                const SizedBox(height: 16),
                _buildStatRow('Roles', _rolesCount.toString()),
                const SizedBox(height: 16),
                _buildStatRow('Created', _createdDateStr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

