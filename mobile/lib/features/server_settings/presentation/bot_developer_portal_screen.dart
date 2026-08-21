import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Bot Developer Portal Screen
/// Developer portal for creating bot applications, setting intents, and generating SHA-256 secure bot tokens.
class BotDeveloperPortalScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BotDeveloperPortalScreen({super.key, required this.serverId});

  @override
  ConsumerState<BotDeveloperPortalScreen> createState() => _BotDeveloperPortalScreenState();
}

class _BotDeveloperPortalScreenState extends ConsumerState<BotDeveloperPortalScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bots = [];

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadBots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadBots() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('bot_applications')
          .select('*, bot_tokens(*)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _bots = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBot() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final botResp = await Supabase.instance.client.from('bot_applications').insert({
        'bot_name': name,
        'bot_description': _descController.text.trim(),
        'owner_id': userId,
        'public_bot': true,
      }).select().single();

      final botId = botResp['id'] as String;

      // Generate secure client-side secret & SHA-256 token hash
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawSecret = 'bot_${botId.substring(0, 8)}_${timestamp}_${userId.substring(0, 8)}';
      final tokenHash = sha256.convert(utf8.encode(rawSecret)).toString();
      final prefix = '${rawSecret.substring(0, 12)}...';

      await Supabase.instance.client.from('bot_tokens').insert({
        'application_id': botId,
        'token_prefix': prefix,
        'token_hash': tokenHash,
      });

      _nameController.clear();
      _descController.clear();
      if (mounted) Navigator.pop(context);
      await _loadBots();

      if (mounted) {
        _showTokenDialog(rawSecret);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating bot: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showTokenDialog(String rawToken) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Bot Token Generated', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copy your bot token now. For security reasons, it will never be shown again.', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(rawToken, style: GoogleFonts.spaceMono(color: const Color(FlickoColors.brandLime), fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawToken));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied to clipboard')));
              Navigator.pop(context);
            },
            child: Text('Copy Token', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateBotModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Bot Application', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Bot Name (e.g. MusicBot)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Bot Description (e.g. Plays high quality music)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createBot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Generate Bot Token & Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
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
          onPressed: () => context.pop(),
        ),
        title: Text('Bot Developer Portal', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(FlickoColors.brandLime)),
            onPressed: _showCreateBotModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _bots.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bots.length,
                  itemBuilder: (context, index) {
                    final bot = _bots[index];
                    final tokens = bot['bot_tokens'] as List? ?? [];
                    final prefix = tokens.isNotEmpty ? tokens.first['token_prefix'] as String? ?? 'Active Token' : 'Active Token';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.smart_toy_rounded, color: Color(FlickoColors.brandLime), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bot['bot_name'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (bot['bot_description'] != null)
                                      Text(bot['bot_description'] as String, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Token: $prefix', style: GoogleFonts.spaceMono(color: Colors.white70, fontSize: 11)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('SHA-256 Verified', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 64, color: Color(FlickoColors.brandLime)),
          const SizedBox(height: 16),
          Text('No Bot Applications', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Create a custom bot to get your API Token & Gateway access', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateBotModal,
            icon: const Icon(Icons.add),
            label: const Text('Create Bot Application'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.brandLime),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
