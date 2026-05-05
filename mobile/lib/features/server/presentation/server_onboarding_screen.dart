import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ServerOnboardingScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerOnboardingScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerOnboardingScreen> createState() => _ServerOnboardingScreenState();
}

class _ServerOnboardingScreenState extends ConsumerState<ServerOnboardingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _config;
  int _step = 0;
  final Map<String, List<String>> _selectedOptions = {};
  bool _rulesAccepted = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await Supabase.instance.client
          .from('onboarding_configs')
          .select('*')
          .eq('server_id', widget.serverId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _isLoading = false;
          _config = null;
        });
        return;
      }

      setState(() {
        _config = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalSteps {
    if (_config == null) return 1;
    final prompts = _config!['prompts'] as List? ?? [];
    return 1 + prompts.length + 1;
  }

  bool get _isLastStep => _step == _totalSteps - 1;

  Future<void> _handleNext() async {
    if (_isLastStep) {
      await _completeOnboarding();
    } else {
      setState(() => _step = _step + 1);
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (user == null) return;

      setState(() => _isSubmitting = true);

      await Supabase.instance.client.from('onboarding_completions').insert({
        'server_id': widget.serverId,
        'user_id': user.id,
        'responses': _selectedOptions,
        'completed_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete onboarding: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  void _toggleOption(String promptId, String optionLabel) {
    setState(() {
      final current = _selectedOptions[promptId] ?? [];
      final has = current.contains(optionLabel);
      _selectedOptions[promptId] =
          has ? current.where((o) => o != optionLabel).toList() : [...current, optionLabel];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        
        body: const Center(
          child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        
        appBar: AppBar(
          
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
              const SizedBox(height: 16),
              Text('Error loading onboarding', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_config == null || !_config!['enabled']) {
      return Scaffold(
        
        appBar: AppBar(
          
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No onboarding configured', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Onboarding',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: const Color(FlickoColors.bgTertiary),
            valueColor: const AlwaysStoppedAnimation(Color(FlickoColors.blurple)),
          ),
          Expanded(child: _buildStepContent()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final prompts = _config!['prompts'] as List? ?? [];
    final currentPrompt = _step > 0 && _step <= prompts.length ? prompts[_step - 1] : null;

    if (_step == 0) {
      return _buildWelcomeStep();
    } else if (currentPrompt != null) {
      return _buildPromptStep(currentPrompt);
    } else {
      return _buildCompletionStep();
    }
  }

  Widget _buildWelcomeStep() {
    final rules = _config!['rules'] as List? ?? [];
    final requireAcceptance = _config!['require_rules_acceptance'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 64, color: Color(FlickoColors.blurple)),
          const SizedBox(height: 24),
          Text(
            _config!['welcome_title'] ?? 'Welcome!',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (_config!['welcome_description'] != null) ...[
            const SizedBox(height: 16),
            Text(
              _config!['welcome_description'] as String,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server Rules',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...rules.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(FlickoColors.blurple),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value as String,
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textSecondary),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (requireAcceptance) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(FlickoColors.bgTertiary)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _rulesAccepted = !_rulesAccepted),
                      child: Row(
                        children: [
                          Icon(
                            _rulesAccepted ? Icons.check_box : Icons.check_box_outline_blank,
                            color: _rulesAccepted ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'I agree to the server rules',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptStep(Map<String, dynamic> prompt) {
    final options = prompt['options'] as List? ?? [];
    final promptId = prompt['id'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt['title'] as String,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt['description'] as String,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final label = opt['label'] as String;
            final selected = (_selectedOptions[promptId] ?? []).contains(label);
            return GestureDetector(
              onTap: () => _toggleOption(promptId, label),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? const Color(FlickoColors.bgTertiary) : const Color(FlickoColors.bgSecondary),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? const Color(FlickoColors.blurple) : const Color(FlickoColors.bgTertiary),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompletionStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Color(FlickoColors.success)),
          const SizedBox(height: 24),
          Text(
            "You're all set!",
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy the server',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final requireAcceptance = _config!['require_rules_acceptance'] as bool? ?? false;
    final canProceed = _step > 0 || !requireAcceptance || _rulesAccepted;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: () => setState(() => _step = _step - 1),
              child: const Text('Back'),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: canProceed && !_isSubmitting ? _handleNext : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isLastStep ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }
}
