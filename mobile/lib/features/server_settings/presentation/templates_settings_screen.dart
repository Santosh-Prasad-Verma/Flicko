import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/button.dart';
import 'package:mobile/features/shared/presentation/widgets/card.dart';
import 'package:mobile/features/shared/presentation/widgets/modal.dart';

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
    {
      'id': 'business',
      'title': 'Business/Corporate',
      'description': 'Team channels, announcements, project rooms',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'projects', 'type': 'text'},
        {'name': 'Meeting Room', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'CEO', 'color': '#ED4245'},
        {'name': 'Manager', 'color': '#FEE75C'},
        {'name': 'Employee', 'color': '#5865F2'},
      ],
    },
    {
      'id': 'music',
      'title': 'Music & Streaming',
      'description': 'Music sharing, streaming, voice channels',
      'channels': [
        {'name': 'music-share', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'streaming', 'type': 'text'},
        {'name': 'Music Lounge', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'DJ', 'color': '#EB459E'},
        {'name': 'Listener', 'color': '#57F287'},
      ],
    },
    {
      'id': 'education',
      'title': 'Education/Online Course',
      'description': 'Lecture halls, Q&A, resource sharing',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'homework-help', 'type': 'text'},
        {'name': 'resources', 'type': 'text'},
        {'name': 'Lecture Hall', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Instructor', 'color': '#ED4245'},
        {'name': 'Teaching Assistant', 'color': '#FEE75C'},
        {'name': 'Student', 'color': '#5865F2'},
      ],
    },
    {
      'id': 'support',
      'title': 'Support/Help Desk',
      'description': 'Ticket system, FAQ, support channels',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'faq', 'type': 'text'},
        {'name': 'support-tickets', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
      ],
      'roles': [
        {'name': 'Support Lead', 'color': '#ED4245'},
        {'name': 'Support Agent', 'color': '#57F287'},
        {'name': 'User', 'color': '#99AAB5'},
      ],
    },
    {
      'id': 'development',
      'title': 'Development/Coding',
      'description': 'Code sharing, project collaboration, tech talk',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'code-review', 'type': 'text'},
        {'name': 'projects', 'type': 'text'},
        {'name': 'Dev Lounge', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Lead Developer', 'color': '#ED4245'},
        {'name': 'Developer', 'color': '#5865F2'},
        {'name': 'Contributor', 'color': '#57F287'},
      ],
    },
    {
      'id': 'creative',
      'title': 'Art & Creative',
      'description': 'Art sharing, feedback, collaboration',
      'channels': [
        {'name': 'showcase', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'feedback', 'type': 'text'},
        {'name': 'collaboration', 'type': 'text'},
        {'name': 'Art Studio', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Featured Artist', 'color': '#EB459E'},
        {'name': 'Artist', 'color': '#57F287'},
        {'name': 'Member', 'color': '#99AAB5'},
      ],
    },
    {
      'id': 'fitness',
      'title': 'Fitness & Health',
      'description': 'Workout plans, nutrition, motivation',
      'channels': [
        {'name': 'announcements', 'type': 'text'},
        {'name': 'general', 'type': 'text'},
        {'name': 'workout-plans', 'type': 'text'},
        {'name': 'nutrition', 'type': 'text'},
        {'name': 'Motivation', 'type': 'voice'},
      ],
      'roles': [
        {'name': 'Coach', 'color': '#ED4245'},
        {'name': 'Member', 'color': '#57F287'},
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

      final templates = (response as List).cast<Map<String, dynamic>>();

      // Convert starter presets to template format for display
      final presetTemplates = _starterPresets.map((preset) => {
        'id': preset['id'],
        'code': preset['id'],
        'name': preset['title'],
        'description': preset['description'],
        'serialized_data': {
          'channels': preset['channels'],
          'roles': preset['roles'],
        },
        'usage_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'is_preset': true,
      }).toList();

      setState(() {
        _templates = [...presetTemplates, ...templates];
        _isLoading = false;
      });
    } catch (e) {
      // If database query fails, still show starter presets
      final presetTemplates = _starterPresets.map((preset) => {
        'id': preset['id'],
        'code': preset['id'],
        'name': preset['title'],
        'description': preset['description'],
        'serialized_data': {
          'channels': preset['channels'],
          'roles': preset['roles'],
        },
        'usage_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'is_preset': true,
      }).toList();

      setState(() {
        _templates = presetTemplates;
        _isLoading = false;
      });
    }
  }


  Future<void> _deleteTemplate(String templateId) async {
    final template = _templates.firstWhere((t) => t['id'] == templateId);
    if (template['is_preset'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete pre-made templates'),
            backgroundColor: Color(FlickoColors.danger),
          ),
        );
      }
      return;
    }

    bool confirmed = false;
    if (mounted) {
      confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => Modal(
          visible: true,
          onClose: () => Navigator.pop(context),
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Templates',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
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
        _buildYourTemplates(),
      ],
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
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEMPLATES',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._templates.map((template) => _buildTemplateCard(template)),
      ],
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final data = template['serialized_data'] as Map<String, dynamic>? ?? {};
    final channels = (data['channels'] as List?)?.length ?? 0;
    final roles = (data['roles'] as List?)?.length ?? 0;

    return Card(
      elevation: CardElevation.subtle,
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
}
