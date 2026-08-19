import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/settings/application/user_settings_notifier.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/config/app_config.dart';

/// Privacy & Safety Settings Screen (Sleek Brutalist Black/Neon Theme)
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  Future<void> _setBool(String key, bool value) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    ref.read(userSettingsNotifierProvider.notifier).setBool(key, value);
  }

  void _show2FASheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textWhite.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _neonGreen.withValues(alpha: 0.1),
                      border: Border.all(color: _neonGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.security_rounded, color: _neonGreen, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TWO-FACTOR AUTH',
                          style: GoogleFonts.epilogue(
                            color: _textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Coming soon',
                          style: GoogleFonts.spaceMono(
                            color: _neonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Two-factor authentication will add an extra layer of security to your account using an authenticator app or SMS verification.',
                style: GoogleFonts.inter(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonGreen,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestDataExport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'EXPORT YOUR DATA',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
        content: Text(
          'We will prepare a copy of your personal data and send a download link to your registered email address. This may take up to 24 hours.',
          style: GoogleFonts.inter(color: _textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(
                    color: _textMuted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Request Export',
                style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (!AppConfig.hasApiBaseUrl) {
        throw Exception("API Base URL not configured.");
      }

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final token = client.auth.currentSession?.accessToken ?? "";
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl.endsWith('/')
            ? AppConfig.apiBaseUrl
            : '${AppConfig.apiBaseUrl}/',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.post('privacy/export', data: {
        'format': 'json',
      });

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data export initiated. You will receive an email when your files are ready.',
                style: GoogleFonts.spaceGrotesk(color: Colors.black),
              ),
              backgroundColor: _neonGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception("Failed to request export (HTTP ${response.statusCode})");
      }
    } on DioException catch (e) {
      String errMsg = "Failed to request export.";
      if (e.response != null && e.response!.data is Map) {
        final responseData = e.response!.data as Map;
        if (responseData.containsKey('error')) {
          errMsg = responseData['error'].toString();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeroSection(),
                      const SizedBox(height: 48),
                      _buildPrivacySection(),
                      const SizedBox(height: 40),
                      _buildVisibilitySection(),
                      const SizedBox(height: 40),
                      _buildSecuritySection(),
                      const SizedBox(height: 48),
                      _buildFooterData(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border.fromBorderSide(BorderSide(color: Colors.transparent)),
              ),
              child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'APP SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'SECURITY PROTOCOL',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'PRIVACY',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 0.9,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(color: _neonGreen),
              child: Text(
                'SECURITY',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANAGE YOUR PRIVACY',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Visibility, safety & data controls',
                    style: GoogleFonts.spaceMono(
                      color: _textMuted.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIRECT MESSAGES',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildAccessCard(
          title: 'ALLOW DMs',
          subtitle: 'Allow direct messages from anyone.',
          badge: 'OPEN',
          usePrimaryBadge: true,
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).allowDirectMessages, (val) {
            _setBool('privacy_allow_dms', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'FRIEND REQUESTS',
          subtitle: 'Allow anyone to send friend requests.',
          badge: 'SOCIAL',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).allowFriendRequests, (val) {
            _setBool('privacy_allow_friend_requests', val);
          }),
        ),
      ],
    );
  }

  Widget _buildVisibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISIBILITY',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildAccessCard(
          title: 'ONLINE STATUS',
          subtitle: 'Show when you are active.',
          badge: 'STATUS',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).showOnlineStatus, (val) {
            _setBool('privacy_show_online_status', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'READ RECEIPTS',
          subtitle: 'Show when messages are read.',
          badge: 'SEEN',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).readReceipts, (val) {
            _setBool('privacy_read_receipts', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'TYPING INDICATOR',
          subtitle: 'Show when you are typing.',
          badge: 'LIVE',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).typingIndicator, (val) {
            _setBool('privacy_typing_indicator', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'HIDE ACTIVITY',
          subtitle: 'Hide your game and app activity.',
          badge: 'GHOST',
          toggleWidget: _buildHardwareToggle(!ref.watch(userSettingsNotifierProvider).shareActivityStatus, (val) {
            _setBool('privacy_share_activity', !val); // inverted: hide activity = not sharing
          }),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SECURITY',
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
        _buildAccessCard(
          title: 'TWO-FACTOR AUTH',
          subtitle: 'Add extra security to your account.',
          badge: '2FA',
          usePrimaryBadge: true,
          toggleWidget: _buildHardwareToggle(false, (_) => _show2FASheet()),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _requestDataExport,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'EXPORT DATA',
                            style: GoogleFonts.epilogue(
                              color: _textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _textWhite.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'GDPR',
                              style: GoogleFonts.spaceMono(
                                color: _textWhite.withValues(alpha: 0.4),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Request a copy of your personal data.',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.download_outlined,
                    color: _textWhite.withValues(alpha: 0.2), size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          color: _neonGreen.withValues(alpha: 0.2),
          margin: const EdgeInsets.only(bottom: 24),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _neonGreen.withValues(alpha: 0.05),
            border: Border.symmetric(
              horizontal: BorderSide(color: _textWhite.withValues(alpha: 0.05)),
            ),
          ),
          child: Center(
            child: Text(
              'FLICKO // PRIVACY SHIELD ACTIVE',
              style: GoogleFonts.spaceMono(
                color: _textWhite.withValues(alpha: 0.3),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessCard({
    required String title,
    required String subtitle,
    required String badge,
    required Widget toggleWidget,
    bool usePrimaryBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(
          color: usePrimaryBadge
              ? _neonGreen.withValues(alpha: 0.4)
              : _textWhite.withValues(alpha: 0.05),
          width: usePrimaryBadge ? 1.5 : 1,
        ),
        boxShadow: usePrimaryBadge
            ? [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.epilogue(
                        color: _textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: usePrimaryBadge ? _neonGreen : Colors.transparent,
                        border: usePrimaryBadge
                            ? null
                            : Border.all(
                                color: _textWhite.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.spaceMono(
                          color: usePrimaryBadge
                              ? Colors.black
                              : _textWhite.withValues(alpha: 0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          toggleWidget,
        ],
      ),
    );
  }

  Widget _buildHardwareToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? _neonGreen : const Color(0xFF141416),
          border: Border.all(
            color: value ? _neonGreen : _textWhite.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 26 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? Colors.black : const Color(0xFF71717A),
                ),
                child: Center(
                  child: Container(
                    width: 2,
                    height: 8,
                    color: value
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
