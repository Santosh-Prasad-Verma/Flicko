import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Server Onboarding Settings Screen
///
/// Configure welcome screens, server rules, and new member screening.
/// Uses `screening_rules` and `member_screening_status` tables.
class OnboardingSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;
  const OnboardingSettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<OnboardingSettingsScreen> createState() => _OnboardingSettingsScreenState();
}

class _ScreeningRule {
  final String? id;
  String title;
  String? description;
  bool isRequired;
  bool isEnabled;
  int position;

  _ScreeningRule({
    this.id,
    required this.title,
    this.description,
    this.isRequired = true,
    this.isEnabled = true,
    this.position = 0,
  });
}

class _OnboardingSettingsScreenState extends ConsumerState<OnboardingSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _onboardingEnabled = false;
  bool _previewOpen = false;

  final TextEditingController _welcomeTitleController = TextEditingController();
  final TextEditingController _welcomeDescController = TextEditingController();
  final TextEditingController _newRuleController = TextEditingController();

  List<_ScreeningRule> _rules = [];
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _welcomeTitleController.dispose();
    _welcomeDescController.dispose();
    _newRuleController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      // Load screening rules for this server
      final response = await _client
          .from('screening_rules')
          .select()
          .eq('server_id', widget.serverId)
          .order('position', ascending: true);

      final rules = (response as List).map((row) => _ScreeningRule(
        id: row['id'],
        title: row['title'] ?? '',
        description: row['description'],
        isRequired: row['is_required'] ?? true,
        isEnabled: row['is_enabled'] ?? true,
        position: row['position'] ?? 0,
      )).toList();

      // Load server metadata for welcome config
      final serverResp = await _client
          .from('servers')
          .select('onboarding_config')
          .eq('id', widget.serverId)
          .maybeSingle();

      Map<String, dynamic>? config;
      if (serverResp != null) {
        config = serverResp['onboarding_config'] as Map<String, dynamic>?;
      }

      setState(() {
        _rules = rules;
        _onboardingEnabled = config?['enabled'] == true || rules.isNotEmpty;
        _welcomeTitleController.text = config?['welcome_title'] ?? '';
        _welcomeDescController.text = config?['welcome_description'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Server may not have onboarding_config column, fall back gracefully
      if (mounted) {
        setState(() {
          _onboardingEnabled = false;
          _rules = [];
        });
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Save/update screening rules
      // Delete removed rules (ones that existed in DB but are no longer in list)
      final existingIds = _rules.where((r) => r.id != null).map((r) => r.id!).toList();
      if (existingIds.isNotEmpty) {
        // We'll just upsert existing and insert new ones
        for (int i = 0; i < _rules.length; i++) {
          final rule = _rules[i];
          if (rule.id != null) {
            await _client.from('screening_rules').update({
              'title': rule.title,
              'description': rule.description,
              'is_required': rule.isRequired,
              'is_enabled': rule.isEnabled,
              'position': i,
            }).eq('id', rule.id!);
          } else {
            final resp = await _client.from('screening_rules').insert({
              'server_id': widget.serverId,
              'title': rule.title,
              'description': rule.description,
              'is_required': rule.isRequired,
              'is_enabled': rule.isEnabled,
              'position': i,
              'created_by': ref.read(currentUserIdProvider),
            }).select().single();
            rule.id == resp['id'];
          }
        }
      } else {
        // All new rules
        for (int i = 0; i < _rules.length; i++) {
          final rule = _rules[i];
          await _client.from('screening_rules').insert({
            'server_id': widget.serverId,
            'title': rule.title,
            'description': rule.description,
            'is_required': rule.isRequired,
            'is_enabled': rule.isEnabled,
            'position': i,
            'created_by': ref.read(currentUserIdProvider),
          }).select().single();
        }
      }

      // 2. Try to save welcome config in server metadata
      try {
        await _client.from('servers').update({
          'onboarding_config': {
            'enabled': _onboardingEnabled,
            'welcome_title': _welcomeTitleController.text.trim(),
            'welcome_description': _welcomeDescController.text.trim(),
          },
        }).eq('id', widget.serverId);
      } catch (_) {
        // Column may not exist - that's OK, rules are already saved
      }

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onboarding settings saved'),
            backgroundColor: Color(FlickoColors.green),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: const Color(FlickoColors.danger)),
        );
      }
    }
  }

  void _addRule() {
    final text = _newRuleController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _rules.add(_ScreeningRule(
        title: text,
        position: _rules.length,
      ));
      _newRuleController.clear();
    });
    _markChanged();
  }

  void _removeRule(int index) {
    HapticFeedback.lightImpact();
    final rule = _rules[index];
    // If it exists in DB, delete it
    if (rule.id != null) {
      _client.from('screening_rules').delete().eq('id', rule.id!).then((_) {});
    }
    setState(() => _rules.removeAt(index));
    _markChanged();
  }

  void _showPreview() {
    setState(() => _previewOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Onboarding',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isSaving ? _save : null,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Enable toggle ──
                      _buildToggleCard(
                        title: 'Enable Onboarding',
                        description: 'Show a welcome screen and rules to new members when they join.',
                        value: _onboardingEnabled,
                        onChanged: (v) {
                          setState(() => _onboardingEnabled = v);
                          _markChanged();
                        },
                      ),

                      if (_onboardingEnabled) ...[
                        const SizedBox(height: 24),

                        // ── Welcome Title ──
                        _buildSectionHeader('WELCOME TITLE'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _welcomeTitleController,
                          onChanged: (_) => _markChanged(),
                          maxLength: 100,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 15,
                          ),
                          decoration: _inputDecoration('Welcome to our server!'),
                        ),

                        const SizedBox(height: 16),

                        // ── Description ──
                        _buildSectionHeader('DESCRIPTION'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _welcomeDescController,
                          onChanged: (_) => _markChanged(),
                          maxLength: 300,
                          maxLines: 3,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration('Tell new members about your server'),
                        ),

                        const SizedBox(height: 24),

                        // ── Server Rules ──
                        Row(
                          children: [
                            Expanded(child: _buildSectionHeader('SERVER RULES')),
                            Text(
                              '${_rules.length}/20',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Rules list
                        ..._rules.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final rule = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(FlickoColors.bgSecondary),
                              borderRadius: BorderRadius.circular(FlickoRadius.md),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${idx + 1}.',
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.blurple),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rule.title,
                                    style: GoogleFonts.inter(
                                      color: const Color(FlickoColors.textPrimary),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _removeRule(idx),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Color(FlickoColors.danger),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Add rule input
                        if (_rules.length < 20) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newRuleController,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textPrimary),
                                    fontSize: 14,
                                  ),
                                  decoration: _inputDecoration('Add a rule...'),
                                  onSubmitted: (_) => _addRule(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: const Color(FlickoColors.blurple),
                                borderRadius: BorderRadius.circular(FlickoRadius.md),
                                child: InkWell(
                                  onTap: _addRule,
                                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(Icons.add, color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── Require Rules Acceptance ──
                        _buildToggleCard(
                          title: 'Require Rules Acceptance',
                          description: 'Members must accept rules before they can participate in the server.',
                          value: _rules.any((r) => r.isRequired),
                          onChanged: (v) {
                            setState(() {
                              for (var rule in _rules) {
                                rule.isRequired = v;
                              }
                            });
                            _markChanged();
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Preview Card ──
                        InkWell(
                          onTap: _showPreview,
                          borderRadius: BorderRadius.circular(FlickoRadius.lg),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(FlickoColors.bgSecondary),
                              borderRadius: BorderRadius.circular(FlickoRadius.lg),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(FlickoColors.blurple).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                                  ),
                                  child: const Icon(Icons.visibility_outlined, color: Color(FlickoColors.blurple), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Preview welcome screen',
                                        style: GoogleFonts.inter(
                                          color: const Color(FlickoColors.textPrimary),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'See how new members will experience onboarding.',
                                        style: GoogleFonts.inter(
                                          color: const Color(FlickoColors.textMuted),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Color(FlickoColors.textMuted), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                // ── Preview Modal ──
                if (_previewOpen) _buildPreviewOverlay(),
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
            activeThumbColor: const Color(FlickoColors.blurple),
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
      counterStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildPreviewOverlay() {
    final title = _welcomeTitleController.text.trim().isNotEmpty
        ? _welcomeTitleController.text.trim()
        : 'Welcome';
    final desc = _welcomeDescController.text.trim();
    final hasRules = _rules.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _previewOpen = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(FlickoRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.waving_hand, color: Color(FlickoColors.blurple), size: 32),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (hasRules) ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RULES',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _rules.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${index + 1}. ${_rules[index].title}',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textPrimary),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_rules.any((r) => r.isRequired)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Members must accept these rules before participating.',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.blurple),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _previewOpen = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.blurple),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FlickoRadius.md),
                        ),
                      ),
                      child: Text(
                        'Close Preview',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
