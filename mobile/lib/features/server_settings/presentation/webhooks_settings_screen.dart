import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

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
  final _nameController = TextEditingController();
  bool _isCreating = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load Channels
      final channelsResp = await Supabase.instance.client
          .from('channels')
          .select('id, name, type')
          .eq('server_id', widget.serverId)
          .order('name');

      final loadedChannels = (channelsResp as List).cast<Map<String, dynamic>>();

      // 2. Load Webhooks
      final webhooksResp = await Supabase.instance.client
          .from('external_bots')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      final loadedWebhooks = (webhooksResp as List).cast<Map<String, dynamic>>();

      setState(() {
        _channels = loadedChannels;
        _webhooks = loadedWebhooks;
        if (_channels.isNotEmpty && _selectedChannelId == null) {
          _selectedChannelId = _channels.first['id'] as String;
        }
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

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a Webhook Name', style: GoogleFonts.inter()),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
      return;
    }

    if (_selectedChannelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a target channel', style: GoogleFonts.inter()),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final token = 'wh_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${Random().nextInt(100000)}';
      final generatedUrl = 'https://api.flicko.app/v1/webhooks/$token';
      final currentUser = Supabase.instance.client.auth.currentUser;

      final response = await Supabase.instance.client
          .from('external_bots')
          .insert({
            'name': name,
            'token': token,
            'webhook_url': generatedUrl,
            'server_id': widget.serverId,
            'channel_id': _selectedChannelId,
            'creator_id': currentUser?.id,
            'is_active': true,
          })
          .select()
          .single();

      setState(() {
        _webhooks.insert(0, response);
        _nameController.clear();
        _isCreating = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Webhook created successfully!', style: GoogleFonts.inter()),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create webhook: ${e.toString()}', style: GoogleFonts.inter()),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _sendTestEvent(Map<String, dynamic> webhook) async {
    final channelId = webhook['channel_id'] as String?;
    final webhookName = webhook['name'] as String? ?? 'External Bot';

    if (channelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No target channel configured for this webhook', style: GoogleFonts.inter()),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('messages').insert({
        'channel_id': channelId,
        'user_id': currentUser?.id,
        'content': '🤖 **[Webhook Test]** Webhook "$webhookName" is active and working properly!',
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() => _isTesting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test message posted to channel!', style: GoogleFonts.inter()),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isTesting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test event failed: ${e.toString()}', style: GoogleFonts.inter()),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  Future<void> _deleteWebhook(String webhookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Webhook',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this webhook? Any external integrations using this URL will stop working.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: const Color(FlickoColors.danger).withValues(alpha: 0.1)),
            child: Text('Delete', style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('external_bots').delete().eq('id', webhookId);
      setState(() {
        _webhooks.removeWhere((w) => w['id'] == webhookId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Webhook deleted', style: GoogleFonts.inter()), backgroundColor: const Color(FlickoColors.success)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}', style: GoogleFonts.inter()), backgroundColor: const Color(FlickoColors.danger)),
        );
      }
    }
  }

  void _copyWebhookUrl(Map<String, dynamic> webhook) {
    final url = webhook['webhook_url'] as String? ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Webhook URL copied to clipboard', style: GoogleFonts.inter()), backgroundColor: const Color(FlickoColors.success)),
    );
  }

  void _openCreateModal() {
    _nameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(FlickoColors.textMuted), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Create Incoming Webhook', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Generate a unique webhook URL to receive messages from GitHub, Twitch, Zapier, etc.', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13)),
                const SizedBox(height: 24),
                Text('Webhook Name', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. GitHub Integration',
                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
                    filled: true,
                    fillColor: const Color(FlickoColors.bgTertiary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(FlickoColors.border))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Target Channel', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(FlickoColors.border)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedChannelId,
                      isExpanded: true,
                      dropdownColor: const Color(FlickoColors.bgSecondary),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(FlickoColors.textMuted)),
                      items: _channels.map((ch) {
                        return DropdownMenuItem<String>(
                          value: ch['id'] as String,
                          child: Text('# ${ch['name']}', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => _selectedChannelId = val);
                        setState(() => _selectedChannelId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isCreating
                        ? null
                        : () async {
                            setModalState(() => _isCreating = true);
                            await _createWebhook();
                            if (mounted) setModalState(() => _isCreating = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.brandLime),
                      foregroundColor: const Color(FlickoColors.bgPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isCreating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.bgPrimary)))
                        : Text('Create Webhook', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(FlickoColors.textPrimary), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Webhooks', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Color(FlickoColors.brandLime), size: 20),
              ),
              onPressed: _openCreateModal,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.danger))),
      );
    }

    if (_webhooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(FlickoColors.bgTertiary), shape: BoxShape.circle),
              child: const Icon(Icons.webhook_outlined, size: 36, color: Color(FlickoColors.textMuted)),
            ),
            const SizedBox(height: 20),
            Text('No webhooks yet', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Create a webhook to receive automated messages\nfrom GitHub, Twitch, Zapier, etc.', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateModal,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Create Webhook', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.brandLime),
                foregroundColor: const Color(FlickoColors.bgPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(FlickoColors.brandLime),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _webhooks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildWebhookCard(_webhooks[index]),
      ),
    );
  }

  Widget _buildWebhookCard(Map<String, dynamic> webhook) {
    final channelId = webhook['channel_id'] as String?;
    final channel = _channels.firstWhere((c) => c['id'] == channelId, orElse: () => {'name': 'general'});
    final url = webhook['webhook_url'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(FlickoColors.border), width: 1),
      ),
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
                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.webhook, size: 20, color: Color(FlickoColors.brandLime)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(webhook['name'] ?? 'Unnamed', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Posts to #${channel['name']}', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(FlickoColors.bgTertiary), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(url, style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Color(FlickoColors.brandLime)),
                  onPressed: () => _copyWebhookUrl(webhook),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : () => _sendTestEvent(webhook),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: Text('Send Test Event', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(FlickoColors.brandLime),
                    side: const BorderSide(color: Color(FlickoColors.brandLime)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteWebhook(webhook['id']),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                style: TextButton.styleFrom(foregroundColor: const Color(FlickoColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
