import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Create Server Screen
///
/// Overhauled with custom Neo-Brutalist theme and premium stacked Cards.
class CreateServerScreen extends ConsumerStatefulWidget {
  const CreateServerScreen({super.key});

  @override
  ConsumerState<CreateServerScreen> createState() => _CreateServerScreenState();
}

class _CreateServerScreenState extends ConsumerState<CreateServerScreen> {
  int _currentStep = 0; // 0 = hub (create/join/templates), 1 = purpose, 2 = customize
  String _selectedTemplate = 'custom';
  String _purpose = 'friends';
  String _serverName = '';
  File? _iconFile;
  File? _bannerFile;
  String _error = '';
  bool _isCreating = false;

  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  final List<_TemplateOption> _templates = const [
    _TemplateOption(id: 'gaming', label: 'Gaming', icon: Icons.sports_esports, color: Color(FlickoColors.green)),
    _TemplateOption(id: 'school', label: 'School Club', icon: Icons.school, color: Color(FlickoColors.yellow)),
    _TemplateOption(id: 'study', label: 'Study Group', icon: Icons.book, color: Color(FlickoColors.pink)),
    _TemplateOption(id: 'friends', label: 'Friends Hub', icon: Icons.people, color: Color(FlickoColors.red)),
    _TemplateOption(id: 'creators', label: 'Creators Space', icon: Icons.palette, color: Color(FlickoColors.blurple)),
    _TemplateOption(id: 'community', label: 'Community', icon: Icons.public, color: Color(FlickoColors.green)),
  ];

  final Map<String, List<Map<String, String>>> _templateChannels = {
    'custom': [{'name': 'general', 'type': 'text'}],
    'gaming': [
      {'name': 'general', 'type': 'text'},
      {'name': 'game-chat', 'type': 'text'},
      {'name': 'clips', 'type': 'text'},
      {'name': 'Gaming Voice', 'type': 'voice'},
    ],
    'school': [
      {'name': 'general', 'type': 'text'},
      {'name': 'announcements', 'type': 'text'},
      {'name': 'homework-help', 'type': 'text'},
      {'name': 'Study Room', 'type': 'voice'},
    ],
    'study': [
      {'name': 'general', 'type': 'text'},
      {'name': 'study-resources', 'type': 'text'},
      {'name': 'Study Session', 'type': 'voice'},
    ],
    'friends': [
      {'name': 'general', 'type': 'text'},
      {'name': 'memes', 'type': 'text'},
      {'name': 'Hangout', 'type': 'voice'},
    ],
    'creators': [
      {'name': 'general', 'type': 'text'},
      {'name': 'show-your-work', 'type': 'text'},
      {'name': 'Creative Voice', 'type': 'voice'},
    ],
    'community': [
      {'name': 'general', 'type': 'text'},
      {'name': 'introductions', 'type': 'text'},
      {'name': 'Community Voice', 'type': 'voice'},
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
        imageQuality: 80,
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
    } catch (_) {}
  }

  void _selectTemplate(String template) {
    setState(() {
      _selectedTemplate = template;
      _currentStep = 1;
    });
  }

  void _selectPurpose(String purpose) {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (_, profile) => profile,
      orElse: () => null,
    );
    final username = user?.displayName ?? user?.username ?? 'User';

    setState(() {
      _purpose = purpose;
      _currentStep = 2;
      if (_serverName.isEmpty) {
        _serverName = "$username's space";
        _nameController.text = _serverName;
      }
    });
  }

  Future<void> _createServer() async {
    final trimmedName = _serverName.trim();
    if (trimmedName.isEmpty) {
      setState(() => _error = 'Space name is required');
      return;
    }
    if (trimmedName.length > 100) {
      setState(() => _error = 'Space name must be 100 characters or less');
      return;
    }

    final currentUser = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );
    if (currentUser == null) {
      setState(() => _error = 'Session not found');
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

        await client.from('server_members').insert({
          'server_id': serverId,
          'user_id': currentUser.id,
          'role': 'owner',
        });

        await client.from('channels').insert({
          'server_id': serverId,
          'name': 'general',
          'type': 'text',
          'position': 0,
        });
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
          const SnackBar(content: Text('Digital space successfully initialized.')),
        );
        context.go('/server/$serverId');
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
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            _currentStep == 0 ? Icons.close : Icons.arrow_back,
            color: const Color(FlickoColors.textPrimary),
          ),
          onPressed: _goBack,
        ),
        title: Text(
          'SPACE GATEWAY',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: const Color(FlickoColors.textMuted),
          ),
        ),
        centerTitle: true,
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
        return _buildHubStep();
      case 1:
        return _buildPurposeStep();
      case 2:
        return _buildCustomizeStep();
      default:
        return _buildHubStep();
    }
  }

  Widget _buildHubStep() {
    return SingleChildScrollView(
      key: const ValueKey('hub'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE YOUR',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 0.9,
              color: const Color(FlickoColors.textPrimary),
            ),
          ),
          Text(
            'PATHWAY',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: const Color(FlickoColors.blurple),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establish an isolated private quadrant, or secure an access key to step into an existing sector.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(FlickoColors.textSecondary),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Huge Stacked Hero Cards
          _buildHeroCard(
            title: 'CREATE NEW DOMAIN',
            subtitle: 'Deploy a custom environment from standard protocols or scratch.',
            icon: Icons.add_circle_outline,
            accentColor: const Color(FlickoColors.blurple),
            onTap: () => _selectTemplate('custom'),
          ),
          const SizedBox(height: 16),
          _buildHeroCard(
            title: 'ACCESS EXISTING SPACE',
            subtitle: 'Input a routing sequence or secure token from an organizer.',
            icon: Icons.login,
            accentColor: const Color(FlickoColors.green),
            onTap: () => context.push('/server/discover'),
          ),

          const SizedBox(height: 36),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFF232428), thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'BLUEPRINT PRESETS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: const Color(FlickoColors.textMuted),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFF232428), thickness: 1.5)),
            ],
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final tpl = _templates[index];
              return _buildTemplateGridTile(tpl);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF232428), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.03),
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PROTOCOL',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(FlickoColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(FlickoColors.textSecondary),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF18191C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF232428), width: 2),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateGridTile(_TemplateOption tpl) {
    return InkWell(
      onTap: () => _selectTemplate(tpl.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF232428), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tpl.icon, color: tpl.color, size: 24),
            const Spacer(),
            Text(
              tpl.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(FlickoColors.textPrimary),
              ),
            ),
            Text(
              'Blueprint',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(FlickoColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeStep() {
    return SingleChildScrollView(
      key: const ValueKey('purpose'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TELL US MORE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: const Color(FlickoColors.textPrimary),
              height: 0.9,
            ),
          ),
          Text(
            'ABOUT INTENT',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: const Color(FlickoColors.yellow),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'To build optimum configuration, should this quadrant operate for close acquaintances or larger open networks?',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          _buildNeoPurposeCard(
            title: 'CLOSED SYNDICATE',
            subtitle: 'For me and my close associates.',
            icon: Icons.lock_outline,
            accentColor: const Color(FlickoColors.pink),
            onTap: () => _selectPurpose('friends'),
          ),
          const SizedBox(height: 16),
          _buildNeoPurposeCard(
            title: 'PUBLIC COMMUNE',
            subtitle: 'For a club or structured community.',
            icon: Icons.public,
            accentColor: const Color(FlickoColors.green),
            onTap: () => _selectPurpose('community'),
          ),

          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => _selectPurpose('friends'),
              child: Text(
                'Skip configuration step',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoPurposeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF232428), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: const Color(FlickoColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(FlickoColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(FlickoColors.textMuted)),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        key: const ValueKey('customize'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CUSTOMIZE THE',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(FlickoColors.textPrimary),
                height: 0.9,
              ),
            ),
            Text(
              'ENVIRONMENT',
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: const Color(FlickoColors.pink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Define the visual signature. Assign a static identifier banner and access icon.',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            _buildNeoBannerUpload(),
            const SizedBox(height: 24),
            
            Text(
              'SPACE MONIKER',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(FlickoColors.textMuted),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
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
              style: GoogleFonts.spaceGrotesk(
                color: const Color(FlickoColors.textPrimary),
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: "$username's space",
                hintStyle: GoogleFonts.spaceGrotesk(color: const Color(FlickoColors.textMuted), fontWeight: FontWeight.w700),
                filled: true,
                fillColor: const Color(0xFF000000),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF232428), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(FlickoColors.blurple), width: 2.5),
                ),
                errorText: _error.isNotEmpty ? _error : null,
                errorStyle: GoogleFonts.inter(color: const Color(FlickoColors.red), fontSize: 12),
              ),
              maxLength: 100,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createServer(),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF232428), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_outlined, color: Color(FlickoColors.textMuted), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'By deploying, you certify alignment with the ',
                        style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 11, height: 1.3),
                        children: const [
                          TextSpan(
                            text: 'Sector Guidelines.',
                            style: TextStyle(color: Color(FlickoColors.blurple), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // spacer for safe view scroll
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          border: Border(top: BorderSide(color: Color(0xFF232428), width: 2)),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _serverName.trim().isEmpty || _isCreating ? null : _createServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF18191C),
              disabledForegroundColor: const Color(FlickoColors.textMuted),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'INITIALIZE PROTOCOL',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeoBannerUpload() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner area
        GestureDetector(
          onTap: () => _pickImage(true),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF232428), width: 2),
              image: _bannerFile != null
                  ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: _bannerFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.landscape_outlined, color: Color(FlickoColors.textMuted), size: 28),
                      const SizedBox(height: 6),
                      Text(
                        'SET WIDE BANNER',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: const Color(FlickoColors.textMuted),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
          ),
        ),
        // Circular Icon Overlaid
        Positioned(
          bottom: -20,
          left: 20,
          child: GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF121316),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(FlickoColors.bgPrimary), width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1F22),
                      border: Border.all(color: const Color(0xFF232428), width: 2),
                      image: _iconFile != null
                          ? DecorationImage(image: FileImage(_iconFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _iconFile == null
                        ? const Center(
                            child: Icon(Icons.camera_alt_outlined, color: Color(FlickoColors.textMuted), size: 24),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(FlickoColors.blurple),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
