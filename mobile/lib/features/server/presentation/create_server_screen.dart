import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/data/clients/api_client.dart';

import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';

/// Create Server Screen
///
/// Multi-step server creation flow:
/// Step 1: Choose template
/// Step 2: Select purpose (friends vs community)
/// Step 3: Customize (name, icon, banner, create)
/// Route: /server/create
class CreateServerScreen extends ConsumerStatefulWidget {
  const CreateServerScreen({super.key});

  @override
  ConsumerState<CreateServerScreen> createState() => _CreateServerScreenState();
}

class _CreateServerScreenState extends ConsumerState<CreateServerScreen> {
  int _currentStep = 0; // 0 = template, 1 = purpose, 2 = customize
  String _selectedTemplate = 'custom';
  String _serverName = '';
  File? _iconFile;
  File? _bannerFile;
  String _error = '';
  bool _isCreating = false;
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  final List<_TemplateOption> _templates = const [
    _TemplateOption(id: 'custom', label: 'Create My Own', icon: Icons.add_circle_outline, color: Color(FlickoColors.brandLime)),
    _TemplateOption(id: 'gaming', label: 'Gaming', icon: Icons.sports_esports, color: Color(FlickoColors.emeraldGreen)),
    _TemplateOption(id: 'school', label: 'School Club', icon: Icons.school, color: Color(FlickoColors.warning)),
    _TemplateOption(id: 'study', label: 'Study Group', icon: Icons.book, color: Color(FlickoColors.info)),
    _TemplateOption(id: 'friends', label: 'Friends', icon: Icons.people, color: Color(FlickoColors.danger)),
    _TemplateOption(id: 'creators', label: 'Artists & Creators', icon: Icons.palette, color: Color(FlickoColors.pink)),
    _TemplateOption(id: 'community', label: 'Local Community', icon: Icons.public, color: Color(FlickoColors.gold)),
  ];

  final Map<String, List<Map<String, String>>> _templateChannels = {
    'custom': [
      {'name': 'general', 'type': 'text'},
    ],
    'gaming': [
      {'name': 'general', 'type': 'text'},
      {'name': 'game-chat', 'type': 'text'},
      {'name': 'looking-for-group', 'type': 'text'},
      {'name': 'clips-and-highlights', 'type': 'text'},
      {'name': 'Gaming Voice', 'type': 'voice'},
      {'name': 'AFK', 'type': 'voice'},
    ],
    'school': [
      {'name': 'general', 'type': 'text'},
      {'name': 'announcements', 'type': 'text'},
      {'name': 'homework-help', 'type': 'text'},
      {'name': 'resources', 'type': 'text'},
      {'name': 'off-topic', 'type': 'text'},
      {'name': 'Study Room', 'type': 'voice'},
    ],
    'study': [
      {'name': 'general', 'type': 'text'},
      {'name': 'study-resources', 'type': 'text'},
      {'name': 'questions', 'type': 'text'},
      {'name': 'homework-help', 'type': 'text'},
      {'name': 'Study Session', 'type': 'voice'},
      {'name': 'Quiet Study', 'type': 'voice'},
    ],
    'friends': [
      {'name': 'general', 'type': 'text'},
      {'name': 'memes', 'type': 'text'},
      {'name': 'games', 'type': 'text'},
      {'name': 'music', 'type': 'text'},
      {'name': 'Hangout', 'type': 'voice'},
      {'name': 'Music', 'type': 'voice'},
    ],
    'creators': [
      {'name': 'general', 'type': 'text'},
      {'name': 'show-your-work', 'type': 'text'},
      {'name': 'feedback', 'type': 'text'},
      {'name': 'resources', 'type': 'text'},
      {'name': 'collaborations', 'type': 'text'},
      {'name': 'Creative Voice', 'type': 'voice'},
    ],
    'community': [
      {'name': 'general', 'type': 'text'},
      {'name': 'introductions', 'type': 'text'},
      {'name': 'announcements', 'type': 'text'},
      {'name': 'events', 'type': 'text'},
      {'name': 'off-topic', 'type': 'text'},
      {'name': 'Community Voice', 'type': 'voice'},
      {'name': 'Events', 'type': 'voice'},
    ],
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBanner) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked != null) {
        setState(() {
          if (isBanner) {
            _bannerFile = File(picked.path);
          } else {
            _iconFile = File(picked.path);
          }
        });
      }
    } catch (_) {
      // Fail silently
    }
  }

  void _selectTemplate(String templateId) {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (_, profile) => profile,
      orElse: () => null,
    );
    final username = user?.displayName ?? user?.username ?? 'User';

    setState(() {
      _selectedTemplate = templateId;
      _currentStep = 1;
      if (_serverName.isEmpty) {
        _serverName = "$username's server";
        _nameController.text = _serverName;
      }
    });
  }

  void _selectPurpose(String purpose) {
    setState(() {
      _currentStep = 2;
    });
  }

  Future<void> _createServer() async {
    final trimmedName = _serverName.trim();

    if (trimmedName.isEmpty) {
      setState(() => _error = 'SERVER_NAME_REQUIRED');
      return;
    }

    if (trimmedName.length > 100) {
      setState(() => _error = 'NAME_TOO_LONG');
      return;
    }

    final currentUser = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (currentUser == null) {
      setState(() => _error = 'AUTH_ERROR');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = '';
    });

    final client = Supabase.instance.client;

    try {
      String serverId;

      try {
        final result = await client.rpc('create_server_rpc', params: {'p_name': trimmedName});
        serverId = result['id'] as String;
      } catch (_) {
        final response = await client.from('servers').insert({
          'name': trimmedName,
          'owner_id': currentUser.id,
        }).select().single();

        serverId = response['id'] as String;
      }

      if (_iconFile != null) {
        try {
          final fileName = 'server_icons/${serverId}_${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage.from('server-assets').upload(fileName, _iconFile!);
          final iconUrl = client.storage.from('server-assets').getPublicUrl(fileName);
          await client.from('servers').update({'icon': iconUrl}).eq('id', serverId);
        } catch (_) {}
      }

      if (_bannerFile != null) {
        try {
          final fileName = 'server_banners/${serverId}_${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage.from('server-assets').upload(fileName, _bannerFile!);
          final bannerUrl = client.storage.from('server-assets').getPublicUrl(fileName);
          await client.from('servers').update({'banner': bannerUrl}).eq('id', serverId);
        } catch (_) {}
      }

      final channels = (_templateChannels[_selectedTemplate] ?? [])
          .where((ch) => ch['name'] != 'general' && ch['name'] != 'welcome')
          .toList();

      for (int i = 0; i < channels.length; i++) {
        await client.from('channels').insert({
          'name': channels[i]['name'],
          'type': channels[i]['type'],
          'server_id': serverId,
          'position': i + 1,
        });
      }

      if (mounted) {
        // Refresh server list and select the newly created server
        ref.read(serversNotifierProvider.notifier).refresh();
        ref.read(serversNotifierProvider.notifier).selectServer(serverId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server created successfully!'),
            backgroundColor: Color(FlickoColors.brandLime),
          ),
        );

        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _goBack() {
    if (_currentStep == 2) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 0);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
          decoration: const BoxDecoration(
            color: Color(FlickoColors.bgSecondary),
            border: Border(
              bottom: BorderSide(
                color: Color(FlickoColors.border),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  _currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new,
                  size: 20,
                  color: const Color(FlickoColors.textPrimary),
                ),
                onPressed: _goBack,
              ),
              Text(
                'Create a Server',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildTemplateStep();
      case 1:
        return _buildPurposeStep();
      case 2:
        return _buildCustomizeStep();
      default:
        return _buildTemplateStep();
    }
  }

  Widget _buildTemplateStep() {
    return SingleChildScrollView(
      key: const ValueKey('template'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your server',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: const Color(FlickoColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your server is where you and your friends hang out. Make yours and start talking.",
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ..._templates.map((tpl) => _buildTemplateRow(tpl)),
          const SizedBox(height: 32),
          Text(
            'Have an invite already?',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/discover'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(FlickoColors.border), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Join a Server',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.brandLime),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateRow(_TemplateOption tpl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _selectTemplate(tpl.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(FlickoColors.border), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tpl.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(tpl.icon, size: 20, color: tpl.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  tpl.label,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(FlickoColors.textSecondary), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeStep() {
    return SingleChildScrollView(
      key: const ValueKey('purpose'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us a bit more',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: const Color(FlickoColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In order to help you set up, is your new server for a few friends or a larger community?',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildPurposeCard(
            icon: Icons.people_outline_rounded,
            iconColor: const Color(FlickoColors.brandLime),
            title: 'For me and my friends',
            subtitle: 'A private space for your inner circle.',
            onTap: () => _selectPurpose('friends'),
          ),
          const SizedBox(height: 16),
          _buildPurposeCard(
            icon: Icons.public_rounded,
            iconColor: const Color(FlickoColors.emeraldGreen),
            title: 'For a club or community',
            subtitle: 'A public space for anyone to join.',
            onTap: () => _selectPurpose('community'),
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => _selectPurpose('skip'),
              child: Text(
                'Skip this question',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(FlickoColors.border), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(FlickoColors.textSecondary), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizeStep() {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (_, profile) => profile,
      orElse: () => null,
    );
    final username = user?.displayName ?? user?.username ?? 'User';

    return SingleChildScrollView(
      key: const ValueKey('customize'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize your server',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: const Color(FlickoColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Give your server a personality with a name and image. You can always change this later.',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          _buildBannerUpload(),
          const SizedBox(height: 20),

          _buildIconUpload(),
          const SizedBox(height: 28),

          Text(
            'Server Template',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(FlickoColors.border), width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTemplate,
                dropdownColor: const Color(FlickoColors.bgSecondary),
                icon: const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.keyboard_arrow_down, color: Color(FlickoColors.textSecondary)),
                ),
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: _templates.map((tpl) {
                  return DropdownMenuItem<String>(
                    value: tpl.id,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: tpl.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(tpl.icon, color: tpl.color, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(tpl.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTemplate = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Server Name',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _error.isNotEmpty
                    ? const Color(FlickoColors.danger)
                    : const Color(FlickoColors.border),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _nameController,
              onChanged: (v) {
                setState(() {
                  _serverName = v;
                  if (_error.isNotEmpty) _error = '';
                });
              },
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: const Color(FlickoColors.brandLime),
              decoration: InputDecoration(
                hintText: "$username's server",
                hintStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: InputBorder.none,
                counterText: '',
              ),
              maxLength: 100,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createServer(),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(FlickoColors.danger), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error == 'SERVER_NAME_REQUIRED' ? 'Server name is required.' : _error,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.danger),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          Center(
            child: Text(
              "By creating a server, you agree to Flicko's Community Guidelines.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _serverName.trim().isEmpty || _isCreating ? null : _createServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.brandLime),
              foregroundColor: const Color(FlickoColors.black),
              disabledBackgroundColor: const Color(FlickoColors.bgSecondary),
              disabledForegroundColor: const Color(FlickoColors.textMuted),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Create Server',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBannerUpload() {
    return GestureDetector(
      onTap: () => _pickImage(true),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(FlickoColors.border), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: _bannerFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_bannerFile!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          'Tap to change banner',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.panorama_outlined, size: 32, color: Color(FlickoColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Server Banner',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended size: 960x540',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildIconUpload() {
    return Center(
      child: GestureDetector(
        onTap: () => _pickImage(false),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(FlickoColors.border), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: _iconFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_iconFile!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black54,
                        child: Center(
                          child: Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_rounded, size: 24, color: Color(FlickoColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      'ICON',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TemplateOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _TemplateOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}
