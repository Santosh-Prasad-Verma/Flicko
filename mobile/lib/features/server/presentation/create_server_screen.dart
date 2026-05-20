import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';

/// Create Server Screen
///
/// Discord-style multi-step server creation flow:
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

  // Template definitions matching React Native
  final List<_TemplateOption> _templates = const [
    _TemplateOption(id: 'custom', label: 'Create My Own', icon: Icons.add_circle_outline, color: Color(FlickoColors.blurple)),
    _TemplateOption(id: 'gaming', label: 'Gaming', icon: Icons.sports_esports, color: Color(FlickoColors.green)),
    _TemplateOption(id: 'school', label: 'School Club', icon: Icons.school, color: Color(FlickoColors.yellow)),
    _TemplateOption(id: 'study', label: 'Study Group', icon: Icons.book, color: Color(FlickoColors.pink)),
    _TemplateOption(id: 'friends', label: 'Friends', icon: Icons.people, color: Color(FlickoColors.red)),
    _TemplateOption(id: 'creators', label: 'Artists & Creators', icon: Icons.palette, color: Color(FlickoColors.blurple)),
    _TemplateOption(id: 'community', label: 'Local Community', icon: Icons.public, color: Color(FlickoColors.green)),
  ];

  // Template channel presets
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

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);

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
    } catch (e) {
      // Image picker cancelled or error
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
      // Create server via RPC if available, otherwise direct insert
      String serverId;

      try {
        final result = await client.rpc('create_server_rpc', params: {'p_name': trimmedName});
        serverId = result['id'] as String;
      } catch (_) {
        // Fallback: direct insert
        final response = await client.from('servers').insert({
          'name': trimmedName,
          'owner_id': currentUser.id,
        }).select().single();

        serverId = response['id'] as String;

        // Join owner
        await client.from('server_members').insert({
          'server_id': serverId,
          'user_id': currentUser.id,
          'role': 'owner',
        });

        // Create general channel
        await client.from('channels').insert({
          'server_id': serverId,
          'name': 'general',
          'type': 'text',
          'position': 0,
        });
      }

      // Upload icon if selected
      if (_iconFile != null) {
        try {
          final fileName = 'server_icons/${serverId}_${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage.from('server-assets').upload(fileName, _iconFile!);
          final iconUrl = client.storage.from('server-assets').getPublicUrl(fileName);
          await client.from('servers').update({'icon': iconUrl}).eq('id', serverId);
        } catch (_) {
          // Icon upload failed, continue
        }
      }

      // Upload banner if selected
      if (_bannerFile != null) {
        try {
          final fileName = 'server_banners/${serverId}_${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage.from('server-assets').upload(fileName, _bannerFile!);
          final bannerUrl = client.storage.from('server-assets').getPublicUrl(fileName);
          await client.from('servers').update({'banner': bannerUrl}).eq('id', serverId);
        } catch (_) {
          // Banner upload failed, continue
        }
      }

      // Create template channels (skip 'general' as it's created by trigger or above)
      final channels = (_templateChannels[_selectedTemplate] ?? [])
          .where((ch) => ch['name'] != 'general')
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SERVER_INITIALIZED_SUCCESSFULLY'),
            backgroundColor: lime,
          ),
        );

        // Navigate to new server
        context.go('/server/$serverId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().toUpperCase());
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
      backgroundColor: black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: black,
            border: Border(bottom: BorderSide(color: lime, width: 4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BrutalistIconButton(
                icon: _currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new,
                onTap: _goBack,
              ),
              Text(
                'CORE.CREATE',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 45), // Spacer to center title
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Text(
                'INITIALIZE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  letterSpacing: -2,
                  color: lime,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'SERVER',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: -2,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(width: 60, height: 8, color: lime),
          const SizedBox(height: 24),
          Text(
            "YOUR SERVER IS A NODE IN THE NETWORK. START THE INITIALIZATION PROCESS BY SELECTING A TEMPLATE PROTOCOL.",
            style: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          // Template list
          ..._templates.map((tpl) => _buildTemplateRow(tpl)),
          const SizedBox(height: 48),
          const BrutalistLegalFooter(),
          const SizedBox(height: 24),
          Text(
            'EXISTING_INVITE_DETECTED?',
            style: GoogleFonts.robotoMono(
              color: white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          BrutalistButton(
            text: 'JOIN_A_SERVER',
            onTap: () => context.push('/discover'),
            backgroundColor: black,
            textColor: white,
            shadowColor: lime,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateRow(_TemplateOption tpl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () => _selectTemplate(tpl.id),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: black,
            border: Border.all(color: white, width: 3),
            boxShadow: const [
              BoxShadow(color: lime, offset: Offset(6, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tpl.color,
                  border: Border.all(color: black, width: 2),
                ),
                child: Icon(tpl.icon, size: 24, color: black),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  tpl.label.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward, color: lime, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeStep() {
    return SingleChildScrollView(
      key: const ValueKey('purpose'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT_SCOPE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 0.9,
              letterSpacing: -2,
              color: white,
            ),
          ),
          const SizedBox(height: 24),
          Container(width: 60, height: 8, color: lime),
          const SizedBox(height: 24),
          Text(
            'DEFINE THE TARGET AUDIENCE FOR THIS NODE. SYSTEM REQUIRES CLARIFICATION ON NETWORK SCALE.',
            style: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _buildPurposeCard(
            icon: Icons.people,
            iconColor: lime,
            title: 'PRIVATE_NETWORK',
            subtitle: 'SMALL SCALE / FRIENDS ONLY',
            onTap: () => _selectPurpose('friends'),
          ),
          const SizedBox(height: 24),
          _buildPurposeCard(
            icon: Icons.public,
            iconColor: white,
            title: 'PUBLIC_NODE',
            subtitle: 'LARGE SCALE / COMMUNITY HUB',
            onTap: () => _selectPurpose('community'),
          ),
          const SizedBox(height: 48),
          Center(
            child: TextButton(
              onPressed: () => _selectPurpose('skip'),
              child: Text(
                '>> SKIP_PROTOCOL_FOR_NOW',
                style: GoogleFonts.robotoMono(
                  color: white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: white, width: 3),
          boxShadow: [
            BoxShadow(color: iconColor == lime ? white : lime, offset: const Offset(6, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor,
                border: Border.all(color: black, width: 2),
              ),
              child: Icon(icon, size: 32, color: black),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.robotoMono(
                      color: white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: white, size: 24),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Customise your server',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Give your new server a personality with a name and an icon. You can always change it later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Banner upload
          _buildBannerUpload(),
          const SizedBox(height: 16),
          // Icon upload
          _buildIconUpload(),
          const SizedBox(height: 24),
          // Server Category Selector (dropdown)
          Text(
            'CATEGORY',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTemplate,
                dropdownColor: const Color(0xFF1E1F22),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                isExpanded: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                items: _templates.map((tpl) {
                  return DropdownMenuItem<String>(
                    value: tpl.id,
                    child: Row(
                      children: [
                        Icon(tpl.icon, color: tpl.color, size: 20),
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
          // Server name
          Text(
            'SERVER NAME',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (v) {
              setState(() {
                _serverName = v;
                if (_error.isNotEmpty) _error = '';
              });
            },
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
            ),
            decoration: InputDecoration(
              hintText: "$username's server",
              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
              filled: true,
              fillColor: const Color(FlickoColors.bgTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              errorText: _error.isNotEmpty ? _error : null,
              errorStyle: GoogleFonts.inter(
                color: const Color(FlickoColors.red),
                fontSize: 13,
              ),
            ),
            maxLength: 100,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createServer(),
          ),
          // TOS
          const SizedBox(height: 16),
          Text(
            "By creating a server, you agree to Flicko's ",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Open community guidelines
            },
            child: Text(
              'Community Guidelines',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.blurple),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Create button
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _serverName.trim().isEmpty || _isCreating ? null : _createServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: const Color(FlickoColors.bgTertiary),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Create Server',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerUpload() {
    return InkWell(
      onTap: () => _pickImage(true),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: white, width: 3),
          boxShadow: const [
            BoxShadow(color: lime, offset: Offset(6, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _bannerFile != null
            ? Image.file(_bannerFile!, fit: BoxFit.cover)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_outlined, size: 32, color: white),
                    const SizedBox(height: 8),
                    Text(
                      'UPLOAD_BANNER',
                      style: GoogleFonts.robotoMono(
                        color: white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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
      child: InkWell(
        onTap: () => _pickImage(false),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgTertiary),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(FlickoColors.textMuted),
              style: BorderStyle.solid,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _iconFile != null
              ? Image.file(_iconFile!, fit: BoxFit.cover)
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 28, color: Color(FlickoColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          'UPLOAD',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    // Plus badge
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(FlickoColors.blurple),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Template option model
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
