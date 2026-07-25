import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/settings/application/user_settings_notifier.dart';
import 'package:mobile/features/store/data/notification_sound_service.dart';

/// Notifications Settings Screen (Sleek Brutalist Black/Neon Theme)
class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);
  static const Color _neon = Color(0xFF9B84EE);

  Future<void> _setBool(String key, bool value) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    ref.read(userSettingsNotifierProvider.notifier).setBool(key, value);
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
                      _buildPushSection(),
                      const SizedBox(height: 40),
                      _buildSoundsSection(),
                      const SizedBox(height: 40),
                      _buildQuietSection(),
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
                  'ALERT PREFERENCES',
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
          'NOTIFI\nCATIONS',
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
                'ALERTS',
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
                    'CONFIGURE NOTIFICATIONS',
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Push alerts, sounds & quiet hours',
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

  Widget _buildPushSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PUSH NOTIFICATIONS',
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
          title: 'ENABLE ALL',
          subtitle: 'Receive push notifications from Flicko.',
          badge: 'MASTER',
          usePrimaryBadge: true,
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).pushNotifications, (val) {
            _setBool('notif_push', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'DIRECT MESSAGES',
          subtitle: 'Notify when you receive a DM.',
          badge: 'DM',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).dmNotifications, (val) {
            _setBool('notif_dms', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'MENTIONS',
          subtitle: 'Notify when you are mentioned.',
          badge: '@',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).messageNotifications, (val) {
            _setBool('notif_messages', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'SERVER MESSAGES',
          subtitle: 'Notify for server channel messages.',
          badge: 'CHANNEL',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).serverNotifications, (val) {
            _setBool('notif_servers', val);
          }),
        ),
      ],
    );
  }

  Widget _buildSoundsSection() {
    final selectedSound = ref.watch(selectedSoundProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOUNDS',
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
        // Custom notification sound selector
        GestureDetector(
          onTap: () {
            showSoundPicker(
              context,
              selectedSound: selectedSound,
              onSoundSelected: (sound) {
                ref.read(selectedSoundProvider.notifier).setSound(sound);
              },
            );
          },
          child: _buildAccessCard(
            title: 'NOTIFICATION SOUND',
            subtitle: 'Current: ${selectedSound.name}',
            badge: selectedSound.previewEmoji ?? '🔔',
            usePrimaryBadge: selectedSound.isPremium,
            toggleWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _neonGreen.withValues(alpha: 0.1),
                border: Border.all(color: _neonGreen.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.music_note, color: _neonGreen, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'MESSAGE SOUND',
          subtitle: 'Play sound for new messages.',
          badge: 'AUDIO',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).soundOnNotification, (val) {
            _setBool('notif_sound', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'CALL SOUND',
          subtitle: 'Play sound for incoming calls.',
          badge: 'RING',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).callSound, (val) {
            _setBool('notif_call_sound', val);
          }),
        ),
        const SizedBox(height: 14),
        _buildAccessCard(
          title: 'VIBRATE',
          subtitle: 'Vibrate on notification.',
          badge: 'ALERT',
          toggleWidget: _buildHardwareToggle(ref.watch(userSettingsNotifierProvider).vibrateOnNotification, (val) {
            _setBool('notif_vibrate', val);
          }),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final currentStr = isStart ? settings.quietHoursStart : settings.quietHoursEnd;
    final parts = currentStr.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? (isStart ? 22 : 8),
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _neonGreen,
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF0C0C0E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    ref.read(userSettingsNotifierProvider.notifier).setString(
          isStart ? 'notif_quiet_start' : 'notif_quiet_end',
          formatted,
        );
  }

  Widget _buildQuietSection() {
    final settings = ref.watch(userSettingsNotifierProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUIET HOURS',
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
          title: 'ENABLE QUIET HOURS',
          subtitle: 'Disable notifications during set hours.',
          badge: 'SCHEDULE',
          toggleWidget: _buildHardwareToggle(settings.quietHoursEnabled, (val) {
            _setBool('notif_quiet_hours', val);
          }),
        ),
        if (settings.quietHoursEnabled) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              border: Border.all(
                color: _neonGreen.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TIME RANGE',
                  style: GoogleFonts.epilogue(
                    color: _textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notifications are silenced between these hours.',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(isStart: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _bgBlack,
                            border: Border.all(
                                color: _textWhite.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FROM',
                                style: GoogleFonts.spaceMono(
                                  color: _textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.quietHoursStart,
                                style: GoogleFonts.spaceGrotesk(
                                  color: _neonGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(isStart: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _bgBlack,
                            border: Border.all(
                                color: _textWhite.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TO',
                                style: GoogleFonts.spaceMono(
                                  color: _textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.quietHoursEnd,
                                style: GoogleFonts.spaceGrotesk(
                                  color: _neonGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
              'FLICKO // PREFERENCES SECURE',
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
