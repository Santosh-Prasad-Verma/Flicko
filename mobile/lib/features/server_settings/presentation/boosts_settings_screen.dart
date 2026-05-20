import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class BoostsSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const BoostsSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<BoostsSettingsScreen> createState() => _BoostsSettingsScreenState();
}

class _BoostsSettingsScreenState extends ConsumerState<BoostsSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _boostData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBoostData();
  }

  Future<void> _loadBoostData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('server_boosts')
          .select('*')
          .eq('server_id', widget.serverId)
          .maybeSingle();

      setState(() {
        _boostData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.blurple),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.blurple),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Server Boosts',
          style: GoogleFonts.inter(
            color: Colors.white,
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
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            Text('Error loading boosts', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBoostData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Retry', style: TextStyle(color: Color(FlickoColors.blurple))),
            ),
          ],
        ),
      );
    }

    final boostCount = _boostData?['boost_count'] ?? 0;
    final boostLevel = _boostData?['boost_level'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildBoostCard(boostCount, boostLevel),
          const SizedBox(height: 24),
          _buildBenefits(boostLevel),
          const SizedBox(height: 24),
          _buildBoostButton(),
        ],
      ),
    );
  }

  Widget _buildBoostCard(int boostCount, int boostLevel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.rocket_launch, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            '$boostCount Boosts',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level $boostLevel',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(int level) {
    final benefits = [
      if (level >= 1) 'Higher audio quality',
      if (level >= 2) 'Higher upload limits',
      if (level >= 3) 'Animated server icon',
      if (level >= 7) 'Custom server banner',
      if (level >= 14) 'Vanity URL',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Benefits',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (benefits.isEmpty)
            Text(
              'Boost this server to unlock benefits',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
            )
          else
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      benefit,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoostButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Boost server - Coming Soon'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          'Boost Server',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.blurple),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
