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
  String? _errorMessage;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadWebhooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('external_bots')
          .select('*')
          .eq('server_id', widget.serverId)
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
    final webhookUrl = _urlController.text.trim();

    if (name.isEmpty || webhookUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Name and Webhook URL are required',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final response = await Supabase.instance.client
          .from('external_bots')
          .insert({
            'name': name,
            'webhook_url': webhookUrl,
            'server_id': widget.serverId,
            'creator_id': Supabase.instance.client.auth.currentUser?.id,
            'is_active': true,
          })
          .select()
          .single();

      setState(() {
        _webhooks.insert(0, response);
        _nameController.clear();
        _urlController.clear();
        _isCreating = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Webhook created successfully',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create webhook: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Webhook',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this webhook? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(FlickoColors.danger).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.danger),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('external_bots')
          .delete()
          .eq('id', webhookId);

      setState(() {
        _webhooks.removeWhere((w) => w['id'] == webhookId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Webhook deleted',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  void _copyWebhookUrl(Map<String, dynamic> webhook) {
    final url = webhook['webhook_url'] as String? ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No webhook URL available',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(FlickoColors.warning),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'URL copied to clipboard',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(FlickoColors.success),
      ),
    );
  }

  void _openCreateModal() {
    _nameController.clear();
    _urlController.clear();

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
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.textMuted),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'New Webhook',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create an external bot webhook for this server.',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Name',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. GitHub Notifications',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(FlickoColors.bgTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.border)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.border)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.brandLime), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Webhook URL',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                  ),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/webhook',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(FlickoColors.bgTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.border)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.border)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.brandLime), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            setState(() => _isCreating = true);
                            await _createWebhook();
                            if (mounted) {
                              setModalState(() => _isCreating = false);
                              setState(() => _isCreating = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.brandLime),
                      foregroundColor: const Color(FlickoColors.bgPrimary),
                      disabledBackgroundColor: const Color(FlickoColors.brandLimeDim),
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
                              color: Color(FlickoColors.bgPrimary),
                            ),
                          )
                        : Text(
                            'Create Webhook',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
        title: Text(
          'Webhooks',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
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
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 32, color: Color(FlickoColors.danger)),
              ),
              const SizedBox(height: 20),
              Text(
                'Error loading webhooks',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                height: 42,
                child: ElevatedButton(
                  onPressed: _loadWebhooks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: const Color(FlickoColors.bgPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.webhook_outlined, size: 36, color: Color(FlickoColors.textMuted)),
            ),
            const SizedBox(height: 20),
            Text(
              'No webhooks yet',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a webhook to integrate external\nservices with this server.',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _openCreateModal,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Create Webhook',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.brandLime),
                  foregroundColor: const Color(FlickoColors.bgPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWebhooks,
      color: const Color(FlickoColors.brandLime),
      backgroundColor: const Color(FlickoColors.bgSecondary),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _webhooks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildWebhookCard(_webhooks[index]),
      ),
    );
  }

  Widget _buildWebhookCard(Map<String, dynamic> webhook) {
    final isActive = webhook['is_active'] as bool? ?? false;
    final description = webhook['description'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(FlickoColors.border),
          width: 1,
        ),
      ),
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
                      Text(
                        webhook['name'] ?? 'Unnamed',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(FlickoColors.success).withValues(alpha: 0.1)
                        : const Color(FlickoColors.textMuted).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.inter(
                      color: isActive
                          ? const Color(FlickoColors.success)
                          : const Color(FlickoColors.textMuted),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: const Color(FlickoColors.border),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextButton.icon(
                      onPressed: () => _copyWebhookUrl(webhook),
                      icon: const Icon(Icons.copy, size: 15),
                      label: Text(
                        'Copy URL',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(FlickoColors.brandLime),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: TextButton.icon(
                    onPressed: () => _deleteWebhook(webhook['id']),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(FlickoColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
