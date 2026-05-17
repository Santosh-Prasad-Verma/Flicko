import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class AutomodSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;
  const AutomodSettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<AutomodSettingsScreen> createState() => _AutomodSettingsScreenState();
}

class _AutomodSettingsScreenState extends ConsumerState<AutomodSettingsScreen> {
  bool _isLoading = true;
  
  // Mapping rules to UI names
  Map<String, Map<String, dynamic>> _activeRules = {};

  final int _capsThreshold = 70;
  final int _emojiMax = 10;
  final int _mentionMax = 5;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('auto_mod_rules')
          .select()
          .eq('server_id', widget.serverId);

      final rules = <String, Map<String, dynamic>>{};
      for (var rule in data) {
        final name = rule['name'] as String;
        rules[name] = rule;
      }

      if (mounted) {
        setState(() {
          _activeRules = rules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading AutoMod rules: $e')),
        );
      }
    }
  }

  Future<void> _toggleRule(String ruleName, bool enabled, String ruleType, Map<String, dynamic> triggerConfig) async {
    // Optimistic UI update
    final wasEnabled = _activeRules.containsKey(ruleName) && _activeRules[ruleName]!['is_enabled'] == true;
    
    setState(() {
      if (enabled) {
        if (_activeRules.containsKey(ruleName)) {
           _activeRules[ruleName]!['is_enabled'] = true;
        } else {
           _activeRules[ruleName] = {
             'name': ruleName,
             'is_enabled': true,
           };
        }
      } else {
        if (_activeRules.containsKey(ruleName)) {
           _activeRules[ruleName]!['is_enabled'] = false;
        }
      }
    });

    try {
      final client = Supabase.instance.client;
      if (enabled) {
        // Find existing rule to enable, or create
        final existing = await client
            .from('auto_mod_rules')
            .select()
            .eq('server_id', widget.serverId)
            .eq('name', ruleName)
            .maybeSingle();

        if (existing != null) {
          await client.from('auto_mod_rules').update({'is_enabled': true}).eq('id', existing['id']);
        } else {
          await client.from('auto_mod_rules').insert({
            'server_id': widget.serverId,
            'name': ruleName,
            'rule_type': ruleType,
            'trigger_config': triggerConfig,
            'action_type': 'block',
            'action_config': {},
            'is_enabled': true,
          });
        }
      } else {
        // Disable existing rule
        final existing = await client
            .from('auto_mod_rules')
            .select()
            .eq('server_id', widget.serverId)
            .eq('name', ruleName)
            .maybeSingle();
            
        if (existing != null) {
          await client.from('auto_mod_rules').update({'is_enabled': false}).eq('id', existing['id']);
        }
      }
      // Reload strictly from server to sync IDs
      await _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
        await _loadRules(); // Revert on error
      }
    }
  }

  bool _isRuleEnabled(String name) {
    return _activeRules.containsKey(name) && _activeRules[name]!['is_enabled'] == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'AutoMod',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple))),
      );
    }

    // Has any rule enabled
    bool isAnyEnabled = _activeRules.values.any((r) => r['is_enabled'] == true);

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
          'AutoMod',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AutoMod',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Automatically filter spam, links, excessive caps and more.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters section
          Text(
            'FILTERS',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildFilterToggle(
                  'Invite Link Filter',
                  'Block Discord/server invite links',
                  _isRuleEnabled('Invite Link Filter'),
                  (v) => _toggleRule('Invite Link Filter', v, 'links', {'type': 'invite_links'}),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildFilterToggle(
                  'URL Filter',
                  'Block all URLs',
                  _isRuleEnabled('URL Filter'),
                  (v) => _toggleRule('URL Filter', v, 'links', {'type': 'all_links'}),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildFilterToggle(
                  'Caps Filter',
                  'Block excessive caps (threshold: $_capsThreshold%)',
                  _isRuleEnabled('Caps Filter'),
                  (v) => _toggleRule('Caps Filter', v, 'spam', {'type': 'caps', 'threshold': _capsThreshold}),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildFilterToggle(
                  'Emoji Spam Filter',
                  'Block messages with $_emojiMax+ emojis',
                  _isRuleEnabled('Emoji Filter'),
                  (v) => _toggleRule('Emoji Filter', v, 'spam', {'type': 'emoji', 'max': _emojiMax}),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildFilterToggle(
                  'Mention Spam Filter',
                  'Block messages with $_mentionMax+ mentions',
                  _isRuleEnabled('Mention Filter'),
                  (v) => _toggleRule('Mention Filter', v, 'mentions', {'max': _mentionMax}),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildFilterToggle(
                  'Duplicate Message Filter',
                  'Block repeated messages',
                  _isRuleEnabled('Duplicate Filter'),
                  (v) => _toggleRule('Duplicate Filter', v, 'spam', {'type': 'duplicate'}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Exemptions
          Text(
            'EXEMPTIONS',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('Exempt Roles', '0 roles'),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildInfoRow('Exempt Channels', '0 channels'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Commands reference
          Text(
            'COMMANDS',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('/automod enable', 'Enable AutoMod for this server'),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildInfoRow('/automod disable', 'Disable AutoMod'),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildInfoRow('/automod status', 'View current filter status'),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildInfoRow('/automod configure', 'Toggle individual filters'),
                const Divider(height: 1, indent: 16, color: Color(0xFF232428)),
                _buildInfoRow('/automod-exempt', 'Exempt a role from filters'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(String label, String description, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(FlickoColors.blurple),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
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
    );
  }
}
