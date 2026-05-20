import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/button.dart';
import 'package:mobile/features/shared/presentation/widgets/card.dart' as flicko_card;
import 'package:mobile/features/shared/presentation/widgets/input.dart';
import 'package:mobile/features/shared/presentation/widgets/modal.dart';

import 'dart:math';

class TemplatesSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const TemplatesSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<TemplatesSettingsScreen> createState() => _TemplatesSettingsScreenState();
}

class _TemplatesSettingsScreenState extends ConsumerState<TemplatesSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _templates = [];
  String? _errorMessage;
  bool _showCreateModal = false;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isCreating = false;
  String? _addingPreset;

  final _starterPresets = [
    {
      'id': 'gaming',
      'title': 'Gaming server',
      'description': 'General, LFG, voice lounge, and staff role',
      'channels': [
        {'name': 'welcome', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'lfg', 'type': 'text'},
        {'name': 'Lounge', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Admin', 'color': '#ED4245'},
        {'name': 'Member', 'color': '#99AAB5'},
      ],
    },
    {
      'id': 'study',
      'title': 'Study group',
      'description': 'Quiet rooms, homework help, announcements',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'Study Room 1', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Moderator', 'color': '#5865F2'},
        {'name': 'Student', 'color': '#57F287'},
      ],
    },
    {
      'id': 'community',
      'title': 'Community hub',
      'description': 'Introductions, off-topic, and events',
      'channels': [
        {'name': 'rules', 'type': 'text'},
        {'name': 'introductions', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'events', 'type': 'text'},
      ],
      'roles': [
        {'name': 'Member', 'color': '#EB459E'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('server_templates')
          .select('*')
          .eq('source_server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _templates = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addPreset(Map<String, dynamic> preset) async {
    setState(() => _addingPreset = preset['id']);

    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      final response = await Supabase.instance.client
          .from('server_templates')
          .insert({'code': List.generate(12, (index) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(62)]).join(),
            'name': preset['title'],
            'description': preset['description'],
            'source_server_id': widget.serverId,
            'creator_id': currentUser?.id,
            'template_data': {
              'channels': preset['channels'],
              'roles': preset['roles'],
            },
            'usage_count': 0,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      setState(() {
        _templates.insert(0, response);
        _addingPreset = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template added'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _addingPreset = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add template: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _createTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      final response = await Supabase.instance.client
          .from('server_templates')
          .insert({'code': List.generate(12, (index) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(62)]).join(),
            'name': name,
            'description': _descController.text.trim(),
            'source_server_id': widget.serverId,
            'creator_id': currentUser?.id,
            'template_data': {'channels': [], 'roles': []},
            'usage_count': 0,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      setState(() {
        _templates.insert(0, response);
        _showCreateModal = false;
        _nameController.clear();
        _descController.clear();
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template created'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create template: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    bool confirmed = false;
    if (mounted) {
      confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => Modal(
          visible: true,
          onClose: () => Navigator.of(context).pop(false),
          title: 'Delete Template',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete this template?',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      title: 'Cancel',
                      onPress: () => Navigator.of(context).pop(false),
                      variant: ButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Button(
                      title: 'Delete',
                      onPress: () => Navigator.of(context).pop(true),
                      variant: ButtonVariant.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ) ?? false;
    }

    if (confirmed) {
      try {
        await Supabase.instance.client
            .from('server_templates')
            .delete()
            .eq('id', templateId);

        setState(() {
          _templates.removeWhere((t) => t['id'] == templateId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template deleted'),
              backgroundColor: Color(FlickoColors.success),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: const Color(FlickoColors.danger),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Templates',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: () => _openCreateModal(),
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
            Text('Error loading templates', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Button(
              title: 'Retry',
              onPress: _loadTemplates,
              variant: ButtonVariant.primary,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStarterPresets(),
        const SizedBox(height: 24),
        _buildYourTemplates(),
      ],
    );
  }

  Widget _buildStarterPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STARTER TEMPLATES',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add a ready-made channel and role layout to this server as a reusable template.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        ..._starterPresets.map((preset) => _buildPresetCard(preset)),
        const SizedBox(height: 24),
        Text(
          'YOUR TEMPLATES',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(Map<String, dynamic> preset) {
    final isLoading = _addingPreset == preset['id'];
    return flicko_card.Card(
      elevation: flicko_card.CardElevation.subtle,
      margin: const EdgeInsets.only(bottom: 8),
      onPress: isLoading ? null : () => _addPreset(preset),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset['title'],
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset['description'],
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 13,
                    ),
                  ),
                  ],
                ),
              ),
              isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple)),
                    )
                  : const Icon(Icons.add_circle_outline, color: Color(FlickoColors.blurple), size: 26),
            ],
        ),
      ),
    );
  }

  Widget _buildYourTemplates() {
    if (_templates.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.description, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              'No saved templates yet',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Use starters above or snapshot your current server',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Button(
              title: 'Create from server',
              onPress: () => _openCreateModal(),
              variant: ButtonVariant.primary,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _templates.map((template) => _buildTemplateCard(template)).toList(),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final data = template['template_data'] as Map<String, dynamic>? ?? {};
    final channels = (data['channels'] as List?)?.length ?? 0;
    final roles = (data['roles'] as List?)?.length ?? 0;

    return flicko_card.Card(
      elevation: flicko_card.CardElevation.subtle,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.content_copy, color: Color(FlickoColors.blurple)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template['name'] ?? 'Unnamed',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (template['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          template['description'],
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textSecondary),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$channels channel${channels != 1 ? 's' : ''} • $roles role${roles != 1 ? 's' : ''} • Used ${template['usage_count'] ?? 0} times',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteTemplate(template['id']),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: const Color(FlickoColors.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Modal(
        visible: true,
        onClose: () {
          setState(() => _showCreateModal = false);
          Navigator.of(context).pop();
        },
        title: 'Create Template',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Input(
              controller: _nameController,
              label: 'Name',
              hint: 'Enter template name',
            ),
            const SizedBox(height: 16),
            Input(
              controller: _descController,
              label: 'Description (optional)',
              hint: 'Enter description',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Button(
              title: 'Create',
              onPress: _isCreating ? () {} : _createTemplate,
              variant: ButtonVariant.primary,
              loading: _isCreating,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
