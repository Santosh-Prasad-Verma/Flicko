import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/button.dart';
import 'package:mobile/features/shared/presentation/widgets/card.dart' as flicko_card;
import 'package:mobile/features/shared/presentation/widgets/input.dart';
import 'package:mobile/features/shared/presentation/widgets/modal.dart';

class WebhooksSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const WebhooksSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<WebhooksSettingsScreen> createState() => _WebhooksSettingsScreenState();
}

class _WebhooksSettingsScreenState extends ConsumerState<WebhooksSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _webhooks = [];
  List<Map<String, dynamic>> _channels = [];
  String? _selectedChannelId;
  String? _errorMessage;
  bool _showCreateModal = false;
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
    _loadChannels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final response = await Supabase.instance.client
          .from('channels')
          .select('id, name')
          .eq('server_id', widget.serverId)
          .order('position', ascending: true);

      if (mounted) {
        setState(() {
          _channels = (response as List).cast<Map<String, dynamic>>();
          if (_channels.isNotEmpty) {
            _selectedChannelId = _channels.first['id'] as String?;
          }
        });
      }
    } catch (e) {
      // Ignore silently
    }
  }

  Future<void> _loadWebhooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('webhooks')
          .select('*, channels!inner(server_id)')
          .eq('channels.server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _webhooks = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createWebhook() async {
    final name = _nameController.text.trim();
    final channelId = _selectedChannelId;

    if (name.isEmpty || channelId == null || channelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Channel are required')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final response = await Supabase.instance.client
          .from('webhooks')
          .insert({
            'name': name,
            'channel_id': channelId,
            'created_by': Supabase.instance.client.auth.currentUser?.id,
          })
          .select()
          .single();

      setState(() {
        _webhooks.add(response);
        _showCreateModal = false;
        _nameController.clear();
        _isCreating = false;
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close create modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Webhook created successfully'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create webhook: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _deleteWebhook(String webhookId) async {
    bool confirmed = false;
    if (mounted) {
      confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => Modal(
          visible: true,
          onClose: () => Navigator.of(context).pop(false),
          title: 'Delete Webhook',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete this webhook?',
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
            .from('webhooks')
            .delete()
            .eq('id', webhookId);

        setState(() {
          _webhooks.removeWhere((w) => w['id'] == webhookId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Webhook deleted'),
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

  void _copyWebhookUrl(Map<String, dynamic> webhook) {
    final url = 'https://api.flicko.app/webhooks/${webhook['id']}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard'),
        backgroundColor: Color(FlickoColors.success),
      ),
    );
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
          'Webhooks',
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
            Text('Error loading webhooks', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Button(
              title: 'Retry',
              onPress: _loadWebhooks,
              variant: ButtonVariant.primary,
            ),
          ],
        ),
      );
    }

    if (_webhooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text('No webhooks yet', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 16),
            Button(
              title: 'Create Webhook',
              onPress: () => _openCreateModal(),
              variant: ButtonVariant.primary,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _webhooks.length,
      itemBuilder: (context, index) => _buildWebhookCard(_webhooks[index]),
    );
  }

  Widget _buildWebhookCard(Map<String, dynamic> webhook) {
    return flicko_card.Card(
      elevation: flicko_card.CardElevation.subtle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link, color: Color(FlickoColors.blurple)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        webhook['name'] ?? 'Unnamed',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Created ${_formatDate(webhook['created_at'])}',
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Button(
                  title: 'Copy URL',
                  onPress: () => _copyWebhookUrl(webhook),
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                ),
                const SizedBox(width: 8),
                Button(
                  title: 'Delete',
                  onPress: () => _deleteWebhook(webhook['id']),
                  variant: ButtonVariant.danger,
                  size: ButtonSize.sm,
                ),
              ],
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
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Modal(
            visible: true,
            onClose: () {
              setState(() => _showCreateModal = false);
              Navigator.of(context).pop();
            },
            title: 'New Webhook',
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Input(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter webhook name',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Channel',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedChannelId,
                    dropdownColor: const Color(FlickoColors.bgSecondary),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(FlickoColors.textSecondary)),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(FlickoColors.bgSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(FlickoColors.border)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(FlickoColors.border)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(FlickoColors.brandLime)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _channels.isEmpty
                        ? [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(
                                'No channels available',
                                style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                              ),
                            )
                          ]
                        : _channels.map((channel) {
                            return DropdownMenuItem<String>(
                              value: channel['id'] as String,
                              child: Text(
                                '# ${channel['name'] ?? 'channel'}',
                                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                              ),
                            );
                          }).toList(),
                    onChanged: _channels.isEmpty
                        ? null
                        : (value) {
                            setModalState(() {
                              _selectedChannelId = value;
                            });
                            setState(() {
                              _selectedChannelId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 24),
                  Button(
                    title: 'Create',
                    onPress: _isCreating
                        ? () {}
                        : () async {
                            setModalState(() => _isCreating = true);
                            await _createWebhook();
                            if (mounted) {
                              setModalState(() => _isCreating = false);
                            }
                          },
                    variant: ButtonVariant.primary,
                    loading: _isCreating,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}
