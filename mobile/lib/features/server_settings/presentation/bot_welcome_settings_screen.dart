import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/appwrite_storage_service.dart';

class BotWelcomeSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotWelcomeSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BotWelcomeSettingsScreen> createState() => _BotWelcomeSettingsScreenState();
}

class _BotWelcomeSettingsScreenState extends ConsumerState<BotWelcomeSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  Map<String, dynamic>? _settings;
  String? _errorMessage;

  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _roles = [];

  final _welcomeMsgController = TextEditingController();
  final _welcomeBannerController = TextEditingController();
  final _welcomeGifController = TextEditingController();
  final _dmMsgController = TextEditingController();
  final _leaveMsgController = TextEditingController();

  String? _welcomeChannelId;
  String? _leaveChannelId;
  bool _botEnabled = false;
  bool _dmEnabled = false;
  bool _welcomeCardEnabled = false;
  bool _leaveEnabled = false;
  List<String> _autoRoles = [];

  bool _isUploadingBanner = false;
  bool _isUploadingGif = false;

  Future<void> _pickBanner() async {
    if (_isUploadingBanner) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingBanner = true);
      try {
        final url = await AppwriteStorageService.instance.uploadImage(File(image.path));
        setState(() {
          _welcomeBannerController.text = url;
          _isUploadingBanner = false;
          _hasChanges = true;
        });
      } catch (e) {
        setState(() => _isUploadingBanner = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading banner: $e'), backgroundColor: const Color(FlickoColors.danger)),
          );
        }
      }
    }
  }

  Future<void> _pickGif() async {
    if (_isUploadingGif) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingGif = true);
      try {
        final url = await AppwriteStorageService.instance.uploadImage(File(image.path));
        setState(() {
          _welcomeGifController.text = url;
          _isUploadingGif = false;
          _hasChanges = true;
        });
      } catch (e) {
        setState(() => _isUploadingGif = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading GIF: $e'), backgroundColor: const Color(FlickoColors.danger)),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _welcomeMsgController.dispose();
    _welcomeBannerController.dispose();
    _welcomeGifController.dispose();
    _dmMsgController.dispose();
    _leaveMsgController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      // 1. Fetch welcome settings
      final settingsResponse = await client
          .from('welcome_settings')
          .select('*')
          .eq('server_id', widget.serverId)
          .maybeSingle();

      // 2. Fetch text channels
      final channelsResponse = await client
          .from('channels')
          .select('id, name, type')
          .eq('server_id', widget.serverId)
          .eq('type', 'text');

      // 3. Fetch server roles
      final rolesResponse = await client
          .from('roles')
          .select('id, name')
          .eq('server_id', widget.serverId);

      setState(() {
        _settings = settingsResponse;
        _channels = List<Map<String, dynamic>>.from((channelsResponse as List?) ?? []);
        _roles = List<Map<String, dynamic>>.from((rolesResponse as List?) ?? []);

        if (settingsResponse != null) {
          _botEnabled = settingsResponse['enabled'] ?? false;
          _welcomeMsgController.text = settingsResponse['welcome_message'] ?? 'Welcome {{user}} to **{{server}}**! 🎉';
          _welcomeBannerController.text = settingsResponse['welcome_banner_url'] ?? '';
          _welcomeGifController.text = settingsResponse['welcome_gif_url'] ?? '';
          _dmMsgController.text = settingsResponse['dm_message'] ?? 'Welcome to **{{server}}**! Read the rules to get started.';
          _leaveMsgController.text = settingsResponse['leave_message'] ?? '**{{username}}** has left the server. 😢';
          _welcomeChannelId = settingsResponse['welcome_channel_id'];
          _leaveChannelId = settingsResponse['leave_channel_id'];
          _dmEnabled = settingsResponse['dm_enabled'] ?? false;
          _welcomeCardEnabled = settingsResponse['welcome_card_enabled'] ?? false;
          _leaveEnabled = settingsResponse['leave_enabled'] ?? false;
          _autoRoles = List<String>.from(settingsResponse['auto_roles'] ?? []);
        } else {
          // Initialize default templates
          _botEnabled = true;
          _welcomeMsgController.text = 'Welcome {{user}} to **{{server}}**! 🎉';
          _welcomeBannerController.text = '';
          _welcomeGifController.text = '';
          _dmMsgController.text = 'Welcome to **{{server}}**! Read the rules to get started.';
          _leaveMsgController.text = '**{{username}}** has left the server. 😢';
          _welcomeChannelId = null;
          _leaveChannelId = null;
          _dmEnabled = false;
          _welcomeCardEnabled = true;
          _leaveEnabled = false;
          _autoRoles = [];
        }

        if (_welcomeChannelId == null && _channels.isNotEmpty) {
          final welcomeChan = _channels.firstWhere(
            (c) => (c['name'] as String? ?? '').toLowerCase() == 'welcome',
            orElse: () => _channels.first,
          );
          _welcomeChannelId = welcomeChan['id'] as String?;
        }

        _hasChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final payload = {
        'enabled': _botEnabled,
        'welcome_message': _welcomeMsgController.text.trim(),
        'welcome_banner_url': _welcomeBannerController.text.trim(),
        'welcome_gif_url': _welcomeGifController.text.trim(),
        'dm_message': _dmMsgController.text.trim(),
        'leave_message': _leaveMsgController.text.trim(),
        'welcome_channel_id': _welcomeChannelId,
        'leave_channel_id': _leaveChannelId,
        'dm_enabled': _dmEnabled,
        'welcome_card_enabled': _welcomeCardEnabled,
        'leave_enabled': _leaveEnabled,
        'auto_roles': _autoRoles,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_settings != null) {
        await Supabase.instance.client
            .from('welcome_settings')
            .update(payload)
            .eq('server_id', widget.serverId);
      } else {
        payload['server_id'] = widget.serverId;
        payload['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client
            .from('welcome_settings')
            .insert(payload);
      }

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(FlickoColors.green),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to save settings: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(FlickoColors.danger),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
      filled: true,
      fillColor: const Color(FlickoColors.bgTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FlickoRadius.md),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Welcome Bot',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isSaving ? _saveSettings : null,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple)),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: _hasChanges ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text(
              'Error loading settings',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(FlickoRadius.lg),
            ),
            child: Row(
              children: [
                const Text('👋', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Greet new members, assign auto-roles and send goodbye messages.',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Enable toggle
          _buildToggleCard(
            title: 'Enable Welcome Bot',
            description: 'Automatically welcome new members when they join',
            value: _botEnabled,
            onChanged: (v) {
              setState(() {
                _botEnabled = v;
              });
              _markChanged();
            },
          ),
          const SizedBox(height: 24),

          if (_botEnabled) ...[
            // Welcome channel
            _buildSectionHeader('WELCOME CHANNEL'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _welcomeChannelId,
              dropdownColor: const Color(FlickoColors.bgSecondary),
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: _inputDecoration('Select a welcome channel'),
              items: _channels.map((ch) {
                return DropdownMenuItem<String>(
                  value: ch['id'] as String,
                  child: Text('# ${ch['name']}', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _welcomeChannelId = val;
                });
                _markChanged();
              },
            ),
            const SizedBox(height: 16),

            // Welcome message template
            _buildSectionHeader('WELCOME MESSAGE'),
            const SizedBox(height: 8),
            TextField(
              controller: _welcomeMsgController,
              maxLines: 3,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: _inputDecoration('Welcome message template'),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 16),

            // Welcome banner URL & Upload
            _buildSectionHeader('WELCOME BANNER'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _welcomeBannerController,
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                    decoration: _inputDecoration('https://example.com/banner.png or upload'),
                    onChanged: (_) => _markChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _isUploadingBanner ? null : _pickBanner,
                  icon: _isUploadingBanner
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_rounded, color: Color(FlickoColors.brandLime)),
                  tooltip: 'Upload Banner Image',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Welcome GIF URL & Upload
            _buildSectionHeader('WELCOME GIF'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _welcomeGifController,
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                    decoration: _inputDecoration('https://example.com/welcome.gif or upload'),
                    onChanged: (_) => _markChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _isUploadingGif ? null : _pickGif,
                  icon: _isUploadingGif
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.gif_box_rounded, color: Color(FlickoColors.brandLime)),
                  tooltip: 'Upload GIF Image',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DM on Join Toggle
            _buildToggleCard(
              title: 'Send DM on Join',
              description: 'Send a private message to new members when they join',
              value: _dmEnabled,
              onChanged: (v) {
                setState(() {
                  _dmEnabled = v;
                });
                _markChanged();
              },
            ),
            if (_dmEnabled) ...[
              const SizedBox(height: 16),
              _buildSectionHeader('DM MESSAGE'),
              const SizedBox(height: 8),
              TextField(
                controller: _dmMsgController,
                maxLines: 3,
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                decoration: _inputDecoration('Welcome message sent to DM'),
                onChanged: (_) => _markChanged(),
              ),
            ],
            const SizedBox(height: 16),

            // Welcome Card Toggle
            _buildToggleCard(
              title: 'Generate Welcome Card',
              description: 'Generate a visual welcome card image',
              value: _welcomeCardEnabled,
              onChanged: (v) {
                setState(() {
                  _welcomeCardEnabled = v;
                });
                _markChanged();
              },
            ),
            const SizedBox(height: 16),

            // Leave message status toggle
            _buildToggleCard(
              title: 'Enable Leave Messages',
              description: 'Send goodbye message when a member leaves',
              value: _leaveEnabled,
              onChanged: (v) {
                setState(() {
                  _leaveEnabled = v;
                });
                _markChanged();
              },
            ),
            if (_leaveEnabled) ...[
              const SizedBox(height: 16),
              // Leave message channel
              _buildSectionHeader('LEAVE MESSAGE CHANNEL'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _leaveChannelId,
                dropdownColor: const Color(FlickoColors.bgSecondary),
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                decoration: _inputDecoration('Select leave message channel'),
                items: _channels.map((ch) {
                  return DropdownMenuItem<String>(
                    value: ch['id'] as String,
                    child: Text('# ${ch['name']}', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _leaveChannelId = val;
                  });
                  _markChanged();
                },
              ),
              const SizedBox(height: 16),

              // Leave message template
              _buildSectionHeader('LEAVE MESSAGE'),
              const SizedBox(height: 8),
              TextField(
                controller: _leaveMsgController,
                maxLines: 3,
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                decoration: _inputDecoration('Leave message template'),
                onChanged: (_) => _markChanged(),
              ),
            ],
            const SizedBox(height: 24),

            // Auto roles section
            _buildSectionHeader('AUTO ASSIGNED ROLES'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(FlickoRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatically assign these roles to new members:',
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      ..._autoRoles.map((roleId) {
                        final role = _roles.firstWhere((r) => r['id'] == roleId, orElse: () => {'name': 'Unknown Role'});
                        return Chip(
                          label: Text(
                            role['name'],
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          ),
                          backgroundColor: const Color(FlickoColors.blurple),
                          deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                          onDeleted: () {
                            setState(() {
                              _autoRoles.remove(roleId);
                            });
                            _markChanged();
                          },
                        );
                      }),
                      if (_roles.length > _autoRoles.length)
                        DropdownButton<String>(
                          hint: Text('Add role...', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13)),
                          icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
                          underline: Container(),
                          items: _roles
                              .where((role) => !_autoRoles.contains(role['id']))
                              .map((role) => DropdownMenuItem<String>(
                                    value: role['id'] as String,
                                    child: Text(role['name'] as String, style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                                  ))
                              .toList(),
                          onChanged: (roleId) {
                            if (roleId != null) {
                              setState(() {
                                _autoRoles.add(roleId);
                              });
                              _markChanged();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Template Variables
            _buildSectionHeader('TEMPLATE VARIABLES'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(FlickoRadius.lg),
              ),
              child: Column(
                children: [
                  _buildVariableRow('{{user}}', 'Mentions the user'),
                  _buildVariableRow('{{username}}', "User's display name"),
                  _buildVariableRow('{{server}}', 'Server name'),
                  _buildVariableRow('{{memberCount}}', 'Total member count'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(FlickoRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(FlickoColors.blurple),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: const Color(FlickoColors.textMuted),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildVariableRow(String variable, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            variable,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.blurple),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            desc,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
