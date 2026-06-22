import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/clients/dio_client.dart';

class StandaloneRoomScreen extends ConsumerStatefulWidget {
  const StandaloneRoomScreen({super.key});

  @override
  ConsumerState<StandaloneRoomScreen> createState() => _StandaloneRoomScreenState();
}

class _StandaloneRoomScreenState extends ConsumerState<StandaloneRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isPublic = false;
  String _lobbyName = '';
  String _mediaUrl = '';
  String _mediaTitle = '';
  String _mediaKind = 'youtube';
  int _maxViewers = 12;
  bool _allowSeek = true;
  
  bool _isLoading = false;
  String? _error;
  
  // Results after creation
  String? _createdSessionId;
  bool _isCreated = false;

  final List<Map<String, String>> _mediaKinds = [
    {'value': 'youtube', 'label': 'YouTube Video'},
    {'value': 'vimeo', 'label': 'Vimeo Stream'},
    {'value': 'mp4', 'label': 'Direct MP4 Link'},
    {'value': 'hls', 'label': 'HLS Stream (m3u8)'},
    {'value': 'appwrite', 'label': 'Appwrite Storage File'},
  ];

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      
      final response = await dio.post(
        '/api/v1/wt/sessions',
        data: {
          'room_id': '', // empty string represents standalone session
          'media': {
            'kind': _mediaKind,
            'url': _mediaUrl,
            'title': _mediaTitle.isNotEmpty ? _mediaTitle : 'Watch Together Room',
          },
          'settings': {
            'max_viewers': _maxViewers,
            'allow_seek_by_viewer': _allowSeek,
          },
          'is_public': _isPublic,
          'lobby_name': _isPublic ? (_lobbyName.isNotEmpty ? _lobbyName : 'Co-watching Session') : '',
        },
      );

      final data = response.data;
      setState(() {
        _createdSessionId = data['id'] as String;
        _isCreated = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Watch Room',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x1F52B788),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              const Color(FlickoColors.brandLime).withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _isCreated ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E1E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.live_tv_rounded,
                          color: Color(FlickoColors.brandLime),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Standalone Watch Room',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Watch movies and streams together directly using invite links without joining a voice channel.',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textSecondary),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Private vs Public selector
            Text(
              'ROOM PRIVACY',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPrivacyCard(
                    title: 'Private Room',
                    description: 'Access only via direct invite link',
                    icon: Icons.lock_outline,
                    isSelected: !_isPublic,
                    onTap: () => setState(() => _isPublic = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrivacyCard(
                    title: 'Public Room',
                    description: 'Listed in public lobbies directory',
                    icon: Icons.public_rounded,
                    isSelected: _isPublic,
                    onTap: () => setState(() => _isPublic = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lobby name input (if public)
            if (_isPublic) ...[
              Text(
                'LOBBY NAME',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _inputDecoration('e.g. tarun\'s watch room'),
                validator: (value) {
                  if (_isPublic && (value == null || value.trim().isEmpty)) {
                    return 'Lobby name is required for public rooms';
                  }
                  return null;
                },
                onSaved: (value) => _lobbyName = value ?? '',
              ),
              const SizedBox(height: 20),
            ],

            // Media Info Section
            Text(
              'MEDIA CONFIGURATION',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E1E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _mediaKind,
                    dropdownColor: const Color(FlickoColors.bgSecondary),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration('Media Stream Type'),
                    items: _mediaKinds.map((kind) {
                      return DropdownMenuItem<String>(
                        value: kind['value'],
                        child: Text(kind['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _mediaKind = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _inputDecoration('Media URL (e.g. YouTube video URL)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Media URL is required';
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid absolute URL';
                      }
                      return null;
                    },
                    onSaved: (value) => _mediaUrl = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _inputDecoration('Media Title (optional)'),
                    onSaved: (value) => _mediaTitle = value ?? '',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Room settings
            Text(
              'SETTINGS',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E1E)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Allow viewers to seek/pause',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      ),
                      Switch(
                        value: _allowSeek,
                        activeThumbColor: const Color(FlickoColors.brandLime),
                        onChanged: (val) => setState(() => _allowSeek = val),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF222222)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max Viewers',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: _maxViewers > 2 ? () => setState(() => _maxViewers--) : null,
                          ),
                          Text(
                            '$_maxViewers',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.brandLime),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: _maxViewers < 50 ? () => setState(() => _maxViewers++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(FlickoColors.danger).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(FlickoColors.danger)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.brandLime),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: const Color(FlickoColors.brandLime).withValues(alpha: 0.4),
                ),
                onPressed: _isLoading ? null : _createRoom,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        'Create Room',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(FlickoColors.brandLime).withValues(alpha: 0.08)
              : const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(FlickoColors.brandLime)
                : const Color(0xFF1E1E1E),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(FlickoColors.brandLime) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final inviteLink = 'flicko://wt/join/$_createdSessionId';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(FlickoColors.brandLime),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Room Created Successfully!',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your co-watching room is online and ready.',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Invite link card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E1E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHARE ROOM ACCESS LINK',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgPrimary),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Color(FlickoColors.textMuted), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            inviteLink,
                            style: GoogleFonts.robotoMono(
                              color: const Color(FlickoColors.brandLime),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2D2D2D)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                          label: Text(
                            'Copy Link',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Launch Activity / Done buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.brandLime),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Launching Watch Room $_createdSessionId...'),
                    ),
                  );
                  context.pop();
                },
                child: Text(
                  'Launch Stream Room',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to home',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13),
      filled: true,
      fillColor: const Color(FlickoColors.bgTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      errorStyle: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontSize: 12),
    );
  }
}
